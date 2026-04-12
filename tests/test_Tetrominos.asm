; =============================================================================
; test_Tetrominos.asm - Test ROM for Tetrominos module
; =============================================================================
; Tests PickNewTetromino and CanPieceBePlacedHere functions.
;
; Build: make test_Tetrominos
; Run:   node tests/run_tests.js dist/test_Tetrominos.gb
; =============================================================================

INCLUDE "runtime.inc"
INCLUDE "Tetrominos.inc"
INCLUDE "common.inc"

; Test result WRAM (fixed addresses for headless runner)
SECTION "TestResults", WRAM0[$CFF0]
wTestDone::    DS 1
wTestCount::   DS 1
wTestResults:: DS 8

; =============================================================================
; Test entry point
; =============================================================================

SECTION "TestMain", ROM0

_main::
    xor a
    ld [wTestDone], a
    ld a, 8
    ld [wTestCount], a

    ; === Test 0: PickNewTetromino should set currentX to 5 ===
    ld a, 3
    ld [_nextCurrentTetromino], a
    ld a, 2
    ld [_nextCurrentTetrominoRotation], a
    xor a
    ld [_currentX], a
    ld [_currentY], a
    ld [_currentTetromino], a

    ; Set blankTile so CanPieceBePlacedHere can check board
    ; Default VRAM tiles are 0, so blankTile=0 means board is empty
    xor a
    ld [_blankTile], a

    call _PickNewTetromino

    ; Check: currentX should be 5 (spawn column)
    ld a, [_currentX]
    cp 5
    jr nz, .test0_fail

    ld a, 1
    ld [wTestResults + 0], a
    jr .test1
.test0_fail:
    xor a
    ld [wTestResults + 0], a

.test1:
    ; === Test 1: PickNewTetromino should copy nextCurrentTetromino ===
    ld a, 3
    ld [_nextCurrentTetromino], a
    ld a, 2
    ld [_nextCurrentTetrominoRotation], a
    xor a
    ld [_currentTetromino], a
    ld [_blankTile], a

    call _PickNewTetromino

    ; Check: currentTetromino should be 3 (copied from next)
    ld a, [_currentTetromino]
    cp 3
    jr nz, .test1_fail

    ld a, 1
    ld [wTestResults + 1], a
    jr .test2
.test1_fail:
    xor a
    ld [wTestResults + 1], a

.test2:
    ; === Test 2: CanPieceBePlacedHere should return 0 for out-of-bounds row ===
    ; Row 20 is well past the board bottom (rows 0-17)
    xor a
    ld [_blankTile], a
    ld b, 0                         ; piece = 0
    ld c, 0                         ; rotation = 0
    ld d, 5                         ; column = 5
    ld e, 20                        ; row = 20 (out of bounds)
    call _CanPieceBePlacedHere

    ; Should return 0 (cannot place)
    or a
    jr nz, .test2_fail

    ld a, 1
    ld [wTestResults + 2], a
    jr .test3
.test2_fail:
    xor a
    ld [wTestResults + 2], a

.test3:
    ; === Test 3: PickNewTetromino should set currentY to 0 ===
    ld a, 3
    ld [_nextCurrentTetromino], a
    ld a, 2
    ld [_nextCurrentTetrominoRotation], a
    ld a, 10                        ; set to non-zero
    ld [_currentY], a
    xor a
    ld [_blankTile], a

    call _PickNewTetromino

    ; Check: currentY should be 0 (spawn at top)
    ld a, [_currentY]
    or a
    jr nz, .test3_fail

    ld a, 1
    ld [wTestResults + 3], a
    jr .test4
.test3_fail:
    xor a
    ld [wTestResults + 3], a

.test4:
    ; === Test 4: PickNewTetromino should copy rotation ===
    ld a, 3
    ld [_nextCurrentTetromino], a
    ld a, 2
    ld [_nextCurrentTetrominoRotation], a
    xor a
    ld [_currentTetrominoRotation], a
    ld [_blankTile], a

    call _PickNewTetromino

    ; Check: currentTetrominoRotation should be 2 (copied from next)
    ld a, [_currentTetrominoRotation]
    cp 2
    jr nz, .test4_fail

    ld a, 1
    ld [wTestResults + 4], a
    jr .test5
.test4_fail:
    xor a
    ld [wTestResults + 4], a

.test5:
    ; === Test 5: CanPieceBePlacedHere returns 0 when cell is occupied ===
    ; Place a non-blank tile where piece 0 rot 0 would land.
    ; I-piece rot 0 metasprite: 4 tiles in a horizontal row.
    ; At column=5 row=2, the metasprite offsets put tiles at BG positions
    ; around (finalColumn-1, finalRow-2). Place a blocker tile at (4, 0).
    ;
    ; blankTile = $FF, and we write $42 (non-blank) to the cell.
    ld a, $FF
    ld [_blankTile], a
    ; Fill play area with blankTile so board is "empty"
    ld e, 0
.fillForTest5:
    push de
    ld a, e
    add 2
    ld b, a
    ld c, 0
    ld d, $FF                       ; blankTile
    call set_bkg_tile_xy
    pop de
    inc e
    ld a, e
    cp 10
    jr c, .fillForTest5
    ; Now place a blocker where piece would go
    ld b, 4                         ; column 4 (play area)
    ld c, 0                         ; row 0
    ld d, $42                       ; non-blank = occupied
    call set_bkg_tile_xy

    ld b, 0                         ; piece = 0
    ld c, 0                         ; rotation = 0
    ld d, 5                         ; column = 5
    ld e, 2                         ; row = 2
    call _CanPieceBePlacedHere

    ; Should return 0 (cell occupied, cannot place)
    or a
    jr nz, .test5_fail              ; stub returns 1 → FAIL (correct!)

    ld a, 1
    ld [wTestResults + 5], a
    jr .test6
.test5_fail:
    xor a
    ld [wTestResults + 5], a

.test6:
    ; === Test 6: CanPieceBePlacedHere returns 1 for pentomino on empty board ===
    ; Piece 7 = first pentomino (Pentomino1). On an empty board, it should fit.
    xor a
    ld [_blankTile], a                  ; VRAM default is 0 = blank
    ld b, 7                             ; piece = 7 (Pentomino1)
    ld c, 0                             ; rotation = 0
    ld d, 5                             ; column = 5
    ld e, 4                             ; row = 4
    call _CanPieceBePlacedHere

    ; Should return 1 (can place)
    cp 1
    jr nz, .test6_fail

    ld a, 1
    ld [wTestResults + 6], a
    jr .test7
.test6_fail:
    xor a
    ld [wTestResults + 6], a

.test7:
    ; === Test 7: PIECE_COUNT is 25 (7 tetrominoes + 18 pentominoes) ===
    ld a, PIECE_COUNT
    cp 25
    jr nz, .test7_fail

    ld a, 1
    ld [wTestResults + 7], a
    jr .test_done
.test7_fail:
    xor a
    ld [wTestResults + 7], a

.test_done:
    ld a, $01
    ld [wTestDone], a
.halt:
    halt
    nop
    jr .halt
