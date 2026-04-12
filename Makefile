# =============================================================================
# Tetris Game Boy - RGBDS Assembly Build System
# =============================================================================
# Builds a Game Boy ROM from RGBDS assembly sources.
# Supports incremental module-by-module porting from the original GBDK/C version.
#
# Usage:
#   make            - build dist/Tetris.gb (full ROM)
#   make gfx        - generate all graphics data from PNGs
#   make test       - build all test ROMs
#   make test_common - build + run test for common module
#   make clean      - remove build artifacts
# =============================================================================

# Tools
RGBASM  := rgbasm
RGBLINK := rgblink
RGBFIX  := rgbfix
RGBGFX  := rgbgfx
PNG2ASSET := /opt/gbdk/bin/png2asset
PYTHON3 := python3
NODE    := node

# Directories
ASM_DIR   := asm
INC_DIR   := inc
GFX_DIR   := gfx
GEN_DIR   := gfx/gen
BIN_DIR   := bin
DIST_DIR  := dist
TEST_DIR  := tests
SRC_DIR   := source/asm
TEST_RUNNER := $(TEST_DIR)/run_tests.js

# Include paths for our code (gfx/ for generated sprite_defs.inc etc.)
INCLUDES := -I $(INC_DIR)/ -I $(GFX_DIR)/ -I lib/hUGEDriver/

# Special include path for hUGEDriver (needs source/asm/ so "include/..." resolves via symlink)
HUGE_INCLUDES := -I $(SRC_DIR)/

# ROM metadata
ROM_TITLE := TETRIS
ROM_TYPE  := -C

# =============================================================================
# Source file lists
# =============================================================================

# All assembly source files for the main ROM
ASM_SRCS := $(wildcard $(ASM_DIR)/*.asm)
HUGE_SRC := $(SRC_DIR)/hUGEDriver.asm

# Object files
ASM_OBJS := $(patsubst $(ASM_DIR)/%.asm,$(BIN_DIR)/%.o,$(ASM_SRCS))
HUGE_OBJ := $(BIN_DIR)/hUGEDriver.o

ALL_OBJS := $(ASM_OBJS) $(HUGE_OBJ)

# Test sources and ROMs
TEST_SRCS := $(wildcard $(TEST_DIR)/test_*.asm)
TEST_ROMS := $(patsubst $(TEST_DIR)/test_%.asm,$(DIST_DIR)/test_%.gb,$(TEST_SRCS))

# =============================================================================
# Graphics assets
# =============================================================================

# Piece selection: PENTO=1 includes pentominoes
PENTO ?= 0
ifeq ($(PENTO),1)
SPRITE_PNGS := $(wildcard Graphics/Tetromino[1-7].png) $(wildcard Graphics/Pentomino*.png)
else
SPRITE_PNGS := $(wildcard Graphics/Tetromino[1-7].png)
endif

# png2asset intermediate C files
TETROMINO_C  := $(patsubst Graphics/%.png,$(GEN_DIR)/%.c,$(filter Graphics/Tetromino%.png,$(SPRITE_PNGS)))
PENTOMINO_C  := $(patsubst Graphics/%.png,$(GEN_DIR)/%.c,$(filter Graphics/Pentomino%.png,$(SPRITE_PNGS)))
ALL_SPRITE_C := $(TETROMINO_C) $(PENTOMINO_C)
PALETTE_C    := $(GEN_DIR)/Palette.c

# Generated assembly include files from png2asm.py
SPRITE_DEFS    := $(GFX_DIR)/sprite_defs.inc
SPRITE_DATA    := $(GFX_DIR)/sprite_data.inc
PALETTE_DATA   := $(GFX_DIR)/palette_data.inc
SETUP_SPRITES  := $(GFX_DIR)/setup_sprites.inc
GEN_INCS       := $(SPRITE_DEFS) $(SPRITE_DATA) $(PALETTE_DATA) $(SETUP_SPRITES)

# Background tiles and tilemaps (still processed by rgbgfx)
BKG_ASSETS := $(GFX_DIR)/UserInterface.2bpp $(GFX_DIR)/UserInterface.tilemap \
              $(GFX_DIR)/UserInterface.attrmap \
              $(GFX_DIR)/TileAnimation.2bpp \
              $(GFX_DIR)/Numbers.2bpp

# All graphics
ALL_GFX := $(GEN_INCS) $(BKG_ASSETS)

# =============================================================================
# Default target
# =============================================================================

.PHONY: all gfx test clean pento

all: $(DIST_DIR)/Tetris.gb

pento:
	$(MAKE) clean
	$(MAKE) PENTO=1 all

# =============================================================================
# Directory creation
# =============================================================================

$(BIN_DIR) $(DIST_DIR):
	mkdir -p $@

# GFX_DIR uses a stamp file to avoid circular deps with gfx/*.2bpp
.gfx_dir_stamp:
	mkdir -p $(GFX_DIR) $(GEN_DIR)
	@touch $@

# Symlink for hUGEDriver includes (it uses include "include/hardware.inc")
$(SRC_DIR)/include:
	ln -sf ../../lib/hUGEDriver $@

# =============================================================================
# Graphics pipeline
# =============================================================================

gfx: $(ALL_GFX)

# --- Sprite data pipeline: PNG → png2asset → C → png2asm.py → ASM includes ---

# Step 1: png2asset converts sprite PNGs to C source files
$(GEN_DIR)/Tetromino%.c $(GEN_DIR)/Tetromino%.h: Graphics/Tetromino%.png | .gfx_dir_stamp
	$(PNG2ASSET) $< -c $@ -px 0 -py 0 -sw 32 -sh 32 -spr8x8 -keep_palette_order -noflip

$(GEN_DIR)/Pentomino%.c $(GEN_DIR)/Pentomino%.h: Graphics/Pentomino%.png | .gfx_dir_stamp
	$(PNG2ASSET) $< -c $@ -px 0 -py 0 -sw 40 -sh 40 -spr8x8 -keep_palette_order -noflip

$(GEN_DIR)/Palette.c $(GEN_DIR)/Palette.h: Graphics/Palette.png | .gfx_dir_stamp
	$(PNG2ASSET) $< -c $@ -map -use_map_attributes -keep_palette_order -noflip

# Step 2: png2asm.py converts C source files to assembly include files
$(GEN_INCS): $(ALL_SPRITE_C) $(PALETTE_C) tools/png2asm.py | .gfx_dir_stamp
	$(PYTHON3) tools/png2asm.py $(ALL_SPRITE_C) $(PALETTE_C)

# --- Background assets ---

# UserInterface background: png2asset (not rgbgfx) to keep palette indices consistent with Palette_palettes
$(GEN_DIR)/UserInterface.c $(GEN_DIR)/UserInterface.h: Graphics/UserInterface.png | .gfx_dir_stamp
	$(PNG2ASSET) $< -c $@ -map -use_map_attributes -keep_palette_order -noflip

$(GFX_DIR)/UserInterface.2bpp $(GFX_DIR)/UserInterface.tilemap $(GFX_DIR)/UserInterface.attrmap: $(GEN_DIR)/UserInterface.c tools/bg2bin.py | .gfx_dir_stamp
	$(PYTHON3) tools/bg2bin.py $< $(GFX_DIR)/UserInterface

# TileAnimation background tiles
$(GFX_DIR)/TileAnimation.2bpp: Graphics/TileAnimation.png | .gfx_dir_stamp
	$(RGBGFX) -o $@ $<

# Number font tiles
$(GFX_DIR)/Numbers.2bpp: Graphics/Numbers.png | .gfx_dir_stamp
	$(RGBGFX) -o $@ $<

# =============================================================================
# Assembly
# =============================================================================

# Game modules (asm/*.asm -> bin/*.o)
$(BIN_DIR)/%.o: $(ASM_DIR)/%.asm | $(BIN_DIR)
	$(RGBASM) $(INCLUDES) -o $@ $<

# All .o files depend on sprite_defs.inc (included transitively via common.inc)
$(ASM_OBJS): $(SPRITE_DEFS)

# Modules that INCBIN/INCLUDE graphics must depend on generated files
$(BIN_DIR)/Tetrominos.o: $(SPRITE_DATA)
$(BIN_DIR)/gameplay.o: $(PALETTE_DATA) $(SETUP_SPRITES)
$(BIN_DIR)/UserInterface.o: $(GFX_DIR)/UserInterface.2bpp $(GFX_DIR)/UserInterface.tilemap $(GFX_DIR)/UserInterface.attrmap $(GFX_DIR)/TileAnimation.2bpp
$(BIN_DIR)/hud.o: $(GFX_DIR)/Numbers.2bpp

# hUGEDriver (special include path)
$(BIN_DIR)/hUGEDriver.o: $(SRC_DIR)/hUGEDriver.asm | $(BIN_DIR) $(SRC_DIR)/include
	$(RGBASM) $(HUGE_INCLUDES) $(INCLUDES) -o $@ $<

# =============================================================================
# Linking
# =============================================================================

$(DIST_DIR)/Tetris.gb: $(ALL_OBJS) | $(DIST_DIR)
	$(RGBLINK) -o $@ -n $(DIST_DIR)/Tetris.sym -m $(DIST_DIR)/Tetris.map $(ALL_OBJS)
	$(RGBFIX) -v -p 0xFF -t "$(ROM_TITLE)" $(ROM_TYPE) $@

# =============================================================================
# Test ROMs
# =============================================================================

test: $(TEST_ROMS)
	$(NODE) $(TEST_RUNNER) $(TEST_ROMS)

# Build individual test ROM
# Each test links: the test itself + the module under test + runtime + header + hUGEDriver
# (header.asm's VBlank handler calls hUGE_dosound, so hUGEDriver is always needed)
$(DIST_DIR)/test_%.gb: $(BIN_DIR)/test_%.o $(BIN_DIR)/%.o $(BIN_DIR)/runtime.o $(BIN_DIR)/header.o $(HUGE_OBJ) | $(DIST_DIR)
	$(RGBLINK) -o $@ $^
	$(RGBFIX) -v -p 0xFF -t "TEST" $(ROM_TYPE) $@

# --- Explicit link rules for tests with non-standard dependencies ---

# test_runtime: no separate module .o (runtime IS the module under test)
$(DIST_DIR)/test_runtime.gb: $(BIN_DIR)/test_runtime.o $(BIN_DIR)/runtime.o $(BIN_DIR)/header.o $(HUGE_OBJ) | $(DIST_DIR)
	$(RGBLINK) -o $@ $^
	$(RGBFIX) -v -p 0xFF -t "TEST" $(ROM_TYPE) $@

# test_hud: hud.asm needs common.o + Tetrominos.o (UpdateGui uses metasprites)
$(DIST_DIR)/test_hud.gb: $(BIN_DIR)/test_hud.o $(BIN_DIR)/hud.o $(BIN_DIR)/Tetrominos.o $(BIN_DIR)/common.o $(BIN_DIR)/runtime.o $(BIN_DIR)/header.o $(HUGE_OBJ) | $(DIST_DIR)
	$(RGBLINK) -o $@ $^
	$(RGBFIX) -v -p 0xFF -t "TEST" $(ROM_TYPE) $@

# test_Tetrominos: Tetrominos.asm includes common.inc, needs common.o
$(DIST_DIR)/test_Tetrominos.gb: $(BIN_DIR)/test_Tetrominos.o $(BIN_DIR)/Tetrominos.o $(BIN_DIR)/common.o $(BIN_DIR)/runtime.o $(BIN_DIR)/header.o $(HUGE_OBJ) | $(DIST_DIR)
	$(RGBLINK) -o $@ $^
	$(RGBFIX) -v -p 0xFF -t "TEST" $(ROM_TYPE) $@

# test_Board: Board.asm needs hud.o + Tetrominos.o + UserInterface.o + common.o
$(DIST_DIR)/test_Board.gb: $(BIN_DIR)/test_Board.o $(BIN_DIR)/Board.o $(BIN_DIR)/hud.o $(BIN_DIR)/Tetrominos.o $(BIN_DIR)/UserInterface.o $(BIN_DIR)/common.o $(BIN_DIR)/runtime.o $(BIN_DIR)/header.o $(HUGE_OBJ) | $(DIST_DIR)
	$(RGBLINK) -o $@ $^
	$(RGBFIX) -v -p 0xFF -t "TEST" $(ROM_TYPE) $@

# test_UserInterface: UserInterface.asm needs common.o
$(DIST_DIR)/test_UserInterface.gb: $(BIN_DIR)/test_UserInterface.o $(BIN_DIR)/UserInterface.o $(BIN_DIR)/common.o $(BIN_DIR)/runtime.o $(BIN_DIR)/header.o $(HUGE_OBJ) | $(DIST_DIR)
	$(RGBLINK) -o $@ $^
	$(RGBFIX) -v -p 0xFF -t "TEST" $(ROM_TYPE) $@

# test_gameplay: gameplay.asm needs all modules (calls functions from each)
$(DIST_DIR)/test_gameplay.gb: $(BIN_DIR)/test_gameplay.o $(BIN_DIR)/gameplay.o $(BIN_DIR)/Board.o $(BIN_DIR)/hud.o $(BIN_DIR)/Tetrominos.o $(BIN_DIR)/UserInterface.o $(BIN_DIR)/common.o $(BIN_DIR)/runtime.o $(BIN_DIR)/header.o $(HUGE_OBJ) | $(DIST_DIR)
	$(RGBLINK) -o $@ $^
	$(RGBFIX) -v -p 0xFF -t "TEST" $(ROM_TYPE) $@

# Assemble test sources
$(BIN_DIR)/test_%.o: $(TEST_DIR)/test_%.asm $(SPRITE_DEFS) | $(BIN_DIR)
	$(RGBASM) $(INCLUDES) -o $@ $<

# Run a specific test
test_%: $(DIST_DIR)/test_%.gb
	$(NODE) $(TEST_RUNNER) $<

# =============================================================================
# Convenience targets for individual modules
# =============================================================================

%.o: $(BIN_DIR)/%.o
	@echo "Built $<"

# =============================================================================
# Clean
# =============================================================================

clean:
	rm -rf $(BIN_DIR) $(DIST_DIR) .gfx_dir_stamp
	rm -f $(GFX_DIR)/*.2bpp $(GFX_DIR)/*.tilemap $(GFX_DIR)/*.attrmap $(GFX_DIR)/*.pal
	rm -f $(GFX_DIR)/sprite_defs.inc $(GFX_DIR)/sprite_data.inc $(GFX_DIR)/palette_data.inc $(GFX_DIR)/setup_sprites.inc
	rm -rf $(GEN_DIR)
