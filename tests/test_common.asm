; =============================================================================
; test_common.asm - Test ROM for the common module
; =============================================================================
; Tests RandomNumber and ResetAllSprites functions.
; Results are written to both serial port and WRAM for headless testing.
;
; Build: make test_common
; Run:   node tests/run_tests.js dist/test_common.gb
; =============================================================================

INCLUDE "runtime.inc"
INCLUDE "common.inc"

; =============================================================================
; Test result WRAM (fixed addresses for headless runner)
; =============================================================================
; Protocol:
;   wTestDone    ($DFF0) = $01 when all tests finished
;   wTestCount   ($DFF1) = number of tests
;   wTestResults ($DFF2+) = $01=PASS, $00=FAIL per test

SECTION "TestResults", WRAM0[$CFF0]
wTestDone::    DS 1
wTestCount::   DS 1
wTestResults:: DS 8

; =============================================================================
; Macros for test output
; =============================================================================

; Write a single character to serial port
MACRO SERIAL_CHAR
    ld a, \1
    ldh [rSB], a
    ld a, $81                       ; transfer start + internal clock
    ldh [rSC], a
    ; Brief delay for transfer
    ld a, 10
.waitSerial\@:
    dec a
    jr nz, .waitSerial\@
ENDM

; Write "PASS" to serial port
MACRO SERIAL_PASS
    SERIAL_CHAR ASCII_P
    SERIAL_CHAR ASCII_A
    SERIAL_CHAR ASCII_S
    SERIAL_CHAR ASCII_S
    SERIAL_CHAR ASCII_NEWLINE
ENDM

; Write "FAIL" to serial port
MACRO SERIAL_FAIL
    SERIAL_CHAR ASCII_F
    SERIAL_CHAR ASCII_A
    SERIAL_CHAR ASCII_I
    SERIAL_CHAR ASCII_L
    SERIAL_CHAR ASCII_NEWLINE
ENDM

; Record test result in WRAM: \1 = test index (0-based), pass/fail in A (1/0)
MACRO RECORD_RESULT
    ld [wTestResults + \1], a
ENDM

; =============================================================================
; Test entry point
; =============================================================================
; This test ROM uses header.asm for boot, which jumps to _main.
; We define _main here as our test entry point.

SECTION "TestMain", ROM0

_main::
    ; Initialize test result area
    xor a
    ld [wTestDone], a
    ld a, 2                         ; 2 tests in this ROM
    ld [wTestCount], a

    ; --- Test 1: RandomNumber returns value in range [min, max) ---
    ; Call RandomNumber(3, 10) - result should be >= 3 and < 10
    ld b, 3                         ; min
    ld c, 10                        ; max
    call _RandomNumber

    ; Check: result >= 3
    cp 3
    jr c, .test1_fail               ; if A < 3, fail

    ; Check: result < 10
    cp 10
    jr nc, .test1_fail              ; if A >= 10, fail

    ld a, 1
    RECORD_RESULT 0
    SERIAL_PASS
    jr .test2

.test1_fail:
    xor a
    RECORD_RESULT 0
    SERIAL_FAIL

.test2:
    ; --- Test 2: ResetAllSprites moves all sprites offscreen ---
    ; First, put some data in shadow OAM to verify it gets cleared
    ld hl, wShadowOAM
    ld a, $42                       ; non-zero value
    ld [hli], a                     ; sprite 0 Y
    ld [hli], a                     ; sprite 0 X
    ld [hli], a                     ; sprite 0 tile
    ld [hl], a                      ; sprite 0 props

    call _ResetAllSprites

    ; Verify sprite 0 has been moved offscreen
    ; ResetAllSprites uses move_sprite(i, 160, 160), so:
    ; Y should be 160, X should be 160
    ld hl, wShadowOAM
    ld a, [hli]                     ; Y
    cp 160
    jr nz, .test2_fail

    ld a, [hl]                      ; X
    cp 160
    jr nz, .test2_fail

    ld a, 1
    RECORD_RESULT 1
    SERIAL_PASS
    jr .test_done

.test2_fail:
    xor a
    RECORD_RESULT 1
    SERIAL_FAIL

.test_done:
    ; Mark tests as complete
    ld a, $01
    ld [wTestDone], a

    ; Infinite loop - test complete
.halt:
    halt
    nop
    jr .halt
