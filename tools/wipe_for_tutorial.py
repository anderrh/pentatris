#!/usr/bin/env python3
"""
wipe_for_tutorial.py - Replace tutorial function bodies with stubs.

Run this on the asm_port branch to create a skeleton for the student.
Each function listed in FUNCTIONS_TO_WIPE is replaced with a simple
`ret` or `xor a / ret` stub, preserving all boilerplate (includes,
sections, variable declarations, data).

Usage:
    python3 tools/wipe_for_tutorial.py
"""

import re
import os

# Functions to wipe: (file, label, stub_lines)
# stub_lines is what replaces the function body (after the label line)
FUNCTIONS_TO_WIPE = [
    # runtime.asm - foundational functions the student implements first
    ("asm/runtime.asm", "move_sprite::", [
        "    ; TODO: Implement move_sprite",
        "    ; A=sprite_id, B=x, C=y -> write Y and X to shadow OAM",
        "    ret",
    ]),
    ("asm/runtime.asm", "set_sprite_tile::", [
        "    ; TODO: Implement set_sprite_tile",
        "    ; A=sprite_id, B=tile -> write tile to shadow OAM",
        "    ret",
    ]),
    ("asm/runtime.asm", "get_bkg_tile_xy::", [
        "    ; TODO: Implement get_bkg_tile_xy",
        "    ; B=x, C=y -> A=tile at that background position",
        "    xor a",
        "    ret",
    ]),
    ("asm/runtime.asm", "set_bkg_tile_xy::", [
        "    ; TODO: Implement set_bkg_tile_xy",
        "    ; B=x, C=y, D=tile -> write tile to background tilemap",
        "    ret",
    ]),
    ("asm/runtime.asm", "wait_vbl_done::", [
        "    ; TODO: Implement wait_vbl_done",
        "    ; Halt CPU until VBlank interrupt sets wVBlankFlag",
        "    ret",
    ]),
    ("asm/runtime.asm", "hide_metasprite::", [
        "    ; TODO: Implement hide_metasprite",
        "    ; HL=metasprite, A=base_sprite -> hide all sprites in metasprite",
        "    ret",
    ]),

    # common.asm
    ("asm/common.asm", "_RandomNumber::", [
        "    ; TODO: Implement RandomNumber",
        "    ; B = min, C = max -> A = result in [min, max)",
        "    xor a",
        "    ret",
    ]),
    ("asm/common.asm", "_ResetAllSprites::", [
        "    ; TODO: Implement ResetAllSprites",
        "    ; Reset all 40 sprites: set_sprite_tile(i,0); move_sprite(i,160,160)",
        "    ret",
    ]),

    # hud.asm
    ("asm/hud.asm", "_DrawNumber::", [
        "    ; TODO: Implement DrawNumber",
        "    ; B=x, C=y, DE=number, A=digits -> draw number on BG",
        "    ret",
    ]),
    ("asm/hud.asm", "_UpdateGui::", [
        "    ; TODO: Implement UpdateGui",
        "    ; Redraw score, level, lines, and next piece preview",
        "    ret",
    ]),
    ("asm/hud.asm", "_IncreaseScore::", [
        "    ; TODO: Implement IncreaseScore",
        "    ; A = amount to add to 16-bit _score, then call _UpdateGui",
        "    ret",
    ]),

    # UserInterface.asm
    ("asm/UserInterface.asm", "_SetupAnimatedBackground::", [
        "    ; TODO: Implement SetupAnimatedBackground",
        "    ; Scan 32x32 BG tiles, replace _tileAnimationBase with checkerboard",
        "    ret",
    ]),
    ("asm/UserInterface.asm", "_SetupUserInterface::", [
        "    ; TODO: Implement SetupUserInterface",
        "    ; Load UI tilemap, read reference tiles, fill borders, call SetupAnimatedBackground",
        "    ret",
    ]),
    ("asm/UserInterface.asm", "_AnimateBackground::", [
        "    ; TODO: Implement AnimateBackground",
        "    ; Advance tile animation counter and update VRAM tile frames",
        "    ret",
    ]),

    # Tetrominos.asm
    ("asm/Tetrominos.asm", "_CanPieceBePlacedHere::", [
        "    ; TODO: Implement CanPieceBePlacedHere",
        "    ; B=piece, C=rotation, D=column, E=row -> A=1 if fits, 0 if blocked",
        "    ld a, 1",
        "    ret",
    ]),
    ("asm/Tetrominos.asm", "_PickNewTetromino::", [
        "    ; TODO: Implement PickNewTetromino",
        "    ; Spawn next piece at (5,0), generate new random next piece",
        "    ; Returns A=1 success, A=0 game over",
        "    ld a, 1",
        "    ret",
    ]),

    # Board.asm
    ("asm/Board.asm", "_IsRowFull::", [
        "    ; TODO: Implement IsRowFull",
        "    ; B=row, C=both_flag -> A=1 if full, 0 if not",
        "    xor a",
        "    ret",
    ]),
    ("asm/Board.asm", "_ShiftAllTilesAboveThisRowDown::", [
        "    ; TODO: Implement ShiftAllTilesAboveThisRowDown",
        "    ; B=row -> clear row, shift all rows above it down by one",
        "    ret",
    ]),
    ("asm/Board.asm", "_ShiftAllTilesDown::", [
        "    ; TODO: Implement ShiftAllTilesDown",
        "    ; Scan rows 17..0, while row is full shift it down",
        "    ret",
    ]),
    ("asm/Board.asm", "_BlinkFullRows::", [
        "    ; TODO: Implement BlinkFullRows",
        "    ; Detect full rows, score them, blink animation, clear window",
        "    ret",
    ]),
    ("asm/Board.asm", "_SetCurrentPieceInBackground::", [
        "    ; TODO: Implement SetCurrentPieceInBackground",
        "    ; Copy current piece's sprite tiles into the background tilemap",
        "    ret",
    ]),

    # gameplay.asm - _UpdateFallTimer is extracted from main.asm by this script
    ("asm/gameplay.asm", "_UpdateFallTimer::", [
        "    ; TODO: Implement UpdateFallTimer",
        "    ; Increment fall timer, try to move piece down, handle lock delay",
        "    ret",
    ]),
    ("asm/gameplay.asm", "_HandleInput::", [
        "    ; TODO: Implement HandleInput",
        "    ; Read joypad, handle rotation/movement/acceleration",
        "    ret",
    ]),
    ("asm/gameplay.asm", "_SetupVRAM::", [
        "    ; TODO: Implement SetupVRAM",
        "    ; Load all tile data and palettes into VRAM",
        "    ret",
    ]),
    ("asm/gameplay.asm", "_SetupGameplay::", [
        "    ; TODO: Implement SetupGameplay",
        "    ; Initialize game state for a new round",
        "    ret",
    ]),
]


def find_function_end(lines, start_idx):
    """
    Find the end of a function starting at start_idx (the label line).
    A function ends at:
    - The next global label (line starts with a letter or _, not '.' or whitespace)
    - A SECTION directive
    - End of file
    """
    i = start_idx + 1
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        # Skip empty lines and comments
        if not stripped or stripped.startswith(';'):
            i += 1
            continue
        # Check for next global label or SECTION directive.
        # Global labels start at column 0 (no leading whitespace) and
        # begin with a letter or underscore (not '.' which is a local label).
        if line[0:1] not in (' ', '\t', '.', '\n', '\r', ''):
            if re.match(r'^[A-Za-z_]', line):
                return i
        # Check for SECTION directive (may be indented in some styles)
        if stripped.upper().startswith('SECTION '):
            return i
        i += 1
    return i  # end of file


def wipe_functions_in_file(filepath, functions):
    """
    Wipe the specified functions in a file.
    functions: list of (label, stub_lines)
    """
    with open(filepath, 'r') as f:
        lines = f.readlines()

    # Process functions in reverse order of their position in the file
    # so that line indices remain valid as we modify the list
    replacements = []
    for label, stub in functions:
        for i, line in enumerate(lines):
            if line.strip() == label or line.strip().startswith(label):
                # Make sure the label is at the start (possibly with leading whitespace)
                if label in line:
                    end = find_function_end(lines, i)
                    replacements.append((i, end, label, stub))
                    break

    # Sort by position (reverse) so we can modify without invalidating indices
    replacements.sort(key=lambda x: x[0], reverse=True)

    for start, end, label, stub in replacements:
        # Keep the label line, replace everything until end with stub
        label_line = lines[start]
        stub_text = [label_line] + [s + '\n' for s in stub] + ['\n']
        lines[start:end] = stub_text
        print(f"  Wiped {label} in {filepath} (lines {start+1}-{end})")

    with open(filepath, 'w') as f:
        f.writelines(lines)


def revert_pentatris():
    """
    Revert pentatris-specific changes so the student starts with tetris-only.
    After completing the asm tutorial, they follow the pentatris tutorial to
    re-apply these changes.
    """
    print("Reverting pentatris-specific changes...")

    # 1. Set PENTO ?= 0 in Makefile
    makefile = "Makefile"
    if os.path.exists(makefile):
        with open(makefile, 'r') as f:
            content = f.read()
        if 'PENTO ?= 1' in content:
            content = content.replace('PENTO ?= 1', 'PENTO ?= 0')
            with open(makefile, 'w') as f:
                f.write(content)
            print(f"  Set PENTO ?= 0 in {makefile}")

    # 2. Reduce test_Tetrominos count from 8 to 6 and remove pentomino tests
    tet_test = "tests/test_Tetrominos.asm"
    if os.path.exists(tet_test):
        with open(tet_test, 'r') as f:
            content = f.read()
        # Change test count
        content = content.replace('    ld a, 8\n    ld [wTestCount]', '    ld a, 6\n    ld [wTestCount]')
        # Remove test 6 and 7 (pentomino tests) - they're at the end before .test_done
        marker6 = '.test6:'
        marker_done = '.test_done:'
        idx6 = content.find(marker6)
        idx_done = content.find(marker_done)
        if idx6 > 0 and idx_done > idx6:
            # Find the jump that goes to test6 and change it to test_done
            content = content.replace('jr .test6', 'jr .test_done')
            content = content.replace('jp .test6', 'jp .test_done')
            # Remove the test6/test7 code
            content = content[:idx6] + content[idx_done:]
        with open(tet_test, 'w') as f:
            f.write(content)
        print(f"  Removed pentomino tests from {tet_test} (8 -> 6 tests)")

    # 3. Reduce test_Board count from 9 to 8 and remove pentomino test
    board_test = "tests/test_Board.asm"
    if os.path.exists(board_test):
        with open(board_test, 'r') as f:
            content = f.read()
        # Change test count
        content = content.replace('    ld a, 9\n    ld [wTestCount]', '    ld a, 8\n    ld [wTestCount]')
        # Remove test 8 (pentomino SetCurrentPieceInBackground test)
        marker8 = '.test8:'
        marker_done = '.test_done:'
        idx8 = content.find(marker8)
        idx_done = content.find(marker_done)
        if idx8 > 0 and idx_done > idx8:
            content = content.replace('jr .test8', 'jr .test_done')
            content = content.replace('jp .test8', 'jp .test_done')
            content = content[:idx8] + content[idx_done:]
        with open(board_test, 'w') as f:
            f.write(content)
        print(f"  Removed pentomino test from {board_test} (9 -> 8 tests)")

    print()


def main():
    # Step 1: Revert pentatris to tetris-only
    revert_pentatris()

    # Step 2: Group functions by file and wipe them
    by_file = {}
    for filepath, label, stub in FUNCTIONS_TO_WIPE:
        if filepath not in by_file:
            by_file[filepath] = []
        by_file[filepath].append((label, stub))

    print("Wiping tutorial function bodies...")
    print()

    for filepath, functions in sorted(by_file.items()):
        if not os.path.exists(filepath):
            print(f"WARNING: {filepath} not found, skipping")
            continue
        print(f"Processing {filepath}:")
        wipe_functions_in_file(filepath, functions)
        print()

    print("Done! All function bodies have been replaced with stubs.")
    print("The game is now tetris-only with stub functions.")
    print("Follow asm_tutorial.html to implement all functions.")
    print("Then follow pentatris_tutorial.html to add pentomino support.")
    print()
    print("Run 'make clean && make gfx && make' to build the skeleton ROM.")
    print("Run 'make test' to see which functions still need implementation.")


if __name__ == '__main__':
    main()
