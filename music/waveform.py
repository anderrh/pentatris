#!/usr/bin/env python3
"""
Create a copy of a .uge file with a different bass waveform.

Usage:
  python3 waveform.py input.uge staircase     # -> input_staircase.uge
  python3 waveform.py input.uge plateau       # -> input_plateau.uge
  python3 waveform.py input.uge asymmetric    # -> input_asymmetric.uge
  python3 waveform.py input.uge curved        # -> input_curved.uge
  python3 waveform.py input.uge sine          # -> input_sine.uge
  python3 waveform.py input.uge triangle      # -> input_triangle.uge
  python3 waveform.py input.uge ascending     # -> input_ascending.uge
  python3 waveform.py input.uge custom 15,15,14,14,...  # -> input_custom.uge
  python3 waveform.py list                    # Show all presets
"""

import sys
import os
import shutil

PRESETS = {
    'staircase': {
        'desc': 'Smooth descending staircase (from Rulz_FastPaceSpeedRace)',
        'wave': [15,15,14,14,13,13,12,12,11,11,10,10,9,9,8,8,
                  7,7,6,6,5,5,4,4,3,3,2,2,1,1,0,0],
    },
    'plateau': {
        'desc': 'Lingering peaks, extra warmth',
        'wave': [15,15,15,14,14,13,13,12,12,11,11,10,10,9,9,8,
                  7,7,6,6,5,5,4,4,3,3,2,2,1,1,0,0],
    },
    'asymmetric': {
        'desc': 'Faster descent, more time high = brasher/brighter',
        'wave': [15,15,15,15,14,14,14,13,13,12,12,11,11,10,9,8,
                  7,6,5,5,4,4,3,3,2,2,2,1,1,0,0,0],
    },
    'curved': {
        'desc': 'Exponential-ish descent, mimics natural instrument decay',
        'wave': [15,15,14,14,13,13,12,11,11,10,9,9,8,7,7,6,
                  5,5,4,4,3,3,2,2,2,1,1,1,0,0,0,0],
    },
    'sine': {
        'desc': 'Sine wave from Rulz (wave 6)',
        'wave': [7,10,12,13,13,11,7,5,2,1,1,3,6,8,11,13,
                 13,12,9,7,4,1,0,1,4,7,9,12,13,13,11,8],
    },
    'triangle': {
        'desc': 'Triangle wave from Rulz (wave 5)',
        'wave': [15,14,13,12,11,10,9,8,7,6,5,4,3,2,1,0,
                  1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,15],
    },
    'ascending': {
        'desc': 'Ascending staircase sawtooth',
        'wave': [0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,
                 8,8,9,9,10,10,11,11,12,12,13,13,14,14,15,15],
    },
}

# The waveform 0 starts at a fixed offset in .uge files:
# header(4) + 3 shortstrings(3*256) + 45 instruments(45*1385) + waveform_0_start
# Each instrument: int(4) + shortstring(256) + int(4) + byte(1) + byte(1) + int(4)
#   + byte(1) + int(4) + int(4) + int(4) + byte(1) + int(4) + int(4) + int(4)
#   + byte(1) + 64 cells(64*17)
# = 4+256+4+1+1+4+1+4+4+4+1+4+4+4+1+64*17 = 297+1088 = 1385
INST_SIZE = 4 + 256 + 4 + 1 + 1 + 4 + 1 + 4 + 4 + 4 + 1 + 4 + 4 + 4 + 1 + 64*17
WAVE0_OFFSET = 4 + 3*256 + 45*INST_SIZE  # = 63097


def create_variant(input_path, wave_data, preset_name):
    """Copy a .uge file and replace waveform 0 in the copy."""
    if not os.path.exists(input_path):
        print(f"  Error: {input_path} not found")
        return None
    base, ext = os.path.splitext(input_path)
    output_path = f"{base}_{preset_name}{ext}"
    shutil.copy2(input_path, output_path)
    with open(output_path, 'r+b') as f:
        f.seek(WAVE0_OFFSET)
        old = list(f.read(32))
        f.seek(WAVE0_OFFSET)
        f.write(bytes(wave_data))
    print(f"  {output_path}")
    print(f"    waveform: {wave_data}")
    return output_path


def main():
    if len(sys.argv) < 2 or sys.argv[1] in ('-h', '--help', 'help'):
        print(__doc__)
        return

    if sys.argv[1].lower() == 'list':
        print("Available waveform presets:\n")
        for name, info in PRESETS.items():
            wave = info['wave']
            print(f"  {name:14s}  {info['desc']}")
            print(f"  {'':14s}  [{','.join(str(v) for v in wave[:16])},")
            print(f"  {'':14s}   {','.join(str(v) for v in wave[16:])}]")
            print()
        return

    if len(sys.argv) < 3:
        print("Usage: python3 waveform.py <input.uge> <preset>")
        print("       python3 waveform.py list")
        return

    input_path = sys.argv[1]
    cmd = sys.argv[2].lower()

    if cmd == 'custom':
        if len(sys.argv) < 4:
            print("Usage: python3 waveform.py input.uge custom 15,15,14,14,...")
            return
        try:
            values = [int(x.strip()) for x in sys.argv[3].split(',')]
            if len(values) != 32:
                print(f"Error: need exactly 32 values, got {len(values)}")
                return
            if any(v < 0 or v > 15 for v in values):
                print("Error: all values must be 0-15")
                return
            wave_data = values
            desc = "custom waveform"
        except ValueError:
            print("Error: values must be comma-separated integers 0-15")
            return
    elif cmd in PRESETS:
        wave_data = PRESETS[cmd]['wave']
        desc = PRESETS[cmd]['desc']
    else:
        print(f"Unknown preset '{cmd}'. Use 'list' to see options.")
        return

    print(f"Waveform: {cmd} - {desc}\n")
    result = create_variant(input_path, wave_data, cmd)
    if result:
        print(f"\nCreated: {result}")


if __name__ == '__main__':
    main()
