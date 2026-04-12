; =============================================================================
; test_hud.asm - Test ROM for HUD module
; =============================================================================
; Tests IncreaseScore, DrawNumber, and UpdateGui functions.
;
; Build: make test_hud
; Run:   node tests/run_tests.js dist/test_hud.gb
; =============================================================================

INCLUDE "runtime.inc"
INCLUDE "common.inc"
INCLUDE "hud.inc"
INCLUDE "Tetrominos.inc"

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
    ld a, 6
    ld [wTestCount], a

    ; === Test 0: IncreaseScore(5) should set score to 5 ===
    xor a
    ld [_score], a
    ld [_score + 1], a

    ld a, 5
    call _IncreaseScore

    ; Check score low byte = 5
    ld a, [_score]
    cp 5
    jr nz, .test0_fail
    ; Check score high byte = 0
    ld a, [_score + 1]
    or a
    jr nz, .test0_fail

    ld a, 1
    ld [wTestResults + 0], a
    jr .test1
.test0_fail:
    xor a
    ld [wTestResults + 0], a

.test1:
    ; === Test 1: IncreaseScore(100) twice should set score to 200 ===
    xor a
    ld [_score], a
    ld [_score + 1], a

    ld a, 100
    call _IncreaseScore
    ld a, 100
    call _IncreaseScore

    ; Check score = 200 (low byte = 200, high byte = 0)
    ld a, [_score]
    cp 200
    jr nz, .test1_fail
    ld a, [_score + 1]
    or a
    jr nz, .test1_fail

    ld a, 1
    ld [wTestResults + 1], a
    jr .test2
.test1_fail:
    xor a
    ld [wTestResults + 1], a

.test2:
    ; === Test 2: IncreaseScore carry: score=250, add 10 → score=260 ===
    ; 260 = $0104, so low byte = $04 (4), high byte = $01 (1)
    ld a, 250
    ld [_score], a
    xor a
    ld [_score + 1], a

    ld a, 10
    call _IncreaseScore

    ; Check low byte = 4 ($104 & $FF = $04)
    ld a, [_score]
    cp 4
    jr nz, .test2_fail
    ; Check high byte = 1
    ld a, [_score + 1]
    cp 1
    jr nz, .test2_fail

    ld a, 1
    ld [wTestResults + 2], a
    jr .test3
.test2_fail:
    xor a
    ld [wTestResults + 2], a

.test3:
    ; === Test 3: DrawNumber(0, 0, 42, 3) tiles at expected positions ===
    ; Expected: "042" → tile(0,0)=NUMBERS_TILES_START (leading 0)
    ;                    tile(1,0)=NUMBERS_TILES_START+4 (digit '4')
    ;                    tile(2,0)=NUMBERS_TILES_START+2 (digit '2')
    ;
    ; First clear tiles (0,0)-(2,0) to $FF so we can detect writes
    ld b, 0
    ld c, 0
    ld d, $FF
    call set_bkg_tile_xy
    ld b, 1
    ld c, 0
    ld d, $FF
    call set_bkg_tile_xy
    ld b, 2
    ld c, 0
    ld d, $FF
    call set_bkg_tile_xy

    ; DrawNumber: B=x, C=y, DE=number, A=digits
    ld b, 0
    ld c, 0
    ld de, 42
    ld a, 3
    call _DrawNumber

    ; Check tile at (0,0) = NUMBERS_TILES_START (leading zero)
    ld b, 0
    ld c, 0
    call get_bkg_tile_xy
    cp NUMBERS_TILES_START
    jr nz, .test3_fail

    ; Check tile at (1,0) = NUMBERS_TILES_START + 4
    ld b, 1
    ld c, 0
    call get_bkg_tile_xy
    cp NUMBERS_TILES_START + 4
    jr nz, .test3_fail

    ; Check tile at (2,0) = NUMBERS_TILES_START + 2
    ld b, 2
    ld c, 0
    call get_bkg_tile_xy
    cp NUMBERS_TILES_START + 2
    jr nz, .test3_fail

    ld a, 1
    ld [wTestResults + 3], a
    jr .test4
.test3_fail:
    xor a
    ld [wTestResults + 3], a

.test4:
    ; === Test 4: DrawNumber(0, 0, 0, 1) → single zero tile ===
    ; Expected: tile(0,0) = NUMBERS_TILES_START (digit '0')
    ld b, 0
    ld c, 0
    ld d, $FF
    call set_bkg_tile_xy

    ld b, 0
    ld c, 0
    ld de, 0
    ld a, 1
    call _DrawNumber

    ld b, 0
    ld c, 0
    call get_bkg_tile_xy
    cp NUMBERS_TILES_START
    jr nz, .test4_fail

    ld a, 1
    ld [wTestResults + 4], a
    jr .test5
.test4_fail:
    xor a
    ld [wTestResults + 4], a

.test5:
    ; === Test 5: UpdateGui writes score at (14,10) ===
    ; With score=0 and 5-digit display, tile(14,10) should be NUMBERS_TILES_START
    ; (leading zero of the 5-digit score)
    xor a
    ld [_score], a
    ld [_score + 1], a
    ld a, 1
    ld [_level], a
    xor a
    ld [_lines], a
    ld [_lines + 1], a
    ; Set next piece info for the metasprite preview
    xor a
    ld [_nextCurrentTetromino], a
    ld [_nextCurrentTetrominoRotation], a

    ; Clear tile at (14,10) first
    ld b, 14
    ld c, 10
    ld d, $FF
    call set_bkg_tile_xy

    call _UpdateGui

    ; Check tile at (14,10) = NUMBERS_TILES_START (leading zero)
    ld b, 14
    ld c, 10
    call get_bkg_tile_xy
    cp NUMBERS_TILES_START
    jr nz, .test5_fail

    ld a, 1
    ld [wTestResults + 5], a
    jr .test_done
.test5_fail:
    xor a
    ld [wTestResults + 5], a

.test_done:
    ld a, $01
    ld [wTestDone], a
.halt:
    halt
    nop
    jr .halt
