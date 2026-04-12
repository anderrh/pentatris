#!/usr/bin/env python3
"""
Hexfoil – Game Boy chiptune original
hUGE Tracker V6 .uge file

Key: F major (verse/chorus), D minor (bridge)

Structure:
  Intro(2) → Verse 1(4) → Chorus 1(2) → Verse 2(2) →
  Chorus 2(2) → Bridge/Dm(4) → Final Chorus(2) → Outro(2)
  = 20 order entries ≈ 2:30 at ~128 BPM

Channels:
  CH1 Duty 25%  – Lead melody
  CH2 Duty 50%  – Countermelody (a real second voice)
  CH3 Wave      – Bass (warm sawtooth)
  CH4 Noise     – Drums
"""

import struct
import os

# ==================================================================
# UGE V6 binary format
# ==================================================================
NO_NOTE = 90
UGE_V6 = 6


def write_ss(f, s):
    e = s.encode('ascii')[:255]
    f.write(bytes([len(e)]) + e + bytes(255 - len(e)))


def write_i(f, v):
    f.write(struct.pack('<i', v))


def write_cell(f, note=NO_NOTE, inst=0, vol=0, fx=0, fxp=0):
    write_i(f, note)
    write_i(f, inst)
    write_i(f, vol)
    write_i(f, fx)
    f.write(bytes([fxp & 0xFF]))


def write_inst(f, type_=0, name="", length=0, len_en=False,
               init_vol=0, sw_dir=0, sw_amt=0,
               sw_time=0, sw_inc=0, sw_shift=0,
               duty=2, out_lvl=0, wave=0, ctr_step=0, subpat=False):
    write_i(f, type_)
    write_ss(f, name)
    write_i(f, length)
    f.write(bytes([1 if len_en else 0, init_vol & 0x0F]))
    write_i(f, sw_dir)
    f.write(bytes([sw_amt & 0x07]))
    write_i(f, sw_time)
    write_i(f, sw_inc)
    write_i(f, sw_shift)
    f.write(bytes([duty & 0x03]))
    write_i(f, out_lvl)
    write_i(f, wave)
    write_i(f, ctr_step)
    f.write(bytes([1 if subpat else 0]))
    for _ in range(64):
        write_cell(f)


# ==================================================================
# Note constants  (hUGE: 0 = C3, 12 = C4, 24 = C5 …)
# ==================================================================
(C3, Cs3, D3, Eb3, E3, F3, Fs3, G3, Ab3, A3, Bb3, B3) = range(12)
(C4, Cs4, D4, Eb4, E4, F4, Fs4, G4, Ab4, A4, Bb4, B4) = range(12, 24)
(C5, Cs5, D5, Eb5, E5, F5, Fs5, G5) = range(24, 32)

# Noise channel "notes" (lower value = higher pitch)
HH, SN, KK = 4, 18, 36  # hi-hat, snare, kick


# ==================================================================
# Pattern builder
# ==================================================================
class Pat:
    """64-row pattern for one channel."""
    def __init__(self):
        self.cells = {}

    def n(self, row, note, inst):
        if 0 <= row < 64:
            self.cells[row] = (note, inst)
        return self

    def write(self, f, key):
        write_i(f, key)
        for r in range(64):
            if r in self.cells:
                nt, ins = self.cells[r]
                write_cell(f, note=nt, inst=ins)
            else:
                write_cell(f)


def empty():
    return Pat()


def mel(notes):
    """CH1 melody pattern from [(row, note), …]."""
    p = Pat()
    for r, n in notes:
        p.n(r, n, 1)
    return p


def ctr(notes):
    """CH2 counter-melody pattern from [(row, note), …]."""
    p = Pat()
    for r, n in notes:
        p.n(r, n, 2)
    return p


def bass(notes):
    """CH3 bass pattern from [(row, note), …]."""
    p = Pat()
    for r, n in notes:
        p.n(r, n, 1)
    return p


def drums(hits):
    """CH4 noise pattern from [(row, noise_note, instrument), …].
    Build lists in priority order: hi-hat, then snare, then kick –
    later entries overwrite earlier ones at the same row."""
    p = Pat()
    for r, n, i in hits:
        p.n(r, n, i)
    return p


# ==================================================================
# Drum templates
# ==================================================================

def _dk(hh_rows, sn_rows, kk_rows):
    """Assemble drum hits in priority order (HH < SN < KK)."""
    h = [(r, HH, 1) for r in hh_rows]
    h += [(r, SN, 2) for r in sn_rows]
    h += [(r, KK, 3) for r in kk_rows]
    return drums(h)


def dk_sparse():
    return _dk([16, 48], [], [0, 32])


def dk_buildup():
    hh = list(range(0, 32, 8)) + list(range(32, 64, 4))
    return _dk(hh, [40, 56], [0, 32])


def dk_std():
    return _dk(range(0, 64, 4), [8, 24, 40, 56], [0, 16, 32, 48])


def dk_drive():
    return _dk(range(0, 64, 2), [8, 24, 40, 56],
               [0, 6, 16, 22, 32, 38, 48, 54])


def dk_fill():
    hh = list(range(0, 48, 4))
    sn = [8, 24, 40] + list(range(48, 62, 2))
    return _dk(hh, sn, [0, 16, 32, 62])


def dk_half():
    return _dk(range(0, 64, 8), [16, 48], [0, 32])


# ==================================================================
# Bass helpers
# ==================================================================

def bass_4(r1, r2, r3, r4, style='verse'):
    """Bass over 4 chords (each 16 rows). r1…r4 are root hUGE notes.
    All styles use syncopation – offbeat hits, anticipations, rests –
    so the bass grooves rather than locking rigidly to the grid."""
    notes = []
    for start, root in [(0, r1), (16, r2), (32, r3), (48, r4)]:
        fifth = root + 7
        if style == 'sparse':
            # Root on beat 1, ghost on the "and" of 3
            notes += [(start, root), (start + 10, root)]
        elif style == 'verse':
            # Syncopated: beat 1, *and* of 2, beat 3, *and* of 3
            notes += [(start, root), (start + 6, fifth),
                      (start + 8, root), (start + 10, root)]
        elif style == 'drive':
            # Driving but syncopated: hit on 1, and-of-1, 3, and-of-3
            notes += [(start, root), (start + 2, root),
                      (start + 8, root), (start + 10, fifth)]
        elif style == 'bridge':
            # Dark, sparse with an offbeat anticipation
            notes += [(start, root), (start + 6, root),
                      (start + 14, root)]
        elif style == 'walk':
            # Syncopated walk: root, offbeat passing tone, fifth, anticipation
            notes += [(start, root), (start + 3, root + 2),
                      (start + 8, fifth), (start + 14, root + 4)]
    return bass(notes)


# ==================================================================
# Chord roots (octave 4 – brighter, less muddy on wave channel)
# ==================================================================
Gm_r = G4    # 19
Dm_r = D4    # 14
F_r  = F4    # 17
C_r  = C4    # 12
Bb_r = Bb4   # 22
A_r  = A4    # 21


# ==================================================================
# Build the complete song
# ==================================================================

def build_song():
    """Return (ch1[], ch2[], ch3[], ch4[], order[])."""
    ch1, ch2, ch3, ch4 = [], [], [], []

    # ------------------------------------------------------------------
    # 0  INTRO 1  (Gm | F | Dm | C) – sparse, mood-setting
    # ------------------------------------------------------------------
    # CH1: foreshadow the C–A–D rocking motif, slowly
    ch1.append(mel([
        (4, C5), (12, A4), (16, D5), (24, C5),
        (32, Bb4), (40, A4), (48, G4), (56, F4),
    ]))
    ch2.append(empty())
    ch3.append(bass_4(Gm_r, F_r, Dm_r, C_r, 'sparse'))
    ch4.append(dk_sparse())

    # ------------------------------------------------------------------
    # 1  INTRO 2  (Gm | Dm | F | C) – counter enters, building
    # ------------------------------------------------------------------
    ch1.append(mel([
        (0, A4), (4, G4), (8, F4), (12, A4),
        (16, D4), (24, F4),
        (32, E4), (36, G4), (40, C5),
        (48, Bb4), (52, A4), (56, G4), (60, F4),
    ]))
    ch2.append(ctr([
        (0, D4), (16, A3), (32, C4), (48, E4),
    ]))
    ch3.append(bass_4(Gm_r, Dm_r, F_r, C_r, 'sparse'))
    ch4.append(dk_buildup())

    # ------------------------------------------------------------------
    # 2  VERSE A  (Gm | Dm | F | C) – main motif: C–A–D rocking
    #    Original used F–D–G (down 3rd, up 4th); same intervals, new notes
    # ------------------------------------------------------------------
    ch1.append(mel([
        # Gm: rocking motif
        (0, C5), (3, A4), (6, D5),
        (8, C5), (11, A4), (14, D5),
        # Dm: chromatic oscillation (like original's F–E–F–E)
        (16, C5),
        (22, C5), (24, Bb4), (26, C5), (28, Bb4),
        # F: dramatic drop then return
        (32, F4), (36, G4), (40, Bb4),
        # C: long held resolution
        (48, A4),
    ]))
    ch2.append(ctr([
        # Sustained tones while melody rocks, then fills when melody holds
        (0, D4), (8, F4),
        (16, F4), (24, D4), (28, E4),
        (32, C4), (36, D4), (40, E4), (44, F4),
        (48, E4), (52, D4), (56, E4), (60, F4),
    ]))
    ch3.append(bass_4(Gm_r, Dm_r, F_r, C_r, 'verse'))
    ch4.append(dk_std())

    # ------------------------------------------------------------------
    # 3  VERSE B  (Gm | Dm | F | C) – answering phrase
    # ------------------------------------------------------------------
    ch1.append(mel([
        # Gm: ascending answer
        (0, G4), (4, A4), (6, Bb4), (8, C5), (12, D5), (14, C5),
        # Dm: graceful descent
        (16, Bb4), (18, A4), (20, G4), (24, F4), (28, E4),
        # F: arrival on tonic
        (32, F4), (36, G4), (40, A4),
        # C: transition
        (48, C5), (52, Bb4), (56, A4), (60, G4),
    ]))
    ch2.append(ctr([
        # Contrary motion – descends then ascends
        (0, D4), (8, E4), (12, F4),
        (16, D4), (24, A3), (30, Bb3),
        (32, C4), (40, D4), (44, E4),
        (48, E4), (52, F4), (56, E4), (60, D4),
    ]))
    ch3.append(bass_4(Gm_r, Dm_r, F_r, C_r, 'walk'))
    ch4.append(dk_std())

    # ------------------------------------------------------------------
    # 4  CHORUS A  (Bb | F | Dm | C) – energy!
    #    Rhythmic repeated notes (like original's Bb4 chorus)
    # ------------------------------------------------------------------
    ch1.append(mel([
        # Bb: driving repeated D5
        (0, D5), (2, D5), (4, D5), (6, D5),
        (8, D5), (10, D5), (12, D5), (14, C5),
        # F: repeated C5 with leap
        (16, C5), (18, C5), (20, C5), (22, C5),
        (24, C5), (26, C5), (28, E5), (30, C5),
        # Dm: melodic motion
        (32, Bb4), (34, Bb4), (36, Bb4), (38, A4),
        (40, Bb4), (42, C5), (44, D5), (46, C5),
        # C: resolution descent
        (48, C5), (52, Bb4), (56, A4), (60, G4),
    ]))
    # Counter: a real independent descending-then-ascending line
    ch2.append(ctr([
        # descends while melody drones on D5
        (0, Bb4), (3, A4), (6, G4),
        (8, F4), (10, G4), (12, A4),
        # ascends while melody drones on C5
        (16, G4), (18, A4), (20, Bb4),
        (24, A4), (26, G4), (28, F4),
        # own ascending phrase
        (32, D4), (34, E4), (36, F4), (38, G4),
        (40, A4), (42, G4), (44, F4),
        # contrary resolution (ascends while melody descends)
        (48, E4), (50, F4), (52, G4), (56, A4), (60, Bb4),
    ]))
    ch3.append(bass_4(Bb_r, F_r, Dm_r, C_r, 'drive'))
    ch4.append(dk_drive())

    # ------------------------------------------------------------------
    # 5  CHORUS B  (Bb | F | Dm | C) – climax + resolution
    # ------------------------------------------------------------------
    ch1.append(mel([
        # Bb: soaring phrase
        (0, D5), (2, E5), (4, F5), (8, E5), (10, D5), (12, C5), (14, D5),
        # F: stepwise descent
        (16, C5), (20, A4), (24, F4), (28, G4), (30, A4),
        # Dm: transitional
        (32, Bb4), (36, A4), (38, G4), (40, F4), (44, E4),
        # C: ascending for next section
        (48, E4), (50, F4), (52, G4), (56, A4), (58, Bb4), (60, C5),
    ]))
    ch2.append(ctr([
        (0, F4), (2, E4), (4, D4), (8, E4), (12, F4),
        (16, A4), (20, G4), (24, F4), (28, E4),
        (32, D4), (36, E4), (38, F4), (40, G4), (44, A4),
        (48, G4), (52, F4), (56, E4), (60, D4),
    ]))
    ch3.append(bass_4(Bb_r, F_r, Dm_r, C_r, 'drive'))
    ch4.append(dk_fill())

    # ------------------------------------------------------------------
    # 6  VERSE 2 A  (Gm | Dm | F | C) – inverted rocking: D–F–C
    # ------------------------------------------------------------------
    ch1.append(mel([
        (0, D5), (3, F5), (6, C5),
        (8, D5), (11, F5), (14, C5),
        (16, D5), (18, C5), (20, D5), (22, C5),
        (24, A4), (28, Bb4), (30, C5),
        (32, C5), (40, Bb4), (44, A4),
        (48, G4), (50, A4), (52, Bb4), (54, C5),
        (56, D5), (58, C5), (60, Bb4), (62, A4),
    ]))
    ch2.append(ctr([
        (0, Bb4), (6, A4), (8, G4), (14, F4),
        (16, F4), (22, E4), (24, F4), (30, D4),
        (32, A4), (36, G4), (40, F4), (44, E4),
        (48, E4), (52, D4), (56, E4), (60, F4),
    ]))
    ch3.append(bass_4(Gm_r, Dm_r, F_r, C_r, 'verse'))
    ch4.append(dk_std())

    # ------------------------------------------------------------------
    # 7  VERSE 2 B  (Gm | Dm | F | C) – varied continuation
    # ------------------------------------------------------------------
    ch1.append(mel([
        (0, Bb4), (4, C5), (6, D5), (8, C5), (12, Bb4), (14, A4),
        (16, G4), (20, A4), (24, Bb4), (28, A4), (30, G4),
        (32, A4), (36, C5), (40, Bb4),
        (48, A4), (50, G4), (52, F4), (56, G4), (60, A4), (62, Bb4),
    ]))
    ch2.append(ctr([
        (0, D4), (6, F4), (8, E4), (14, D4),
        (16, D4), (24, F4), (30, E4),
        (32, F4), (36, E4), (40, D4),
        (48, C4), (52, D4), (56, E4), (60, D4),
    ]))
    ch3.append(bass_4(Gm_r, Dm_r, F_r, C_r, 'walk'))
    ch4.append(dk_fill())

    # ==================================================================
    # BRIDGE  –  D minor (D E F G A Bb C#)
    # ==================================================================

    # ------------------------------------------------------------------
    # 8  BRIDGE 1  (Dm | Bb | Gm | A) – dark, lower register
    # ------------------------------------------------------------------
    ch1.append(mel([
        # Dm arpeggio
        (0, D4), (4, F4), (8, A4), (12, G4), (14, F4),
        # Bb: stepping up
        (16, D4), (20, E4), (24, F4), (28, G4),
        # Gm: plaintive
        (32, Bb4), (36, A4), (38, G4), (40, F4), (44, D4),
        # A: harmonic-minor C# for tension
        (48, Cs5), (52, D5), (56, Cs5), (60, D5),
    ]))
    ch2.append(ctr([
        # Offset entry, contrary motion
        (2, G4), (6, F4), (10, E4), (14, D4),
        (16, F4), (20, D4), (24, Bb3), (28, D4),
        (32, G4), (36, F4), (40, D4), (44, F4),
        (48, E4), (52, F4), (56, E4), (60, F4),
    ]))
    ch3.append(bass_4(Dm_r, Bb_r, Gm_r, A_r, 'bridge'))
    ch4.append(dk_half())

    # ------------------------------------------------------------------
    # 9  BRIDGE 2  (Dm | Bb | Gm | A) – building intensity
    # ------------------------------------------------------------------
    ch1.append(mel([
        (0, A4), (2, Bb4), (4, A4), (6, G4),
        (8, F4), (10, G4), (12, A4), (14, Bb4),
        (16, C5), (18, D5), (20, C5), (22, Bb4),
        (24, A4), (28, Bb4), (30, C5),
        (32, D5), (36, C5), (38, Bb4), (40, A4), (42, Bb4), (44, C5),
        (48, Cs5), (50, D5), (52, E5),
        (56, D5), (58, Cs5), (60, D5), (62, E5),
    ]))
    ch2.append(ctr([
        (0, D4), (4, E4), (8, D4), (12, E4),
        (16, F4), (20, G4), (24, F4), (28, D4),
        (32, G4), (38, F4), (42, D4),
        (48, A4), (52, Bb4), (56, A4), (60, A4),
    ]))
    ch3.append(bass_4(Dm_r, Bb_r, Gm_r, A_r, 'bridge'))
    ch4.append(dk_std())

    # ------------------------------------------------------------------
    # 10  BRIDGE CLIMAX 1  (Dm | C | Bb | A)
    # ------------------------------------------------------------------
    ch1.append(mel([
        (0, D5), (2, E5), (4, F5), (6, E5),
        (8, D5), (10, C5), (12, D5), (14, E5),
        (16, E5), (18, D5), (20, C5), (22, D5),
        (24, E5), (26, C5), (28, D5), (30, C5),
        (32, Bb4), (34, C5), (36, D5), (38, C5),
        (40, Bb4), (42, A4), (44, Bb4), (46, C5),
        (48, Cs5), (50, D5), (52, Cs5), (54, A4),
        (56, Bb4), (58, A4), (60, Cs5), (62, D5),
    ]))
    ch2.append(ctr([
        (0, A4), (4, D4), (8, F4), (12, G4),
        (16, G4), (20, A4), (24, G4), (28, F4),
        (32, F4), (36, G4), (40, F4), (44, D4),
        (48, E4), (52, A4), (56, E4), (60, F4),
    ]))
    ch3.append(bass_4(Dm_r, C_r, Bb_r, A_r, 'drive'))
    ch4.append(dk_drive())

    # ------------------------------------------------------------------
    # 11  BRIDGE CLIMAX 2 / TRANSITION  (Dm | C | Bb | A→F)
    #     Modulates back to F major at the end
    # ------------------------------------------------------------------
    ch1.append(mel([
        (0, D5), (2, F5), (4, D5), (8, A4), (12, Bb4), (14, C5),
        (16, D5), (20, C5), (24, Bb4), (28, A4),
        # brightening toward F major
        (32, Bb4), (36, C5), (40, D5), (44, C5),
        # the moment of return!
        (48, C5), (50, D5), (52, C5), (54, Bb4),
        (56, A4), (58, Bb4), (60, C5), (62, D5),
    ]))
    ch2.append(ctr([
        (0, A4), (4, F4), (8, E4), (12, D4),
        (16, G4), (20, F4), (24, E4), (28, F4),
        (32, D4), (36, E4), (40, F4), (44, G4),
        (48, A4), (52, G4), (56, F4), (60, G4), (62, A4),
    ]))
    ch3.append(bass_4(Dm_r, C_r, Bb_r, A_r, 'drive'))
    ch4.append(dk_fill())

    # ==================================================================
    # FINAL CHORUS  –  triumphant return to F major
    # ==================================================================

    # ------------------------------------------------------------------
    # 12  FINAL CHORUS A  (Bb | F | Dm | C) – high energy
    # ------------------------------------------------------------------
    ch1.append(mel([
        (0, D5), (2, D5), (4, D5), (6, E5),
        (8, F5), (10, E5), (12, D5), (14, C5),
        (16, C5), (18, D5), (20, E5), (22, F5),
        (24, E5), (26, D5), (28, C5), (30, D5),
        (32, D5), (34, C5), (36, Bb4), (38, A4),
        (40, Bb4), (42, C5), (44, D5), (46, E5),
        (48, E5), (50, D5), (52, C5), (54, D5),
        (56, E5), (58, F5), (60, E5), (62, D5),
    ]))
    ch2.append(ctr([
        # Parallel support, creating harmonic richness
        (0, Bb4), (4, C5), (8, D5), (12, A4),
        (16, A4), (20, C5), (24, C5), (28, A4),
        (32, Bb4), (36, G4), (40, G4), (44, Bb4),
        (48, C5), (52, A4), (56, C5), (60, C5),
    ]))
    ch3.append(bass_4(Bb_r, F_r, Dm_r, C_r, 'drive'))
    ch4.append(dk_drive())

    # ------------------------------------------------------------------
    # 13  FINAL CHORUS B  (Bb | F | C | F) – resolution
    # ------------------------------------------------------------------
    ch1.append(mel([
        (0, D5), (2, C5), (4, D5), (6, E5), (8, D5), (12, C5), (14, Bb4),
        (16, A4), (20, Bb4), (24, C5), (28, D5),
        (32, E5), (36, D5), (40, C5), (44, D5),
        # Final resolution to F
        (48, C5), (50, Bb4), (52, A4),
        (56, F4), (60, A4), (62, C5),
    ]))
    ch2.append(ctr([
        (0, Bb4), (4, A4), (8, Bb4), (12, A4),
        (16, F4), (20, G4), (24, A4), (28, Bb4),
        (32, C5), (36, Bb4), (40, A4), (44, G4),
        (48, A4), (52, F4), (56, C4), (60, F4),
    ]))
    ch3.append(bass_4(Bb_r, F_r, C_r, F_r, 'drive'))
    ch4.append(dk_fill())

    # ==================================================================
    # OUTRO
    # ==================================================================

    # ------------------------------------------------------------------
    # 14  OUTRO 1  (Gm | F | Dm | C) – winding down
    # ------------------------------------------------------------------
    ch1.append(mel([
        (0, C5), (8, Bb4), (16, A4), (24, G4),
        (32, F4), (40, G4), (48, A4), (56, G4),
    ]))
    ch2.append(ctr([
        (0, G4), (16, F4), (32, D4), (48, E4),
    ]))
    ch3.append(bass_4(Gm_r, F_r, Dm_r, C_r, 'sparse'))
    ch4.append(dk_half())

    # ------------------------------------------------------------------
    # 15  OUTRO 2  (F | F | F | F) – final tonic
    # ------------------------------------------------------------------
    ch1.append(mel([
        (0, F4), (8, A4), (16, C5), (32, A4), (48, F4),
    ]))
    ch2.append(ctr([
        (0, C4), (16, F4), (32, C4), (48, A3),
    ]))
    ch3.append(bass([(0, F3), (32, F3)]))
    ch4.append(dk_sparse())

    # ------------------------------------------------------------------
    # SONG ORDER
    # ------------------------------------------------------------------
    order = [
        0, 1,           # Intro
        2, 3, 2, 3,     # Verse 1 (repeat for familiarity)
        4, 5,           # Chorus 1
        6, 7,           # Verse 2 (new melody, same chords)
        4, 5,           # Chorus 2
        8, 9, 10, 11,   # Bridge (D minor – key change!)
        12, 13,         # Final Chorus (triumphant return to F major)
        14, 15,         # Outro
    ]

    return ch1, ch2, ch3, ch4, order


# ==================================================================
# Write .uge file
# ==================================================================

def write_song(path):
    ch1, ch2, ch3, ch4, order = build_song()
    n = len(ch1)   # unique patterns per channel (16)
    empty_key = 4 * n
    total_keys = 4 * n + 1

    with open(path, 'wb') as f:
        # ---- header ----
        write_i(f, UGE_V6)
        write_ss(f, "Hexfoil")
        write_ss(f, "")
        write_ss(f, "Original chiptune for geometry dash")

        # ---- 15 duty instruments ----
        # 0: Melody (25% duty, bright lead, gentle decay)
        write_inst(f, type_=0, name="Melody",
                   init_vol=12, duty=1, sw_dir=1, sw_amt=1)
        # 1: Counter (50% duty, rounder, sustained)
        write_inst(f, type_=0, name="Counter",
                   init_vol=10, duty=2)
        for _ in range(13):
            write_inst(f, type_=0)

        # ---- 15 wave instruments ----
        # 0: Bass (warm sawtooth, full output, wave 0)
        write_inst(f, type_=1, name="Bass", out_lvl=1, wave=0)
        for _ in range(14):
            write_inst(f, type_=1)

        # ---- 15 noise instruments ----
        write_inst(f, type_=2, name="HiHat",
                   init_vol=6, length=8, len_en=True,
                   sw_dir=1, sw_amt=3)
        write_inst(f, type_=2, name="Snare",
                   init_vol=12, length=16, len_en=True,
                   sw_dir=1, sw_amt=2)
        write_inst(f, type_=2, name="Kick",
                   init_vol=15, length=24, len_en=True,
                   sw_dir=1, sw_amt=1)
        for _ in range(12):
            write_inst(f, type_=2)

        # ---- 16 waves ----
        # 0: warm sawtooth – descending staircase, doubled samples
        #    All harmonics present, smooth uniform steps = warm not harsh
        f.write(bytes([15, 15, 14, 14, 13, 13, 12, 12,
                        11, 11, 10, 10,  9,  9,  8,  8,
                         7,  7,  6,  6,  5,  5,  4,  4,
                         3,  3,  2,  2,  1,  1,  0,  0]))
        # 1: slight-curve sawtooth – exponential-ish descent, natural decay
        f.write(bytes([15, 15, 14, 14, 13, 13, 12, 11,
                        11, 10,  9,  9,  8,  7,  7,  6,
                         5,  5,  4,  4,  3,  3,  2,  2,
                         2,  1,  1,  1,  0,  0,  0,  0]))
        # 2: triangle (fallback)
        f.write(bytes(list(range(16)) + list(range(15, -1, -1))))
        # 3-15: silence
        for _ in range(13):
            f.write(bytes(32))

        # ---- timing ----
        write_i(f, 7)        # ticks_per_row  → ~128 BPM at 4 rows/beat
        f.write(bytes([0]))  # timer disabled
        write_i(f, 0)        # timer divider

        # ---- patterns ----
        write_i(f, total_keys)
        for i in range(n):
            ch1[i].write(f, i)
        for i in range(n):
            ch2[i].write(f, n + i)
        for i in range(n):
            ch3[i].write(f, 2 * n + i)
        for i in range(n):
            ch4[i].write(f, 3 * n + i)
        # empty pattern
        write_i(f, empty_key)
        for _ in range(64):
            write_cell(f)

        # ---- order matrix ----
        order_len = len(order) + 1   # +1 for loop-back
        for offset in [0, n, 2 * n, 3 * n]:
            write_i(f, order_len)
            for idx in order:
                write_i(f, offset + idx)
            write_i(f, 0)  # loop to position 0

        # ---- 16 routines (empty) ----
        for _ in range(16):
            write_i(f, 0)

    size = os.path.getsize(path)
    dur_sec = len(order) * 64 * 7 / 59.7275
    print(f"Hexfoil – GB chiptune")
    print(f"Key: F major | Bridge: D minor | ~128 BPM")
    print(f"Patterns: {n}/ch × 4 ch + 1 empty = {total_keys}")
    print(f"Order: {len(order)} entries")
    print(f"Duration: ~{dur_sec:.0f}s ({dur_sec / 60:.1f} min)")
    print(f"Output: {path} ({size} bytes)")


# ==================================================================
# Main
# ==================================================================

if __name__ == '__main__':
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'hexfoil.uge')
    write_song(out)
