#!/usr/bin/env node
// =============================================================================
// run_tests.js - Headless Game Boy test runner using serverboy
// =============================================================================
// Loads a test ROM, runs it for up to N frames, then reads WRAM results.
//
// Test ROM protocol (fixed WRAM addresses):
//   $DFF0 (wTestDone)    = $01 when all tests finished
//   $DFF1 (wTestCount)   = number of tests
//   $DFF2+ (wTestResults) = $01=PASS, $00=FAIL per test
//
// Usage: node tests/run_tests.js <rom.gb> [<rom2.gb> ...]
// Exit code: 0 if all tests pass, 1 if any fail
// =============================================================================

'use strict';

const fs = require('fs');
const path = require('path');

// Resolve serverboy - use SERVERBOY_PATH env var (for Bazel) or fallback to vendored copy
const serverboyPath = process.env.SERVERBOY_PATH || require('path').join(__dirname, '..', 'third_party', 'serverboy', 'src', 'interface.js');
const Gameboy = require(serverboyPath);

// WRAM addresses for test results
const ADDR_TEST_DONE    = 0xCFF0;
const ADDR_TEST_COUNT   = 0xCFF1;
const ADDR_TEST_RESULTS = 0xCFF2;

const MAX_FRAMES = 600;  // ~10 seconds at 60fps (BlinkFullRows needs ~160+ frames)

function runTestRom(romPath) {
    const romName = path.basename(romPath, '.gb');
    const rom = fs.readFileSync(romPath);

    const gameboy = new Gameboy();
    gameboy.loadRom(rom);

    // Run frames until tests complete or timeout
    let done = false;
    for (let frame = 0; frame < MAX_FRAMES; frame++) {
        gameboy.doFrame();

        const memory = gameboy.getMemory();
        if (memory[ADDR_TEST_DONE] === 0x01) {
            done = true;
            break;
        }
    }

    const memory = gameboy.getMemory();
    const testCount = memory[ADDR_TEST_COUNT];
    const testDone = memory[ADDR_TEST_DONE];

    if (!done) {
        console.log(`  ${romName}: TIMEOUT (wTestDone=$${testDone.toString(16).padStart(2,'0')}, ran ${MAX_FRAMES} frames)`);
        return false;
    }

    let allPass = true;
    for (let i = 0; i < testCount; i++) {
        const result = memory[ADDR_TEST_RESULTS + i];
        const status = result === 0x01 ? 'PASS' : 'FAIL';
        if (result !== 0x01) allPass = false;
        console.log(`  ${romName} test ${i + 1}/${testCount}: ${status}`);
    }

    return allPass;
}

// --- Main ---
const args = process.argv.slice(2);
if (args.length === 0) {
    console.error('Usage: node tests/run_tests.js <rom.gb> [<rom2.gb> ...]');
    process.exit(1);
}

let allPass = true;
for (const romPath of args) {
    if (!fs.existsSync(romPath)) {
        console.error(`ROM not found: ${romPath}`);
        allPass = false;
        continue;
    }
    console.log(`--- ${path.basename(romPath)} ---`);
    if (!runTestRom(romPath)) {
        allPass = false;
    }
}

process.exit(allPass ? 0 : 1);
