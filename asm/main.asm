; =============================================================================
; main.asm - Main game loop and entry point
; Ported from: source/main/main.c
; =============================================================================

INCLUDE "common.inc"
INCLUDE "hud.inc"
INCLUDE "UserInterface.inc"
INCLUDE "board.inc"
INCLUDE "Tetrominos.inc"

; External symbols (resolved by linker):
;   _tetris_music - from tetris_music.asm
;   hUGE_init - from hUGEDriver.asm (no underscore - not GBDK build)
;   _HandleInput, _SetupVRAM, _SetupGameplay - from gameplay.asm

; =============================================================================
; Main entry point
; =============================================================================
; Called from Init in header.asm after hardware setup.
;
; Original C:
; void main(void)
; {
;     DISPLAY_ON;
;     SHOW_BKG;
;     SHOW_SPRITES;
;
;     SetupVRAM();
;     SetupUserInterface();
;
;     NR52_REG = 0x80;
;     NR51_REG = 0xFF;
;     NR50_REG = 0x77;
;
;     __critical {
;         hUGE_init(&tetris_music);
;         add_VBL(hUGE_dosound);
;     }
;
;     GameplayStart:
;     SetupGameplay();
;
;     while (1)
;     {
;         if(currentTetromino==255){
;             uint8_t canSpawnNewShape = PickNewTetromino();
;             if(!canSpawnNewShape){
;                 goto GameplayStart;
;             }else{
;                 UpdateGui();
;             }
;         }
;
;         AnimateBackground();
;         fallTimer++;
;
;         if (fallTimer >= 30)
;         {
;             if(!CanPieceBePlacedHere(currentTetromino,currentTetrominoRotation,currentX,currentY+1)){
;                 IncreaseScore(5);
;                 SetCurrentPieceInBackground();
;                 BlinkFullRows();
;                 ShiftAllTilesDown();
;                 hide_metasprite(Tetrominos_metasprites[currentTetromino*4+currentTetrominoRotation],0);
;                 currentTetromino=255;
;             }else{
;                 currentY++;
;                 fallTimer = 0;
;             }
;         }
;
;         if(currentTetromino!=255){
;             HandleInput();
;             move_metasprite(Tetrominos_metasprites[currentTetromino*4+currentTetrominoRotation],tileOffsets[currentTetromino],0,currentX*8,currentY*8);
;         }
;
;         wait_vbl_done();
;     }
; }

SECTION "MainCode", ROM0

_main::
    ; Disable interrupts during all setup - VBlank ISR calls hUGE_dosound
    ; which must not run before hUGE_init, and VRAM writes must not be
    ; interrupted to avoid mode 3 corruption.
    di

    ; --- Setup VRAM and UI with LCD OFF ---
    ; BCPD/OCPD palette writes and VRAM tile/tilemap writes are only safe
    ; during HBlank/VBlank or when the LCD is off. Doing all setup with LCD
    ; off avoids mode 3 corruption (which causes palette mismatches between
    ; BG and sprite palettes, making pieces change color on landing).
    call _SetupVRAM
    call _SetupUserInterface

    ; --- Turn on display AFTER all VRAM/palette writes are done ---
    DISPLAY_ON

    ; --- Enable audio ---
    ; NR52_REG = 0x80;  (enable sound)
    ld a, $80
    ldh [rNR52], a
    ; NR51_REG = 0xFF;  (all channels to both terminals)
    ld a, $FF
    ldh [rNR51], a
    ; NR50_REG = 0x77;  (max volume both terminals)
    ld a, $77
    ldh [rNR50], a

    ; --- Initialize music ---
    ; __critical { hUGE_init(&tetris_music); }
    ld hl, _tetris_music
    call hUGE_init

    ; All setup done - enable interrupts
    ei

.GameplayStart:
    ; Restart the music from the beginning on each new game
    di
    ld hl, _tetris_music
    call hUGE_init
    ei

    ; SetupGameplay();
    call _SetupGameplay

    ; --- Main game loop ---
.mainLoop:

    ; if(currentTetromino==255)
    ld a, [_currentTetromino]
    cp 255
    jr nz, .hasTetromino

    ; uint8_t canSpawnNewShape = PickNewTetromino();
    call _PickNewTetromino
    or a
    ; if(!canSpawnNewShape) goto GameplayStart;
    jr z, .GameplayStart
    ; else UpdateGui();
    call _UpdateGui

.hasTetromino:

    ; AnimateBackground();
    call _AnimateBackground

    ; --- Handle input BEFORE fall logic (allows last-moment moves) ---
    ld a, [_currentTetromino]
    cp 255
    jr z, .skipInput

    ; HandleInput();
    call _HandleInput

    ; move_metasprite(Tetrominos_metasprites[...], tileOffsets[...], 0, currentX*8, currentY*8)
    ld a, [_currentTetromino]
    sla a
    sla a
    ld b, a
    ld a, [_currentTetrominoRotation]
    add b                           ; A = piece*4 + rotation
    ld c, a
    ld b, 0
    ld hl, _Tetrominos_metasprites
    add hl, bc
    add hl, bc                      ; HL = &metasprites[index]
    ld a, [hli]
    ld h, [hl]
    ld l, a                         ; HL = metasprite pointer
    push hl                         ; save metasprite ptr

    ; Get base_tile = tileOffsets[currentTetromino]
    ld a, [_currentTetromino]
    ld c, a
    ld b, 0
    ld hl, _tileOffsets
    add hl, bc
    ld a, [hl]                      ; A = base_tile
    push af                         ; save base_tile

    ; D = currentX * 8, E = currentY * 8
    ld a, [_currentX]
    sla a
    sla a
    sla a
    ld d, a
    ld a, [_currentY]
    sla a
    sla a
    sla a
    ld e, a

    pop af                          ; A = base_tile
    ld b, 0                         ; base_sprite = 0
    pop hl                          ; HL = metasprite ptr
    call move_metasprite

.skipInput:

    ; --- Fall timer, gravity, and piece locking ---
    call _UpdateFallTimer

.noLock:

    ; wait_vbl_done();
    call wait_vbl_done

    ; Trigger OAM DMA to copy shadow OAM to hardware OAM
    call run_dma

    jp .mainLoop

; HandleInput, SetupVRAM, SetupGameplay are in gameplay.asm
