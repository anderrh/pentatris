; =============================================================================
; gameplay.asm - Gameplay helper functions
; Extracted from main.asm for independent testability.
; Ported from: source/main/main.c
; =============================================================================

INCLUDE "common.inc"
INCLUDE "hud.inc"
INCLUDE "UserInterface.inc"
INCLUDE "board.inc"
INCLUDE "Tetrominos.inc"

; =============================================================================
; Palette data (auto-generated from png2asset output by tools/png2asm.py)
; =============================================================================
INCLUDE "palette_data.inc"

; =============================================================================
; SECTION: GameplayVariables
; =============================================================================
SECTION "GameplayVariables", WRAM0
_hiNextRot: DS 1                    ; temp for HandleInput rotation calc

; =============================================================================
; SECTION: GameplayCode
; =============================================================================
SECTION "GameplayCode", ROM0

; -----------------------------------------------------------------------------
; UpdateFallTimer - Gravity and piece locking                | clobbers: all
;
; Called once per frame from the main loop. Increments the fall timer.
; When it reaches 30, checks if the piece can move down one row.
; If yes, moves it. If no, starts a lock delay countdown.
; When the lock delay expires, locks the piece: copies it to the background,
; blinks/clears full rows, hides the sprites, and marks "no active piece."
; -----------------------------------------------------------------------------
_UpdateFallTimer::
    ; TODO: Implement UpdateFallTimer
    ; Increment fall timer, try to move piece down, handle lock delay
    ret

_HandleInput::
    ; TODO: Implement HandleInput
    ; Read joypad, handle rotation/movement/acceleration
    ret

_SetupVRAM::
    ; TODO: Implement SetupVRAM
    ; Load all tile data and palettes into VRAM
    ret

_SetupGameplay::
    ; TODO: Implement SetupGameplay
    ; Initialize game state for a new round
    ret

