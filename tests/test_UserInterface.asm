; =============================================================================
; test_UserInterface.asm - Test ROM for UserInterface module
; =============================================================================
; Tests AnimateBackground, SetupAnimatedBackground, and SetupUserInterface.
;
; Build: make test_UserInterface
; Run:   node tests/run_tests.js dist/test_UserInterface.gb
; =============================================================================

INCLUDE "runtime.inc"
INCLUDE "common.inc"
INCLUDE "UserInterface.inc"

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
    ld a, 4
    ld [wTestCount], a

    ; === Test 0: AnimateBackground increments counter by 6 ===
    ; The C code: tileAnimationCounter += 6;
    xor a
    ld [_tileAnimationCounter], a

    call _AnimateBackground

    ld a, [_tileAnimationCounter]
    cp 6
    jr nz, .test0_fail

    ld a, 1
    ld [wTestResults + 0], a
    jr .test1
.test0_fail:
    xor a
    ld [wTestResults + 0], a

.test1:
    ; === Test 1: AnimateBackground wraps counter at 128 ===
    ; C code: if(tileAnimationCounter>=128)tileAnimationCounter=0;
    ; Set counter to 126, add 6 = 132 >= 128, should wrap to 0
    ld a, 126
    ld [_tileAnimationCounter], a

    call _AnimateBackground

    ld a, [_tileAnimationCounter]
    or a                            ; should be 0
    jr nz, .test1_fail

    ld a, 1
    ld [wTestResults + 1], a
    jr .test2
.test1_fail:
    xor a
    ld [wTestResults + 1], a

.test2:
    ; === Test 2: SetupAnimatedBackground replaces animation base tiles ===
    ; The C code scans all 32x32 BG tiles looking for tileAnimationBase,
    ; then replaces them with TILEANIMATION_TILE1_VRAM or _TILE2_VRAM
    ; in a checkerboard pattern.
    ;
    ; Setup: write _tileAnimationBase tile at (0,0) and verify it changes.
    ld a, $AA
    ld [_tileAnimationBase], a
    ; Place the animation base tile at position (0,0)
    ld b, 0
    ld c, 0
    ld d, $AA                       ; matches _tileAnimationBase
    call set_bkg_tile_xy

    call _SetupAnimatedBackground

    ; After call, tile at (0,0) should be TILEANIMATION_TILE1_VRAM
    ; (even row, even column → TILE1 per the C code)
    ld b, 0
    ld c, 0
    call get_bkg_tile_xy
    cp TILEANIMATION_TILE1_VRAM
    jr nz, .test2_fail

    ld a, 1
    ld [wTestResults + 2], a
    jr .test3
.test2_fail:
    xor a
    ld [wTestResults + 2], a

.test3:
    ; === Test 3: SetupUserInterface sets _blankTile from VRAM ===
    ; The C code reads the BG tile at position (3,3) and stores it
    ; in _blankTile: blankTile = get_bkg_tile_xy(3,3)
    ; It also reads (0,0) into _tileAnimationBase.
    ;
    ; Setup: write known tile at BG position (3,3) before calling.
    ; The function loads the tilemap first (which overwrites it), but
    ; then reads back from (3,3). Since INCBIN data is commented out,
    ; the implementation will read whatever is in VRAM at (3,3).
    ; We pre-set (3,3) to $77. After SetupUserInterface, _blankTile
    ; should be $77 (read from VRAM).
    ld b, 3
    ld c, 3
    ld d, $77
    call set_bkg_tile_xy
    ; Also set (0,0) for _tileAnimationBase
    ld b, 0
    ld c, 0
    ld d, $88
    call set_bkg_tile_xy

    ; Pre-set _blankTile to something different so we can detect the write
    ld a, $EE
    ld [_blankTile], a

    call _SetupUserInterface

    ; _blankTile should have been updated (read from VRAM at (3,3))
    ; With stub: _blankTile stays $EE → FAIL
    ; With impl: _blankTile = whatever is at (3,3) after tilemap load
    ld a, [_blankTile]
    cp $EE
    jr z, .test3_fail               ; still $EE = stub didn't update it

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
