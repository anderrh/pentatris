; =============================================================================
; header.asm - ROM header, interrupt vectors, and boot code
; =============================================================================
; Game Boy ROM header with interrupt vectors, Nintendo logo, and
; initialization code. Sets up OAM DMA, clears shadow OAM, enables
; VBlank interrupt, then jumps to _main.
; =============================================================================

INCLUDE "runtime.inc"

; External symbols (resolved by linker):
;   _main - from main.asm
;   _hUGE_dosound - from hUGEDriver.asm

; =============================================================================
; Interrupt Vectors ($0000-$0067)
; =============================================================================

SECTION "RST $00", ROM0[$0000]
    ret

SECTION "RST $08", ROM0[$0008]
    ret

SECTION "RST $10", ROM0[$0010]
    ret

SECTION "RST $18", ROM0[$0018]
    ret

SECTION "RST $20", ROM0[$0020]
    ret

SECTION "RST $28", ROM0[$0028]
    ret

SECTION "RST $30", ROM0[$0030]
    ret

SECTION "RST $38", ROM0[$0038]
    ret

; -----------------------------------------------------------------------------
; VBlank interrupt handler ($0040)
; Only 8 bytes available before the next vector at $0048, so jump to the
; full handler in the Init section.
; -----------------------------------------------------------------------------
SECTION "VBlank ISR", ROM0[$0040]
    jp VBlankHandler

; -----------------------------------------------------------------------------
; STAT interrupt handler ($0048)
; -----------------------------------------------------------------------------
SECTION "STAT ISR", ROM0[$0048]
    reti

; -----------------------------------------------------------------------------
; Timer interrupt handler ($0050)
; -----------------------------------------------------------------------------
SECTION "Timer ISR", ROM0[$0050]
    reti

; -----------------------------------------------------------------------------
; Serial interrupt handler ($0058)
; -----------------------------------------------------------------------------
SECTION "Serial ISR", ROM0[$0058]
    reti

; -----------------------------------------------------------------------------
; Joypad interrupt handler ($0060)
; -----------------------------------------------------------------------------
SECTION "Joypad ISR", ROM0[$0060]
    reti

; =============================================================================
; ROM Header ($0100-$014F)
; =============================================================================

SECTION "Header", ROM0[$0100]
    nop
    jp Init

    ; Nintendo logo - required for boot ROM validation
    NINTENDO_LOGO

    ; Title and other header fields are filled by rgbfix
    DS $0150 - @, 0

; =============================================================================
; Initialization Code
; =============================================================================

SECTION "Init", ROM0

Init:
    ; Disable interrupts during setup
    di

    ; Set stack pointer
    ld sp, $FFFE

    ; Wait for VBlank before turning off LCD
    ; (turning off LCD outside VBlank can damage DMG hardware)
.waitVBlank:
    ldh a, [rLY]
    cp 144
    jr c, .waitVBlank

    ; Turn off the LCD
    xor a
    ldh [rLCDC], a

    ; Copy OAM DMA routine to HRAM
    ld hl, OAMDMA_Routine
    ld de, hOAMDMA
    ld bc, OAMDMA_Routine.end - OAMDMA_Routine
.copyDMA:
    ld a, [hli]
    ld [de], a
    inc de
    dec bc
    ld a, b
    or c
    jr nz, .copyDMA

    ; Clear shadow OAM buffer (160 bytes = 40 sprites x 4 bytes)
    ld hl, wShadowOAM
    ld bc, OAM_COUNT * sizeof_OAM_ATTRS
    xor a
.clearOAM:
    ld [hli], a
    dec bc
    ld a, b
    or c
    jr nz, .clearOAM

    ; Enable VBlank interrupt
    ld a, IEF_VBLANK
    ldh [rIE], a

    ; Clear any pending interrupt flags
    xor a
    ldh [rIF], a

    ; Enable interrupts
    ei

    ; Jump to main game code
    jp _main

; =============================================================================
; VBlank Handler (full handler, jumped to from the VBlank vector)
; =============================================================================
; Sets the VBlank flag so wait_vbl_done knows a frame has passed,
; then calls hUGE_dosound to tick the music engine.

VBlankHandler:
    push af
    push hl
    push de
    push bc

    ld a, 1
    ld [wVBlankFlag], a

    call _hUGE_dosound

    pop bc
    pop de
    pop hl
    pop af
    reti

; =============================================================================
; OAM DMA Routine (copied to HRAM at runtime)
; =============================================================================
; This routine is 10 bytes and gets copied to HRAM.
; It triggers a DMA transfer from the shadow OAM buffer in WRAM to OAM RAM.
; During DMA (160 cycles), only HRAM is accessible, so this must run from HRAM.

OAMDMA_Routine:
    ld a, HIGH(wShadowOAM)
    ldh [rDMA], a
    ld a, 40                    ; Wait 160 cycles (40 iterations x 4 cycles)
.wait:
    dec a
    jr nz, .wait
    ret
.end:

; =============================================================================
; WRAM - Working RAM variables
; =============================================================================

SECTION "VBlank Flag", WRAM0
wVBlankFlag:: DS 1              ; Set to 1 by VBlank ISR, cleared by wait_vbl_done

SECTION "Shadow OAM", WRAM0, ALIGN[8]
wShadowOAM:: DS OAM_COUNT * sizeof_OAM_ATTRS   ; 160 bytes, 256-byte aligned

; =============================================================================
; HRAM - High RAM
; =============================================================================

SECTION "OAM DMA HRAM", HRAM
hOAMDMA:: DS 10                 ; OAM DMA routine copied here at init
