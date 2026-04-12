; =============================================================================
; test_gameplay.asm - Test ROM for gameplay functions (from gameplay.asm)
; =============================================================================
; Tests SetupGameplay, HandleInput, and SetupVRAM.
;
; Build: make test_gameplay
; Run:   node tests/run_tests.js dist/test_gameplay.gb
; =============================================================================

INCLUDE "runtime.inc"
INCLUDE "common.inc"
INCLUDE "hud.inc"
INCLUDE "UserInterface.inc"
INCLUDE "board.inc"
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
    ld a, 5
    ld [wTestCount], a

    ; === Test 0: SetupGameplay sets _fallTimer to 0 ===
    ; Pre-set fallTimer to non-zero
    ld a, 99
    ld [_fallTimer], a

    call _SetupGameplay

    ld a, [_fallTimer]
    or a
    jr nz, .test0_fail

    ld a, 1
    ld [wTestResults + 0], a
    jr .test1
.test0_fail:
    xor a
    ld [wTestResults + 0], a

.test1:
    ; === Test 1: SetupGameplay sets _level to 1 ===
    xor a
    ld [_level], a                  ; pre-set to 0

    call _SetupGameplay

    ld a, [_level]
    cp 1
    jr nz, .test1_fail

    ld a, 1
    ld [wTestResults + 1], a
    jr .test2
.test1_fail:
    xor a
    ld [wTestResults + 1], a

.test2:
    ; === Test 2: SetupGameplay sets _score to 0 ===
    ld a, $FF
    ld [_score], a
    ld [_score + 1], a

    call _SetupGameplay

    ld a, [_score]
    or a
    jr nz, .test2_fail
    ld a, [_score + 1]
    or a
    jr nz, .test2_fail

    ld a, 1
    ld [wTestResults + 2], a
    jr .test3
.test2_fail:
    xor a
    ld [wTestResults + 2], a

.test3:
    ; === Test 3: HandleInput copies _joypadCurrent to _joypadPrevious ===
    ; The C code: joypadPrevious = joypadCurrent;
    ; This must happen before reading new joypad state.
    ; A stub that just `ret`s won't update _joypadPrevious.
    ld a, $42
    ld [_joypadCurrent], a          ; set current to known value
    xor a
    ld [_joypadPrevious], a         ; previous is different

    ; Setup piece state so movement code doesn't crash
    ld a, 5
    ld [_currentX], a
    ld a, 3
    ld [_currentY], a
    xor a
    ld [_currentTetromino], a
    ld [_currentTetrominoRotation], a

    call _HandleInput

    ; _joypadPrevious should now be $42 (copied from old _joypadCurrent)
    ld a, [_joypadPrevious]
    cp $42
    jr nz, .test3_fail

    ld a, 1
    ld [wTestResults + 3], a
    jr .test4
.test3_fail:
    xor a
    ld [wTestResults + 3], a

.test4:
    ; === Test 4: SetupVRAM writes tile data to VRAM ===
    ; SetupVRAM calls set_sprite_data and set_bkg_data to load
    ; tile graphics into VRAM. We pre-fill a VRAM area with $FF
    ; and verify it changes after SetupVRAM.
    ;
    ; The first call is: set_sprite_data(tileOffsets[0], Tetromino1_TILE_COUNT, Tetromino1_tiles)
    ; tileOffsets[0] = 0, so this writes to sprite tile VRAM at $8000.
    ; If tile data exists, VRAM[$8000] will change from $FF.
    ;
    ; Pre-fill first sprite tile slot with $FF. LCD is off so VRAM
    ; is directly writable.
    ld hl, $8000
    ld a, $FF
    ld [hl], a

    call _SetupVRAM

    ; Check if VRAM[$8000] changed from $FF
    ; With stub: SetupVRAM does nothing, VRAM stays $FF → FAIL
    ; With impl: tile data loaded, VRAM[$8000] likely != $FF
    ld a, [$8000]
    cp $FF
    jr z, .test4_fail               ; still $FF = stub didn't write anything

    ld a, 1
    ld [wTestResults + 4], a
    jr .test_done
.test4_fail:
    xor a
    ld [wTestResults + 4], a

.test_done:
    ld a, $01
    ld [wTestDone], a
.halt:
    halt
    nop
    jr .halt
