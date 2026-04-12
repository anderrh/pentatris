#!/usr/bin/env python3
"""
PENTATRIS - A falling block puzzle anthem for Game Boy
Generates a .uge file (hUGE Tracker V6 format)

Mood: Melancholy Soviet worker march meets the stirring hope of
      the Internationale. Stately, wistful, with moments of
      defiant rising melody.

Key design choices for musicality:
  - Channels are STAGGERED: drums anticipate beats, bass walks between
    melody notes, harmony sustains across lead rests. Nothing lands
    together except at intentional moments of impact.
  - Every pattern is unique - no copy-paste. Melodies develop and
    transform across the song.
  - Drum patterns vary constantly: fills, accents, and ghost notes
    shift every section.

Key: C minor (C D Eb F G Ab Bb)
Tempo: ticks_per_row=6
Duration: ~2 minutes
"""

import struct

NO_NOTE = 90
UGE_FORMAT_VERSION = 6

def write_uge_shortstring(f, s):
    encoded = s.encode('ascii')[:255]
    f.write(bytes([len(encoded)]))
    f.write(encoded)
    f.write(bytes(255 - len(encoded)))

def write_uge_int(f, value):
    f.write(struct.pack('<i', value))

def write_uge_cell(f, note=NO_NOTE, instrument=0, volume=0, effect_code=0, effect_params=0):
    write_uge_int(f, note)
    write_uge_int(f, instrument)
    write_uge_int(f, volume)
    write_uge_int(f, effect_code)
    f.write(bytes([effect_params & 0xFF]))

def write_uge_instrument(f, type_=0, name="", length=0, length_enabled=False,
                         initial_volume=0, vol_sweep_dir=0, vol_sweep_amount=0,
                         sweep_time=0, sweep_inc_dec=0, sweep_shift=0,
                         duty=2, output_level=0, waveform=0, counter_step=0,
                         subpattern_enabled=False):
    write_uge_int(f, type_)
    write_uge_shortstring(f, name)
    write_uge_int(f, length)
    f.write(bytes([1 if length_enabled else 0]))
    f.write(bytes([initial_volume & 0x0F]))
    write_uge_int(f, vol_sweep_dir)
    f.write(bytes([vol_sweep_amount & 0x07]))
    write_uge_int(f, sweep_time)
    write_uge_int(f, sweep_inc_dec)
    write_uge_int(f, sweep_shift)
    f.write(bytes([duty & 0x03]))
    write_uge_int(f, output_level)
    write_uge_int(f, waveform)
    write_uge_int(f, counter_step)
    f.write(bytes([1 if subpattern_enabled else 0]))
    for _ in range(64):
        write_uge_cell(f)

C3, D3, Eb3, F3, G3, Ab3, Bb3 = 0, 2, 3, 5, 7, 8, 10
C4, D4, Eb4, F4, G4, Ab4, Bb4 = 12, 14, 15, 17, 19, 20, 22
C5, D5, Eb5, F5, G5, Ab5, Bb5 = 24, 26, 27, 29, 31, 32, 34
C6, D6, Eb6, F6, G6 = 36, 38, 39, 41, 43
B3, B4, B5 = 11, 23, 35
A3, A4, A5 = 9, 21, 33
E3, E4, E5 = 4, 16, 28

HIHAT = 4
HIHAT_OPEN = 8
SNARE = 18
KICK = 36
TOM_HI = 24
TOM_LO = 30

EFF_ARP = 0
EFF_VIBRATO = 4
EFF_SETVOL = 12
EFF_NOTECUT = 14


class Pattern:
    def __init__(self):
        self.cells = {}
    def note(self, row, note, instrument=0, volume=0, effect_code=0, effect_params=0):
        if 0 <= row < 64:
            self.cells[row] = (note, instrument, volume, effect_code, effect_params)
        return self
    def arp(self, row, base_note, semitones_up, instrument=0):
        return self.note(row, base_note, instrument,
                        effect_code=EFF_ARP, effect_params=(semitones_up << 4))
    def vol(self, row, note, instrument, volume):
        return self.note(row, note, instrument, effect_code=EFF_SETVOL, effect_params=volume)
    def vibrato(self, row, note, instrument=0, speed=3, depth=4):
        return self.note(row, note, instrument,
                        effect_code=EFF_VIBRATO, effect_params=(speed << 4) | depth)
    def write(self, f, key):
        write_uge_int(f, key)
        for row in range(64):
            if row in self.cells:
                n, i, v, ec, ep = self.cells[row]
                write_uge_cell(f, note=n, instrument=i, volume=v,
                              effect_code=ec, effect_params=ep)
            else:
                write_uge_cell(f)

def empty_pattern():
    return Pattern()

# ============================================
# DRUMS - all unique, staggered from melody
# ============================================

def drums_00_intro():
    p = Pattern()
    p.vol(12, SNARE, instrument=2, volume=4)
    p.vol(44, SNARE, instrument=2, volume=5)
    return p

def drums_01_march_enters():
    p = Pattern()
    p.note(6, KICK, instrument=3)
    p.note(28, KICK, instrument=3)
    p.note(20, SNARE, instrument=2)
    p.note(52, SNARE, instrument=2)
    for row in [2, 14, 36, 46]:
        p.vol(row, HIHAT, instrument=1, volume=4)
    return p

def drums_02_march_answer():
    p = Pattern()
    p.note(4, KICK, instrument=3)
    p.note(38, KICK, instrument=3)
    p.note(22, SNARE, instrument=2)
    p.note(54, SNARE, instrument=2)
    for row in [10, 18, 34, 46, 60]:
        p.vol(row, HIHAT, instrument=1, volume=4)
    p.vol(30, HIHAT_OPEN, instrument=1, volume=5)
    return p

def drums_03_weary():
    p = Pattern()
    p.note(2, KICK, instrument=3)
    p.note(34, KICK, instrument=3)
    p.vol(18, SNARE, instrument=2, volume=7)
    p.vol(50, SNARE, instrument=2, volume=7)
    for row in [10, 26, 42, 58]:
        p.vol(row, HIHAT, instrument=1, volume=3)
    return p

def drums_04_cadence_fill():
    p = Pattern()
    p.note(6, KICK, instrument=3)
    p.vol(18, SNARE, instrument=2, volume=6)
    p.vol(10, HIHAT, instrument=1, volume=3)
    p.vol(26, HIHAT, instrument=1, volume=3)
    for row in [32, 36, 40, 42, 44, 46, 48, 50, 52, 54]:
        vol = 4 + (row - 32) // 4
        p.vol(row, SNARE, instrument=2, volume=min(vol, 12))
    p.note(56, KICK, instrument=3)
    p.note(60, KICK, instrument=3)
    return p

def drums_05_solidarity_1():
    p = Pattern()
    p.note(2, KICK, instrument=3)
    p.note(26, KICK, instrument=3)
    p.note(42, KICK, instrument=3)
    p.note(14, SNARE, instrument=2)
    p.note(34, SNARE, instrument=2)
    p.note(54, SNARE, instrument=2)
    for row in [6, 18, 30, 46, 62]:
        p.note(row, HIHAT, instrument=1)
    return p

def drums_06_solidarity_2():
    p = Pattern()
    p.note(6, KICK, instrument=3)
    p.note(22, KICK, instrument=3)
    p.note(38, KICK, instrument=3)
    p.note(58, KICK, instrument=3)
    p.note(14, SNARE, instrument=2)
    p.note(30, SNARE, instrument=2)
    p.note(46, SNARE, instrument=2)
    p.vol(2, SNARE, instrument=2, volume=4)
    p.vol(34, SNARE, instrument=2, volume=4)
    for row in range(0, 64, 4):
        if row not in [2, 6, 14, 22, 30, 34, 38, 46, 58]:
            p.vol(row, HIHAT, instrument=1, volume=5)
    return p

def drums_07_soaring():
    p = Pattern()
    p.note(2, HIHAT_OPEN, instrument=1)
    p.note(18, HIHAT_OPEN, instrument=1)
    p.note(6, KICK, instrument=3)
    p.note(14, KICK, instrument=3)
    p.note(34, KICK, instrument=3)
    p.note(50, KICK, instrument=3)
    p.note(10, SNARE, instrument=2)
    p.note(26, SNARE, instrument=2)
    p.note(42, SNARE, instrument=2)
    p.note(58, SNARE, instrument=2)
    for row in [22, 30, 38, 46, 54, 62]:
        p.vol(row, HIHAT, instrument=1, volume=4)
    return p

def drums_08_dev_1():
    p = Pattern()
    for row in [3, 15, 27, 39, 51]:
        p.note(row, KICK, instrument=3)
    for row in [9, 21, 45, 57]:
        p.note(row, SNARE, instrument=2)
    for row in range(1, 64, 6):
        if row < 64:
            p.vol(row, HIHAT, instrument=1, volume=5)
    return p

def drums_09_dev_2():
    p = Pattern()
    for row in range(1, 64, 4):
        p.note(row, HIHAT, instrument=1)
    for row in [3, 11, 19, 35, 43, 55]:
        p.note(row, KICK, instrument=3)
    for row in [7, 23, 39, 51, 63]:
        p.note(row, SNARE, instrument=2)
    return p

def drums_10_climax_1():
    p = Pattern()
    for row in [1, 5, 9, 13]:
        p.note(row, KICK, instrument=3)
    for row in [29, 37, 45, 53]:
        p.note(row, KICK, instrument=3)
    for row in [17, 25, 41, 49, 61]:
        p.note(row, SNARE, instrument=2)
    p.note(0, HIHAT_OPEN, instrument=1)
    p.note(16, HIHAT_OPEN, instrument=1)
    for row in range(3, 64, 8):
        if row not in [1,5,9,13,17,25,29,37,41,45,49,53,61]:
            p.vol(row, HIHAT, instrument=1, volume=5)
    return p

def drums_11_climax_2():
    p = Pattern()
    p.note(0, TOM_HI, instrument=3)
    p.note(2, TOM_LO, instrument=3)
    for row in [5, 13, 21, 37, 45, 53]:
        p.note(row, KICK, instrument=3)
    for row in [8, 9, 10, 11]:
        p.vol(row, SNARE, instrument=2, volume=6 + (row-8))
    for row in [40, 41, 42, 43]:
        p.vol(row, SNARE, instrument=2, volume=6 + (row-40))
    for row in [17, 33, 49]:
        p.note(row, SNARE, instrument=2)
    p.note(4, HIHAT_OPEN, instrument=1)
    for row in [15, 23, 31, 47, 55, 63]:
        p.vol(row, HIHAT, instrument=1, volume=4)
    return p

def drums_12_recap():
    p = Pattern()
    p.note(4, KICK, instrument=3)
    p.note(26, KICK, instrument=3)
    p.note(36, KICK, instrument=3)
    p.note(58, KICK, instrument=3)
    p.note(14, SNARE, instrument=2)
    p.note(42, SNARE, instrument=2)
    p.vol(30, SNARE, instrument=2, volume=5)
    p.vol(54, SNARE, instrument=2, volume=5)
    for row in [2, 10, 18, 22, 34, 46, 50, 62]:
        p.note(row, HIHAT, instrument=1)
    return p

def drums_13_recap_2():
    p = Pattern()
    p.note(2, KICK, instrument=3)
    p.note(18, KICK, instrument=3)
    p.note(34, KICK, instrument=3)
    p.note(50, KICK, instrument=3)
    p.note(10, SNARE, instrument=2)
    p.note(26, SNARE, instrument=2)
    p.note(42, SNARE, instrument=2)
    p.note(58, SNARE, instrument=2)
    for row in [6, 14, 22, 30, 38, 46, 54, 62]:
        p.vol(row, HIHAT, instrument=1, volume=5)
    return p

def drums_14_recap_cadence():
    p = Pattern()
    p.note(4, KICK, instrument=3)
    p.note(12, SNARE, instrument=2)
    p.note(20, KICK, instrument=3)
    p.note(28, SNARE, instrument=2)
    p.vol(8, HIHAT, instrument=1, volume=5)
    p.vol(16, HIHAT, instrument=1, volume=5)
    p.vol(24, HIHAT, instrument=1, volume=5)
    p.note(32, TOM_HI, instrument=3)
    p.note(35, TOM_HI, instrument=3)
    p.note(38, TOM_LO, instrument=3)
    p.note(41, TOM_LO, instrument=3)
    p.note(44, SNARE, instrument=2)
    p.note(46, SNARE, instrument=2)
    p.note(48, SNARE, instrument=2)
    p.note(50, SNARE, instrument=2)
    p.note(52, KICK, instrument=3)
    p.note(56, KICK, instrument=3)
    p.vol(54, SNARE, instrument=2, volume=10)
    p.vol(58, SNARE, instrument=2, volume=8)
    p.vol(60, SNARE, instrument=2, volume=6)
    p.vol(62, SNARE, instrument=2, volume=4)
    return p

def drums_15_coda_1():
    p = Pattern()
    p.vol(6, KICK, instrument=3, volume=5)
    p.vol(22, SNARE, instrument=2, volume=4)
    p.vol(38, KICK, instrument=3, volume=4)
    p.vol(54, SNARE, instrument=2, volume=3)
    return p

def drums_16_coda_2():
    p = Pattern()
    p.vol(10, KICK, instrument=3, volume=3)
    p.vol(42, SNARE, instrument=2, volume=2)
    return p

def drums_17_final():
    p = Pattern()
    p.vol(8, KICK, instrument=3, volume=2)
    return p

# ============================================
# BASS - offset from lead melody
# ============================================

def bass_00_intro():
    p = Pattern()
    p.note(8, C3, instrument=1)
    p.note(24, G3, instrument=1)
    return p

def bass_01_march_A1():
    p = Pattern()
    for row, note in [(4, C3), (10, Eb3), (20, G3), (28, Ab3),
                      (36, G3), (44, F3), (52, Eb3), (60, D3)]:
        p.note(row, note, instrument=1)
    return p

def bass_02_march_A2():
    p = Pattern()
    for row, note in [(2, C3), (6, D3), (14, Eb3), (22, F3),
                      (30, G3), (38, Ab3), (46, G3), (54, F3)]:
        p.note(row, note, instrument=1)
    return p

def bass_03_weary():
    p = Pattern()
    for row, note in [(3, C3), (10, Eb3), (18, Ab3),
                      (28, G3), (34, F3), (42, Eb3),
                      (50, D3), (58, C3)]:
        p.note(row, note, instrument=1)
    return p

def bass_04_cadence():
    p = Pattern()
    for row, note in [(2, C3), (10, D3), (18, Eb3), (22, F3),
                      (30, G3), (38, Ab3), (46, Bb3), (54, G3), (62, C3)]:
        p.note(row, note, instrument=1)
    return p

def bass_05_solidarity_1():
    p = Pattern()
    for row, note in [(2, Eb3), (10, F3), (18, G3), (22, Ab3),
                      (30, Bb3), (34, C4), (42, Bb3),
                      (50, Ab3), (58, G3)]:
        p.note(row, note, instrument=1)
    return p

def bass_06_solidarity_2():
    p = Pattern()
    for row, note in [(2, C3), (6, D3), (10, Eb3), (14, F3),
                      (18, G3), (22, Ab3), (26, Bb3), (30, C4),
                      (34, Bb3), (38, Ab3), (42, G3), (46, F3),
                      (50, Eb3), (54, D3), (58, C3), (62, G3)]:
        p.note(row, note, instrument=1)
    return p

def bass_07_soaring():
    p = Pattern()
    for row, note in [(2, C3), (6, C4), (14, Bb3), (22, Ab3),
                      (26, G3), (30, F3), (38, Eb3), (42, F3),
                      (46, G3), (50, Ab3), (54, Bb3), (62, C4)]:
        p.note(row, note, instrument=1)
    return p

def bass_08_dev_1():
    p = Pattern()
    for row, note in [(2, C3), (6, Eb3), (10, G3),
                      (14, Ab3), (18, Bb3), (22, C4),
                      (26, Bb3), (30, Ab3), (34, G3),
                      (38, F3), (42, Eb3), (46, D3),
                      (50, Eb3), (54, G3), (58, Bb3), (62, C4)]:
        p.note(row, note, instrument=1)
    return p

def bass_09_dev_2():
    p = Pattern()
    notes = [C3, Eb3, G3, Ab3, Bb3, C4, Bb3, Ab3,
             G3, F3, Eb3, D3, C3, D3, Eb3, F3,
             G3, Ab3, Bb3, Ab3, G3, F3, Eb3, D3,
             C3, Eb3, G3, C4, Bb3, Ab3, G3, C3]
    for i, note in enumerate(notes):
        row = i * 2 + 1
        if row < 64:
            p.note(row, note, instrument=1)
    return p

def bass_10_climax_1():
    p = Pattern()
    for row, note in [(3, C3), (7, Eb3), (11, G3), (15, C4),
                      (19, Ab3), (23, G3), (27, F3),
                      (31, Eb3), (35, D3), (39, C3),
                      (43, Eb3), (47, F3), (51, G3),
                      (55, Ab3), (59, Bb3), (63, C4)]:
        p.note(row, note, instrument=1)
    return p

def bass_11_climax_2():
    p = Pattern()
    for row, note in [(1, C4), (5, Bb3), (9, Ab3), (13, G3),
                      (17, F3), (21, Eb3), (25, D3), (29, C3),
                      (33, Eb3), (37, G3), (41, Bb3), (45, C4),
                      (49, Ab3), (53, G3), (57, F3), (61, G3)]:
        p.note(row, note, instrument=1)
    return p

def bass_12_recap():
    p = Pattern()
    for row, note in [(4, C3), (8, C4), (14, Eb3),
                      (20, G3), (28, Ab3), (36, G3),
                      (44, F3), (52, Eb3), (58, D3)]:
        p.note(row, note, instrument=1)
    return p

def bass_13_recap_2():
    p = Pattern()
    for row, note in [(2, C3), (6, D3), (10, Eb3), (14, F3),
                      (22, G3), (26, Ab3), (30, Bb3),
                      (38, C4), (42, Bb3), (46, Ab3),
                      (50, G3), (58, F3), (62, Eb3)]:
        p.note(row, note, instrument=1)
    return p

def bass_14_recap_cadence():
    p = Pattern()
    for row, note in [(2, C3), (10, Eb3), (18, G3), (26, C4),
                      (34, Ab3), (42, G3), (50, F3), (58, C3)]:
        p.note(row, note, instrument=1)
    return p

def bass_15_coda_1():
    p = Pattern()
    p.vol(4, C3, instrument=1, volume=2)
    p.vol(28, G3, instrument=1, volume=2)
    p.vol(52, C3, instrument=1, volume=1)
    return p

def bass_16_coda_2():
    p = Pattern()
    p.vol(8, C3, instrument=1, volume=1)
    p.vol(40, G3, instrument=1, volume=1)
    return p

def bass_17_final():
    p = Pattern()
    p.vol(4, C3, instrument=1, volume=1)
    return p

# ============================================
# LEAD MELODY (CH1)
# ============================================

def lead_00_intro():
    p = Pattern()
    for row, note in [(0, Eb5), (12, D5), (16, C5),
                      (32, Eb5), (40, F5), (48, G5)]:
        p.note(row, note, instrument=1)
    return p

def lead_01_march_A1():
    p = Pattern()
    for row, note in [(0, C5), (8, Eb5), (12, F5), (16, G5),
                      (24, Ab5), (28, G5), (32, F5),
                      (40, Eb5), (44, D5), (48, C5),
                      (56, D5), (60, Eb5)]:
        p.note(row, note, instrument=1)
    return p

def lead_02_march_A2():
    p = Pattern()
    for row, note in [(0, F5), (8, Eb5), (12, D5), (16, Eb5),
                      (24, C5), (28, D5), (32, Eb5),
                      (40, F5), (44, G5), (48, Ab5),
                      (56, G5), (60, F5)]:
        p.note(row, note, instrument=1)
    return p

def lead_03_march_A3():
    p = Pattern()
    for row, note in [(0, G5), (6, Ab5), (8, G5), (12, F5),
                      (16, Eb5), (20, D5), (24, C5),
                      (32, Eb5), (36, F5), (40, G5),
                      (44, Ab5), (48, Bb5), (52, Ab5),
                      (56, G5), (60, F5)]:
        p.note(row, note, instrument=1)
    return p

def lead_04_march_cadence():
    p = Pattern()
    for row, note in [(0, Eb5), (8, D5), (12, C5), (16, D5),
                      (24, Eb5), (28, F5), (32, G5),
                      (40, F5), (44, Eb5), (48, D5),
                      (60, C5)]:
        p.note(row, note, instrument=1)
    return p

def lead_05_solidarity_B1():
    p = Pattern()
    for row, note in [(0, Eb5), (4, F5), (8, G5), (12, Ab5),
                      (16, Bb5), (20, C6), (24, Bb5),
                      (28, Ab5), (32, G5), (36, F5),
                      (40, G5), (44, Ab5), (48, Bb5),
                      (52, Ab5), (56, G5), (60, F5)]:
        p.note(row, note, instrument=1)
    return p

def lead_06_solidarity_B2():
    p = Pattern()
    for row, note in [(0, G5), (4, Ab5), (8, Bb5), (12, C6),
                      (16, Bb5), (20, Ab5), (24, Bb5),
                      (28, C6), (32, Bb5), (36, Ab5),
                      (40, G5), (44, F5), (48, Eb5),
                      (52, F5), (56, G5), (60, Eb5)]:
        p.note(row, note, instrument=1)
    return p

def lead_07_solidarity_B3():
    p = Pattern()
    for row, note in [(0, C6), (4, Bb5), (8, Ab5), (12, Bb5),
                      (16, C6), (20, Bb5), (24, G5),
                      (28, F5), (32, Eb5), (36, F5),
                      (40, G5), (44, Ab5), (48, G5),
                      (52, F5), (56, Eb5), (60, D5)]:
        p.note(row, note, instrument=1)
    return p

def lead_08_dev_1():
    p = Pattern()
    for row, note in [(0, C5), (4, Eb5), (8, G5),
                      (12, Ab5), (16, Bb5), (20, C6),
                      (24, Bb5), (28, Ab5), (32, G5),
                      (36, F5), (40, Eb5), (44, D5),
                      (48, Eb5), (52, G5), (56, Bb5),
                      (60, C6)]:
        p.note(row, note, instrument=1)
    return p

def lead_09_dev_2():
    p = Pattern()
    for row, note in [(0, C6), (4, Bb5), (6, Ab5), (8, G5),
                      (10, F5), (12, Eb5), (14, F5),
                      (16, G5), (18, Ab5), (20, Bb5), (22, C6),
                      (24, Bb5), (28, G5),
                      (32, Ab5), (34, G5), (36, F5), (38, Eb5),
                      (40, D5), (42, Eb5), (44, F5), (46, G5),
                      (48, Ab5), (50, Bb5), (52, C6),
                      (56, Bb5), (58, Ab5), (60, G5), (62, F5)]:
        p.note(row, note, instrument=1)
    return p

def lead_10_climax_1():
    p = Pattern()
    for row, note in [(0, C5), (2, Eb5), (4, G5), (6, C6),
                      (8, Eb5), (10, G5), (12, Bb5), (14, C6),
                      (16, Bb5), (20, Ab5), (24, G5),
                      (28, Ab5), (32, G5), (36, F5),
                      (40, Eb5), (44, D5),
                      (48, Eb5), (50, F5), (52, G5), (54, Ab5),
                      (56, Bb5), (58, C6), (60, Bb5), (62, C6)]:
        p.note(row, note, instrument=1)
    return p

def lead_11_climax_2():
    p = Pattern()
    for row, note in [(0, C6), (4, Bb5), (8, Ab5), (12, G5),
                      (16, F5), (18, G5), (20, Ab5), (22, Bb5),
                      (24, C6), (26, Bb5), (28, Ab5),
                      (32, G5), (34, Ab5), (36, Bb5),
                      (40, C6), (42, Bb5), (44, Ab5), (46, G5),
                      (48, Ab5), (50, Bb5), (52, C6),
                      (54, Bb5), (56, C6), (58, Bb5),
                      (60, Ab5), (62, G5)]:
        p.note(row, note, instrument=1)
    return p

def lead_12_recap_A1():
    p = Pattern()
    p.vibrato(0, C5, instrument=1, speed=2, depth=3)
    p.note(8, Eb5, instrument=1)
    p.note(12, F5, instrument=1)
    p.vibrato(16, G5, instrument=1, speed=2, depth=3)
    p.note(24, Ab5, instrument=1)
    p.note(28, G5, instrument=1)
    p.vibrato(32, F5, instrument=1, speed=2, depth=3)
    p.note(40, Eb5, instrument=1)
    p.note(44, D5, instrument=1)
    p.vibrato(48, C5, instrument=1, speed=2, depth=3)
    p.note(56, D5, instrument=1)
    p.note(60, Eb5, instrument=1)
    return p

def lead_13_recap_A2():
    p = Pattern()
    for row, note in [(0, F5), (4, G5), (8, F5), (12, Eb5),
                      (16, D5), (20, Eb5), (24, F5),
                      (28, G5), (32, Ab5), (36, Bb5),
                      (40, Ab5), (44, G5), (48, F5),
                      (52, Eb5), (56, D5), (60, C5)]:
        p.note(row, note, instrument=1)
    return p

def lead_14_recap_cadence():
    p = Pattern()
    for row, note in [(0, Eb5), (6, F5), (8, G5), (12, Ab5),
                      (16, G5), (20, F5), (24, Eb5),
                      (32, D5), (36, Eb5), (40, F5),
                      (48, Eb5), (56, D5), (62, C5)]:
        p.note(row, note, instrument=1)
    return p

def lead_15_coda_1():
    p = Pattern()
    for row, note in [(0, C5), (16, Eb5), (24, G5),
                      (40, Ab5), (52, G5)]:
        p.vol(row, note, instrument=1, volume=4)
    return p

def lead_16_coda_2():
    p = Pattern()
    p.vol(0, Eb5, instrument=1, volume=3)
    p.vol(20, G5, instrument=1, volume=2)
    p.vol(44, C5, instrument=1, volume=2)
    return p

def lead_17_final():
    p = Pattern()
    p.vol(0, C5, instrument=1, volume=3)
    p.vol(20, Eb5, instrument=1, volume=2)
    p.vol(40, G5, instrument=1, volume=1)
    return p

# ============================================
# HARMONY (CH2) - in the cracks of the lead
# ============================================

def harmony_00_intro():
    p = Pattern()
    p.vol(6, Eb4, instrument=2, volume=4)
    p.vol(36, G4, instrument=2, volume=3)
    return p

def harmony_01_march_A1():
    p = Pattern()
    for row, note in [(4, Eb4), (14, Ab4), (20, Eb4),
                      (36, Ab4), (42, G4), (52, Eb4), (58, F4)]:
        p.note(row, note, instrument=2)
    return p

def harmony_02_march_A2():
    p = Pattern()
    for row, note in [(2, Ab4), (10, G4), (18, G4),
                      (26, Eb4), (34, G4), (42, Ab4),
                      (50, Bb4), (58, Ab4)]:
        p.note(row, note, instrument=2)
    return p

def harmony_03_weary():
    p = Pattern()
    for row, note in [(4, Eb4), (14, D4), (22, C4),
                      (34, G4), (44, Ab4), (54, G4)]:
        p.note(row, note, instrument=2)
    return p

def harmony_04_cadence():
    p = Pattern()
    for row, note in [(4, G4), (14, F4), (20, Eb4),
                      (30, Ab4), (38, G4), (46, Ab4),
                      (54, Bb4), (62, G4)]:
        p.note(row, note, instrument=2)
    return p

def harmony_05_solidarity_1():
    p = Pattern()
    for row, note in [(2, C4), (6, D4), (10, Eb4), (14, F4),
                      (18, G4), (22, Ab4), (26, G4),
                      (30, F4), (34, Eb4), (38, D4),
                      (42, Eb4), (46, F4), (50, G4),
                      (54, F4), (58, Eb4), (62, D4)]:
        p.note(row, note, instrument=2)
    return p

def harmony_06_solidarity_2():
    p = Pattern()
    p.arp(2, Eb4, 3, instrument=2)
    p.arp(10, Ab4, 4, instrument=2)
    p.arp(18, G4, 3, instrument=2)
    p.arp(26, Ab4, 4, instrument=2)
    p.arp(34, G4, 3, instrument=2)
    p.arp(42, F4, 3, instrument=2)
    p.arp(50, Eb4, 3, instrument=2)
    p.arp(58, D4, 3, instrument=2)
    return p

def harmony_07_soaring():
    p = Pattern()
    for row, note in [(2, Ab4), (6, G4), (10, F4), (14, G4),
                      (18, Ab4), (22, G4), (26, Eb4),
                      (30, D4), (34, C4), (38, D4),
                      (42, Eb4), (46, F4), (50, Eb4),
                      (54, D4), (58, C4), (62, F4)]:
        p.note(row, note, instrument=2)
    return p

def harmony_08_dev_1():
    p = Pattern()
    p.arp(2, C4, 3, instrument=2)
    p.arp(10, Ab4, 4, instrument=2)
    p.arp(18, Bb4, 3, instrument=2)
    p.arp(26, G4, 3, instrument=2)
    p.arp(34, Ab4, 4, instrument=2)
    p.arp(42, Eb4, 3, instrument=2)
    p.arp(50, F4, 3, instrument=2)
    p.arp(58, G4, 5, instrument=2)
    return p

def harmony_09_dev_2():
    p = Pattern()
    for row, note in [(1, Eb4), (9, G4), (17, Bb4), (25, Ab4),
                      (33, F4), (41, Eb4), (49, G4), (57, Ab4)]:
        p.note(row, note, instrument=2)
    return p

def harmony_10_climax_1():
    p = Pattern()
    p.arp(2, C4, 3, instrument=2)
    p.arp(10, Eb4, 3, instrument=2)
    p.arp(18, Ab4, 4, instrument=2)
    p.arp(26, G4, 3, instrument=2)
    p.arp(34, F4, 3, instrument=2)
    p.arp(42, Eb4, 7, instrument=2)
    p.arp(50, G4, 5, instrument=2)
    p.arp(58, Bb4, 3, instrument=2)
    return p

def harmony_11_climax_2():
    p = Pattern()
    p.arp(3, Eb4, 3, instrument=2)
    p.arp(11, G4, 5, instrument=2)
    p.arp(19, Ab4, 4, instrument=2)
    p.arp(27, F4, 3, instrument=2)
    p.arp(35, G4, 3, instrument=2)
    p.arp(43, Ab4, 4, instrument=2)
    p.arp(51, Bb4, 2, instrument=2)
    p.arp(59, G4, 5, instrument=2)
    return p

def harmony_12_recap():
    p = Pattern()
    for row, note in [(6, Eb4), (14, Ab4), (22, Eb4),
                      (30, F4), (38, Ab4), (46, G4),
                      (54, Eb4), (62, F4)]:
        p.note(row, note, instrument=2)
    return p

def harmony_13_recap_2():
    p = Pattern()
    for row, note in [(2, Ab4), (6, G4), (10, Ab4),
                      (18, G4), (22, F4), (26, Eb4),
                      (34, F4), (38, G4), (42, Ab4),
                      (50, G4), (54, F4), (58, Eb4)]:
        p.note(row, note, instrument=2)
    return p

def harmony_14_recap_cadence():
    p = Pattern()
    for row, note in [(4, G4), (10, Ab4), (16, Bb4),
                      (24, Ab4), (30, G4),
                      (38, F4), (44, G4),
                      (52, G4), (60, Eb4)]:
        p.note(row, note, instrument=2)
    return p

def harmony_15_coda_1():
    p = Pattern()
    p.vol(8, Eb4, instrument=2, volume=3)
    p.vol(32, G4, instrument=2, volume=2)
    p.vol(56, Eb4, instrument=2, volume=2)
    return p

def harmony_16_coda_2():
    p = Pattern()
    p.vol(12, G4, instrument=2, volume=2)
    p.vol(48, Eb4, instrument=2, volume=1)
    return p

def harmony_17_final():
    p = Pattern()
    p.vol(12, Eb4, instrument=2, volume=1)
    return p

# ============================================
# Song assembly
# ============================================

def build_song():
    ch1 = [lead_00_intro(), lead_01_march_A1(), lead_02_march_A2(),
           lead_03_march_A3(), lead_04_march_cadence(),
           lead_05_solidarity_B1(), lead_06_solidarity_B2(), lead_07_solidarity_B3(),
           lead_08_dev_1(), lead_09_dev_2(),
           lead_10_climax_1(), lead_11_climax_2(),
           lead_12_recap_A1(), lead_13_recap_A2(), lead_14_recap_cadence(),
           lead_15_coda_1(), lead_16_coda_2(), lead_17_final()]

    ch2 = [harmony_00_intro(), harmony_01_march_A1(), harmony_02_march_A2(),
           harmony_03_weary(), harmony_04_cadence(),
           harmony_05_solidarity_1(), harmony_06_solidarity_2(), harmony_07_soaring(),
           harmony_08_dev_1(), harmony_09_dev_2(),
           harmony_10_climax_1(), harmony_11_climax_2(),
           harmony_12_recap(), harmony_13_recap_2(), harmony_14_recap_cadence(),
           harmony_15_coda_1(), harmony_16_coda_2(), harmony_17_final()]

    ch3 = [bass_00_intro(), bass_01_march_A1(), bass_02_march_A2(),
           bass_03_weary(), bass_04_cadence(),
           bass_05_solidarity_1(), bass_06_solidarity_2(), bass_07_soaring(),
           bass_08_dev_1(), bass_09_dev_2(),
           bass_10_climax_1(), bass_11_climax_2(),
           bass_12_recap(), bass_13_recap_2(), bass_14_recap_cadence(),
           bass_15_coda_1(), bass_16_coda_2(), bass_17_final()]

    ch4 = [drums_00_intro(), drums_01_march_enters(), drums_02_march_answer(),
           drums_03_weary(), drums_04_cadence_fill(),
           drums_05_solidarity_1(), drums_06_solidarity_2(), drums_07_soaring(),
           drums_08_dev_1(), drums_09_dev_2(),
           drums_10_climax_1(), drums_11_climax_2(),
           drums_12_recap(), drums_13_recap_2(), drums_14_recap_cadence(),
           drums_15_coda_1(), drums_16_coda_2(), drums_17_final()]

    song_order = [
        0,              # Intro
        1, 2,           # March A
        3, 4,           # March weary + cadence
        5, 6, 7,        # Solidarity rises + soars
        8, 9,           # Development
        10, 11,         # Climax (two different patterns)
        12, 13, 14,     # Recap + cadence
        15, 16, 17,     # Coda fading
    ]

    return ch1, ch2, ch3, ch4, song_order


def write_song(output_path):
    ch1_pats, ch2_pats, ch3_pats, ch4_pats, song_order = build_song()
    n = len(ch1_pats)
    empty_key = 4 * n
    total_keys = 4 * n + 1

    with open(output_path, 'wb') as f:
        write_uge_int(f, UGE_FORMAT_VERSION)
        write_uge_shortstring(f, "Pentatris")
        write_uge_shortstring(f, "")
        write_uge_shortstring(f, "A falling block anthem")

        # Duty instruments
        write_uge_instrument(f, type_=0, name="Lead Brass",
                           initial_volume=11, duty=1,
                           vol_sweep_dir=1, vol_sweep_amount=1)
        write_uge_instrument(f, type_=0, name="Choir",
                           initial_volume=9, duty=2)
        write_uge_instrument(f, type_=0, name="Soft Voice",
                           initial_volume=7, duty=2,
                           vol_sweep_dir=1, vol_sweep_amount=1)
        for _ in range(12):
            write_uge_instrument(f, type_=0)

        # Wave instruments
        write_uge_instrument(f, type_=1, name="March Bass", output_level=1)
        for _ in range(14):
            write_uge_instrument(f, type_=1)

        # Noise instruments
        write_uge_instrument(f, type_=2, name="HiHat",
                           initial_volume=5, length=8, length_enabled=True,
                           vol_sweep_dir=1, vol_sweep_amount=3)
        write_uge_instrument(f, type_=2, name="Snare",
                           initial_volume=11, length=16, length_enabled=True,
                           vol_sweep_dir=1, vol_sweep_amount=2)
        write_uge_instrument(f, type_=2, name="Bass Drum",
                           initial_volume=14, length=20, length_enabled=True,
                           vol_sweep_dir=1, vol_sweep_amount=1)
        for _ in range(12):
            write_uge_instrument(f, type_=2)

        # Waves
        triangle = list(range(16)) + list(range(15, -1, -1))
        f.write(bytes(triangle))
        f.write(bytes([i % 16 for i in range(32)]))
        f.write(bytes([0]*16 + [15]*16))
        sine_approx = [8,10,12,13,14,15,15,15,14,13,12,10,8,6,4,3,
                       2,1,1,1,2,3,4,6,8,8,8,8,8,8,8,8]
        f.write(bytes(sine_approx))
        for _ in range(12):
            f.write(bytes(32))

        # Timing
        write_uge_int(f, 6)
        f.write(bytes([0]))
        write_uge_int(f, 0)

        # Patterns
        write_uge_int(f, total_keys)
        for i, pat in enumerate(ch1_pats):
            pat.write(f, i)
        for i, pat in enumerate(ch2_pats):
            pat.write(f, n + i)
        for i, pat in enumerate(ch3_pats):
            pat.write(f, 2*n + i)
        for i, pat in enumerate(ch4_pats):
            pat.write(f, 3*n + i)

        write_uge_int(f, empty_key)
        for _ in range(64):
            write_uge_cell(f)

        # Order matrix
        order_len = len(song_order) + 1
        write_uge_int(f, order_len)
        for idx in song_order:
            write_uge_int(f, idx)
        write_uge_int(f, 0)

        write_uge_int(f, order_len)
        for idx in song_order:
            write_uge_int(f, n + idx)
        write_uge_int(f, 0)

        write_uge_int(f, order_len)
        for idx in song_order:
            write_uge_int(f, 2*n + idx)
        write_uge_int(f, 0)

        write_uge_int(f, order_len)
        for idx in song_order:
            write_uge_int(f, 3*n + idx)
        write_uge_int(f, 0)

        for _ in range(16):
            write_uge_int(f, 0)

    import os
    file_size = os.path.getsize(output_path)
    total_rows = len(song_order) * 64
    seconds = total_rows * 6 / 59.7
    print(f"Song: Pentatris")
    print(f"Key: C minor, ticks_per_row=6")
    print(f"Patterns: {n} per channel x 4 = {4*n} + 1 empty = {total_keys}")
    print(f"Song order: {len(song_order)} entries (all unique)")
    print(f"Duration: ~{seconds:.0f} seconds ({seconds/60:.1f} minutes)")
    print(f"Output: {output_path} ({file_size} bytes)")

if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description='Generate Pentatris .uge song')
    parser.add_argument('output', nargs='?', default='pentatris.uge',
                        help='Output .uge file path')
    args = parser.parse_args()
    write_song(args.output)
