; =============================================================================
; Tetrominos.inc - Tetromino function and data declarations
; Ported from: headers/main/Tetrominos.h
; =============================================================================

IF !DEF(TETROMINOS_INC)
DEF TETROMINOS_INC EQU 1

; Data (resolved by linker):
;   _Tetrominos_metasprites: table of 28 metasprite pointers (7 pieces x 4 rotations)
;   _tileOffsets: 8-byte table of cumulative tile counts for VRAM layout
;
; Functions (resolved by linker):
;   _CanPieceBePlacedHere: B=piece, C=rotation, D=column, E=row -> A=result (0 or 1)
;   _PickNewTetromino: -> A = 1 if successful, 0 if cannot spawn

ENDC ; TETROMINOS_INC
