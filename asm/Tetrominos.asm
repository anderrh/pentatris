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
    ; B=piece, C=rotation, D=column, E=row -> A=0/1  | clobbers: all
    ;
    ; Save column and row
    push de                         ; D=column, E=row

    ; Compute index = piece*4 + rotation
    ld a, b
    sla a
    sla a                           ; A = piece * 4
    add c                           ; A = piece*4 + rotation

    ; Look up metasprite pointer from table
    ld c, a
    ld b, 0
    ld hl, _Tetrominos_metasprites
    add hl, bc
    add hl, bc                      ; HL = &metasprites[index] (2 bytes each)
    ld a, [hli]
    ld c, a
    ld a, [hl]
    ld b, a                         ; BC = metasprite pointer

    pop de                          ; D=column, E=row
    ; Now: BC=metasprite ptr, D=finalColumn, E=finalRow

.cpbph_loop:
    ; Read dy from [BC], check sentinel
    ld a, [bc]
    cp $80                          ; METASPRITE_END sentinel?
    jr z, .cpbph_pass
    inc bc                          ; advance past dy (A has the value)
    ; finalRow += dy / 8 (arithmetic right shift 3)
    sra a
    sra a
    sra a
    add e
    ld e, a                         ; E = finalRow

    ; Read dx from [BC], advance BC
    ld a, [bc]
    inc bc
    ; finalColumn += dx / 8
    sra a
    sra a
    sra a
    add d
    ld d, a                         ; D = finalColumn

    inc bc                          ; skip dtile
    inc bc                          ; skip props → BC points to next entry

    ; if(finalRow - 2 >= 18) return 0
    ; Guard: when finalRow < 2, sub 2 would underflow (254/255), giving
    ; a false positive. Piece is above the board top, which is valid.
    ld a, e                         ; A = finalRow
    cp 2
    jr c, .cpbph_aboveBoard         ; finalRow < 2 → skip bounds check
    sub 2                           ; A = finalRow - 2 (safe, no underflow)
    cp 18
    jr nc, .cpbph_fail              ; finalRow - 2 >= 18 → below board

.cpbph_aboveBoard:
    ; if(finalColumn >= 1 && finalRow >= 2)
    ld a, d                         ; A = finalColumn
    cp 1
    jr c, .cpbph_skip               ; finalColumn < 1
    ld a, e                         ; A = finalRow
    cp 2
    jr c, .cpbph_skip               ; finalRow < 2

    ; get_bkg_tile_xy(finalColumn-1, finalRow-2) != blankTile → return 0
    push bc
    push de
    ld a, d
    dec a                           ; finalColumn - 1
    ld b, a
    ld a, e
    sub 2                           ; finalRow - 2
    ld c, a
    call get_bkg_tile_xy            ; A = tile
    ld b, a
    ld a, [_blankTile]
    cp b
    pop de
    pop bc
    jr nz, .cpbph_fail              ; tile != blankTile → occupied

.cpbph_skip:
    jr .cpbph_loop

.cpbph_pass:
    ld a, 1
    ret

.cpbph_fail:
    xor a
    ret

; ---------------------------------------------------------------------------
; _PickNewTetromino: (none) -> A=1 success, 0 game_over      | clobbers: all
; ---------------------------------------------------------------------------
_PickNewTetromino::
    ; if(CanPieceBePlacedHere(nextCurrentTetromino, nextCurrentTetrominoRotation, 5, 0))
    ld a, [_nextCurrentTetromino]
    ld b, a
    ld a, [_nextCurrentTetrominoRotation]
    ld c, a
    ld d, 5                         ; column = 5
    ld e, 0                         ; row = 0
    call _CanPieceBePlacedHere
    or a
    jr z, .pnt_fail

    ; currentX = 5
    ld a, 5
    ld [_currentX], a
    ; currentY = 0
    xor a
    ld [_currentY], a
    ; currentTetromino = nextCurrentTetromino
    ld a, [_nextCurrentTetromino]
    ld [_currentTetromino], a
    ; currentTetrominoRotation = nextCurrentTetrominoRotation
    ld a, [_nextCurrentTetrominoRotation]
    ld [_currentTetrominoRotation], a
    ; nextCurrentTetromino = RandomNumber(0, 7)
    ld b, 0
    ld c, PIECE_COUNT
    call _RandomNumber
    ld [_nextCurrentTetromino], a
    ; nextCurrentTetrominoRotation = RandomNumber(0, 4)
    ld b, 0
    ld c, 4
    call _RandomNumber
    ld [_nextCurrentTetrominoRotation], a
    ; return 1
    ld a, 1
    ret

.pnt_fail:
    xor a
    ret
