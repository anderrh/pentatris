; Ported from: source/main/common.c

INCLUDE "common.inc"

; ---------------------------------------------------------------------------
; SECTION: CommonVariables
; All global variables from common.c declared in WRAM0.
; ---------------------------------------------------------------------------
SECTION "CommonVariables", WRAM0

; uint8_t tileAnimationCounter=0;
_tileAnimationCounter:: DS 1

; uint8_t fallTimer = 0, isBlinking = 0;
_fallTimer:: DS 1
_isBlinking:: DS 1
_lockDelay:: DS 1
_dasTimer:: DS 1

; uint8_t currentTetromino = 0, nextCurrentTetromino=0;
_currentTetromino:: DS 1
_nextCurrentTetromino:: DS 1

; uint8_t currentTetrominoRotation = 0, nextCurrentTetrominoRotation=0;
_currentTetrominoRotation:: DS 1
_nextCurrentTetrominoRotation:: DS 1

; uint8_t joypadCurrent, joypadPrevious;
_joypadCurrent:: DS 1
_joypadPrevious:: DS 1

; uint8_t currentX, currentY;
_currentX:: DS 1
_currentY:: DS 1

; uint16_t score, lines;
_score:: DS 2
_lines:: DS 2

; uint8_t level=1;
_level:: DS 1

; uint8_t blankTile=0, blankTilePalette=0, tileAnimationBase, tileAnimationBasePalette;
_blankTile:: DS 1
_blankTilePalette:: DS 1
_tileAnimationBase:: DS 1
_tileAnimationBasePalette:: DS 1

; ---------------------------------------------------------------------------
; SECTION: CommonReusableRow
; ---------------------------------------------------------------------------
SECTION "CommonReusableRow", WRAM0

; unsigned char reusableRow10[] = {0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00};
_reusableRow10:: DS 10

; ---------------------------------------------------------------------------
; SECTION: CommonCode
; ---------------------------------------------------------------------------
SECTION "CommonCode", ROM0

; ---------------------------------------------------------------------------
; uint8_t RandomNumber(uint8_t min, uint8_t max)
; {
;     const unsigned char *ptr_div_reg = 0xFF04;
;
;     // get value at memory address
;     return min + (*(ptr_div_reg) % (max - min));
; }
; ---------------------------------------------------------------------------
; Calling convention: B = min, C = max -> A = result
_RandomNumber::
    ; A = min + (DIV_REG % (max - min))
    ; B = min, C = max
    ld a, c
    sub b                           ; A = max - min (range)
    ld c, a                         ; C = range
    ldh a, [rDIV]                   ; A = DIV register (pseudo-random)
.mod:
    ; A = A % C (unsigned modulo)
    cp c
    jr c, .modDone
    sub c
    jr .mod
.modDone:
    add b                           ; A = min + (DIV % range)
    ret

; ---------------------------------------------------------------------------
; void ResetAllSprites(){
;
;     // Reset all sprites
;     for (uint8_t i = 0; i < 40; i++){
;         set_sprite_tile(i, 0);
;         move_sprite(i,160,160);
;     }
; }
; ---------------------------------------------------------------------------
; Calling convention: no arguments, no return value
_ResetAllSprites::
    ; for i = 0 to 39: set_sprite_tile(i, 0); move_sprite(i, 160, 160);
    ; Use stack to preserve loop counter since calls clobber DE
    ld e, 0                         ; E = sprite index (0-39)
.resetLoop:
    push de                         ; save counter

    ; set_sprite_tile(E, 0)
    ld a, e
    ld b, 0                         ; tile = 0
    call set_sprite_tile

    pop de
    push de

    ; move_sprite(E, 160, 160)
    ld a, e
    ld b, 160                       ; X = 160
    ld c, 160                       ; Y = 160
    call move_sprite

    pop de
    inc e
    ld a, e
    cp 40
    jr c, .resetLoop
    ret
