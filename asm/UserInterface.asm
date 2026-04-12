; ============================================================================
; Ported from: source/main/UserInterface.c
; ============================================================================

    INCLUDE "common.inc"
    INCLUDE "UserInterface.inc"

; ============================================================================
; SECTION: UIGraphicsData
; ============================================================================
SECTION "UIGraphicsData", ROM0

UserInterface_tiles::
    INCBIN "gfx/UserInterface.2bpp"
UserInterface_map:
    INCBIN "gfx/UserInterface.tilemap"
UserInterface_map_attributes:
    INCBIN "gfx/UserInterface.attrmap"
TileAnimation_tiles::
    INCBIN "gfx/TileAnimation.2bpp"

; ============================================================================
; SECTION: UIVariables
; ============================================================================
SECTION "UIVariables", WRAM0
_uiLoopI: DS 1
_uiLoopJ: DS 1

; ============================================================================
; SECTION: UICode
; ============================================================================
SECTION "UICode", ROM0

; ----------------------------------------------------------------------------
; _SetupAnimatedBackground: (none)                        | clobbers: all
;
; Scans all 32x32 BG tiles. Where a tile matches _tileAnimationBase,
; replaces it with TILEANIMATION_TILE1_VRAM or _TILE2_VRAM in a
; checkerboard pattern.
; ----------------------------------------------------------------------------
_SetupAnimatedBackground::
    xor a
    ld [_uiLoopI], a                ; i = 0 (column)
.sab_outerLoop:
    xor a
    ld [_uiLoopJ], a                ; j = 0 (row)
.sab_innerLoop:
    ; get_bkg_tile_xy(i, j)
    ld a, [_uiLoopI]
    ld b, a
    ld a, [_uiLoopJ]
    ld c, a
    call get_bkg_tile_xy            ; A = tile at (i, j)

    ; if(tile == tileAnimationBase)
    ld b, a
    ld a, [_tileAnimationBase]
    cp b
    jr nz, .sab_nextJ

    ; Determine replacement tile based on checkerboard pattern
    ; if(j%2==0): even row
    ;   if(i%2==0) → TILE1, else → TILE2
    ; else: odd row
    ;   if(i%2==0) → TILE2, else → TILE1
    ld a, [_uiLoopJ]
    and 1                           ; j % 2
    ld c, a                         ; C = j%2
    ld a, [_uiLoopI]
    and 1                           ; i % 2
    xor c                           ; A = (i%2) XOR (j%2)
    ; if A==0: both even or both odd → TILE1
    ; if A==1: one even, one odd → TILE2
    jr nz, .sab_tile2
    ld d, TILEANIMATION_TILE1_VRAM
    jr .sab_setTile
.sab_tile2:
    ld d, TILEANIMATION_TILE2_VRAM
.sab_setTile:
    ld a, [_uiLoopI]
    ld b, a
    ld a, [_uiLoopJ]
    ld c, a
    call set_bkg_tile_xy

.sab_nextJ:
    ld a, [_uiLoopJ]
    inc a
    ld [_uiLoopJ], a
    cp 32
    jr c, .sab_innerLoop

    ld a, [_uiLoopI]
    inc a
    ld [_uiLoopI], a
    cp 32
    jr c, .sab_outerLoop
    ret

; ----------------------------------------------------------------------------
; _SetupUserInterface: (none)                             | clobbers: all
;
; Loads the UI tilemap, reads reference tiles for blank and animation,
; fills border areas, then calls SetupAnimatedBackground.
; ----------------------------------------------------------------------------
_SetupUserInterface::
    ; VBK_REG=1; set_bkg_tiles(0,0,20,18,UserInterface_map_attributes)
    ld a, 1
    ldh [rVBK], a
    ld b, 0
    ld c, 0
    ld d, 20
    ld e, 18
    ld hl, UserInterface_map_attributes
    call set_bkg_tiles

    ; VBK_REG=0; set_bkg_based_tiles(0,0,20,18,UserInterface_map,USERINTERFACE_TILE_START)
    xor a
    ldh [rVBK], a
    ld b, 0
    ld c, 0
    ld d, 20
    ld e, 18
    ld hl, UserInterface_map
    ld a, USERINTERFACE_TILE_START
    call set_bkg_based_tiles

    ; VBK_REG=1; tileAnimationBasePalette = get_bkg_tile_xy(0,0)
    ld a, 1
    ldh [rVBK], a
    ld b, 0
    ld c, 0
    call get_bkg_tile_xy
    ld [_tileAnimationBasePalette], a

    ; VBK_REG=0; tileAnimationBase = get_bkg_tile_xy(0,0)
    xor a
    ldh [rVBK], a
    ld b, 0
    ld c, 0
    call get_bkg_tile_xy
    ld [_tileAnimationBase], a

    ; VBK_REG=1; blankTilePalette = get_bkg_tile_xy(3,3)
    ld a, 1
    ldh [rVBK], a
    ld b, 3
    ld c, 3
    call get_bkg_tile_xy
    ld [_blankTilePalette], a

    ; VBK_REG=0; blankTile = get_bkg_tile_xy(3,3)
    xor a
    ldh [rVBK], a
    ld b, 3
    ld c, 3
    call get_bkg_tile_xy
    ld [_blankTile], a

    ; VBK_REG=1; fill border areas with tileAnimationBasePalette
    ld a, 1
    ldh [rVBK], a
    ld a, [_tileAnimationBasePalette]
    ld b, 0
    ld c, 18
    ld d, 31
    ld e, 14
    call fill_bkg_rect
    ld a, [_tileAnimationBasePalette]
    ld b, 20
    ld c, 0
    ld d, 12
    ld e, 31
    call fill_bkg_rect

    ; VBK_REG=0; fill border areas with tileAnimationBase
    xor a
    ldh [rVBK], a
    ld a, [_tileAnimationBase]
    ld b, 0
    ld c, 18
    ld d, 31
    ld e, 14
    call fill_bkg_rect
    ld a, [_tileAnimationBase]
    ld b, 20
    ld c, 0
    ld d, 12
    ld e, 31
    call fill_bkg_rect

    ; SetupAnimatedBackground()
    call _SetupAnimatedBackground
    ret

; ----------------------------------------------------------------------------
; _AnimateBackground: (none)                              | clobbers: all
;
; Advances the tile animation counter by 6 (wrapping at 128) and updates
; the two animation tile slots in VRAM with the appropriate frame.
; ----------------------------------------------------------------------------
_AnimateBackground::
    ; tileAnimationCounter += 6
    ld a, [_tileAnimationCounter]
    add 6
    ; if(tileAnimationCounter >= 128) tileAnimationCounter = 0
    cp 128
    jr c, .ab_noWrap
    xor a
.ab_noWrap:
    ld [_tileAnimationCounter], a

    ; set_bkg_data(TILEANIMATION_TILE1_VRAM, 1, TileAnimation_tiles + (counter>>4)*16)
    ; (counter>>4)*16 = counter & $F0
    and $F0
    ld c, a
    ld b, 0
    ld hl, TileAnimation_tiles
    add hl, bc
    ld a, TILEANIMATION_TILE1_VRAM
    ld b, 1
    call set_bkg_data

    ; set_bkg_data(TILEANIMATION_TILE2_VRAM, 1, TileAnimation_tiles + 128 + (counter>>4)*16)
    ld a, [_tileAnimationCounter]
    and $F0
    ld c, a
    ld b, 0
    ld hl, TileAnimation_tiles + 128
    add hl, bc
    ld a, TILEANIMATION_TILE2_VRAM
    ld b, 1
    call set_bkg_data
    ret
