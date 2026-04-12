#!/usr/bin/env python3
"""Convert png2asset C output for background maps to binary files.

Reads a png2asset-generated C file (with -map -use_map_attributes) and
produces three binary files matching the rgbgfx output format:
  - .2bpp    : tile data (raw 2bpp, 16 bytes per tile)
  - .tilemap : tile map (1 byte per tile position)
  - .attrmap : attribute map (1 byte per tile position)

Usage:
    python3 bg2bin.py <input.c> <output_prefix>

Example:
    python3 bg2bin.py gfx/gen/UserInterface.c gfx/UserInterface
    # produces: gfx/UserInterface.2bpp, gfx/UserInterface.tilemap, gfx/UserInterface.attrmap
"""

import re
import sys


def parse_c_array(content, pattern):
    """Extract a C array's values as a list of integers."""
    m = re.search(pattern, content, re.DOTALL)
    if not m:
        return None
    array_body = m.group(1)
    values = []
    for token in re.findall(r'0x[0-9a-fA-F]+|\d+', array_body):
        values.append(int(token, 0))
    return values


def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <input.c> <output_prefix>")
        sys.exit(1)

    input_path = sys.argv[1]
    output_prefix = sys.argv[2]

    with open(input_path) as f:
        content = f.read()

    # Extract tile data
    tiles = parse_c_array(content, r'_tiles\[\d+\]\s*=\s*\{([^}]+)\}')
    if tiles is None:
        print(f"Error: no tile data found in {input_path}")
        sys.exit(1)

    # Extract tile map
    tilemap = parse_c_array(content, r'_map\[\d+\]\s*=\s*\{([^}]+)\}')
    if tilemap is None:
        print(f"Error: no map data found in {input_path}")
        sys.exit(1)

    # Extract attribute map
    attrmap = parse_c_array(content, r'_map_attributes\[\d+\]\s*=\s*\{([^}]+)\}')
    if attrmap is None:
        print(f"Error: no map_attributes data found in {input_path}")
        sys.exit(1)

    # Write binary files
    with open(f"{output_prefix}.2bpp", 'wb') as f:
        f.write(bytes(tiles))
    with open(f"{output_prefix}.tilemap", 'wb') as f:
        f.write(bytes(tilemap))
    with open(f"{output_prefix}.attrmap", 'wb') as f:
        f.write(bytes(attrmap))

    print(f"  {output_prefix}.2bpp     : {len(tiles)} bytes ({len(tiles)//16} tiles)")
    print(f"  {output_prefix}.tilemap  : {len(tilemap)} bytes")
    print(f"  {output_prefix}.attrmap  : {len(attrmap)} bytes")


if __name__ == '__main__':
    main()
