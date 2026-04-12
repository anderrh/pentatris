; =============================================================================
; common.inc - Common variables and utility function declarations
; Ported from: headers/main/common.h
; =============================================================================

IF !DEF(COMMON_INC)
DEF COMMON_INC EQU 1

INCLUDE "runtime.inc"
INCLUDE "sprite_defs.inc"

; =============================================================================
; Tile VRAM layout constants
; Tetromino tile counts come from sprite_defs.inc (auto-generated).
; =============================================================================

; UserInterface tile count
DEF UserInterface_TILE_COUNT EQU 31

; Numbers font tile count (0-9 = 10 tiles)
DEF Numbers_TILE_COUNT EQU 10

; Derived VRAM layout constants (matching common.h defines)
; USERINTERFACE_TILE_START = sum of all piece tile counts
DEF USERINTERFACE_TILE_START EQU TOTAL_SPRITE_TILES

; TILEANIMATION_TILE1_VRAM = USERINTERFACE_TILE_START + UserInterface_TILE_COUNT
DEF TILEANIMATION_TILE1_VRAM EQU USERINTERFACE_TILE_START + UserInterface_TILE_COUNT

; TILEANIMATION_TILE2_VRAM = TILEANIMATION_TILE1_VRAM + 1
DEF TILEANIMATION_TILE2_VRAM EQU TILEANIMATION_TILE1_VRAM + 1

; NUMBERS_TILES_START = TILEANIMATION_TILE2_VRAM + 1
DEF NUMBERS_TILES_START EQU TILEANIMATION_TILE2_VRAM + 1

; =============================================================================
; External variable references (resolved by linker)
; =============================================================================
;
; 16-bit variables: _score (2), _lines (2)
; DAS (Delayed Auto Shift) constants for left/right auto-repeat
DEF DAS_DELAY EQU 16       ; frames before auto-repeat starts (~267ms)
DEF DAS_REPEAT EQU 6       ; frames between repeats (~100ms)

; 8-bit variables: _fallTimer, _isBlinking, _lockDelay, _dasTimer, _currentTetromino,
;   _nextCurrentTetromino, _currentTetrominoRotation,
;   _nextCurrentTetrominoRotation, _joypadCurrent, _joypadPrevious,
;   _currentX, _currentY, _level, _tileAnimationCounter,
;   _blankTile, _blankTilePalette, _tileAnimationBase, _tileAnimationBasePalette
; Arrays: _reusableRow10 (10 bytes)
;
; Functions:
;   _RandomNumber: B=min, C=max -> A=result
;   _ResetAllSprites: no args

ENDC ; COMMON_INC
