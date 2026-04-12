#!/usr/bin/env python3
"""
generate_pentominoes.py - Generate pentomino sprite sheet PNGs for Game Boy

Creates 18 PNG files (Pentomino1.png through Pentomino18.png) in Graphics/
Each is 160x40 pixels (4 rotations x 40x40 frame, using 8x8 cells).

The PNGs use indexed color with a 32-entry palette matching the existing
tetromino sprite sheets, ensuring correct CGB palette mapping by png2asset.

Usage:
    python3 tools/generate_pentominoes.py
"""

from PIL import Image
import os
import sys

# =============================================================================
# Constants
# =============================================================================

CELL_SIZE = 8
FRAME_SIZE = 40   # 5 cells x 8 pixels per cell
SHEET_W = 160     # 4 rotations x 40 pixels
SHEET_H = 40

OUTPUT_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'Graphics')

# Dummy/filler color for unused palette indices
DUMMY = (255, 0, 168)

# =============================================================================
# Palette data - extracted from existing tetromino PNGs
# =============================================================================
# Each sub-palette has 4 colors: [bg/transparent, color1, color2, color3]
# The sub-palette index determines the CGB palette register (0-7).
# Color index within sub-palette: 0=transparent, 1-3=visible.

PALETTES = [
    # Pal 0 (Tetromino1 - orange):
    [(113, 198, 233), (120, 40, 0),   (0, 0, 0),     (248, 120, 48)],
    # Pal 1 (Tetromino2 - green):
    [(113, 198, 233), (248, 248, 248), (0, 0, 0),     (96, 248, 96)],
    # Pal 2 (Tetromino3 - amber):
    [(113, 198, 233), (248, 248, 248), (0, 0, 0),     (248, 160, 8)],
    # Pal 3 (Tetromino4 - magenta):
    [(113, 198, 233), (248, 248, 248), (0, 0, 0),     (248, 0, 248)],
    # Pal 4 (Tetromino5 - blue):
    [(41, 126, 174),  (248, 248, 248), (0, 0, 0),     (113, 198, 233)],
    # Pal 5 (Tetromino6 - red):
    [(248, 160, 8),   (0, 0, 0),       (248, 248, 0), (248, 0, 0)],
    # Pal 6 (Tetromino7 - yellow):
    [(113, 198, 233), (0, 0, 0),       (0, 0, 0),     (248, 248, 0)],
    # Pal 7 (unused - placeholder):
    [(113, 198, 233), (0, 0, 0),       (0, 0, 0),     (0, 0, 0)],
]

# Per-palette: (border_offset, fill_offset) within the 4-color sub-palette.
# "Border" is always the black color; "fill" is the distinctive piece color.
PALETTE_ROLES = [
    (2, 3),  # Pal 0: black=offset 2, orange=offset 3
    (2, 3),  # Pal 1: black=offset 2, green=offset 3
    (2, 3),  # Pal 2: black=offset 2, amber=offset 3
    (2, 3),  # Pal 3: black=offset 2, magenta=offset 3
    (2, 3),  # Pal 4: black=offset 2, blue=offset 3
    (1, 3),  # Pal 5: black=offset 1, red=offset 3
    (1, 3),  # Pal 6: black=offset 1, yellow=offset 3
    (1, 3),  # Pal 7: placeholder
]

# =============================================================================
# Pentomino shape definitions
# =============================================================================
# Each entry: (letter_name, cells_as_row_col_tuples, palette_index)
#
# The 18 one-sided pentominoes (12 free + 6 mirror variants).
# Mirror variants are denoted with 'm' suffix (F', L'=J, N', P', Y', Z'=S).
#
# Shapes drawn for reference:
#
# F:  .##    Fm: ##.    I: #####    L: #.    Lm: .#
#     ##.        .##       (bar)       #.        .#
#     .#.        .#.                   #.        .#
#                                      ##        ##
#
# N:  .#     Nm: #.     P: ##     Pm: ##    T: ###
#     ##         ##        ##         ##       .#.
#     #.         .#        #.         .#       .#.
#     #.         .#
#
# U: #.#    V: #..    W: #..    X: .#.    Y: .#     Ym: #.
#    ###       #..       ##.       ###       ##         ##
#              ###       .##       .#.       .#         #.
#                                            .#         #.
#
# Z: ##.    Zm: .##
#    .#.        .#.
#    .##        ##.

PENTOMINOES = [
    ('F',  [(0, 1), (0, 2), (1, 0), (1, 1), (2, 1)], 0),
    ('Fm', [(0, 0), (0, 1), (1, 1), (1, 2), (2, 1)], 1),
    ('I',  [(0, 0), (0, 1), (0, 2), (0, 3), (0, 4)], 2),
    ('L',  [(0, 0), (1, 0), (2, 0), (3, 0), (3, 1)], 3),
    ('Lm', [(0, 1), (1, 1), (2, 1), (3, 0), (3, 1)], 4),
    ('N',  [(0, 1), (1, 0), (1, 1), (2, 0), (3, 0)], 5),
    ('Nm', [(0, 0), (1, 0), (1, 1), (2, 1), (3, 1)], 6),
    ('P',  [(0, 0), (0, 1), (1, 0), (1, 1), (2, 0)], 0),
    ('Pm', [(0, 0), (0, 1), (1, 0), (1, 1), (2, 1)], 1),
    ('T',  [(0, 0), (0, 1), (0, 2), (1, 1), (2, 1)], 2),
    ('U',  [(0, 0), (0, 2), (1, 0), (1, 1), (1, 2)], 3),
    ('V',  [(0, 0), (1, 0), (2, 0), (2, 1), (2, 2)], 4),
    ('W',  [(0, 0), (1, 0), (1, 1), (2, 1), (2, 2)], 5),
    ('X',  [(0, 1), (1, 0), (1, 1), (1, 2), (2, 1)], 6),
    ('Y',  [(0, 1), (1, 0), (1, 1), (2, 1), (3, 1)], 0),
    ('Ym', [(0, 0), (1, 0), (1, 1), (2, 0), (3, 0)], 1),
    ('Z',  [(0, 0), (0, 1), (1, 1), (2, 1), (2, 2)], 2),
    ('Zm', [(0, 1), (0, 2), (1, 1), (2, 0), (2, 1)], 3),
]


# =============================================================================
# Rotation logic
# =============================================================================

def rotate_90cw(cells):
    """Rotate cells 90 degrees clockwise and normalize to (0,0) origin.

    Transform: (r, c) -> (c, max_r - r), then shift so min is (0,0).
    """
    max_r = max(r for r, c in cells)
    rotated = [(c, max_r - r) for r, c in cells]
    min_r = min(r for r, c in rotated)
    min_c = min(c for r, c in rotated)
    return tuple(sorted((r - min_r, c - min_c) for r, c in rotated))


def get_4_rotations(cells):
    """Return list of 4 rotations (0, 90, 180, 270 degrees CW).

    Symmetric pieces will have duplicate entries, which is intentional -
    the game uses piece*4+rotation indexing and expects exactly 4 slots.
    """
    cells = tuple(sorted(cells))
    rotations = [cells]
    current = cells
    for _ in range(3):
        current = rotate_90cw(current)
        rotations.append(current)
    return rotations


# =============================================================================
# PNG generation
# =============================================================================

def build_palette_for_piece(pal_idx):
    """Build a 768-byte (256x3) palette for an indexed PNG.

    Only the 4 entries for the piece's sub-palette have real colors.
    All other entries are filled with the dummy color.
    """
    flat = []
    for p in range(8):
        for c in range(4):
            if p == pal_idx:
                flat.extend(PALETTES[p][c])
            else:
                flat.extend(DUMMY)
    # Pad to 256 entries
    while len(flat) < 768:
        flat.extend(DUMMY)
    return flat


def make_cell_tile(pal_idx):
    """Create 8x8 cell as a 2D list of palette indices.

    Uses a square-in-square pattern matching Tetromino7's art style:
      BBBBBBBB
      BFFFFFFB
      BFBBBBFB
      BFBBBBFB
      BFBBBBFB
      BFBBBBFB
      BFFFFFFB
      BBBBBBBB
    """
    base = pal_idx * 4
    brd = base + PALETTE_ROLES[pal_idx][0]   # border (black)
    fill = base + PALETTE_ROLES[pal_idx][1]  # fill (distinctive color)
    B, F = brd, fill
    return [
        [B, B, B, B, B, B, B, B],
        [B, F, F, F, F, F, F, B],
        [B, F, B, B, B, B, F, B],
        [B, F, B, B, B, B, F, B],
        [B, F, B, B, B, B, F, B],
        [B, F, B, B, B, B, F, B],
        [B, F, F, F, F, F, F, B],
        [B, B, B, B, B, B, B, B],
    ]


def generate_pentomino_png(piece_num, name, cells, pal_idx):
    """Generate a 160x40 sprite sheet PNG for one pentomino."""
    img = Image.new('P', (SHEET_W, SHEET_H))
    img.putpalette(build_palette_for_piece(pal_idx))

    bg_idx = pal_idx * 4  # background/transparent = sub-palette color 0

    # Fill entire image with background
    pixels = [bg_idx] * (SHEET_W * SHEET_H)
    for i, px in enumerate(pixels):
        img.putpixel((i % SHEET_W, i // SHEET_W), px)

    # Get 4 rotations
    rotations = get_4_rotations(cells)
    cell_tile = make_cell_tile(pal_idx)

    # Draw each rotation frame
    for rot_idx, rot_cells in enumerate(rotations):
        frame_x = rot_idx * FRAME_SIZE
        for row, col in rot_cells:
            px_x = frame_x + col * CELL_SIZE
            px_y = row * CELL_SIZE
            # Verify within bounds
            assert px_x + CELL_SIZE <= SHEET_W, \
                f'{name} rot{rot_idx}: cell ({row},{col}) x overflow'
            assert px_y + CELL_SIZE <= SHEET_H, \
                f'{name} rot{rot_idx}: cell ({row},{col}) y overflow'
            for ty in range(CELL_SIZE):
                for tx in range(CELL_SIZE):
                    img.putpixel((px_x + tx, px_y + ty), cell_tile[ty][tx])

    filename = f'Pentomino{piece_num}.png'
    output_path = os.path.join(OUTPUT_DIR, filename)
    img.save(output_path)
    return filename


# =============================================================================
# Verification
# =============================================================================

def verify_shapes():
    """Verify all pentomino shapes have exactly 5 cells and fit in 5x5 grid."""
    for name, cells, pal_idx in PENTOMINOES:
        assert len(cells) == 5, f'{name}: expected 5 cells, got {len(cells)}'
        for r, c in cells:
            assert 0 <= r < 5, f'{name}: row {r} out of 5x5 grid'
            assert 0 <= c < 5, f'{name}: col {c} out of 5x5 grid'
        # Verify rotations fit
        for rot_idx, rot in enumerate(get_4_rotations(cells)):
            for r, c in rot:
                assert 0 <= r < 5, \
                    f'{name} rot{rot_idx}: row {r} out of 5x5 grid'
                assert 0 <= c < 5, \
                    f'{name} rot{rot_idx}: col {c} out of 5x5 grid'


def print_shapes():
    """Print all shapes and their rotations for visual verification."""
    for name, cells, pal_idx in PENTOMINOES:
        rotations = get_4_rotations(cells)
        unique = []
        seen = set()
        for r in rotations:
            if r not in seen:
                unique.append(r)
                seen.add(r)

        print(f'Pentomino {name} (pal {pal_idx}, '
              f'{len(unique)} unique rotation{"s" if len(unique) != 1 else ""}):')

        for rot_idx, rot in enumerate(rotations):
            max_r = max(r for r, c in rot)
            max_c = max(c for r, c in rot)
            grid = [['.' for _ in range(max_c + 1)] for _ in range(max_r + 1)]
            for r, c in rot:
                grid[r][c] = '#'
            dup = '' if rot in unique or rot_idx == 0 else ' (dup)'
            # Mark first occurrence
            if rot_idx > 0 and rot == rotations[0]:
                dup = ' (=rot0)'
            elif rot_idx > 1 and rot == rotations[1]:
                dup = ' (=rot1)'
            print(f'  Rot {rot_idx}{dup}:')
            for row in grid:
                print(f'    {"".join(row)}')
        print()


# =============================================================================
# Main
# =============================================================================

def main():
    verify_shapes()

    if '--preview' in sys.argv:
        print_shapes()
        return

    os.makedirs(OUTPUT_DIR, exist_ok=True)

    print(f'Generating {len(PENTOMINOES)} pentomino sprite sheets...')
    print()

    for i, (name, cells, pal_idx) in enumerate(PENTOMINOES, 1):
        filename = generate_pentomino_png(i, name, cells, pal_idx)
        rotations = get_4_rotations(cells)
        unique_count = len(set(rotations))
        dup_note = ''
        if unique_count < 4:
            dup_note = f' ({unique_count} unique, others duplicated)'
        print(f'  {filename:20s} {name:3s}  pal={pal_idx}  '
              f'4 rotations{dup_note}')

    print(f'\nDone. {len(PENTOMINOES)} PNGs written to {OUTPUT_DIR}/')


if __name__ == '__main__':
    main()
