; =============================================================================
; hud.inc - HUD function declarations
; Ported from: headers/main/hud.h
; =============================================================================

IF !DEF(HUD_INC)
DEF HUD_INC EQU 1

; Functions (resolved by linker):
;   _DrawNumber: B=x, C=y, DE=number, A=digits
;   _UpdateGui: no args
;   _IncreaseScore: A=amount

ENDC ; HUD_INC
