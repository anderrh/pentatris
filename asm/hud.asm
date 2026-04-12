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
    ; TODO: Implement DrawNumber
    ; B=x, C=y, DE=number, A=digits -> draw number on BG
    ret

_UpdateGui::
    ; TODO: Implement UpdateGui
    ; Redraw score, level, lines, and next piece preview
    ret

_IncreaseScore::
    ; TODO: Implement IncreaseScore
    ; A = amount to add to 16-bit _score, then call _UpdateGui
    ret

