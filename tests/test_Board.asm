; =============================================================================
; test_Board.asm - Test ROM for Board module
; =============================================================================
; Tests IsRowFull, ShiftAllTilesAboveThisRowDown, ShiftAllTilesDown,
; SetCurrentPieceInBackground, and BlinkFullRows.
;
; Build: make test_Board
; Run:   node tests/run_tests.js dist/test_Board.gb
; =============================================================================

INCLUDE "runtime.inc"
INCLUDE "common.inc"
INCLUDE "board.inc"
INCLUDE "hud.inc"
INCLUDE "Tetrominos.inc"
INCLUDE "UserInterface.inc"

; Test result WRAM (fixed addresses for headless runner)
SECTION "TestResults", WRAM0[$CFF0]
wTestDone::    DS 1
wTestCount::   DS 1
wTestResults:: DS 10

; =============================================================================
; Test entry point
; =============================================================================

SECTION "TestMain", ROM0

_main::
    xor a
    ld [wTestDone], a
    ld a, 9
    ld [wTestCount], a

    ; --- Common setup ---
    ; Set blankTile = $FF so we can distinguish filled vs empty cells.
    ; VRAM initializes to $00, so any tile set to $00 is "filled"
    ; and $FF is "blank".
    ld a, $FF
    ld [_blankTile], a
    xor a
    ld [_blankTilePalette], a

    ; === Test 0: IsRowFull returns 0 on empty row ===
    ; Fill play area row 5 (columns 2-11) with blankTile = $FF
    ; IsRowFull checks get_bkg_tile_xy(2+i, row) for i=0..9
    ld e, 0                         ; column counter
.fillBlankRow:
    push de
    ld a, e
    add 2                           ; play area starts at column 2
    ld b, a
    ld c, 5                         ; row 5
    ld a, [_blankTile]
    ld d, a
    call set_bkg_tile_xy
    pop de
    inc e
    ld a, e
    cp 10
    jr c, .fillBlankRow

    ; IsRowFull: B=row, C=both_flag -> A = result
    ld b, 5                         ; row 5
    ld c, 0                         ; both_flag = FALSE
    call _IsRowFull

    ; Should return 0 (row is empty / all blank)
    or a
    jr nz, .test0_fail

    ld a, 1
    ld [wTestResults + 0], a
    jr .test1
.test0_fail:
    xor a
    ld [wTestResults + 0], a

.test1:
    ; === Test 1: IsRowFull returns 1 on full row ===
    ; Fill row 10 with non-blank tile ($42)
    ld e, 0
.fillFullRow:
    push de
    ld a, e
    add 2
    ld b, a
    ld c, 10                        ; row 10
    ld d, $42                       ; non-blank tile
    call set_bkg_tile_xy
    pop de
    inc e
    ld a, e
    cp 10
    jr c, .fillFullRow

    ld b, 10                        ; row 10
    ld c, 0                         ; both_flag = FALSE
    call _IsRowFull

    ; Should return 1 (row is full)
    cp 1
    jr nz, .test1_fail

    ld a, 1
    ld [wTestResults + 1], a
    jr .test2
.test1_fail:
    xor a
    ld [wTestResults + 1], a

.test2:
    ; === Test 2: ShiftAllTilesAboveThisRowDown clears target row ===
    ; Row 10 is full from test 1. After shifting, row 10 should get
    ; the tiles from row 9 (which are blank from VRAM init).
    ; But first: the function fills the target row with blankTile,
    ; then copies rows above it down. So row 10 ends up with row 9's tiles.
    ;
    ; Setup: put distinctive tile in row 9
    push de
    ld b, 2
    ld c, 9                         ; row 9, column 2
    ld d, $33                       ; distinctive tile
    call set_bkg_tile_xy
    pop de

    ; Call ShiftAllTilesAboveThisRowDown(10)
    ld b, 10
    call _ShiftAllTilesAboveThisRowDown

    ; After shift, row 10 column 2 should have $33 (shifted from row 9)
    ld b, 2
    ld c, 10
    call get_bkg_tile_xy
    cp $33
    jr nz, .test2_fail

    ld a, 1
    ld [wTestResults + 2], a
    jr .test3
.test2_fail:
    xor a
    ld [wTestResults + 2], a

.test3:
    ; === Test 3: ShiftAllTilesDown collapses a full row ===
    ; Clear entire board first, then fill row 17 (bottom) with non-blank.
    ; After ShiftAllTilesDown, row 17 should be blank (collapsed).
    ;
    ; Step 1: Clear all rows 0-17
    ld d, 0                         ; row counter
.clearAllRows:
    push de
    ld e, 0                         ; column counter
.clearRow:
    push de
    ld a, e
    add 2
    ld b, a                         ; column
    ld a, d
    ld c, a                         ; row
    ld a, [_blankTile]
    ld d, a
    call set_bkg_tile_xy
    pop de
    inc e
    ld a, e
    cp 10
    jr c, .clearRow
    pop de
    inc d
    ld a, d
    cp 18
    jr c, .clearAllRows

    ; Step 2: Fill row 17 completely with non-blank tile
    ld e, 0
.fillRow17:
    push de
    ld a, e
    add 2
    ld b, a
    ld c, 17                        ; row 17 (bottom)
    ld d, $42                       ; non-blank tile
    call set_bkg_tile_xy
    pop de
    inc e
    ld a, e
    cp 10
    jr c, .fillRow17

    call _ShiftAllTilesDown

    ; Row 17 should now be blank (the full row was collapsed,
    ; and empty row 16 shifted down into row 17)
    ld b, 2                         ; first play area column
    ld c, 17                        ; row 17
    call get_bkg_tile_xy
    ld b, a
    ld a, [_blankTile]
    cp b
    jr nz, .test3_fail

    ld a, 1
    ld [wTestResults + 3], a
    jr .test4
.test3_fail:
    xor a
    ld [wTestResults + 3], a

.test4:
    ; === Test 4: SetCurrentPieceInBackground writes tiles ===
    ; Set up piece 0 (I-piece) rotation 0 at position (5, 4)
    ; After calling SetCurrentPieceInBackground, we should see
    ; non-blank tiles written to the background at the piece location.
    ;
    ; The function reads metasprite data to compute tile positions:
    ;   finalColumn += metasprite->dx/8
    ;   finalRow += metasprite->dy/8
    ;   set_bkg_tile_xy(finalColumn-1, finalRow-2, tile+tileOffsets[piece])
    ;
    ; For I-piece (piece 0) rotation 0, metasprite has 4 entries.
    ; We check that at least one tile was written (not blankTile).
    xor a
    ld [_currentTetromino], a       ; piece 0
    ld [_currentTetrominoRotation], a ; rotation 0
    ld a, 5
    ld [_currentX], a
    ld a, 4
    ld [_currentY], a

    ; Clear area around where piece will land
    ld b, 4
    ld c, 2
    ld a, [_blankTile]
    ld d, a
    call set_bkg_tile_xy
    ld b, 5
    ld c, 2
    ld a, [_blankTile]
    ld d, a
    call set_bkg_tile_xy
    ld b, 6
    ld c, 2
    ld a, [_blankTile]
    ld d, a
    call set_bkg_tile_xy
    ld b, 7
    ld c, 2
    ld a, [_blankTile]
    ld d, a
    call set_bkg_tile_xy

    call _SetCurrentPieceInBackground

    ; Check that at least one tile in the piece area is NOT blankTile.
    ; We'll check 4 candidate positions around where the I-piece should go.
    ; If any one is non-blank, the function wrote something → pass.
    ld b, 4
    ld c, 2
    call get_bkg_tile_xy
    ld b, a
    ld a, [_blankTile]
    cp b
    jr nz, .test4_pass              ; found a written tile

    ld b, 5
    ld c, 2
    call get_bkg_tile_xy
    ld b, a
    ld a, [_blankTile]
    cp b
    jr nz, .test4_pass

    ld b, 6
    ld c, 2
    call get_bkg_tile_xy
    ld b, a
    ld a, [_blankTile]
    cp b
    jr nz, .test4_pass

    ld b, 7
    ld c, 2
    call get_bkg_tile_xy
    ld b, a
    ld a, [_blankTile]
    cp b
    jr nz, .test4_pass

    ; None of the positions had non-blank tiles → fail
    jr .test4_fail

.test4_pass:
    ld a, 1
    ld [wTestResults + 4], a
    jr .test5
.test4_fail:
    xor a
    ld [wTestResults + 4], a

.test5:
    ; === Test 5: BlinkFullRows with no full rows sets _isBlinking=FALSE ===
    ; Make sure all rows are blank first (cleared in test 3 setup area).
    ; Re-clear to be safe.
    ld d, 0
.clearForBlink:
    push de
    ld e, 0
.clearRowBlink:
    push de
    ld a, e
    add 2
    ld b, a
    ld a, d
    ld c, a
    ld a, [_blankTile]
    ld d, a
    call set_bkg_tile_xy
    pop de
    inc e
    ld a, e
    cp 10
    jr c, .clearRowBlink
    pop de
    inc d
    ld a, d
    cp 18
    jr c, .clearForBlink

    ; Set isBlinking to non-zero so we can verify it gets cleared
    ld a, 1
    ld [_isBlinking], a
    ; Initialize score/lines to known values
    xor a
    ld [_score], a
    ld [_score + 1], a
    ld [_lines], a
    ld [_lines + 1], a

    call _BlinkFullRows

    ; isBlinking should be FALSE (0) since no rows were full
    ld a, [_isBlinking]
    or a
    jr nz, .test5_fail

    ld a, 1
    ld [wTestResults + 5], a
    jr .test6
.test5_fail:
    xor a
    ld [wTestResults + 5], a

.test6:
    ; === Test 6: _IsRowFull does NOT clobber _boardLoopK ===
    ; This test catches the variable-sharing bug where _IsRowFull wrote
    ; both_flag into _boardLoopK, clobbering the blink counter k in
    ; _BlinkFullRows and causing an infinite loop.
    ;
    ; Setup: fill row 15 so IsRowFull returns 1 (exercises full loop)
    ld e, 0
.fillRow15:
    push de
    ld a, e
    add 2
    ld b, a
    ld c, 15
    ld d, $42                       ; non-blank tile
    call set_bkg_tile_xy
    pop de
    inc e
    ld a, e
    cp 10
    jr c, .fillRow15

    ; Set _boardLoopK to a known sentinel value (42)
    ld a, 42
    ld [_boardLoopK], a

    ; Call IsRowFull(15, TRUE) — both_flag=1 is the problematic case
    ld b, 15
    ld c, 1                         ; both_flag = TRUE
    call _IsRowFull

    ; Verify IsRowFull returned 1 (row IS full)
    cp 1
    jr nz, .test6_fail

    ; Critical check: _boardLoopK must still be 42, NOT 1 (both_flag)
    ld a, [_boardLoopK]
    cp 42
    jr nz, .test6_fail

    ld a, 1
    ld [wTestResults + 6], a
    jr .test7
.test6_fail:
    xor a
    ld [wTestResults + 6], a

.test7:
    ; === Test 7: ShiftAllTilesDown clears a full row (full pipeline) ===
    ; Row 15 is full from test 6.
    ; ShiftAllTilesDown should detect and remove it.
    call _ShiftAllTilesDown

    ; Row 15 should now be blank (empty rows above shifted down)
    ld b, 2
    ld c, 15
    call get_bkg_tile_xy
    ld b, a
    ld a, [_blankTile]
    cp b
    jr nz, .test7_fail

    ld a, 1
    ld [wTestResults + 7], a
    jr .test8
.test7_fail:
    xor a
    ld [wTestResults + 7], a

.test8:
    ; === Test 8: SetCurrentPieceInBackground writes 5 tiles for pentomino ===
    ; Pentomino1 (piece 7) rotation 0 has 5 cells. Place at (5,4) and count
    ; how many cells in the 3x3 area become non-blank.
    ; Pentomino1 rot0 metasprite offsets place tiles at BG positions:
    ;   (5,2), (6,2), (4,3), (5,3), (5,4)
    ;
    ; Clear the area first
    ld a, $FF
    ld [_blankTile], a
    xor a
    ld [_blankTilePalette], a

    ; Clear rows 2-4, columns 3-7 with blankTile
    ld d, 2                             ; start row
.clearForTest8_row:
    ld e, 3                             ; start column
.clearForTest8_col:
    push de
    ld b, e                             ; column
    ld c, d                             ; row
    ld d, $FF                           ; blankTile
    call set_bkg_tile_xy
    pop de
    inc e
    ld a, e
    cp 8
    jr c, .clearForTest8_col
    inc d
    ld a, d
    cp 5
    jr c, .clearForTest8_row

    ; Set up pentomino piece
    ld a, 7
    ld [_currentTetromino], a           ; piece 7 = Pentomino1
    xor a
    ld [_currentTetrominoRotation], a   ; rotation 0
    ld a, 5
    ld [_currentX], a
    ld a, 4
    ld [_currentY], a

    call _SetCurrentPieceInBackground

    ; Check all 5 expected tile positions are non-blank.
    ; Check (5, 2) is non-blank
    ld b, 5
    ld c, 2
    call get_bkg_tile_xy
    ld b, a
    ld a, [_blankTile]
    cp b
    jr z, .test8_fail

    ; Check (6, 2) is non-blank
    ld b, 6
    ld c, 2
    call get_bkg_tile_xy
    ld b, a
    ld a, [_blankTile]
    cp b
    jr z, .test8_fail

    ; Check (4, 3) is non-blank
    ld b, 4
    ld c, 3
    call get_bkg_tile_xy
    ld b, a
    ld a, [_blankTile]
    cp b
    jr z, .test8_fail

    ; Check (5, 3) is non-blank
    ld b, 5
    ld c, 3
    call get_bkg_tile_xy
    ld b, a
    ld a, [_blankTile]
    cp b
    jr z, .test8_fail

    ; Check (5, 4) is non-blank
    ld b, 5
    ld c, 4
    call get_bkg_tile_xy
    ld b, a
    ld a, [_blankTile]
    cp b
    jr z, .test8_fail

    ld a, 1
    ld [wTestResults + 8], a
    jr .test_done
.test8_fail:
    xor a
    ld [wTestResults + 8], a

.test_done:
    ld a, $01
    ld [wTestDone], a
.halt:
    halt
    nop
    jr .halt
