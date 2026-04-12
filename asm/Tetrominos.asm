; =============================================================================
; Tetrominos.asm - Tetromino data and collision logic
; Ported from: source/main/Tetrominos.c
; =============================================================================

INCLUDE "common.inc"
INCLUDE "Tetrominos.inc"

; =============================================================================
; Sprite tile data, metasprites, pointer table, and tile offsets
; All auto-generated from png2asset output by tools/png2asm.py
; =============================================================================
INCLUDE "sprite_data.inc"

; =============================================================================
; Code
; =============================================================================

SECTION "TetrominoCode", ROM0

; uint8_t CanPieceBePlacedHere(uint8_t piece, uint8_t rotation, uint8_t column, uint8_t row)
; B=piece, C=rotation, D=column, E=row -> A=result (0 or 1)
;
; Original C:
; uint8_t CanPieceBePlacedHere(uint8_t piece, uint8_t rotation, uint8_t column, uint8_t row){
;     metasprite_t *metasprite = Tetrominos_metasprites[piece*4+rotation];
;     int8_t finalColumn=column;
;     int8_t finalRow=row;
;     uint8_t i=0;
;     while(i<4){
;         finalColumn += metasprite->dx/8;
;         finalRow += metasprite->dy/8;
;         if(finalRow-2>=18)return 0;
;         if(finalColumn>=1&&finalRow>=2){
;             if(get_bkg_tile_xy(finalColumn-1,finalRow-2)!=blankTile)return 0;
;         }
;         metasprite++;
;         i++;
;     }
;     return 1;
; }
_CanPieceBePlacedHere::
    ; TODO: Implement CanPieceBePlacedHere
    ; B=piece, C=rotation, D=column, E=row -> A=1 if fits, 0 if blocked
    ld a, 1
    ret

_PickNewTetromino::
    ; TODO: Implement PickNewTetromino
    ; Spawn next piece at (5,0), generate new random next piece
    ; Returns A=1 success, A=0 game over
    ld a, 1
    ret

