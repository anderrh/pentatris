; =============================================================================
; runtime.asm - GBDK-equivalent hardware runtime library
; =============================================================================
; Reimplements the GBDK C library functions used by the Tetris game.
; Each function documents the original GBDK C signature and the assembly
; calling convention used by our port.
; =============================================================================

INCLUDE "runtime.inc"

; =============================================================================
; VBlank Synchronization
; =============================================================================

SECTION "RuntimeVBlank", ROM0

; void wait_vbl_done(void)
; Halts the CPU until the VBlank interrupt fires.
; The VBlank ISR in header.asm sets wVBlankFlag to 1.
wait_vbl_done::
    ; TODO: Implement wait_vbl_done
    ; Halt CPU until VBlank interrupt sets wVBlankFlag
    ret

SECTION "RuntimeJoypad", ROM0

; uint8_t joypad(void)
; Reads the current joypad state.
; Returns: A = button state (J_* bits set for pressed buttons)
;   Bits: 7=Down 6=Up 5=Left 4=Right 3=Start 2=Select 1=B 0=A
; Clobbers: B
joypad::
    ; Read D-pad
    ld a, P1F_GET_DPAD
    ldh [rP1], a
    ; Read rP1 multiple times for signal settling
    ldh a, [rP1]
    ldh a, [rP1]
    ldh a, [rP1]
    ldh a, [rP1]
    and $0F                         ; lower nibble = d-pad states (active low)
    swap a                          ; move to upper nibble
    cpl                             ; invert (active high)
    and $F0
    ld b, a                         ; B = d-pad in upper nibble

    ; Read buttons
    ld a, P1F_GET_BTN
    ldh [rP1], a
    ldh a, [rP1]
    ldh a, [rP1]
    ldh a, [rP1]
    ldh a, [rP1]
    and $0F
    cpl
    and $0F                         ; A = buttons in lower nibble

    or b                            ; combine d-pad and buttons

    ; Reset joypad register
    ld b, a
    ld a, P1F_GET_NONE
    ldh [rP1], a
    ld a, b
    ret

; =============================================================================
; Background Tile Access
; =============================================================================

SECTION "RuntimeBkgTiles", ROM0

; Internal helper: compute VRAM address for BG tile at (B=x, C=y)
; Returns: HL = _SCRN0 + y*32 + x
; Clobbers: A, DE
_BkgTileAddr:
    ld h, 0
    ld l, c                         ; HL = y
    ; Multiply y by 32: shift left 5 times
    add hl, hl                      ; *2
    add hl, hl                      ; *4
    add hl, hl                      ; *8
    add hl, hl                      ; *16
    add hl, hl                      ; *32
    ld d, 0
    ld e, b                         ; DE = x
    add hl, de                      ; HL = y*32 + x
    ld de, _SCRN0
    add hl, de                      ; HL = _SCRN0 + y*32 + x
    ret

; Internal helper: compute VRAM address for Window tile at (B=x, C=y)
; Returns: HL = _SCRN1 + y*32 + x
; Clobbers: A, DE
_WinTileAddr:
    ld h, 0
    ld l, c
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl
    ld d, 0
    ld e, b
    add hl, de
    ld de, _SCRN1
    add hl, de
    ret

; void set_bkg_tile_xy(uint8_t x, uint8_t y, uint8_t tile)
; B=x, C=y, D=tile
; Sets one background tile at position (x,y).
; Clobbers: A, DE, HL
set_bkg_tile_xy::
    ; TODO: Implement set_bkg_tile_xy
    ; B=x, C=y, D=tile -> write tile to background tilemap
    push de
    call _BkgTileAddr
    call _WaitVRAM
    pop de
    ld a, d
    ld [hl], a

    ret

get_bkg_tile_xy::
    ; TODO: Implement get_bkg_tile_xy
    ; B=x, C=y -> A=tile at that background position
    call _BkgTileAddr
    call _WaitVRAM
    ld a, [hl]


    ret

set_win_tile_xy::
    push de
    call _WinTileAddr
    pop de
    call _WaitVRAM
    ld [hl], d
    ret

; uint8_t get_win_tile_xy(uint8_t x, uint8_t y)
; B=x, C=y -> A=tile
; Gets one window tile at position (x,y).
; Clobbers: DE, HL
get_win_tile_xy::
    call _WinTileAddr
    call _WaitVRAM
    ld a, [hl]
    ret

; void set_bkg_tiles(uint8_t x, uint8_t y, uint8_t w, uint8_t h, const uint8_t *tiles)
; B=x, C=y, D=w, E=h, HL=src
; Copies a rectangular region of tiles to the background map.
; Clobbers: A, BC, DE, HL
set_bkg_tiles::
    ; Save src pointer
    push hl
    ; Save w, h
    push de
    ; Calculate VRAM start address
    call _BkgTileAddr
    ; HL = VRAM dest, restore DE (w,h) and BC (src)
    pop de                          ; D=w, E=h
    pop bc                          ; BC=src
    ; Now: HL=VRAM dest, BC=src, D=w, E=h
    jp _CopyTilesToVRAM

; void get_bkg_tiles(uint8_t x, uint8_t y, uint8_t w, uint8_t h, uint8_t *dst)
; B=x, C=y, D=w, E=h, HL=dst
; Copies a rectangular region of tiles from the background map.
; Clobbers: A, BC, DE, HL
get_bkg_tiles::
    push hl
    push de
    call _BkgTileAddr
    pop de
    pop bc
    ; HL=VRAM src, BC=dst, D=w, E=h
    jp _CopyTilesFromVRAM

; void set_win_tiles(uint8_t x, uint8_t y, uint8_t w, uint8_t h, const uint8_t *tiles)
; B=x, C=y, D=w, E=h, HL=src
; Clobbers: A, BC, DE, HL
set_win_tiles::
    push hl
    push de
    call _WinTileAddr
    pop de
    pop bc
    jp _CopyTilesToVRAM

; void get_win_tiles(uint8_t x, uint8_t y, uint8_t w, uint8_t h, uint8_t *dst)
; B=x, C=y, D=w, E=h, HL=dst
; Clobbers: A, BC, DE, HL
get_win_tiles::
    push hl
    push de
    call _WinTileAddr
    pop de
    pop bc
    jp _CopyTilesFromVRAM

; void fill_bkg_rect(uint8_t x, uint8_t y, uint8_t w, uint8_t h, uint8_t tile)
; B=x, C=y, D=w, E=h, A=tile
; Fills a rectangular region of the background map with a single tile.
; Clobbers: BC, DE, HL
fill_bkg_rect::
    push af                         ; save tile value
    push de                         ; save w, h
    call _BkgTileAddr
    pop de                          ; D=w, E=h
    pop af                          ; A=tile
    jp _FillTileRect

; void fill_win_rect(uint8_t x, uint8_t y, uint8_t w, uint8_t h, uint8_t tile)
; B=x, C=y, D=w, E=h, A=tile
; Fills a rectangular region of the window map with a single tile.
; Clobbers: BC, DE, HL
fill_win_rect::
    push af
    push de
    call _WinTileAddr
    pop de
    pop af
    jp _FillTileRect

; void set_bkg_based_tiles(uint8_t x, uint8_t y, uint8_t w, uint8_t h,
;                          const uint8_t *tiles, uint8_t base)
; B=x, C=y, D=w, E=h, HL=src, A=base
; Copies tiles to background map, adding 'base' to each tile value.
; Clobbers: BC, DE, HL
set_bkg_based_tiles::
    push af                         ; save base
    push hl                         ; save src
    push de                         ; save w, h
    call _BkgTileAddr
    ; HL = VRAM dest
    pop de                          ; D=w, E=h
    pop bc                          ; BC=src
    pop af                          ; A=base
    jp _CopyBasedTilesToVRAM

; =============================================================================
; Internal tile copy helpers
; =============================================================================

SECTION "RuntimeTileCopy", ROM0

; Wait for VRAM to become accessible (not during mode 3)
; Clobbers: A
_WaitVRAM:
    ldh a, [rSTAT]
    and STATF_BUSY
    jr nz, _WaitVRAM
    ret

; Copy tiles TO VRAM rectangle
; HL=VRAM dest, BC=src, D=w, E=h
; Clobbers: A, BC, DE, HL
_CopyTilesToVRAM:
.rowLoop:
    push hl                         ; save row start in VRAM
    push de                         ; save w, h
    ld a, d                         ; A = width counter
.colLoop:
    push af
    call _WaitVRAM
    ld a, [bc]
    ld [hli], a
    inc bc
    pop af
    dec a
    jr nz, .colLoop
    pop de                          ; D=w, E=h
    pop hl                          ; HL = row start
    ; Advance to next row (add 32)
    push de
    ld de, 32
    add hl, de
    pop de
    dec e
    jr nz, .rowLoop
    ret

; Copy tiles FROM VRAM rectangle
; HL=VRAM src, BC=dst, D=w, E=h
; Clobbers: A, BC, DE, HL
_CopyTilesFromVRAM:
.rowLoop:
    push hl
    push de
    ld a, d
.colLoop:
    push af
    call _WaitVRAM
    ld a, [hli]
    ld [bc], a
    inc bc
    pop af
    dec a
    jr nz, .colLoop
    pop de
    pop hl
    push de
    ld de, 32
    add hl, de
    pop de
    dec e
    jr nz, .rowLoop
    ret

; Fill VRAM rectangle with a single tile
; HL=VRAM dest, D=w, E=h, A=tile
; Clobbers: BC, DE, HL
_FillTileRect:
    ld b, a                         ; B = tile to fill
.rowLoop:
    push hl
    push de
    ld a, d                         ; A = width counter
.colLoop:
    push af
    call _WaitVRAM
    ld [hl], b
    inc hl
    pop af
    dec a
    jr nz, .colLoop
    pop de
    pop hl
    push de
    ld de, 32
    add hl, de
    pop de
    dec e
    jr nz, .rowLoop
    ret

; Copy tiles to VRAM with base offset added to each tile
; HL=VRAM dest, BC=src, D=w, E=h, A=base
; Clobbers: BC, DE, HL
_CopyBasedTilesToVRAM:
    ld [_tileBase], a               ; store base
.rowLoop:
    push hl
    push de
    ld a, d
.colLoop:
    push af
    call _WaitVRAM
    ld a, [bc]
    push hl
    ld hl, _tileBase
    add [hl]
    pop hl
    ld [hli], a
    inc bc
    pop af
    dec a
    jr nz, .colLoop
    pop de
    pop hl
    push de
    ld de, 32
    add hl, de
    pop de
    dec e
    jr nz, .rowLoop
    ret

; =============================================================================
; VRAM Tile Data Copy
; =============================================================================

SECTION "RuntimeVRAMData", ROM0

; void set_bkg_data(uint8_t start_tile, uint8_t num_tiles, const uint8_t *data)
; A=start_tile, B=num_tiles, HL=src
; Copies tile data to VRAM background tile area ($8000 + start*16).
; Clobbers: A, BC, DE, HL
set_bkg_data::
    push hl                         ; save src
    ; Calculate VRAM dest: _VRAM + A * 16
    ld h, 0
    ld l, a
    add hl, hl                      ; *2
    add hl, hl                      ; *4
    add hl, hl                      ; *8
    add hl, hl                      ; *16
    ld de, _VRAM
    add hl, de                      ; HL = _VRAM + start*16
    ld d, h
    ld e, l                         ; DE = VRAM dest
    ; Calculate byte count: B * 16
    ld a, b
    ld h, 0
    ld l, a
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl                      ; HL = num_tiles * 16
    ld b, h
    ld c, l                         ; BC = byte count
    pop hl                          ; HL = src
    ; Now: HL=src, DE=dest, BC=count
    jp _CopyToVRAM

; void set_sprite_data(uint8_t start_tile, uint8_t num_tiles, const uint8_t *data)
; A=start_tile, B=num_tiles, HL=src
; Copies tile data to VRAM sprite tile area ($8000 + start*16).
; Note: On GB, BG and sprite tiles share the same $8000 base when LCDCF_BG8000 is set.
; Clobbers: A, BC, DE, HL
set_sprite_data::
    push hl
    ld h, 0
    ld l, a
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl
    ld de, _VRAM
    add hl, de
    ld d, h
    ld e, l
    ld a, b
    ld h, 0
    ld l, a
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl
    ld b, h
    ld c, l
    pop hl
    jp _CopyToVRAM

; Generic copy to VRAM with STAT wait
; HL=src, DE=dest, BC=byte_count
; Clobbers: A, BC, DE, HL
_CopyToVRAM:
    ld a, b
    or c
    ret z                           ; return if count = 0
.loop:
    call _WaitVRAM
    ld a, [hli]
    ld [de], a
    inc de
    dec bc
    ld a, b
    or c
    jr nz, .loop
    ret

; =============================================================================
; CGB Palette Functions
; =============================================================================

SECTION "RuntimePalettes", ROM0

; void set_bkg_palette(uint8_t first_palette, uint8_t num_palettes, const uint16_t *data)
; A=first_palette (0-7), B=num_palettes, HL=palette_data
; Each palette = 4 colors x 2 bytes = 8 bytes. Data is array of RGB555 words.
; Clobbers: A, BC, DE, HL
set_bkg_palette::
    ; Set BCPS: palette index = A*8, auto-increment
    sla a
    sla a
    sla a                           ; A = first_palette * 8
    or $80                          ; set auto-increment bit
    ldh [rBCPS], a
    ; Total bytes = num_palettes * 8
    ld a, b
    sla a
    sla a
    sla a                           ; A = num_palettes * 8
    ld b, a                         ; B = byte count
.loop:
    ld a, [hli]
    ldh [rBCPD], a
    dec b
    jr nz, .loop
    ret

; void set_sprite_palette(uint8_t first_palette, uint8_t num_palettes, const uint16_t *data)
; A=first_palette (0-7), B=num_palettes, HL=palette_data
; Clobbers: A, BC, HL
set_sprite_palette::
    sla a
    sla a
    sla a
    or $80
    ldh [rOCPS], a
    ld a, b
    sla a
    sla a
    sla a
    ld b, a
.loop:
    ld a, [hli]
    ldh [rOCPD], a
    dec b
    jr nz, .loop
    ret

; =============================================================================
; OAM / Sprite Functions
; =============================================================================

SECTION "RuntimeSprites", ROM0

; void move_sprite(uint8_t id, uint8_t x, uint8_t y)
; A=sprite_id (0-39), B=x, C=y
; Moves a sprite in the shadow OAM buffer.
; Clobbers: DE, HL
move_sprite::
    ; args: A = sprite index (0-39), B = x, C = y
    ;
    ; We need to find this sprite's slot in the shadow OAM buffer.
    ; Each sprite takes 4 bytes, so sprite N starts at wShadowOAM + N*4.
    ; The OAM layout for each sprite is: [Y] [X] [tile] [attributes]

    ; TODO: Compute the address of this sprite's OAM entry.
    ;   First, get the index into HL so we can do 16-bit math:
    ;     "ld h, 0" and "ld l, a" puts A (sprite index) into HL.
    ;   Multiply by 4: "add hl, hl" doubles HL (so twice = *4). 
    ; we do this to get to the correct pos in shadow ram but not 
    ;the corect offset(renember each sprite takes up 4 bytes: x,y,tile,attrubutes)
    ;   we are at 0 + 4*aprite in index so we need to add to actully get to the section in memory with shadow oam:
    ;     "ld de, wShadowOAM" then "add hl, de".
    ;   Now HL is the pointer to this sprite's Y byte.
    ;   (6 instructions)

    ; TODO: Write Y and X positions into the OAM slot.
    ;   (3 instructions)

    ld h, 0
    ld l, a
    add hl, hl
    add hl, hl
    ld de, wShadowOAM
    add hl, de
    ld a, c
    ld [hli], a
    ld a, b
    ld [hl], a

    ret

set_sprite_tile::
    ; TODO: Implement set_sprite_tile
    ; A=sprite_id, B=tile -> write tile to shadow OAM

    ld h, 0
    ld l, a
    add hl, hl
    add hl, hl
    ld de, wShadowOAM
    add hl, de
    inc hl
    inc hl
    ld a, b
    ld [hl], a
    ret

move_metasprite::
    ld [_metaBaseTile], a
    ld a, d
    ld [_metaBaseX], a
    ld a, e
    ld [_metaBaseY], a
    ld a, b
    ld [_metaSpriteIdx], a

.loop:
    ; Check for sentinel (dy == 128)
    ld a, [hl]
    cp METASPRITE_END
    jr z, .done

    ; Read dy, compute OAM Y = current_y + dy (cumulative)
    ld a, [_metaBaseY]
    add [hl]                        ; A = current_y + dy
    ld [_metaBaseY], a              ; accumulate position
    inc hl
    ld b, a                         ; B = OAM Y

    ; Read dx, compute OAM X = current_x + dx (cumulative)
    ld a, [_metaBaseX]
    add [hl]                        ; A = current_x + dx
    ld [_metaBaseX], a              ; accumulate position
    inc hl
    ld c, a                         ; C = OAM X

    ; Read dtile, add base_tile
    ld a, [_metaBaseTile]
    add [hl]                        ; A = base_tile + dtile
    inc hl
    ld d, a                         ; D = tile

    ; Read props
    ld a, [hl]
    inc hl
    ld e, a                         ; E = props

    ; Save metasprite pointer
    push hl

    ; Calculate shadow OAM address for current sprite
    ld a, [_metaSpriteIdx]
    ld h, 0
    ld l, a
    add hl, hl
    add hl, hl
    push de                         ; save tile, props
    ld de, wShadowOAM
    add hl, de
    pop de                          ; D=tile, E=props

    ; Write OAM entry: Y, X, tile, props
    ld [hl], b                      ; Y
    inc hl
    ld [hl], c                      ; X
    inc hl
    ld [hl], d                      ; tile
    inc hl
    ld [hl], e                      ; props

    ; Increment sprite index
    ld a, [_metaSpriteIdx]
    inc a
    ld [_metaSpriteIdx], a

    ; Restore metasprite pointer
    pop hl
    jr .loop

.done:
    ld a, [_metaSpriteIdx]
    ret

; void hide_metasprite(const metasprite_t *metasprite, uint8_t base_sprite)
; HL=metasprite, A=base_sprite
; Hides all sprites in a metasprite by moving them offscreen (Y=0, X=0).
; Clobbers: A, BC, DE, HL
hide_metasprite::
    ; TODO: Implement hide_metasprite
    ; HL=metasprite, A=base_sprite -> hide all sprites in metasprite
    ret

run_dma::
    jp hOAMDMA

; =============================================================================
; Utility Functions
; =============================================================================

SECTION "RuntimeUtility", ROM0

; void uitoa(uint16_t value, char *buffer, uint8_t radix)
; HL=value, DE=buffer, B=radix
; Converts unsigned 16-bit integer to null-terminated ASCII string.
; Only radix 10 is needed for this game.
; Clobbers: A, BC, DE, HL
uitoa::
    ; For radix 10: divide HL by 10 repeatedly, store remainders
    ; We'll build digits in reverse on stack, then copy forward

    ld a, b                         ; save radix
    ld [_uitoaRadix], a

    ; Count digits
    xor a
    ld [_uitoaCount], a

    ; Special case: value == 0
    ld a, h
    or l
    jr nz, .divLoop
    ld a, ASCII_0
    ld [de], a
    inc de
    xor a
    ld [de], a                      ; null terminator
    ret

.divLoop:
    ; Divide HL by radix, remainder in A
    push de                         ; save buffer ptr
    ld a, [_uitoaRadix]
    ld b, a
    call _DivHL_B                   ; HL = HL / B, A = remainder
    pop de

    ; Convert remainder to ASCII and push
    add ASCII_0
    push af
    ld a, [_uitoaCount]
    inc a
    ld [_uitoaCount], a

    ; Continue if HL != 0
    ld a, h
    or l
    jr nz, .divLoop

    ; Pop digits in reverse order into buffer
    ld a, [_uitoaCount]
    ld b, a
.popLoop:
    pop af
    ld [de], a
    inc de
    dec b
    jr nz, .popLoop

    ; Null terminator
    xor a
    ld [de], a
    ret

; Divide HL by B
; Returns: HL = quotient, A = remainder
; Clobbers: C
_DivHL_B:
    ; 16-bit / 8-bit division
    xor a                           ; A = remainder = 0
    ld c, 16                        ; 16 bits to process
.loop:
    ; Shift HL left, carry into remainder
    add hl, hl                      ; shift HL left (MSB -> carry)
    rla                             ; shift carry into remainder
    cp b                            ; remainder >= divisor?
    jr c, .noSub
    sub b                           ; remainder -= divisor
    inc l                           ; set bit 0 of quotient
.noSub:
    dec c
    jr nz, .loop
    ret                             ; HL = quotient, A = remainder

; =============================================================================
; Runtime WRAM temporaries
; =============================================================================

SECTION "RuntimeVars", WRAM0

_metaBaseTile:  DS 1
_metaBaseX:     DS 1
_metaBaseY:     DS 1
_metaSpriteIdx: DS 1
_tileBase:      DS 1
_uitoaRadix:    DS 1
_uitoaCount:    DS 1
