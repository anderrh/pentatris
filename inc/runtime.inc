; =============================================================================
; runtime.inc - Runtime library declarations
; =============================================================================
; Include this in any module that needs GBDK-equivalent runtime functions.
; Provides hardware.inc, macros, and constants.
;
; In RGBDS v1.0.0, external symbols are resolved by the linker automatically.
; No EXTERN/IMPORT declarations are needed. The calling conventions are
; documented here as comments for reference.
; =============================================================================

IF !DEF(RUNTIME_INC)
DEF RUNTIME_INC EQU 1

INCLUDE "hardware.inc"

; =============================================================================
; Hardware register aliases matching GBDK naming
; =============================================================================
; VBK_REG = rVBK ($FF4F)   - use: ld a, 1 / ldh [rVBK], a
; NR52_REG = rNR52 ($FF26)
; NR51_REG = rNR51 ($FF25)
; NR50_REG = rNR50 ($FF24)

; =============================================================================
; GBDK display control macros
; =============================================================================

; DISPLAY_ON: enable LCD with BG + sprites + BG tile data at $8000
MACRO DISPLAY_ON
    ld a, LCDCF_ON | LCDCF_BGON | LCDCF_OBJON | LCDCF_BG8000
    ldh [rLCDC], a
ENDM

; DISPLAY_OFF: disable LCD (must be called during VBlank!)
MACRO DISPLAY_OFF
    xor a
    ldh [rLCDC], a
ENDM

; SHOW_BKG: enable background layer
MACRO SHOW_BKG
    ldh a, [rLCDC]
    or LCDCF_BGON
    ldh [rLCDC], a
ENDM

; SHOW_SPRITES: enable sprite layer
MACRO SHOW_SPRITES
    ldh a, [rLCDC]
    or LCDCF_OBJON
    ldh [rLCDC], a
ENDM

; SHOW_WIN: enable window layer
MACRO SHOW_WIN
    ldh a, [rLCDC]
    or LCDCF_WINON
    ldh [rLCDC], a
ENDM

; HIDE_WIN: disable window layer
MACRO HIDE_WIN
    ldh a, [rLCDC]
    and ~LCDCF_WINON & $FF
    ldh [rLCDC], a
ENDM

; =============================================================================
; Joypad button constants (matching GBDK J_* defines)
; =============================================================================
; These are already in hardware.inc as PADF_*, but GBDK uses J_* names
DEF J_RIGHT  EQU PADF_RIGHT   ; $10
DEF J_LEFT   EQU PADF_LEFT    ; $20
DEF J_UP     EQU PADF_UP      ; $40
DEF J_DOWN   EQU PADF_DOWN    ; $80
DEF J_A      EQU PADF_A       ; $01
DEF J_B      EQU PADF_B       ; $02
DEF J_SELECT EQU PADF_SELECT  ; $04
DEF J_START  EQU PADF_START   ; $08

; =============================================================================
; Boolean constants
; =============================================================================
DEF TRUE  EQU 1
DEF FALSE EQU 0

; =============================================================================
; ASCII character constants
; =============================================================================
DEF ASCII_0     EQU $30
DEF ASCII_9     EQU $39
DEF ASCII_A     EQU $41
DEF ASCII_B     EQU $42
DEF ASCII_F     EQU $46
DEF ASCII_I     EQU $49
DEF ASCII_L     EQU $4C
DEF ASCII_P     EQU $50
DEF ASCII_S     EQU $53
DEF ASCII_NEWLINE EQU $0A

; =============================================================================
; Metasprite struct layout
; =============================================================================
; Matches GBDK metasprite_t: { int8_t dy, dx; uint8_t dtile, props; }
; Terminated by a sentinel entry with dy = 128 ($80)
DEF METASPRITE_DY    EQU 0
DEF METASPRITE_DX    EQU 1
DEF METASPRITE_TILE  EQU 2
DEF METASPRITE_PROPS EQU 3
DEF METASPRITE_SIZE  EQU 4
DEF METASPRITE_END   EQU 128  ; sentinel value for dy

; =============================================================================
; Runtime function calling conventions (reference)
; =============================================================================
; All symbols are resolved by the linker. These comments document the
; register-based calling conventions for each runtime function.
;
; CONVENTION: All functions clobber A and F. Other clobbered registers are
; listed explicitly. Callers must save/restore any registers they need that
; appear in the "clobbers" list.
;
; --- VBlank synchronization ---
; wait_vbl_done: halts CPU until VBlank interrupt fires
;   clobbers: A
;
; --- Joypad ---
; joypad: returns A = joypad state (J_* bits set for pressed buttons)
;   clobbers: A, B
;
; --- Background tile access ---
; set_bkg_tile_xy: B=x, C=y, D=tile          | clobbers: A, DE, HL
; get_bkg_tile_xy: B=x, C=y -> A=tile        | clobbers: A, DE, HL
; set_bkg_tiles: B=x, C=y, D=w, E=h, HL=src  | clobbers: all
; get_bkg_tiles: B=x, C=y, D=w, E=h, HL=dst  | clobbers: all
; fill_bkg_rect: B=x, C=y, D=w, E=h, A=tile  | clobbers: all
; set_bkg_based_tiles: B=x, C=y, D=w, E=h, HL=src, A=base | clobbers: all
;
; --- Window tile access ---
; set_win_tile_xy: B=x, C=y, D=tile          | clobbers: A, DE, HL
; get_win_tile_xy: B=x, C=y -> A=tile        | clobbers: A, DE, HL
; set_win_tiles: B=x, C=y, D=w, E=h, HL=src  | clobbers: all
; get_win_tiles: B=x, C=y, D=w, E=h, HL=dst  | clobbers: all
; fill_win_rect: B=x, C=y, D=w, E=h, A=tile  | clobbers: all
;
; --- VRAM tile data ---
; set_bkg_data: A=start_tile, B=num_tiles, HL=src    | clobbers: all
; set_sprite_data: A=start_tile, B=num_tiles, HL=src  | clobbers: all
;
; --- CGB palette ---
; set_bkg_palette: A=first_palette, B=num_palettes, HL=palette_data | clobbers: all
; set_sprite_palette: A=first_palette, B=num_palettes, HL=palette_data | clobbers: all
;
; --- OAM / Sprites ---
; move_sprite: A=sprite_id, B=x, C=y          | clobbers: A, DE, HL
; set_sprite_tile: A=sprite_id, B=tile         | clobbers: A, DE, HL
; move_metasprite: HL=metasprite, A=base_tile, B=base_sprite, D=x, E=y -> A=next sprite | clobbers: all
; hide_metasprite: HL=metasprite, A=base_sprite | clobbers: all
; run_dma: triggers OAM DMA transfer from shadow OAM
;
; --- Utility ---
; uitoa: HL=number, DE=buffer_ptr, B=radix -> DE=buffer (null-terminated) | clobbers: all
;
; --- WRAM from header.asm ---
; wVBlankFlag (1 byte) - set by VBlank ISR, cleared by wait_vbl_done
; wShadowOAM (160 bytes, aligned) - shadow OAM buffer
; hOAMDMA (HRAM) - OAM DMA routine

ENDC ; RUNTIME_INC
