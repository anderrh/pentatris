; =============================================================================
; test_runtime.asm - Test ROM for runtime library functions
; =============================================================================
; Verifies uitoa and move_sprite work correctly.
;
; Build: make test_runtime
; Run:   node tests/run_tests.js dist/test_runtime.gb
; =============================================================================

INCLUDE "runtime.inc"

; Test result WRAM (fixed addresses for headless runner)
SECTION "TestResults", WRAM0[$CFF0]
wTestDone::    DS 1
wTestCount::   DS 1
wTestResults:: DS 8

; Buffer for uitoa output
SECTION "TestBuffer", WRAM0
wUitoaBuffer:: DS 16

; =============================================================================
; Test entry point
; =============================================================================

SECTION "TestMain", ROM0

_main::
    xor a
    ld [wTestDone], a
    ld a, 4
    ld [wTestCount], a

    ; === Test 0: uitoa(123, buf, 10) should produce "123" ===
    ld hl, 123
    ld de, wUitoaBuffer
    ld b, 10
    call uitoa

    ld hl, wUitoaBuffer
    ld a, [hli]
    cp ASCII_0 + 1                  ; '1' = $31
    jr nz, .test0_fail
    ld a, [hli]
    cp ASCII_0 + 2                  ; '2' = $32
    jr nz, .test0_fail
    ld a, [hli]
    cp ASCII_0 + 3                  ; '3' = $33
    jr nz, .test0_fail
    ld a, [hl]
    or a                            ; null terminator
    jr nz, .test0_fail

    ld a, 1
    ld [wTestResults + 0], a
    jr .test1
.test0_fail:
    xor a
    ld [wTestResults + 0], a

.test1:
    ; === Test 1: uitoa(0, buf, 10) should produce "0" ===
    ld hl, 0
    ld de, wUitoaBuffer
    ld b, 10
    call uitoa

    ld hl, wUitoaBuffer
    ld a, [hli]
    cp ASCII_0                      ; '0' = $30
    jr nz, .test1_fail
    ld a, [hl]
    or a                            ; null terminator
    jr nz, .test1_fail

    ld a, 1
    ld [wTestResults + 1], a
    jr .test2
.test1_fail:
    xor a
    ld [wTestResults + 1], a

.test2:
    ; === Test 2: uitoa(65535, buf, 10) should produce "65535" ===
    ld hl, 65535
    ld de, wUitoaBuffer
    ld b, 10
    call uitoa

    ld hl, wUitoaBuffer
    ld a, [hli]
    cp ASCII_0 + 6                  ; '6'
    jr nz, .test2_fail
    ld a, [hli]
    cp ASCII_0 + 5                  ; '5'
    jr nz, .test2_fail
    ld a, [hli]
    cp ASCII_0 + 5                  ; '5'
    jr nz, .test2_fail
    ld a, [hli]
    cp ASCII_0 + 3                  ; '3'
    jr nz, .test2_fail
    ld a, [hli]
    cp ASCII_0 + 5                  ; '5'
    jr nz, .test2_fail
    ld a, [hl]
    or a                            ; null terminator
    jr nz, .test2_fail

    ld a, 1
    ld [wTestResults + 2], a
    jr .test3
.test2_fail:
    xor a
    ld [wTestResults + 2], a

.test3:
    ; === Test 3: move_sprite(0, 50, 100) stores raw values in shadow OAM ===
    ; GBDK convention: move_sprite writes raw OAM coordinates (no +8/+16 offset)
    ; Clear shadow OAM sprite 0
    ld hl, wShadowOAM
    xor a
    ld [hli], a
    ld [hli], a
    ld [hli], a
    ld [hl], a

    ld a, 0                         ; sprite 0
    ld b, 50                        ; X = 50
    ld c, 100                       ; Y = 100
    call move_sprite

    ; Check Y = 100 (raw OAM value)
    ld hl, wShadowOAM
    ld a, [hli]
    cp 100
    jr nz, .test3_fail
    ; Check X = 50 (raw OAM value)
    ld a, [hl]
    cp 50
    jr nz, .test3_fail

    ld a, 1
    ld [wTestResults + 3], a
    jr .test_done
.test3_fail:
    xor a
    ld [wTestResults + 3], a

.test_done:
    ld a, $01
    ld [wTestDone], a
.halt:
    halt
    nop
    jr .halt
