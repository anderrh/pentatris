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
    ; TODO: Implement SetupAnimatedBackground
    ; Scan 32x32 BG tiles, replace _tileAnimationBase with checkerboard
    ret

_SetupUserInterface::
    ; TODO: Implement SetupUserInterface
    ; Load UI tilemap, read reference tiles, fill borders, call SetupAnimatedBackground
    ret

_AnimateBackground::
    ; TODO: Implement AnimateBackground
    ; Advance tile animation counter and update VRAM tile frames
    ret

