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
    ld a, b
    ld [_irfRow], a                 ; row
    ld a, c
    ld [_irfBoth], a                ; both_flag
    xor a
    ld [_irfI], a                   ; i = 0

.irf_loop:
    ; get_bkg_tile_xy(2+i, row)
    ld a, [_irfI]
    add 2
    ld b, a
    ld a, [_irfRow]
    ld c, a
    call get_bkg_tile_xy            ; A = bkg tile

    ; Compare with blankTile
    ld d, a
    ld a, [_blankTile]
    cp d
    jr nz, .irf_notBlank            ; bkg tile is filled

    ; BKG tile IS blank. Check both_flag.
    ld a, [_irfBoth]
    or a
    jr z, .irf_returnZero           ; both=FALSE, blank bkg → not full

    ; both=TRUE: also check window tile
    ld a, [_irfI]
    add 2
    ld b, a
    ld a, [_irfRow]
    ld c, a
    call get_win_tile_xy            ; A = win tile
    ld d, a
    ld a, [_blankTile]
    cp d
    jr nz, .irf_notBlank            ; win tile filled → cell is OK

    ; Both bkg AND win are blank → return 0
.irf_returnZero:
    xor a
    ret

.irf_notBlank:
    ld a, [_irfI]
    inc a
    ld [_irfI], a
    cp 10
    jr c, .irf_loop

    ; All 10 columns filled → row is full
    ld a, 1
    ret

; ----------------------------------------------------------------------------
; _ShiftAllTilesAboveThisRowDown: B=row                    | clobbers: all
;
; Clears the target row, then shifts every row above it down by one.
; Handles both tile data (VBK=0) and attributes (VBK=1).
; ----------------------------------------------------------------------------
_ShiftAllTilesAboveThisRowDown::
    ld a, b
    ld [_boardLoopJ], a             ; save target row

    ; VBK=1: fill_bkg_rect(2, j, 10, 1, blankTilePalette)
    ld a, 1
    ldh [rVBK], a
    ld a, [_boardLoopJ]
    ld c, a
    ld b, 2
    ld d, 10
    ld e, 1
    ld a, [_blankTilePalette]
    call fill_bkg_rect

    ; VBK=0: fill_bkg_rect(2, j, 10, 1, blankTile)
    xor a
    ldh [rVBK], a
    ld a, [_boardLoopJ]
    ld c, a
    ld b, 2
    ld d, 10
    ld e, 1
    ld a, [_blankTile]
    call fill_bkg_rect

    ; j2 = j - 1
    ld a, [_boardLoopJ]
    dec a
    ld [_boardLoopI], a

.satd_loop:
    ld a, [_boardLoopI]
    cp 255
    ret z                           ; j2 wrapped past 0 → done

    ; VBK=1: get row j2 attributes, set into row j2+1
    ld a, 1
    ldh [rVBK], a
    ld b, 2
    ld a, [_boardLoopI]
    ld c, a
    ld d, 10
    ld e, 1
    ld hl, _reusableRow10
    call get_bkg_tiles

    ld a, 1
    ldh [rVBK], a
    ld b, 2
    ld a, [_boardLoopI]
    inc a
    ld c, a
    ld d, 10
    ld e, 1
    ld hl, _reusableRow10
    call set_bkg_tiles

    ; VBK=0: get row j2 tiles, set into row j2+1
    xor a
    ldh [rVBK], a
    ld b, 2
    ld a, [_boardLoopI]
    ld c, a
    ld d, 10
    ld e, 1
    ld hl, _reusableRow10
    call get_bkg_tiles

    xor a
    ldh [rVBK], a
    ld b, 2
    ld a, [_boardLoopI]
    inc a
    ld c, a
    ld d, 10
    ld e, 1
    ld hl, _reusableRow10
    call set_bkg_tiles

    ; j2--
    ld a, [_boardLoopI]
    dec a
    ld [_boardLoopI], a
    jr .satd_loop

; ----------------------------------------------------------------------------
; _ShiftAllTilesDown: (none)                               | clobbers: all
;
; Scans rows 17 down to 0. While a row is full, shifts all rows above it down.
; ----------------------------------------------------------------------------
_ShiftAllTilesDown::
    ld a, 17
    ld [_boardLoopJ], a

.std_outerLoop:
    ld a, [_boardLoopJ]
    cp 255
    ret z

.std_whileLoop:
    ld a, [_boardLoopJ]
    ld b, a
    ld c, 0                         ; both_flag = FALSE
    call _IsRowFull
    or a
    jr z, .std_nextJ

    ld a, [_boardLoopJ]
    ld b, a
    call _ShiftAllTilesAboveThisRowDown
    jr .std_whileLoop

.std_nextJ:
    ld a, [_boardLoopJ]
    dec a
    ld [_boardLoopJ], a
    jr .std_outerLoop

; ----------------------------------------------------------------------------
; _BlinkFullRows: (none)                                   | clobbers: all
;
; Detects full rows, scores them, then plays a blink animation before clearing.
; Uses the window layer as a backup for the original row tiles during blinking.
; ----------------------------------------------------------------------------
_BlinkFullRows::
    ; isBlinking = FALSE
    xor a
    ld [_isBlinking], a

    ; Hide first 16 sprites
    xor a
.bfr_hideLoop:
    push af
    ld b, 160
    ld c, 160
    call move_sprite
    pop af
    inc a
    cp 16
    jr c, .bfr_hideLoop

    ; --- Phase 1: Scan for full rows, copy to window, score ---
    ld a, 17
.bfr_scanLoop:
    ld [_boardLoopJ], a

    ld b, a
    ld c, 0                         ; both_flag = FALSE
    call _IsRowFull
    or a
    jr z, .bfr_scanNext

    ; Row is full
    ld a, TRUE
    ld [_isBlinking], a

    ; lines++ (16-bit)
    ld a, [_lines]
    add 1
    ld [_lines], a
    ld a, [_lines + 1]
    adc 0
    ld [_lines + 1], a

    ; IncreaseScore(100)
    ld a, 100
    call _IncreaseScore

    ; Copy row to window layer (attributes)
    ld a, 1
    ldh [rVBK], a
    ld b, 2
    ld a, [_boardLoopJ]
    ld c, a
    ld d, 10
    ld e, 1
    ld hl, _reusableRow10
    call get_bkg_tiles
    ld a, 1
    ldh [rVBK], a
    ld b, 2
    ld a, [_boardLoopJ]
    ld c, a
    ld d, 10
    ld e, 1
    ld hl, _reusableRow10
    call set_win_tiles

    ; Copy row to window layer (tiles)
    xor a
    ldh [rVBK], a
    ld b, 2
    ld a, [_boardLoopJ]
    ld c, a
    ld d, 10
    ld e, 1
    ld hl, _reusableRow10
    call get_bkg_tiles
    xor a
    ldh [rVBK], a
    ld b, 2
    ld a, [_boardLoopJ]
    ld c, a
    ld d, 10
    ld e, 1
    ld hl, _reusableRow10
    call set_win_tiles

.bfr_scanNext:
    ld a, [_boardLoopJ]
    dec a
    cp 255
    jr nz, .bfr_scanLoop

    ; --- Phase 2: Blink animation ---
    ld a, [_isBlinking]
    or a
    jp z, .bfr_done

    ; for k = 0 to 7
    xor a
    ld [_boardLoopK], a

.bfr_blinkOuter:
    ; for j = 17 down to 0
    ld a, 17
.bfr_blinkInner:
    ld [_boardLoopJ], a

    ld b, a
    ld c, 1                         ; both_flag = TRUE
    call _IsRowFull
    or a
    jr z, .bfr_blinkNextJ

    ; k % 2 == 0?
    ld a, [_boardLoopK]
    and 1
    jr nz, .bfr_blinkOdd

    ; Even k: blank out the row
    ld a, 1
    ldh [rVBK], a
    ld b, 2
    ld a, [_boardLoopJ]
    ld c, a
    ld d, 10
    ld e, 1
    ld a, [_blankTilePalette]
    call fill_bkg_rect
    xor a
    ldh [rVBK], a
    ld b, 2
    ld a, [_boardLoopJ]
    ld c, a
    ld d, 10
    ld e, 1
    ld a, [_blankTile]
    call fill_bkg_rect
    jr .bfr_blinkNextJ

.bfr_blinkOdd:
    ; Odd k: restore from window
    ld a, 1
    ldh [rVBK], a
    ld b, 2
    ld a, [_boardLoopJ]
    ld c, a
    ld d, 10
    ld e, 1
    ld hl, _reusableRow10
    call get_win_tiles
    ld a, 1
    ldh [rVBK], a
    ld b, 2
    ld a, [_boardLoopJ]
    ld c, a
    ld d, 10
    ld e, 1
    ld hl, _reusableRow10
    call set_bkg_tiles
    xor a
    ldh [rVBK], a
    ld b, 2
    ld a, [_boardLoopJ]
    ld c, a
    ld d, 10
    ld e, 1
    ld hl, _reusableRow10
    call get_win_tiles
    xor a
    ldh [rVBK], a
    ld b, 2
    ld a, [_boardLoopJ]
    ld c, a
    ld d, 10
    ld e, 1
    ld hl, _reusableRow10
    call set_bkg_tiles

.bfr_blinkNextJ:
    ld a, [_boardLoopJ]
    dec a
    cp 255
    jp nz, .bfr_blinkInner

    ; Delay: 20 frames of animation
    ld a, 20
    ld [_boardLoopI], a
.bfr_delayLoop:
    call _AnimateBackground
    call wait_vbl_done
    ld a, [_boardLoopI]
    dec a
    ld [_boardLoopI], a
    jr nz, .bfr_delayLoop

    ; k++
    ld a, [_boardLoopK]
    inc a
    ld [_boardLoopK], a
    cp 8
    jp c, .bfr_blinkOuter

    ; Clear entire window layer
    ld a, 1
    ldh [rVBK], a
    ld a, [_blankTilePalette]
    ld b, 0
    ld c, 0
    ld d, 31
    ld e, 31
    call fill_win_rect
    xor a
    ldh [rVBK], a
    ld a, [_blankTile]
    ld b, 0
    ld c, 0
    ld d, 31
    ld e, 31
    call fill_win_rect

.bfr_done:
    ret

; ----------------------------------------------------------------------------
; _SetCurrentPieceInBackground: (none)                     | clobbers: all
;
; Reads the current piece's metasprite data and writes the piece tiles into
; the background tile map at the piece's current position.
; ----------------------------------------------------------------------------
_SetCurrentPieceInBackground::
    ; Compute metasprite index = currentTetromino * 4 + currentTetrominoRotation
    ld a, [_currentTetromino]
    ld [_boardLoopK], a             ; save piece index for tileOffsets
    sla a
    sla a
    ld c, a
    ld a, [_currentTetrominoRotation]
    add c                           ; A = piece*4 + rotation

    ; Look up metasprite pointer
    ld c, a
    ld b, 0
    ld hl, _Tetrominos_metasprites
    add hl, bc
    add hl, bc
    ld a, [hli]
    ld [_boardMetaL], a
    ld a, [hl]
    ld [_boardMetaH], a

    ; Look up tileOffsets[currentTetromino]
    ld a, [_boardLoopK]
    ld c, a
    ld b, 0
    ld hl, _tileOffsets
    add hl, bc
    ld a, [hl]
    ld [_boardBaseTile], a

    ; Initialize position
    ld a, [_currentX]
    ld [_boardFinalCol], a
    ld a, [_currentY]
    ld [_boardFinalRow], a

.scpib_loop:
    ; Load metasprite pointer into HL
    ld a, [_boardMetaH]
    ld h, a
    ld a, [_boardMetaL]
    ld l, a

    ; Read dy / check sentinel
    ld a, [hl]
    cp $80                          ; METASPRITE_END sentinel?
    ret z
    inc hl                          ; advance past dy (A has the value)
    sra a
    sra a
    sra a
    ld b, a
    ld a, [_boardFinalRow]
    add b
    ld [_boardFinalRow], a

    ; Read dx, update finalCol
    ld a, [hli]
    sra a
    sra a
    sra a
    ld b, a
    ld a, [_boardFinalCol]
    add b
    ld [_boardFinalCol], a

    ; Read dtile
    ld a, [hli]
    push af                         ; save dtile

    ; Read props
    ld a, [hli]
    push af                         ; save props

    ; Save updated metasprite pointer
    ld a, l
    ld [_boardMetaL], a
    ld a, h
    ld [_boardMetaH], a

    ; VBK=1: set_bkg_tile_xy(finalColumn-1, finalRow-2, props)
    ld a, 1
    ldh [rVBK], a
    ld a, [_boardFinalCol]
    dec a
    ld b, a                         ; B = finalColumn - 1
    ld a, [_boardFinalRow]
    sub 2
    ld c, a                         ; C = finalRow - 2
    pop af                          ; A = props
    ld d, a                         ; D = props
    call set_bkg_tile_xy

    ; VBK=0: set_bkg_tile_xy(finalColumn-1, finalRow-2, dtile + baseTile)
    xor a
    ldh [rVBK], a
    ld a, [_boardFinalCol]
    dec a
    ld b, a                         ; B = finalColumn - 1
    ld a, [_boardFinalRow]
    sub 2
    ld c, a                         ; C = finalRow - 2
    pop af                          ; A = dtile
    ld d, a
    ld a, [_boardBaseTile]
    add d
    ld d, a                         ; D = dtile + baseTile
    call set_bkg_tile_xy

    jr .scpib_loop
