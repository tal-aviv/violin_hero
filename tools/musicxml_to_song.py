#!/usr/bin/env python3
"""Convert a MusicXML score into a SongDefinition entry for kSongLibrary
in violin_hero/lib/main.dart.

Usage:
    python3 tools/musicxml_to_song.py path/to/score.musicxml \\
        [--id song_id] [--title "Display Title"] [--admin]

Reads MusicXML, maps every pitch to the violin_hero note pool, converts
note durations to NoteDuration enum values, and prints a ready-to-paste
Dart block on stdout. Reports issues (out-of-range pitches, beat-count
mismatches, unsupported rhythms) on stderr.

Companion to the score-to-song skill at .cursor/skills/score-to-song/.
The note pool below MUST stay in sync with `_songNotePool` and `_allNotes`
in lib/main.dart.
"""

import argparse
import io
import sys
import xml.etree.ElementTree as ET
import zipfile
from typing import List, Optional, Tuple

# ── violin_hero note pool ────────────────────────────────────────────
# Each entry: (noteId, midi, string_index)
#   string_index: 0=G, 1=D, 2=A, 3=E
#
# Every pitch is unique by MIDI number, so the converter assigns the
# noteId from MIDI alone — no string-choice ambiguity given the current
# pool.
NOTE_POOL: List[Tuple[str, int, int]] = [
    ("G3_G", 55, 0),
    ("A3_G", 57, 0),
    ("B3_G", 59, 0),
    ("C4_G", 60, 0),
    ("D4_D", 62, 1),
    ("E4_D", 64, 1),
    ("F#4_D", 66, 1),
    ("G4_D", 67, 1),
    ("A4_A", 69, 2),
    ("B4_A", 71, 2),
    ("C5_A", 72, 2),
    ("C#5_A", 73, 2),
    ("D5_A", 74, 2),
    ("E5_E", 76, 3),
    ("F#5_E", 78, 3),
    ("G#5_E", 80, 3),
    ("A5_E", 81, 3),
]

PITCH_TO_SEMITONE = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}

# (beat_units, enum_name)
PITCHED_DURATIONS = [
    (0.25, "sixteenth"),
    (0.5, "eighth"),
    (0.75, "dottedEighth"),
    (1.0, "quarter"),
    (1.5, "dottedQuarter"),
    (2.0, "half"),
    (3.0, "dottedHalf"),
    (4.0, "whole"),
]

REST_DURATIONS = [
    (0.25, "sixteenthRest"),
    (0.5, "eighthRest"),
    (1.0, "quarterRest"),
    (1.5, "dottedQuarterRest"),
    (2.0, "halfRest"),
    (3.0, "dottedHalfRest"),
    (4.0, "wholeRest"),
]


def midi_for(step: str, octave: int, alter: int) -> int:
    return 12 * (octave + 1) + PITCH_TO_SEMITONE[step] + alter


def note_id_for_midi(midi: int, prefer_string: Optional[int] = None) -> Optional[str]:
    """Return the noteId for a given MIDI pitch.

    `prefer_string` is supported for forward-compatibility (in case the
    pool grows to have multiple positions for the same pitch), but the
    current pool has each pitch exactly once.
    """
    candidates = [e for e in NOTE_POOL if e[1] == midi]
    if not candidates:
        return None
    if prefer_string is not None:
        with_pref = [c for c in candidates if c[2] == prefer_string]
        if with_pref:
            return with_pref[0][0]
    candidates.sort(key=lambda e: e[2])  # prefer lower string on ties
    return candidates[0][0]


def beat_units_to_enum(beats: float, is_rest: bool) -> Optional[str]:
    table = REST_DURATIONS if is_rest else PITCHED_DURATIONS
    for entry in table:
        if abs(entry[0] - beats) < 1e-3:
            return entry[1]
    return None


def _read_musicxml_bytes(path: str) -> bytes:
    """Return the raw XML bytes for a score, transparently handling both
    plain MusicXML files and the compressed .mxl format (a ZIP archive
    containing the score XML — produced by Audiveris and others, sometimes
    with a misleading .musicxml extension).
    """
    with open(path, "rb") as f:
        head = f.read(4)
    if head[:2] == b"PK":
        with zipfile.ZipFile(path) as zf:
            score_path = None
            try:
                with zf.open("META-INF/container.xml") as container:
                    container_root = ET.parse(container).getroot()
                ns = {"c": "urn:oasis:names:tc:opendocument:xmlns:container"}
                rootfile = container_root.find(".//c:rootfile", ns)
                if rootfile is None:
                    rootfile = container_root.find(".//rootfile")
                if rootfile is not None:
                    score_path = rootfile.get("full-path")
            except KeyError:
                pass
            if score_path is None:
                for name in zf.namelist():
                    if name.startswith("META-INF/"):
                        continue
                    if name.endswith(".xml") or name.endswith(".musicxml"):
                        score_path = name
                        break
            if score_path is None:
                raise SystemExit(
                    f"{path} is a ZIP archive but no score XML was found inside"
                )
            return zf.read(score_path)
    with open(path, "rb") as f:
        return f.read()


def parse_score(path: str):
    xml_bytes = _read_musicxml_bytes(path)
    root = ET.fromstring(xml_bytes)

    note_ids: List[str] = []
    durations: List[str] = []
    issues: List[str] = []

    parts = root.findall(".//part")
    if not parts:
        raise SystemExit("no <part> element found in MusicXML")
    if len(parts) > 1:
        issues.append(
            f"score has {len(parts)} parts — only the first (id={parts[0].get('id')}) "
            "is read. Edit the MusicXML to remove other parts if needed."
        )
    part = parts[0]

    divisions = 1
    measure_index = 0
    for measure in part.findall("measure"):
        measure_index += 1
        attrs = measure.find("attributes")
        if attrs is not None:
            divs_el = attrs.find("divisions")
            if divs_el is not None and divs_el.text:
                divisions = int(divs_el.text)

        for note in measure.findall("note"):
            if note.find("chord") is not None:
                # Skip secondary notes of a chord — only the principal pitch
                # is emitted as a single slot.
                continue

            duration_el = note.find("duration")
            if duration_el is None or not duration_el.text:
                # Grace notes have no duration. The current rhythm engine
                # has no grace-note support, so skip them and warn.
                issues.append(
                    f"M{measure_index}: <note> with no <duration> (likely a grace note) — skipped"
                )
                continue

            duration_divs = int(duration_el.text)
            beats = duration_divs / divisions if divisions else 0.0

            is_rest = note.find("rest") is not None
            if is_rest:
                enum_name = beat_units_to_enum(beats, is_rest=True)
                if enum_name is None:
                    issues.append(
                        f"M{measure_index}: rest of {beats:.3f} beats has no NoteDuration mapping"
                    )
                    continue
                note_ids.append("''")
                durations.append(f"NoteDuration.{enum_name}")
                continue

            pitch = note.find("pitch")
            if pitch is None:
                issues.append(
                    f"M{measure_index}: <note> with no <pitch> and no <rest> — skipped"
                )
                continue

            step = pitch.findtext("step", "")
            alter_text = pitch.findtext("alter", "0") or "0"
            alter = int(float(alter_text))
            octave = int(pitch.findtext("octave", "0"))
            if step not in PITCH_TO_SEMITONE:
                issues.append(
                    f"M{measure_index}: unknown pitch step '{step}' — skipped"
                )
                continue
            midi = midi_for(step, octave, alter)

            # MusicXML <string> uses 1=highest, 4=lowest on a four-string
            # instrument. Map to violin_hero's 0=G..3=E.
            prefer_string = None
            string_el = note.find(".//technical/string")
            if string_el is not None and string_el.text:
                ms = int(string_el.text)
                prefer_string = {1: 3, 2: 2, 3: 1, 4: 0}.get(ms)

            note_id = note_id_for_midi(midi, prefer_string)
            if note_id is None:
                accidental = ""
                if alter == 1:
                    accidental = "#"
                elif alter == -1:
                    accidental = "b"
                elif alter != 0:
                    accidental = f"({alter:+d})"
                issues.append(
                    f"M{measure_index}: pitch {step}{accidental}{octave} (MIDI {midi}) "
                    "is outside the violin_hero note pool — extend _songNotePool / _allNotes "
                    "in lib/main.dart, or transpose the song"
                )
                continue

            enum_name = beat_units_to_enum(beats, is_rest=False)
            if enum_name is None:
                issues.append(
                    f"M{measure_index}: note of {beats:.3f} beats has no NoteDuration mapping "
                    "(supported: 0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4 quarter-beats)"
                )
                continue

            note_ids.append(f"'{note_id}'")
            durations.append(f"NoteDuration.{enum_name}")

    return note_ids, durations, issues


def emit_dart(
    note_ids: List[str],
    durations: List[str],
    song_id: str,
    title: str,
    admin: bool,
) -> str:
    out: List[str] = []
    out.append("SongDefinition(")
    out.append(f"  id: '{song_id}',")
    out.append(f"  title: '{title}',")
    out.append("  icon: Icons.music_note_rounded,")
    out.append("  color: Color(0xFF4FB38E),")
    if admin:
        out.append("  visibility: SongVisibility.admin,")
    out.append("  noteIds: [")
    for chunk in _chunks(note_ids, 8):
        out.append("    " + ", ".join(chunk) + ",")
    out.append("  ],")
    out.append("  noteDurations: [")
    for chunk in _chunks(durations, 4):
        out.append("    " + ", ".join(chunk) + ",")
    out.append("  ],")
    out.append("),")
    return "\n".join(out)


def _chunks(seq, n):
    for i in range(0, len(seq), n):
        yield seq[i : i + n]


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Convert a MusicXML score to a SongDefinition Dart block."
    )
    ap.add_argument("musicxml_path", help="path to a .musicxml or .xml file")
    ap.add_argument("--id", default="my_song", help="snake_case song id (default: my_song)")
    ap.add_argument("--title", default="My Song", help="display title (default: 'My Song')")
    ap.add_argument(
        "--admin",
        action="store_true",
        help="mark the song with visibility: SongVisibility.admin (staging library)",
    )
    args = ap.parse_args()

    note_ids, durations, issues = parse_score(args.musicxml_path)

    if len(note_ids) != len(durations):
        print(
            f"internal error: noteIds ({len(note_ids)}) != noteDurations ({len(durations)})",
            file=sys.stderr,
        )
        return 2

    if issues:
        print("Transcription issues:", file=sys.stderr)
        for issue in issues:
            print(f"  - {issue}", file=sys.stderr)
        suffix = "s" if len(issues) != 1 else ""
        print(f"  ({len(issues)} issue{suffix} total)", file=sys.stderr)
        print("", file=sys.stderr)

    print(emit_dart(note_ids, durations, args.id, args.title, args.admin))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
