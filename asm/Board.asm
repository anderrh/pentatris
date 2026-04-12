; ============================================================================
; Ported from: source/main/Board.c
; ============================================================================

    INCLUDE "common.inc"
    INCLUDE "board.inc"
    INCLUDE "hud.inc"
    INCLUDE "Tetrominos.inc"
    INCLUDE "UserInterface.inc"

; ============================================================================
; SECTION: BoardVariables
; ============================================================================
SECTION "BoardVariables", WRAM0
_boardLoopI:    DS 1
_boardLoopJ:    DS 1
_boardLoopK::   DS 1
_boardMetaL:    DS 1                ; metasprite pointer low byte
_boardMetaH:    DS 1                ; metasprite pointer high byte
_boardFinalCol: DS 1
_boardFinalRow: DS 1
_boardBaseTile: DS 1

; Dedicated locals for _IsRowFull so it doesn't clobber _boardLoopI/J/K
; (which are used by callers like _BlinkFullRows and _ShiftAllTilesDown)
_irfRow:        DS 1                ; row being checked
_irfBoth:       DS 1                ; both_flag
_irfI:          DS 1                ; column loop counter

; ============================================================================
; SECTION: BoardCode
; ============================================================================
SECTION "BoardCode", ROM0

; ----------------------------------------------------------------------------
; _IsRowFull: B=row, C=both_flag -> A=result (1=full, 0=not full) | clobbers: all
;
; Checks if all 10 columns (2..11) in the given row contain non-blank tiles.
; When both_flag is TRUE, a cell must be non-blank in EITHER bkg OR win layer.
; ----------------------------------------------------------------------------
_IsRowFull::
    ; TODO: Implement IsRowFull
    ; B=row, C=both_flag -> A=1 if full, 0 if not
    xor a
    ret

_ShiftAllTilesAboveThisRowDown::
    ; TODO: Implement ShiftAllTilesAboveThisRowDown
    ; B=row -> clear row, shift all rows above it down by one
    ret

_ShiftAllTilesDown::
    ; TODO: Implement ShiftAllTilesDown
    ; Scan rows 17..0, while row is full shift it down
    ret

_BlinkFullRows::
    ; TODO: Implement BlinkFullRows
    ; Detect full rows, score them, blink animation, clear window
    ret

_SetCurrentPieceInBackground::
    ; TODO: Implement SetCurrentPieceInBackground
    ; Copy current piece's sprite tiles into the background tilemap
    ret

