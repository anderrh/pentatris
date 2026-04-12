; Ported from: source/main/hud.c

INCLUDE "common.inc"
INCLUDE "hud.inc"
INCLUDE "Tetrominos.inc"

; =============================================================================
; SECTION: HudGraphicsData
; =============================================================================
SECTION "HudGraphicsData", ROM0

Numbers_tiles::
    INCBIN "gfx/Numbers.2bpp"

; =============================================================================
; SECTION: HudVariables
; =============================================================================
SECTION "HudVariables", WRAM0
_drawNumBuffer: DS 9              ; buffer for uitoa output (max "65535" + null + padding)
_drawNumX:      DS 1              ; current x position during DrawNumber
_drawNumY:      DS 1              ; y position during DrawNumber

; =============================================================================
; SECTION: HudCode
; HUD drawing routines - score, level, lines, next piece preview
; =============================================================================
SECTION "HudCode", ROM0

; ---------------------------------------------------------------------------
; _DrawNumber: B=x, C=y, DE=number, A=digits                | clobbers: all
;
; Draws a number with leading zeros at BG tile position (x, y).
; Sets VBK=1 to write palette attribute 4, then VBK=0 to write tile.
; ---------------------------------------------------------------------------
_DrawNumber::
    ; Save parameters to WRAM
    push af                         ; save digits on stack
    ld a, b
    ld [_drawNumX], a
    ld a, c
    ld [_drawNumY], a

    ; uitoa(HL=number, DE=buffer, B=radix)
    ld h, d
    ld l, e                         ; HL = number
    ld de, _drawNumBuffer           ; DE = buffer
    ld b, 10                        ; radix = 10
    call uitoa

    ; Calculate strlen of buffer
    ld hl, _drawNumBuffer
    ld c, 0                         ; length counter
.strlenLoop:
    ld a, [hli]
    or a
    jr z, .strlenDone
    inc c
    jr .strlenLoop
.strlenDone:
    ; C = string length
    pop af                          ; A = digits
    sub c                           ; A = leading zero count (digits - len)
    push bc                         ; save C = strlen on stack

    ; --- Draw leading zeros ---
    or a
    jr z, .noLeadingZeros
    ld b, a                         ; B = leading zero count
.leadingZeroLoop:
    push bc
    ; VBK_REG = 1; set_bkg_tile_xy(x, y, 4)
    ld a, 1
    ldh [rVBK], a
    ld a, [_drawNumX]
    ld b, a
    ld a, [_drawNumY]
    ld c, a
    ld d, 4
    call set_bkg_tile_xy
    ; VBK_REG = 0; set_bkg_tile_xy(x++, y, NUMBERS_TILES_START)
    xor a
    ldh [rVBK], a
    ld a, [_drawNumX]
    ld b, a
    ld a, [_drawNumY]
    ld c, a
    ld d, NUMBERS_TILES_START
    call set_bkg_tile_xy
    ; x++
    ld a, [_drawNumX]
    inc a
    ld [_drawNumX], a
    pop bc
    dec b
    jr nz, .leadingZeroLoop

.noLeadingZeros:
    pop bc                          ; B = strlen (was C, but pop into bc)
    ; Actually we pushed BC where C=strlen. pop bc gives B=old B, C=strlen
    ; We need strlen in a counter register
    ld a, c
    or a
    jr z, .drawDone
    ld b, a                         ; B = digit count
    ld hl, _drawNumBuffer           ; HL = pointer to buffer

.digitLoop:
    ; Read digit character
    ld a, [hl]
    sub ASCII_0                     ; digit value = char - '0'
    add NUMBERS_TILES_START         ; tile = digit + NUMBERS_TILES_START
    push hl
    push bc
    push af                         ; save tile

    ; VBK_REG = 1; set_bkg_tile_xy(x, y, 4)
    ld a, 1
    ldh [rVBK], a
    ld a, [_drawNumX]
    ld b, a
    ld a, [_drawNumY]
    ld c, a
    ld d, 4
    call set_bkg_tile_xy
    ; VBK_REG = 0; set_bkg_tile_xy(x++, y, tile)
    xor a
    ldh [rVBK], a
    ld a, [_drawNumX]
    ld b, a
    ld a, [_drawNumY]
    ld c, a
    pop af                          ; restore tile
    ld d, a
    call set_bkg_tile_xy
    ; x++
    ld a, [_drawNumX]
    inc a
    ld [_drawNumX], a

    pop bc
    pop hl
    inc hl                          ; next character
    dec b
    jr nz, .digitLoop

.drawDone:
    ret

; ---------------------------------------------------------------------------
; _UpdateGui: (none)                                         | clobbers: all
;
; Redraws score, level, lines on the HUD and the next piece preview.
; ---------------------------------------------------------------------------
_UpdateGui::
    ; DrawNumber(B=14, C=10, DE=_score, A=5)
    ld b, 14
    ld c, 10
    ld a, [_score]
    ld e, a
    ld a, [_score + 1]
    ld d, a
    ld a, 5
    call _DrawNumber

    ; DrawNumber(B=14, C=13, DE=_level, A=2)
    ; _level is 8-bit, load into E with D=0
    ld b, 14
    ld c, 13
    ld a, [_level]
    ld e, a
    ld d, 0
    ld a, 2
    call _DrawNumber

    ; DrawNumber(B=14, C=16, DE=_lines, A=2)
    ld b, 14
    ld c, 16
    ld a, [_lines]
    ld e, a
    ld a, [_lines + 1]
    ld d, a
    ld a, 2
    call _DrawNumber

    ; Hide the 5th preview sprite slot (index 20) which is stale when a
    ; pentomino preview (5 cells) is replaced by a tetromino (4 cells).
    ; move_metasprite overwrites slots 16-19 (or 16-20), so only 20 needs clearing.
    ld a, 20
    ld b, 0
    ld c, 0
    call move_sprite

    ; move_metasprite(Tetrominos_metasprites[nextCurrentTetromino*4+nextCurrentTetrominoRotation],
    ;                 tileOffsets[nextCurrentTetromino], 16, 124, 36)
    ; Compute index = nextCurrentTetromino * 4 + nextCurrentTetrominoRotation
    ld a, [_nextCurrentTetromino]
    push af                         ; save piece index for tileOffsets lookup
    sla a
    sla a                           ; A = piece * 4
    ld c, a
    ld a, [_nextCurrentTetrominoRotation]
    add c                           ; A = piece*4 + rotation

    ; Look up metasprite pointer: _Tetrominos_metasprites[index]
    ld c, a
    ld b, 0
    ld hl, _Tetrominos_metasprites
    add hl, bc
    add hl, bc                      ; HL = &metasprites[index] (2 bytes each)
    ld a, [hli]
    ld e, a
    ld a, [hl]
    ld d, a                         ; DE = metasprite pointer
    push de                         ; save metasprite pointer

    ; Look up tileOffsets[nextCurrentTetromino]
    pop hl                          ; HL = metasprite pointer
    pop af                          ; A = piece index
    push hl                         ; re-save metasprite pointer
    ld c, a
    ld b, 0
    ld hl, _tileOffsets
    add hl, bc
    ld a, [hl]                      ; A = base tile

    ; move_metasprite: HL=metasprite, A=base_tile, B=base_sprite, D=x, E=y
    pop hl                          ; HL = metasprite pointer
    ld b, 16                        ; base_sprite = 16
    ld d, 124                       ; x = 124
    ld e, 36                        ; y = 36
    call move_metasprite
    ret

; ---------------------------------------------------------------------------
; _IncreaseScore: A=amount                                   | clobbers: all
;
; Adds an 8-bit amount to the 16-bit score, then updates the GUI.
; ---------------------------------------------------------------------------
_IncreaseScore::
    ld c, a                         ; save amount
    ld a, [_score]
    add c
    ld [_score], a
    ld a, [_score + 1]
    adc 0                           ; add carry
    ld [_score + 1], a
    call _UpdateGui
    ret
