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
    ; fallTimer++
    ld a, [_fallTimer]
    inc a
    ld [_fallTimer], a

    ; if (fallTimer >= 30)
    cp 30
    jr c, .uft_checkLock

    ; Skip if no active piece
    ld a, [_currentTetromino]
    cp 255
    jr z, .uft_checkLock

    ; Can the piece move down one row?
    ld a, [_currentTetromino]
    ld b, a
    ld a, [_currentTetrominoRotation]
    ld c, a
    ld a, [_currentX]
    ld d, a
    ld a, [_currentY]
    inc a
    ld e, a
    call _CanPieceBePlacedHere
    or a
    jr nz, .uft_canMoveDown

    ; Piece is grounded: start lock delay if not already counting
    ld a, [_lockDelay]
    or a
    jr nz, .uft_clampFallTimer
    ld a, 30
    ld [_lockDelay], a              ; start 30-frame grace period
.uft_clampFallTimer:
    ld a, 30
    ld [_fallTimer], a              ; hold at 30 so we re-check each frame
    jr .uft_checkLock

.uft_canMoveDown:
    ; currentY++
    ld a, [_currentY]
    inc a
    ld [_currentY], a
    ; Reset timers (piece is freely falling)
    xor a
    ld [_fallTimer], a
    ld [_lockDelay], a

.uft_checkLock:
    ; Lock delay countdown
    ld a, [_currentTetromino]
    cp 255
    jr z, .uft_noLock
    ld a, [_lockDelay]
    or a
    jr z, .uft_noLock
    dec a
    ld [_lockDelay], a
    or a
    jr nz, .uft_noLock

    ; === LOCK THE PIECE ===
    ld a, 5
    call _IncreaseScore

    call _SetCurrentPieceInBackground

    call _BlinkFullRows

    call _ShiftAllTilesDown

    ; Hide the piece sprites
    ld a, [_currentTetromino]
    sla a
    sla a
    ld b, a
    ld a, [_currentTetrominoRotation]
    add b
    ld c, a
    ld b, 0
    ld hl, _Tetrominos_metasprites
    add hl, bc
    add hl, bc
    ld a, [hli]
    ld h, [hl]
    ld l, a
    xor a
    call hide_metasprite

    ; Mark "no active piece"
    ld a, 255
    ld [_currentTetromino], a

.uft_noLock:
    ret

; -----------------------------------------------------------------------------
; HandleInput - Process joypad input                        | clobbers: all
;
; Reads joypad state, handles:
;   - D-pad down: accelerate fall
;   - A button: rotate with wall kicks (try center, +1, -1)
;   - Left/Right: move piece laterally
; -----------------------------------------------------------------------------
_HandleInput::
    ; joypadPrevious = joypadCurrent
    ld a, [_joypadCurrent]
    ld [_joypadPrevious], a

    ; joypadCurrent = joypad()
    call joypad
    ld [_joypadCurrent], a

    ; if (joypadCurrent & J_DOWN) fallTimer += 5
    ld a, [_joypadCurrent]
    and J_DOWN
    jr z, .hi_noDown
    ld a, [_fallTimer]
    add 5
    ld [_fallTimer], a
.hi_noDown:

    ; --- A button: rotation with wall kicks ---
    ; if ((joypadCurrent & J_A) && !(joypadPrevious & J_A))
    ld a, [_joypadCurrent]
    and J_A
    jp z, .hi_noA
    ld a, [_joypadPrevious]
    and J_A
    jp nz, .hi_noA

    ; Compute nextRot = (currentTetrominoRotation + 1) & 3
    ld a, [_currentTetrominoRotation]
    inc a
    and 3
    ld [_hiNextRot], a

    ; Try 1: CanPieceBePlacedHere(piece, nextRot, currentX, currentY)
    ld a, [_currentTetromino]
    ld b, a
    ld a, [_hiNextRot]
    ld c, a
    ld a, [_currentX]
    ld d, a
    ld a, [_currentY]
    ld e, a
    call _CanPieceBePlacedHere
    or a
    jr z, .hi_tryRight

    ; Success: apply rotation
    ld a, [_hiNextRot]
    ld [_currentTetrominoRotation], a
    ld a, 30
    ld [_lockDelay], a
    jr .hi_noA

.hi_tryRight:
    ; Try 2: CanPieceBePlacedHere(piece, nextRot, currentX+1, currentY)
    ld a, [_currentTetromino]
    ld b, a
    ld a, [_hiNextRot]
    ld c, a
    ld a, [_currentX]
    inc a
    ld d, a
    ld a, [_currentY]
    ld e, a
    call _CanPieceBePlacedHere
    or a
    jr z, .hi_tryLeft

    ; Success: apply rotation and move right
    ld a, [_hiNextRot]
    ld [_currentTetrominoRotation], a
    ld a, [_currentX]
    inc a
    ld [_currentX], a
    ld a, 30
    ld [_lockDelay], a
    jr .hi_noA

.hi_tryLeft:
    ; Try 3: CanPieceBePlacedHere(piece, nextRot, currentX-1, currentY)
    ld a, [_currentTetromino]
    ld b, a
    ld a, [_hiNextRot]
    ld c, a
    ld a, [_currentX]
    dec a
    ld d, a
    ld a, [_currentY]
    ld e, a
    call _CanPieceBePlacedHere
    or a
    jr z, .hi_noA

    ; Success: apply rotation and move left
    ld a, [_hiNextRot]
    ld [_currentTetrominoRotation], a
    ld a, [_currentX]
    dec a
    ld [_currentX], a
    ld a, 30
    ld [_lockDelay], a

.hi_noA:

    ; --- Left button with DAS ---
    ld a, [_joypadCurrent]
    and J_LEFT
    jr z, .hi_noLeft

    ld a, [_joypadPrevious]
    and J_LEFT
    jr nz, .hi_leftHeld

    ; Fresh press: set DAS delay and try to move
    ld a, DAS_DELAY
    ld [_dasTimer], a
    jr .hi_tryMoveLeft

.hi_leftHeld:
    ; Held: decrement DAS timer, move only if expired
    ld a, [_dasTimer]
    dec a
    ld [_dasTimer], a
    jr nz, .hi_noLeft

    ; Timer expired: set repeat rate and try to move
    ld a, DAS_REPEAT
    ld [_dasTimer], a

.hi_tryMoveLeft:
    ; CanPieceBePlacedHere(piece, rotation, currentX-1, currentY)
    ld a, [_currentTetromino]
    ld b, a
    ld a, [_currentTetrominoRotation]
    ld c, a
    ld a, [_currentX]
    dec a
    ld d, a
    ld a, [_currentY]
    ld e, a
    call _CanPieceBePlacedHere
    or a
    jr z, .hi_noLeft

    ld a, [_currentX]
    dec a
    ld [_currentX], a
    ld a, 30
    ld [_lockDelay], a

.hi_noLeft:

    ; --- Right button with DAS ---
    ld a, [_joypadCurrent]
    and J_RIGHT
    jr z, .hi_noRight

    ld a, [_joypadPrevious]
    and J_RIGHT
    jr nz, .hi_rightHeld

    ; Fresh press: set DAS delay and try to move
    ld a, DAS_DELAY
    ld [_dasTimer], a
    jr .hi_tryMoveRight

.hi_rightHeld:
    ; Held: decrement DAS timer, move only if expired
    ld a, [_dasTimer]
    dec a
    ld [_dasTimer], a
    jr nz, .hi_noRight

    ; Timer expired: set repeat rate and try to move
    ld a, DAS_REPEAT
    ld [_dasTimer], a

.hi_tryMoveRight:
    ; CanPieceBePlacedHere(piece, rotation, currentX+1, currentY)
    ld a, [_currentTetromino]
    ld b, a
    ld a, [_currentTetrominoRotation]
    ld c, a
    ld a, [_currentX]
    inc a
    ld d, a
    ld a, [_currentY]
    ld e, a
    call _CanPieceBePlacedHere
    or a
    jr z, .hi_noRight

    ld a, [_currentX]
    inc a
    ld [_currentX], a
    ld a, 30
    ld [_lockDelay], a

.hi_noRight:
    ret

; -----------------------------------------------------------------------------
; SetupVRAM - Load all tile data into VRAM                  | clobbers: all
;
; Loads sprite tiles for all 7 tetrominoes, background tiles for the UI,
; tile animation frames, number font, and CGB palettes.
; -----------------------------------------------------------------------------
_SetupVRAM::
    ; --- Sprite tile data for all pieces (auto-generated) ---
    INCLUDE "setup_sprites.inc"

    ; --- Background tile data ---

    ; set_bkg_data(USERINTERFACE_TILE_START, UserInterface_TILE_COUNT, UserInterface_tiles)
    ld a, USERINTERFACE_TILE_START
    ld b, UserInterface_TILE_COUNT
    ld hl, UserInterface_tiles
    call set_bkg_data

    ; set_bkg_data(TILEANIMATION_TILE1_VRAM, 1, TileAnimation_tiles)
    ld a, TILEANIMATION_TILE1_VRAM
    ld b, 1
    ld hl, TileAnimation_tiles
    call set_bkg_data

    ; set_bkg_data(TILEANIMATION_TILE2_VRAM, 1, TileAnimation_tiles + 128)
    ld a, TILEANIMATION_TILE2_VRAM
    ld b, 1
    ld hl, TileAnimation_tiles + 128
    call set_bkg_data

    ; set_bkg_data(NUMBERS_TILES_START, Numbers_TILE_COUNT, Numbers_tiles)
    ld a, NUMBERS_TILES_START
    ld b, Numbers_TILE_COUNT
    ld hl, Numbers_tiles
    call set_bkg_data

    ; --- CGB palettes ---

    ; set_bkg_palette(0, 8, Palette_palettes)
    xor a
    ld b, 8
    ld hl, Palette_palettes
    call set_bkg_palette

    ; set_sprite_palette(0, 8, Palette_palettes)
    xor a
    ld b, 8
    ld hl, Palette_palettes
    call set_sprite_palette

    ret

; -----------------------------------------------------------------------------
; SetupGameplay - Initialize game state for a new round     | clobbers: all
;
; Clears the play area (both BG and window layers, tiles and attributes),
; resets sprites, randomizes next piece, picks first piece, zeroes counters,
; and redraws the HUD.
; -----------------------------------------------------------------------------
_SetupGameplay::
    ; VBK=1: fill_win_rect(0, 0, 31, 31, blankTilePalette)
    ld a, 1
    ldh [rVBK], a
    ld b, 0
    ld c, 0
    ld d, 31
    ld e, 31
    ld a, [_blankTilePalette]
    call fill_win_rect

    ; VBK=0: fill_win_rect(0, 0, 31, 31, blankTile)
    xor a
    ldh [rVBK], a
    ld b, 0
    ld c, 0
    ld d, 31
    ld e, 31
    ld a, [_blankTile]
    call fill_win_rect

    ; VBK=1: fill_bkg_rect(2, 0, 10, 18, blankTilePalette)
    ld a, 1
    ldh [rVBK], a
    ld b, 2
    ld c, 0
    ld d, 10
    ld e, 18
    ld a, [_blankTilePalette]
    call fill_bkg_rect

    ; VBK=0: fill_bkg_rect(2, 0, 10, 18, blankTile)
    xor a
    ldh [rVBK], a
    ld b, 2
    ld c, 0
    ld d, 10
    ld e, 18
    ld a, [_blankTile]
    call fill_bkg_rect

    ; ResetAllSprites()
    call _ResetAllSprites

    ; nextCurrentTetromino = RandomNumber(0, PIECE_COUNT)
    ld b, 0
    ld c, PIECE_COUNT
    call _RandomNumber
    ld [_nextCurrentTetromino], a

    ; nextCurrentTetrominoRotation = RandomNumber(0, 4)
    ld b, 0
    ld c, 4
    call _RandomNumber
    ld [_nextCurrentTetrominoRotation], a

    ; PickNewTetromino()
    call _PickNewTetromino

    ; fallTimer = 0, lockDelay = 0, dasTimer = 0
    xor a
    ld [_fallTimer], a
    ld [_lockDelay], a
    ld [_dasTimer], a

    ; lines = 0
    xor a
    ld [_lines], a
    ld [_lines + 1], a

    ; level = 1
    ld a, 1
    ld [_level], a

    ; score = 0
    xor a
    ld [_score], a
    ld [_score + 1], a

    ; UpdateGui()
    call _UpdateGui

    ret
