; =============================================================================
; board.inc - Board function declarations
; Ported from: headers/main/board.h
; =============================================================================

IF !DEF(BOARD_INC)
DEF BOARD_INC EQU 1

; Functions (resolved by linker):
;   _IsRowFull: B=row, C=both_flag -> A=result (0 or 1)
;   _ShiftAllTilesAboveThisRowDown: B=row
;   _ShiftAllTilesDown: no args
;   _BlinkFullRows: no args
;   _SetCurrentPieceInBackground: no args

ENDC ; BOARD_INC
