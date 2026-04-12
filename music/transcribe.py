#!/usr/bin/env python3
"""
Klingon March -> klingon.uge

Dark operatic Game Boy march. Castlevania-density, Klingon gravity.

Rules:
  - Bass: ALWAYS moving. 8th notes minimum. Root-fifth-octave patterns.
  - Harmony: Arpeggiated chords on every beat. Dark chords sustained.
  - Lead: Bold intervals (4ths, 5ths, octaves, aug 2nds). NO stepwise runs.
  - Drums: QUIET - support don't dominate. Hihats well below melody volume.
  - Key changes: Dm -> Gm -> D harmonic minor -> Ebm (half step UP!) -> Dm
  - The augmented 2nd (Bb->C#) is our signature operatic interval.

Structure:
  Overture (2): Fanfare over building drums
  March A (4): Main theme, full band, Castlevania density
  March B (4): Theme development, darker, extended
  Lament (4): G minor, lower, mournful but STILL moving
  Battle (5): D harmonic minor, augmented 2nds, climax
  Requiem (2): Brief breath
  Ascension (4): KEY CHANGE to Eb minor - half step up, theme reborn
  Glory (3): Resolution back to Dm, triumphant
"""

import struct

# ============================================
# .uge format
# ============================================
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

# ============================================
# Notes
# ============================================
C3, Cs3, D3, Ds3, E3, F3, Fs3, G3, Gs3, A3, As3, B3 = range(12)
C4, Cs4, D4, Ds4, E4, F4, Fs4, G4, Gs4, A4, As4, B4 = range(12, 24)
C5, Cs5, D5, Ds5, E5, F5, Fs5, G5, Gs5, A5, As5, B5 = range(24, 36)
C6, Cs6, D6, Ds6, E6, F6 = 36, 37, 38, 39, 40, 41
_ = NO_NOTE

EFF_ARP = 0; EFF_PORTUP = 1; EFF_PORTDN = 2; EFF_VIBRATO = 4
EFF_SETVOL = 12; EFF_NOTECUT = 14; EFF_SPEED = 15

HIHAT = 4; HIHAT_OPEN = 8; SNARE = 18; KICK = 36; TOM_HI = 24; TOM_LO = 30

# Instruments: pattern inst=N maps to .uge file index N-1
# inst=0 means "no instrument" in pattern data, inst=1 = .uge[0], inst=2 = .uge[1]
DECL = 1  # .uge duty[0]: Lead 25% duty
BOLD = 2  # .uge duty[1]: Chords 50% duty
GHOST = 3 # .uge duty[2]: Whisper 12.5%
SWELL = 4 # .uge duty[3]: Swell
BASS = 1  # .uge wave[0]: Wave bass
HH = 1; SN = 2; KK = 3  # .uge noise[0,1,2]


class Pattern:
    def __init__(self):
        self.cells = {}
    def n(self, row, note, inst=0, vol=0, eff=0, ep=0):
        if 0 <= row < 64:
            self.cells[row] = (note, inst, vol, eff, ep)
        return self
    def arp(self, row, note, x, y, inst=0):
        return self.n(row, note, inst, eff=EFF_ARP, ep=((x&0xF)<<4)|(y&0xF))
    def vib(self, row, note, speed=2, depth=4, inst=0):
        return self.n(row, note, inst, eff=EFF_VIBRATO, ep=((speed&0xF)<<4)|(depth&0xF))
    def vol(self, row, note, inst, volume):
        return self.n(row, note, inst, eff=EFF_SETVOL, ep=volume&0xFF)
    def cut(self, row, ticks=0):
        return self.n(row, _, eff=EFF_NOTECUT, ep=ticks)
    def get_cells(self):
        return tuple(self.cells.get(r, (NO_NOTE, 0, 0, 0, 0)) for r in range(64))

    def make_echo(self, delay=3, echo_inst=BOLD, pan_nr51=0xFF):
        """Create an echo pair. Lead plays original notes, echo is delayed
        with softer instrument. pan_nr51 is the GLOBAL NR51 panning register
        value (affects ALL channels), set once at the start of the pattern.

        NR51 bits: [CH4L CH3L CH2L CH1L | CH4R CH3R CH2R CH1R]
        0xFF = all center, 0xD6 = CH1 left/CH2 right, 0xE5 = CH1 right/CH2 left
        """
        lead = Pattern()
        echo = Pattern()
        sorted_rows = sorted(self.cells.keys())
        first_note_set = False
        for row in sorted_rows:
            note, inst, vol, eff, ep = self.cells[row]
            # Lead: set global panning on first note only
            if not first_note_set and note != NO_NOTE:
                lead.n(row, note, inst, eff=EFF_PAN, ep=pan_nr51)
                first_note_set = True
            else:
                lead.n(row, note, inst, vol, eff, ep)
            # Echo: delayed with softer instrument, no panning effect
            echo_row = row + delay
            if echo_row < 64 and note != NO_NOTE:
                echo.n(echo_row, note, echo_inst)
            elif echo_row < 64 and note == NO_NOTE and eff == EFF_NOTECUT:
                echo.cut(echo_row)
        return lead, echo


EFF_PAN = 8   # panning: GLOBAL NR51 value
EFF_SPEED = 15  # Fxx: set ticks per row (tempo)


# ============================================
# BASS PATTERNS - The engine. Never stops.
# Castlevania-style: constant 8th notes, root-fifth-octave
# ============================================

def bass_dm_drive():
    """D minor driving bass. Root-fifth-octave, relentless."""
    p = Pattern()
    # Dm: D-A-D-A-F-D-A-D pattern, 8th notes
    notes = [D3, A3, D4, A3, D3, A3, D4, A3,
             F3, A3, F3, A3, D3, A3, D4, A3,
             D3, A3, D4, A3, D3, A3, D4, A3,
             As3, F3, As3, F3, A3, E3, A3, Cs3]  # Bb-A-C# at end = tension
    for i, note in enumerate(notes):
        p.n(i * 2, note, BASS)
    return p

def bass_dm_march():
    """Martial variant: heavier, more deliberate."""
    p = Pattern()
    notes = [D3, D3, A3, A3, D3, D3, D4, D3,
             As3, As3, F3, F3, As3, As3, A3, A3,
             D3, D3, A3, A3, D3, D3, D4, D3,
             G3, G3, A3, A3, Cs3, Cs3, D3, D3]  # G-A-C#-D cadence
    for i, note in enumerate(notes):
        p.n(i * 2, note, BASS)
    return p

def bass_dm_dark():
    """Darker bass: chromatic neighbors, unsettling."""
    p = Pattern()
    notes = [D3, Cs3, D3, A3, D3, Cs3, D3, A3,
             F3, E3, F3, A3, F3, E3, F3, Gs3,  # G# = tritone neighbor
             D3, Cs3, D3, A3, D3, Cs3, D3, A3,
             As3, A3, As3, A3, Cs3, D3, Cs3, D3]
    for i, note in enumerate(notes):
        p.n(i * 2, note, BASS)
    return p

def bass_gm_drive():
    """G minor driving bass."""
    p = Pattern()
    notes = [G3, D3, G3, D3, G3, D3, G3, D4,
             Ds3, As3, Ds3, As3, D3, A3, D3, A3,
             G3, D3, G3, D3, G3, D3, G3, D4,
             C3, G3, C3, G3, D3, Fs3, D3, Fs3]  # F# = harmonic minor
    for i, note in enumerate(notes):
        p.n(i * 2, note, BASS)
    return p

def bass_gm_descend():
    """Chromatic descending bass in G minor. Inexorable."""
    p = Pattern()
    notes = [G3, D3, G3, D3, Fs3, D3, Fs3, D3,
             F3, D3, F3, D3, E3, D3, E3, D3,
             Ds3, As3, Ds3, As3, D3, A3, D3, A3,
             Cs3, A3, Cs3, A3, D3, A3, D3, A3]  # C# pivot back to Dm
    for i, note in enumerate(notes):
        p.n(i * 2, note, BASS)
    return p

def bass_battle():
    """D harmonic minor battle bass. Augmented 2nd in the bass."""
    p = Pattern()
    notes = [D3, A3, D4, A3, D3, A3, D4, A3,
             As3, Cs4, As3, Cs4, As3, Cs4, As3, D4,  # Bb-C# = AUG 2ND!
             D3, A3, D4, A3, Gs3, D3, Gs3, A3,  # G# tritone
             As3, Cs4, As3, Cs4, D4, D3, D4, D3]
    for i, note in enumerate(notes):
        p.n(i * 2, note, BASS)
    return p

def bass_battle_2():
    """Second battle bass: descending power."""
    p = Pattern()
    notes = [D3, D4, D3, A3, As3, Cs4, D4, A3,
             G3, D3, G3, D3, F3, Cs4, F3, D4,
             As3, F3, As3, Cs4, A3, E3, A3, Cs3,
             D3, A3, D3, A3, D3, D4, D3, D4]
    for i, note in enumerate(notes):
        p.n(i * 2, note, BASS)
    return p

def bass_requiem():
    """Single slow notes. The only time bass rests."""
    p = Pattern()
    p.n(0, D3, BASS)
    p.n(16, A3, BASS)
    p.n(32, D3, BASS)
    p.n(48, Cs3, BASS)  # leading tone, unresolved
    return p

def bass_glory():
    """Full power bass for finale."""
    p = Pattern()
    notes = [D3, D4, A3, D4, D3, D4, A3, D4,
             As3, F3, As3, D4, A3, Cs4, A3, D4,
             D3, D4, A3, D4, D3, D4, A3, D4,
             D3, D3, D3, D3, D3, D3, D3, D3]  # pounding Ds at the end
    for i, note in enumerate(notes):
        p.n(i * 2, note, BASS)
    return p

def bass_overture():
    """Building bass for overture: starts sparse, gets denser."""
    p = Pattern()
    p.n(0, D3, BASS)
    p.n(16, D3, BASS)
    p.n(24, A3, BASS)
    p.n(32, D3, BASS)
    p.n(40, A3, BASS)
    p.n(44, D3, BASS)
    p.n(48, A3, BASS)
    p.n(52, D3, BASS)
    p.n(56, A3, BASS)
    p.n(60, Cs3, BASS)
    return p


# ============================================
# HARMONY PATTERNS - Arpeggiated chords, always present
# Dark chords: minor, diminished, augmented 2nd intervals
# ============================================

def harm_dm():
    """D minor chord, constant arpeggiation. Castlevania style."""
    p = Pattern()
    # Dm arpeggio on every beat, switching chords at phrase points
    for r in range(0, 32, 4):
        p.arp(r, D4, 3, 7, BOLD)    # Dm (D-F-A)
    for r in range(32, 48, 4):
        p.arp(r, As3, 4, 7, BOLD)   # Bb (Bb-D-F)
    for r in range(48, 64, 4):
        p.arp(r, A3, 4, 7, BOLD)    # A major (A-C#-E)
    return p

def harm_dm_2():
    """Dm - Gm - A. Darker progression."""
    p = Pattern()
    for r in range(0, 24, 4):
        p.arp(r, D4, 3, 7, BOLD)    # Dm
    for r in range(24, 48, 4):
        p.arp(r, G3, 3, 7, BOLD)    # Gm
    for r in range(48, 64, 4):
        p.arp(r, A3, 4, 7, BOLD)    # A (dominant)
    return p

def harm_dm_resolve():
    """Dm - F - A - Dm. Resolution pattern."""
    p = Pattern()
    for r in range(0, 16, 4):
        p.arp(r, D4, 3, 7, BOLD)
    for r in range(16, 32, 4):
        p.arp(r, F4, 3, 7, BOLD)    # Fm (not major! keep it dark)
    for r in range(32, 48, 4):
        p.arp(r, A3, 4, 7, BOLD)    # A dominant
    for r in range(48, 64, 4):
        p.arp(r, D4, 3, 7, BOLD)    # Dm home
    return p

def harm_gm():
    """G minor chords."""
    p = Pattern()
    for r in range(0, 24, 4):
        p.arp(r, G3, 3, 7, BOLD)    # Gm
    for r in range(24, 48, 4):
        p.arp(r, Ds4, 4, 7, BOLD)   # Eb major
    for r in range(48, 64, 4):
        p.arp(r, D4, 4, 7, BOLD)    # D major (dominant of Gm)
    return p

def harm_gm_2():
    """G minor with chromatic chord motion."""
    p = Pattern()
    for r in range(0, 16, 4):
        p.arp(r, G3, 3, 7, BOLD)    # Gm
    for r in range(16, 32, 4):
        p.arp(r, C4, 3, 7, BOLD)    # Cm
    for r in range(32, 48, 4):
        p.arp(r, Ds4, 4, 7, BOLD)   # Eb
    for r in range(48, 64, 4):
        p.arp(r, D4, 4, 7, BOLD)    # D dominant
    return p

def harm_battle():
    """D harmonic minor chords. The augmented 2nd in harmony."""
    p = Pattern()
    for r in range(0, 16, 4):
        p.arp(r, D4, 3, 7, BOLD)    # Dm
    for r in range(16, 32, 4):
        p.arp(r, As3, 4, 7, BOLD)   # Bb
    for r in range(32, 48, 4):
        p.arp(r, Cs4, 3, 6, BOLD)   # C#dim (C#-E-Bb) - leading tone chord!
    for r in range(48, 64, 4):
        p.arp(r, D4, 3, 7, BOLD)    # Dm resolution
    return p

def harm_battle_2():
    """Tritone + resolution."""
    p = Pattern()
    for r in range(0, 16, 4):
        p.arp(r, D4, 3, 7, BOLD)    # Dm
    for r in range(16, 32, 4):
        p.arp(r, Gs3, 4, 6, BOLD)   # G#/Ab = tritone harmony!
    for r in range(32, 48, 4):
        p.arp(r, A3, 4, 7, BOLD)    # A major - resolves tritone
    for r in range(48, 64, 4):
        p.arp(r, D4, 3, 7, BOLD)    # Dm
    return p

def harm_overture():
    """Overture: Dm only, building."""
    p = Pattern()
    p.arp(0, D4, 3, 7, BOLD)       # Dm, let it ring
    p.arp(32, D4, 3, 7, BOLD)
    return p

def harm_overture_2():
    """Overture: Bb then A dominant."""
    p = Pattern()
    p.arp(0, As3, 4, 7, BOLD)      # Bb
    p.arp(32, A3, 4, 7, BOLD)      # A dominant
    return p

def harm_requiem():
    """Requiem: single sustained Dm."""
    p = Pattern()
    p.arp(0, D4, 3, 7, BOLD)
    return p

def harm_glory():
    """Glory: full progression, every beat."""
    p = Pattern()
    for r in range(0, 16, 4):
        p.arp(r, D4, 3, 7, BOLD)
    for r in range(16, 32, 4):
        p.arp(r, As3, 4, 7, BOLD)
    for r in range(32, 48, 4):
        p.arp(r, A3, 4, 7, BOLD)
    for r in range(48, 64, 4):
        p.arp(r, D4, 3, 7, BOLD)
    return p


# ============================================
# LEAD PATTERNS - Bold intervals, operatic
# ============================================

# ============================================
# THE MOTIF: D5 - A5 - (gap) - F5 - As5 - A5
# Every section transforms this motif with different DENSITY and TEMPO.
#
# ARC:  Overture(slow,sparse) -> March(medium) -> Lament(slow,sparse)
#       -> Battle(FAST,DENSE) -> Requiem(slowest) -> Ascension(building)
#       -> Glory(medium,triumphant)
#
# Speed effect (F): ticks_per_row. Higher = slower.
#   Overture: 6 (majestic)
#   March: 4 (driving)
#   Lament: 6 (mournful)
#   Battle: 3 (furious!)
#   Requiem: 7 (devastated)
#   Ascension: 4 (rebuilding)
#   Glory: 4 (triumphant)
# ============================================

def lead_overture_1():
    """3 notes. Enormous space. The motif emerges from silence. Speed=6."""
    p = Pattern()
    p.n(0, D5, DECL, eff=EFF_SPEED, ep=6)  # SLOW
    p.vib(8, D5, 1, 4, DECL)
    # ... 20 rows of just D ringing ...
    p.cut(28)
    # ONE more note. The 5th. That's it.
    p.vib(36, A5, 1, 6, DECL)
    # Let it ring for the rest of the pattern
    return p

def lead_overture_2():
    """The motif completes, still slow. Foreshadow aug 2nd."""
    p = Pattern()
    # Complete the motif slowly: F... Bb... A...
    p.n(0, F5, DECL)
    p.vib(6, F5, 1, 4, DECL)
    p.cut(16)
    p.n(24, As5, DECL)         # Bb - tension
    p.vib(28, As5, 1, 3, DECL)
    p.cut(36)
    p.vib(40, A5, 1, 6, DECL)  # resolve - motif complete
    p.cut(52)
    # Foreshadow: hint of C#
    p.n(56, Cs5, DECL)         # first C# in the song!
    p.n(62, D5, DECL)          # resolve, pickup into march
    return p

def lead_march_1():
    """Full motif at march tempo. Speed=4. Medium density (~10 notes)."""
    p = Pattern()
    p.n(0, D5, DECL, eff=EFF_SPEED, ep=4)  # MARCH tempo
    p.n(7, A5, DECL)           # 5th (1 early)
    p.cut(13)
    p.n(18, F5, DECL)          # minor 3rd (2 late)
    p.n(23, As5, DECL)         # Bb (1 early)
    p.vib(28, A5, 1, 3, DECL)  # resolve
    p.cut(34)
    # Answer: motif inverted (descending)
    p.n(38, D6, DECL)
    p.n(43, A5, DECL)
    p.cut(47)
    p.n(50, As5, DECL)
    p.n(55, F5, DECL)
    p.vib(58, D5, 1, 4, DECL)
    return p

def lead_march_2():
    """Motif extended higher. Building intensity."""
    p = Pattern()
    p.n(0, D5, DECL)
    p.n(7, A5, DECL)
    p.n(12, D6, DECL)          # pushes to octave!
    p.vib(16, D6, 1, 3, DECL)
    p.cut(22)
    p.n(26, As5, DECL)
    p.n(31, A5, DECL)
    p.n(38, F5, DECL)
    p.vib(42, F5, 1, 4, DECL)
    p.cut(48)
    p.n(50, E5, DECL)
    p.n(55, Cs5, DECL)         # leading tone - wants resolution
    p.vib(58, Cs5, 2, 6, DECL)
    return p

def lead_march_3():
    """Motif transposed to A. Same shape, new pitch."""
    p = Pattern()
    p.vib(0, D5, 1, 4, DECL)   # resolve C#
    p.cut(8)
    # Motif from A: A-E-C-F-E
    p.n(14, A4, DECL)
    p.n(21, E5, DECL)
    p.cut(27)
    p.n(30, C5, DECL)
    p.n(35, F5, DECL)
    p.vib(40, E5, 1, 3, DECL)
    p.cut(48)
    p.n(52, D5, DECL)
    p.n(57, A5, DECL)
    p.n(62, D4, DECL)
    return p

def lead_march_4():
    """Motif fragmented: Bb-A tension repeated, then Bb-C#-D."""
    p = Pattern()
    p.n(0, D5, DECL)
    p.n(5, As5, DECL)
    p.n(9, A5, DECL)
    p.cut(13)
    p.n(17, D6, DECL)
    p.n(21, As5, DECL)
    p.n(25, A5, DECL)
    p.cut(29)
    # Aug 2nd version
    p.n(34, As5, DECL)
    p.n(39, Cs6, DECL)         # C#!
    p.vib(44, D6, 1, 3, DECL)
    p.cut(50)
    p.n(54, Cs5, DECL)
    p.vib(58, D5, 1, 4, DECL)
    p.cut(63)
    return p

def lead_lament_1():
    """Motif in G minor, SLOW. Speed=6. Only 5 notes. Enormous weight."""
    p = Pattern()
    p.n(0, G4, DECL, eff=EFF_SPEED, ep=6)  # SLOW tempo
    p.vib(4, G4, 1, 6, DECL)
    p.cut(16)
    p.vib(24, D5, 1, 4, DECL)  # 5th, also long
    p.cut(38)
    p.n(42, As4, DECL)         # Bb = minor 3rd of G
    p.vib(48, As4, 1, 6, DECL)
    p.cut(58)
    p.vib(60, G4, 1, 8, DECL)  # back to G
    return p

def lead_lament_2():
    """Aug 2nd in G harmonic minor. Still slow, sparse."""
    p = Pattern()
    p.n(0, G5, DECL)
    p.vib(6, G5, 1, 4, DECL)
    p.cut(14)
    # The Eb->F# aug 2nd, held long
    p.n(20, Ds5, DECL)
    p.cut(28)
    p.vib(32, Fs5, 2, 6, DECL) # F#! Let it ache
    p.cut(44)
    # Slow descent home
    p.n(48, D5, DECL)
    p.vib(56, G4, 1, 8, DECL)
    return p

def lead_lament_3():
    """Pivot from G minor to D minor. Still slow."""
    p = Pattern()
    p.n(0, G4, DECL)
    p.vib(6, G4, 1, 4, DECL)
    p.cut(14)
    p.n(20, As4, DECL)         # Bb
    p.n(28, A4, DECL)          # chromatic descent
    p.cut(36)
    p.n(40, F4, DECL)
    p.vib(44, F4, 2, 5, DECL)
    p.cut(52)
    p.n(56, Cs4, DECL)         # C# leading tone - pivoting to D minor
    p.vib(60, Cs4, 2, 6, DECL)
    return p

def lead_battle_1():
    """Motif TRANSFORMED at FAST tempo. Speed=3. DENSE. 12+ notes."""
    p = Pattern()
    p.n(0, D5, DECL, eff=EFF_SPEED, ep=3)  # FAST!
    p.n(4, A5, DECL)
    p.n(8, D6, DECL)           # rocketing up!
    p.cut(11)
    p.n(14, As5, DECL)         # Bb
    p.n(18, Cs6, DECL)         # C#! Aug 2nd!
    p.vib(22, D6, 1, 3, DECL)  # D! Peak!
    p.cut(28)
    # Battle motif again, lower octave, rapid
    p.n(30, D5, DECL)
    p.n(34, A5, DECL)
    p.cut(37)
    p.n(40, As4, DECL)
    p.n(44, Cs5, DECL)         # aug 2nd lower
    p.vib(48, D5, 1, 4, DECL)
    p.cut(54)
    # Driving pickup
    p.n(56, As5, DECL)
    p.n(60, Cs6, DECL)
    return p

def lead_battle_2():
    """Octave leaps + tritone at battle speed. Maximum density."""
    p = Pattern()
    p.vib(0, D6, 1, 3, DECL)   # resolve from above
    p.cut(4)
    p.n(6, D5, DECL)
    p.n(8, A5, DECL)
    p.n(10, D6, DECL)          # rapid ascent
    p.cut(13)
    p.n(16, A4, DECL)          # crash down
    p.n(18, F5, DECL)
    p.n(20, A5, DECL)
    p.cut(23)
    # Tritone shock
    p.n(26, D5, DECL)
    p.n(30, Gs5, DECL)         # TRITONE
    p.vib(34, Gs5, 3, 6, DECL)
    p.cut(40)
    p.vib(42, A5, 1, 4, DECL)  # resolve
    p.cut(48)
    # Rapid motif fragment
    p.n(50, D5, DECL)
    p.n(53, A5, DECL)
    p.n(56, As5, DECL)
    p.n(59, Cs6, DECL)         # building...
    p.n(62, D6, DECL)          # peak!
    return p

def lead_battle_3():
    """Descending battle motif. Mirror image, still dense."""
    p = Pattern()
    p.n(0, D6, DECL)
    p.n(4, Cs6, DECL)          # C# from above
    p.n(8, As5, DECL)          # Bb
    p.cut(11)
    p.n(14, A5, DECL)
    p.n(18, F5, DECL)
    p.vib(22, D5, 1, 4, DECL)
    p.cut(28)
    # Second descent
    p.n(32, D6, DECL)
    p.n(36, A5, DECL)
    p.cut(39)
    p.n(42, As5, DECL)
    p.n(46, F5, DECL)
    p.vib(50, D5, 1, 4, DECL)
    p.cut(56)
    # Unresolved C#
    p.n(58, As4, DECL)
    p.vib(62, Cs5, 2, 6, DECL)
    return p

def lead_battle_4():
    """Battle climax peak. Maximum notes, highest register."""
    p = Pattern()
    p.vib(0, D5, 1, 3, DECL)
    p.cut(3)
    # Aug 2nd at peak speed
    p.n(4, As5, DECL)
    p.n(8, Cs6, DECL)
    p.vib(12, D6, 1, 4, DECL)
    p.cut(16)
    # Rhythmic Ds
    p.n(18, D6, DECL)
    p.cut(20)
    p.n(22, D5, DECL)
    p.cut(24)
    p.n(26, D6, DECL)
    p.cut(28)
    # Full motif one last time, rapid-fire
    p.n(30, D5, DECL)
    p.n(33, A5, DECL)
    p.cut(36)
    p.n(38, F5, DECL)
    p.n(41, As5, DECL)
    p.n(44, A5, DECL)
    p.cut(48)
    # Descent into requiem
    p.n(50, A5, DECL)
    p.n(54, F5, DECL)
    p.vib(58, D5, 1, 6, DECL)
    return p

def lead_requiem():
    """Ghost of the motif. Speed=7 (slowest). 4 fading notes."""
    p = Pattern()
    p.n(0, D5, GHOST, eff=EFF_SPEED, ep=7)  # SLOWEST tempo
    p.cut(8)
    p.vol(16, A5, GHOST, 4)
    p.cut(22)
    p.vol(32, F5, GHOST, 3)
    p.cut(38)
    p.vol(48, A4, GHOST, 2)    # barely there
    p.cut(54)
    return p

# ============================================
# ASCENSION - KEY CHANGE: Eb minor (half step up!)
# Everything shifts up 1 semitone. The augmented 2nd becomes B->D.
# Eb minor: Eb F Gb Ab Bb Cb Db
# Eb harmonic minor: Eb F Gb Ab Bb Cb D (aug 2nd: Cb/B -> D)
# ============================================

def lead_ascend_1():
    """MOTIF in Eb minor! Speed=4 (back to march tempo). Rebuilding energy."""
    p = Pattern()
    p.n(0, Ds5, DECL, eff=EFF_SPEED, ep=4)  # MARCH tempo returns
    p.n(7, As5, DECL)         # Bb = 5th (like A in original)
    p.cut(13)
    p.n(18, Fs5, DECL)        # Gb = minor 3rd (like F in original)
    p.n(23, B5, DECL)         # Cb/B = tension (like Bb in original)
    p.vib(28, As5, 1, 3, DECL) # resolve to Bb (like A)
    p.cut(34)
    # Answer: descending (same as march_1's answer, transposed)
    p.n(38, Ds6, DECL)
    p.n(43, As5, DECL)
    p.cut(47)
    p.n(50, B5, DECL)          # Cb/B
    p.n(55, Fs5, DECL)
    p.vib(58, Ds5, 1, 4, DECL) # home to Eb
    return p

def lead_ascend_2():
    """Motif development in Eb minor + the NEW aug 2nd: B->D."""
    p = Pattern()
    # Motif pushes higher like march_2
    p.n(0, Ds5, DECL)
    p.n(7, As5, DECL)
    p.n(12, Ds6, DECL)        # octave!
    p.vib(16, Ds6, 1, 3, DECL)
    p.cut(22)
    # Descending with the NEW aug 2nd
    p.n(28, B5, DECL)         # Cb/B
    p.cut(34)
    p.n(38, D6, DECL)         # D! B->D = AUG 2ND in Eb minor!
    p.vib(42, Ds6, 1, 4, DECL) # resolve to Eb
    p.cut(50)
    # Foreshadow return to D minor
    p.n(54, D5, DECL)         # D natural... are we going home?
    p.vib(58, D5, 2, 6, DECL)
    return p

def lead_ascend_3():
    """Motif fragmented, pivoting from Eb minor back to D minor."""
    p = Pattern()
    # Eb motif fragment
    p.n(0, Ds5, DECL)
    p.n(5, As5, DECL)
    p.cut(9)
    # Chromatic pivot: Eb -> D (the key change dissolving)
    p.n(16, Ds5, DECL)
    p.n(22, D5, DECL)         # half step down - we're leaving Eb
    p.cut(28)
    # Original motif fragment returning!
    p.n(34, D5, DECL)         # THE D! We're home!
    p.n(41, A5, DECL)         # THE 5th! Original motif!
    p.cut(47)
    p.n(50, F5, DECL)         # THE minor 3rd!
    p.n(55, Cs5, DECL)        # C# leading tone
    p.vib(58, D5, 1, 4, DECL) # resolve!
    p.cut(63)
    return p

def lead_ascend_4():
    """Full motif returns in D minor. The homecoming."""
    p = Pattern()
    # Original motif, complete, with anticipation
    p.n(0, D5, DECL)           # DA!
    p.n(7, A5, DECL)           # AA!
    p.cut(13)
    p.n(18, F5, DECL)          # FA!
    p.n(23, As5, DECL)         # BA! (Bb)
    p.vib(28, A5, 1, 3, DECL)  # AA! THE MOTIF IS BACK!
    p.cut(36)
    # Now drive into glory: Bb -> C# -> D cadence
    p.n(40, As5, DECL)
    p.n(47, Cs6, DECL)         # C#!
    p.vib(52, D6, 1, 4, DECL)  # D! Into glory!
    p.cut(60)
    return p

def harm_ebm():
    """Eb minor chords."""
    p = Pattern()
    for r in range(0, 32, 4):
        p.arp(r, Ds4, 3, 7, BOLD)   # Ebm (Eb-Gb-Bb)
    for r in range(32, 48, 4):
        p.arp(r, B3, 4, 7, BOLD)    # Cb/B major (B-D#-F#)
    for r in range(48, 64, 4):
        p.arp(r, As3, 4, 7, BOLD)   # Bb major (Bb-D-F)
    return p

def harm_ebm_2():
    """Eb minor with aug 2nd chord."""
    p = Pattern()
    for r in range(0, 16, 4):
        p.arp(r, Ds4, 3, 7, BOLD)   # Ebm
    for r in range(16, 32, 4):
        p.arp(r, B3, 4, 7, BOLD)    # B/Cb
    for r in range(32, 48, 4):
        p.arp(r, D4, 4, 7, BOLD)    # D major! (the aug 2nd chord: D-F#-A)
    for r in range(48, 64, 4):
        p.arp(r, Ds4, 3, 7, BOLD)   # Ebm resolve
    return p

def harm_ebm_pivot():
    """Eb minor dissolving to D minor."""
    p = Pattern()
    for r in range(0, 16, 4):
        p.arp(r, Ds4, 3, 7, BOLD)   # Ebm
    for r in range(16, 32, 4):
        p.arp(r, D4, 3, 7, BOLD)    # Dm (chromatic slide down)
    for r in range(32, 48, 4):
        p.arp(r, A3, 4, 7, BOLD)    # A major = V of Dm
    for r in range(48, 64, 4):
        p.arp(r, D4, 3, 7, BOLD)    # Dm home
    return p

def bass_ebm_drive():
    """Eb minor driving bass."""
    p = Pattern()
    notes = [Ds3, As3, Ds4, As3, Ds3, As3, Ds4, As3,
             Fs3, As3, Fs3, As3, Ds3, As3, Ds4, As3,
             Ds3, As3, Ds4, As3, Ds3, As3, Ds4, As3,
             B3, Fs3, B3, Fs3, As3, F3, As3, D3]  # B-Bb-D at end
    for i, note in enumerate(notes):
        p.n(i * 2, note, BASS)
    return p

def bass_ebm_pivot():
    """Eb minor bass dissolving to D minor."""
    p = Pattern()
    notes = [Ds3, As3, Ds4, As3, Ds3, As3, Ds4, As3,
             D3, A3, D4, A3, D3, A3, D4, A3,    # shift to Dm!
             A3, E3, A3, Cs3, D3, A3, D3, A3,   # dominant of Dm
             D3, A3, D4, A3, D3, D3, D3, D3]
    for i, note in enumerate(notes):
        p.n(i * 2, note, BASS)
    return p

def lead_glory_1():
    """MOTIF FORTISSIMO. Full motif + aug 2nd combined = ultimate form."""
    p = Pattern()
    # Full motif: D-A-(gap)-F-Bb-A
    p.n(0, D5, DECL)
    p.n(5, A5, DECL)
    p.cut(11)
    p.n(14, F5, DECL)
    p.n(19, As5, DECL)         # Bb
    p.vib(24, A5, 1, 3, DECL)  # motif complete
    p.cut(30)
    # NOW the aug 2nd: Bb -> C# -> D (the battle's transformation)
    p.n(34, As5, DECL)
    p.n(41, Cs6, DECL)         # C#!
    p.vib(46, D6, 1, 4, DECL)  # D! Both motif AND battle combined!
    p.cut(56)
    return p

def lead_glory_2():
    """Final aug 2nd, then motif fragments fading away."""
    p = Pattern()
    # One last Bb -> C# -> D
    p.n(0, As5, DECL)
    p.n(7, Cs6, DECL)
    p.vib(12, D6, 1, 4, DECL)  # HOME
    p.cut(22)
    # Motif fragments fading: D... A... F... D...
    p.vol(26, D5, DECL, 12)
    p.cut(32)
    p.vol(34, A5, DECL, 10)
    p.cut(40)
    p.vol(42, F5, DECL, 8)    # the minor 3rd, fading
    p.cut(48)
    p.vol(50, D5, DECL, 5)    # home, quiet
    p.cut(56)
    p.vol(58, D4, DECL, 3)    # final low D
    return p

def lead_glory_3():
    """The very last pattern. Motif one final time, then silence."""
    p = Pattern()
    # Motif start: D - A - (silence). Just the beginning. Unfinished.
    # The listener's mind completes it.
    p.n(0, D5, DECL)
    p.n(7, A5, DECL)
    p.vib(14, D6, 1, 6, DECL) # one last high D
    p.cut(28)
    # Silence. The song is over. The motif echoes in memory.
    return p


# ============================================
# DRUM PATTERNS - quiet hihats, supportive
# ============================================

def drums_overture():
    """Building overture drums."""
    p = Pattern()
    p.vol(0, KICK, KK, 6)
    p.vol(24, KICK, KK, 6)
    p.vol(40, KICK, KK, 7)
    p.vol(52, SNARE, SN, 3)
    p.vol(56, SNARE, SN, 4)
    p.vol(60, SNARE, SN, 5)
    p.vol(62, SNARE, SN, 6)
    return p

def drums_overture_sparse():
    """Just timpani."""
    p = Pattern()
    p.vol(0, KICK, KK, 5)
    p.vol(32, KICK, KK, 4)
    return p

def drums_march():
    """March with quiet hihats."""
    p = Pattern()
    for r in range(0, 64, 8):
        p.vol(r, HIHAT, HH, 2)
    for r in [0, 16, 32, 48]:
        p.vol(r, KICK, KK, 7)
    for r in [8, 24, 40, 56]:
        p.vol(r, SNARE, SN, 5)
    return p

def drums_march_heavy():
    """Heavier march, hihats still restrained."""
    p = Pattern()
    for r in range(0, 64, 4):
        p.vol(r, HIHAT, HH, 2)
    for r in [0, 4, 16, 20, 32, 36, 48, 52]:
        p.vol(r, KICK, KK, 7)
    for r in [8, 24, 40, 56]:
        p.vol(r, SNARE, SN, 6)
    return p

def drums_lament():
    """Funeral march. No hihats."""
    p = Pattern()
    p.vol(0, KICK, KK, 5)
    p.vol(16, SNARE, SN, 3)
    p.vol(32, KICK, KK, 5)
    p.vol(48, SNARE, SN, 3)
    return p

def drums_fill():
    """Transition fill."""
    p = Pattern()
    p.vol(0, KICK, KK, 6)
    p.vol(8, SNARE, SN, 5)
    p.vol(16, KICK, KK, 6)
    p.vol(24, SNARE, SN, 5)
    p.vol(32, TOM_LO, KK, 5)
    p.vol(36, TOM_LO, KK, 5)
    p.vol(40, TOM_HI, KK, 5)
    p.vol(44, TOM_HI, KK, 5)
    p.vol(48, SNARE, SN, 6)
    p.vol(52, SNARE, SN, 6)
    p.vol(56, KICK, KK, 7)
    p.vol(60, KICK, KK, 7)
    return p

def drums_battle():
    """Battle: kicks and snares only, no hihats."""
    p = Pattern()
    for r in [0, 6, 16, 22, 32, 38, 48, 54]:
        p.vol(r, KICK, KK, 7)
    for r in [8, 24, 40, 56]:
        p.vol(r, SNARE, SN, 5)
    return p

def drums_requiem():
    """Near silence."""
    p = Pattern()
    p.vol(0, KICK, KK, 3)
    p.vol(32, KICK, KK, 2)
    return p

def drums_ascend():
    """Ascending section drums."""
    p = Pattern()
    for r in range(0, 64, 8):
        p.vol(r, HIHAT, HH, 2)
    for r in [0, 16, 32, 48]:
        p.vol(r, KICK, KK, 7)
    for r in [8, 24, 40, 56]:
        p.vol(r, SNARE, SN, 5)
    return p


# ============================================
# Song assembly - echo/panning operatic variant
# CH2 becomes a stereo echo of CH1 instead of independent chords
# ============================================

def build_song_opera():
    """Build the operatic echo variant.
    Returns list of (ch1_pat, ch2_pat, ch3_fn, ch4_fn) where
    ch1/ch2 are Pattern objects (not functions) for echo pairs."""
    song = []

    # NR51 panning presets (global: all 4 channels at once)
    # Bits: [CH4L CH3L CH2L CH1L | CH4R CH3R CH2R CH1R]
    PAN_CENTER = 0xFF       # all channels both speakers
    PAN_WIDE_A = 0xDD       # CH1 left, CH2 right, CH3+CH4 both (1101 1101 -> corrected below)
    PAN_WIDE_B = 0xEE       # CH1 right, CH2 left, CH3+CH4 both

    # Actually let me compute properly:
    # CH1L CH2L CH3L CH4L | CH1R CH2R CH3R CH4R (hardware order within each nibble)
    # NR51 = bit7:CH4L bit6:CH3L bit5:CH2L bit4:CH1L | bit3:CH4R bit2:CH3R bit1:CH2R bit0:CH1R
    # Wide A: CH1=left, CH2=right, CH3=both, CH4=both
    #   Left nibble:  CH4L=1 CH3L=1 CH2L=0 CH1L=1 = 0b1101 = 0xD
    #   Right nibble: CH4R=1 CH3R=1 CH2R=1 CH1R=0 = 0b1110 = 0xE
    PAN_WIDE_A = 0xDE  # CH1 left, CH2 right, rest center
    # Wide B: CH1=right, CH2=left, CH3=both, CH4=both
    #   Left nibble:  CH4L=1 CH3L=1 CH2L=1 CH1L=0 = 0b1110 = 0xE
    #   Right nibble: CH4R=1 CH3R=1 CH2R=0 CH1R=1 = 0b1101 = 0xD
    PAN_WIDE_B = 0xED  # CH1 right, CH2 left, rest center

    pan_idx = [0]  # mutable counter for rotation

    def next_pan():
        """Rotate through pan positions slowly: A, A, B, B, center, center..."""
        cycle = [PAN_WIDE_A, PAN_WIDE_A, PAN_WIDE_B, PAN_WIDE_B,
                 PAN_CENTER, PAN_CENTER]
        p = cycle[pan_idx[0] % len(cycle)]
        pan_idx[0] += 1
        return p

    def add_echo(lead_fn, bass_fn, drums_fn, delay=3):
        """Add a song entry with echo + slowly rotating stereo pan."""
        lead_pat = lead_fn()
        lead_panned, echo = lead_pat.make_echo(delay=delay, echo_inst=BOLD,
                                                pan_nr51=next_pan())
        song.append((lead_panned, echo, bass_fn, drums_fn))

    def add_chord(lead_fn, harm_fn, bass_fn, drums_fn):
        """Add a song entry with traditional chord harmony (no echo)."""
        song.append((lead_fn(), harm_fn(), bass_fn, drums_fn))

    # I. OVERTURE (2) - Chords here (sparse, establishing the key)
    add_chord(lead_overture_1, harm_overture,   bass_overture,  drums_overture_sparse)
    add_chord(lead_overture_2, harm_overture_2, bass_overture,  drums_overture)

    # II. MARCH A (4) - ECHO with rotating pan
    add_echo(lead_march_1, bass_dm_drive, drums_march, delay=4)
    add_echo(lead_march_2, bass_dm_march, drums_march, delay=4)
    add_echo(lead_march_3, bass_dm_drive, drums_march_heavy, delay=3)
    add_echo(lead_march_4, bass_dm_march, drums_march, delay=4)

    # III. MARCH B (4) - Longer delays = cavernous hall
    add_echo(lead_march_1, bass_dm_dark, drums_march_heavy, delay=6)
    add_echo(lead_march_2, bass_dm_drive, drums_march_heavy, delay=6)
    add_echo(lead_march_3, bass_dm_dark, drums_march, delay=5)
    add_echo(lead_march_4, bass_dm_march, drums_fill, delay=6)

    # IV. LAMENT (4) - Echo here too, long delay = mournful reverb
    add_echo(lead_lament_1, bass_gm_drive,   drums_lament, delay=5)
    add_echo(lead_lament_2, bass_gm_descend, drums_lament, delay=6)
    add_echo(lead_lament_1, bass_gm_drive,   drums_lament, delay=5)
    add_echo(lead_lament_3, bass_gm_descend, drums_fill,   delay=6)

    # V. BATTLE (5) - Tight echo = powerful doubling
    add_echo(lead_battle_1, bass_battle,   drums_battle, delay=3)
    add_echo(lead_battle_2, bass_battle_2, drums_battle, delay=3)
    add_echo(lead_battle_3, bass_battle,   drums_battle, delay=4)
    add_echo(lead_battle_1, bass_battle_2, drums_battle, delay=3)
    add_echo(lead_battle_4, bass_battle,   drums_fill,   delay=3)

    # VI. REQUIEM (1) - Maximum echo delay = vast empty hall
    add_echo(lead_requiem, bass_requiem, drums_requiem, delay=8)

    # VII. ASCENSION (4) - Echo in the new key, building
    add_echo(lead_ascend_1, bass_ebm_drive, drums_ascend,      delay=4)
    add_echo(lead_ascend_2, bass_ebm_drive, drums_ascend,      delay=4)
    add_echo(lead_ascend_3, bass_ebm_drive, drums_march_heavy, delay=3)
    add_echo(lead_ascend_4, bass_ebm_pivot, drums_fill,        delay=4)

    # VIII. GLORY (3) - Grand finale, echo tightening for power
    add_echo(lead_glory_1, bass_glory, drums_march_heavy, delay=3)
    add_echo(lead_glory_2, bass_glory, drums_march,       delay=4)
    add_echo(lead_glory_3, bass_glory, drums_lament,      delay=6)

    return song


def build_song():
    """Original version (chord harmony)."""
    return [
        (lead_overture_1(),  harm_overture(),   bass_overture,    drums_overture_sparse),
        (lead_overture_2(),  harm_overture_2(), bass_overture,    drums_overture),
        (lead_march_1(),     harm_dm(),         bass_dm_drive,    drums_march),
        (lead_march_2(),     harm_dm_2(),       bass_dm_march,    drums_march),
        (lead_march_3(),     harm_dm_resolve(), bass_dm_drive,    drums_march_heavy),
        (lead_march_4(),     harm_dm(),         bass_dm_march,    drums_march),
        (lead_march_1(),     harm_dm_2(),       bass_dm_dark,     drums_march_heavy),
        (lead_march_2(),     harm_dm(),         bass_dm_drive,    drums_march_heavy),
        (lead_march_3(),     harm_dm_resolve(), bass_dm_dark,     drums_march),
        (lead_march_4(),     harm_dm_2(),       bass_dm_march,    drums_fill),
        (lead_lament_1(),    harm_gm(),         bass_gm_drive,    drums_lament),
        (lead_lament_2(),    harm_gm_2(),       bass_gm_descend,  drums_lament),
        (lead_lament_1(),    harm_gm_2(),       bass_gm_drive,    drums_lament),
        (lead_lament_3(),    harm_gm(),         bass_gm_descend,  drums_fill),
        (lead_battle_1(),    harm_battle(),     bass_battle,      drums_battle),
        (lead_battle_2(),    harm_battle_2(),   bass_battle_2,    drums_battle),
        (lead_battle_3(),    harm_battle(),     bass_battle,      drums_battle),
        (lead_battle_1(),    harm_battle_2(),   bass_battle_2,    drums_battle),
        (lead_battle_4(),    harm_battle(),     bass_battle,      drums_fill),
        (lead_requiem(),     harm_requiem(),    bass_requiem,     drums_requiem),
        (lead_ascend_1(),    harm_ebm(),        bass_ebm_drive,   drums_ascend),
        (lead_ascend_2(),    harm_ebm_2(),      bass_ebm_drive,   drums_ascend),
        (lead_ascend_3(),    harm_ebm_2(),      bass_ebm_drive,   drums_march_heavy),
        (lead_ascend_4(),    harm_ebm_pivot(),  bass_ebm_pivot,   drums_fill),
        (lead_glory_1(),     harm_glory(),      bass_glory,       drums_march_heavy),
        (lead_glory_2(),     harm_glory(),      bass_glory,       drums_march),
        (lead_glory_3(),     harm_glory(),      bass_glory,       drums_lament),
    ]


def write_uge(output_path='klingon.uge', opera=False):
    song = build_song_opera() if opera else build_song()
    num_orders = len(song)
    mode_name = "Opera (echo+pan)" if opera else "Standard (chords)"
    print(f"Mode: {mode_name}")

    all_cells = []
    ch_order = [[], [], [], []]
    seen = {}
    next_key = 0

    for entry in song:
        for ch in range(4):
            item = entry[ch]
            # CH1/CH2 are Pattern objects, CH3/CH4 are functions
            if isinstance(item, Pattern):
                pat = item
            else:
                pat = item()
            cells = pat.get_cells()
            if cells in seen:
                ch_order[ch].append(seen[cells])
            else:
                seen[cells] = next_key
                all_cells.append(cells)
                ch_order[ch].append(next_key)
                next_key += 1

    empty_cells = tuple([(NO_NOTE, 0, 0, 0, 0)] * 64)
    if empty_cells not in seen:
        seen[empty_cells] = next_key
        all_cells.append(empty_cells)

    total_keys = len(all_cells)
    est_asm = total_keys * 194 + 4 * num_orders * 2 + 200
    print(f"Song: {num_orders} orders, {total_keys} unique patterns")
    print(f"Estimated assembly: ~{est_asm} bytes (limit 16384)")

    ticks_per_row = 4

    with open(output_path, 'wb') as f:
        write_uge_int(f, UGE_FORMAT_VERSION)
        write_uge_shortstring(f, "Klingon March")
        write_uge_shortstring(f, "D.R.Horn")
        song_comment = "qo'noS battle opera - stereo echo" if opera else "qo'noS battle opera"
        write_uge_shortstring(f, song_comment)

        # Duty instruments (15): pattern inst=N -> .uge[N-1]
        write_uge_instrument(f, type_=0, name="Declarative", initial_volume=15, duty=2,
                            vol_sweep_dir=1, vol_sweep_amount=7)  # [0] DECL=1, 50% duty, very slow decay
        write_uge_instrument(f, type_=0, name="Echo", initial_volume=12, duty=2,
                            vol_sweep_dir=1, vol_sweep_amount=4)  # [1] BOLD=2, fades like real echo
        write_uge_instrument(f, type_=0, name="Ghost", initial_volume=5, duty=0,
                            vol_sweep_dir=1, vol_sweep_amount=2)  # [2] GHOST=3
        write_uge_instrument(f, type_=0, name="Swell", initial_volume=8, duty=2,
                            vol_sweep_dir=1, vol_sweep_amount=1)  # [3] SWELL=4
        for _ in range(11):
            write_uge_instrument(f, type_=0)

        # Wave instruments (15): pattern inst=N -> .uge[N-1]
        write_uge_instrument(f, type_=1, name="Bass", output_level=1)  # [0] BASS=1, 100% vol
        for _ in range(14):
            write_uge_instrument(f, type_=1)

        # Noise instruments (15): pattern inst=N -> .uge[N-1]
        write_uge_instrument(f, type_=2, name="HiHat", initial_volume=2,
                            vol_sweep_dir=1, vol_sweep_amount=3,
                            length=4, length_enabled=True)   # [0] HH=1
        write_uge_instrument(f, type_=2, name="Snare", initial_volume=8,
                            vol_sweep_dir=1, vol_sweep_amount=4,
                            length=10, length_enabled=True)  # [1] SN=2
        write_uge_instrument(f, type_=2, name="Kick", initial_volume=10,
                            vol_sweep_dir=1, vol_sweep_amount=3,
                            length=14, length_enabled=True)  # [2] KK=3
        for _ in range(12):
            write_uge_instrument(f, type_=2)

        # Waveforms (16 x 32 bytes)
        # 0: Warm descending sawtooth from Rulz_FastPaceSpeedRace
        #    Smooth staircase: each value held 2 samples, no sharp jumps
        f.write(bytes([15,15,14,14,13,13,12,12,11,11,10,10,9,9,8,8,
                       7,7,6,6,5,5,4,4,3,3,2,2,1,1,0,0]))
        # 1: Triangle
        f.write(bytes([15,14,13,12,11,10,9,8,7,6,5,4,3,2,1,0,
                       1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,15]))
        # 2: Sine (from Rulz)
        f.write(bytes([7,10,12,13,13,11,7,5,2,1,1,3,6,8,11,13,
                       13,12,9,7,4,1,0,1,4,7,9,12,13,13,11,8]))
        # 3: Ascending sawtooth (from Rulz)
        f.write(bytes([0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,
                       7,8,8,9,9,10,10,11,11,12,12,13,13,14,14,15]))
        for _ in range(12):
            f.write(bytes(32))

        write_uge_int(f, ticks_per_row)
        f.write(bytes([0]))
        write_uge_int(f, 0)

        write_uge_int(f, total_keys)
        for key, cells in enumerate(all_cells):
            write_uge_int(f, key)
            for note, inst, vol, eff, ep in cells:
                write_uge_cell(f, note=note, instrument=inst, volume=vol,
                              effect_code=eff, effect_params=ep)

        for ch in range(4):
            order = ch_order[ch]
            order_len = len(order) + 1
            write_uge_int(f, order_len)
            for key in order:
                write_uge_int(f, key)
            write_uge_int(f, ch_order[ch][2])  # loop to March A

        for _ in range(16):
            write_uge_int(f, 0)

    import os
    file_size = os.path.getsize(output_path)
    total_rows = num_orders * 64
    seconds = total_rows * ticks_per_row / 59.7
    print(f"\nOverture -> March -> Lament(Gm) -> Battle(D harm) -> Requiem -> Glory")
    print(f"Tempo: ~{60.0 / (8 * ticks_per_row / 59.7):.0f} BPM")
    print(f"Duration: ~{seconds:.0f}s ({seconds/60:.1f} min), loops to March")
    print(f"Output: {output_path} ({file_size} bytes)")


if __name__ == '__main__':
    import sys
    if '--opera' in sys.argv:
        write_uge('klingon_opera.uge', opera=True)
    else:
        write_uge('klingon.uge', opera=False)
    # Generate both if --both
    if '--both' in sys.argv:
        write_uge('klingon.uge', opera=False)
        print()
        write_uge('klingon_opera.uge', opera=True)
