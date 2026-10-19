# zig-c64-baseline

Baseline for working on c64 games in zig, using [zig-mos-bootstrap](https://github.com/kassane/zig-mos-bootstrap) and [llvm-mos-sdk](https://github.com/llvm-mos/llvm-mos-sdk).

## Requirements

- [zig-mos-bootstrap](https://github.com/kassane/zig-mos-bootstrap/releases) — Zig toolchain with LLVM-MOS backend

```bash
mise use github:kassane/zig-mos-bootstrap@0.17.0
```

## Build

```sh
git clone git@github.com:SimoneFelici/zig-c64-baseline.git
cd zig-c64-baseline
zig build -Doptimize=ReleaseSmall <c64-hello | c64-fibonacci | c64-plasma>
```

Named steps (build one at a time):

```sh
# Commodore 64
zig build c64-hello
zig build c64-fibonacci
zig build c64-plasma

```

Output files land in `zig-out/bin/`.

## Gallery

### C64

| Example | Preview |
|---------|---------|
| `c64-plasma` — Commodore 64 plasma effect | ![](.github/c64_plasma.gif) |

## Platforms

| `c64-hello`, `c64-fibonacci` | Commodore 64 | mos6502 | `.prg` |
| `c64-plasma` | Commodore 64 | mos6502 | `.prg` |


## Host tools

Built automatically alongside the examples (`zig build --summary all`).

### `bininfo` — binary inspector

Identifies and inspects any MOS-platform output binary.

```sh
zig-out/bin/bininfo <file> [files…] [flags]
```

| Flag | Short | Description |
|------|-------|-------------|
| `--sections` | `-S` | List ELF sections |
| `--symbols` | `-n` | List ELF symbols |
| `--dwarf` | `-d` | Dump DWARF section inventory, CU headers, and subprogram listing |
| `--xxd` | `-x` | Hex+ASCII dump (xxd style) |
| `--xxd-limit N` | | Cap xxd output at N bytes |
| `--disasm` | `-D` | 6502 disassembly of file payload |

Flags may appear before or after filenames.

Detected formats: iNES 1.0/2.0 (`.nes`), SNES SFC/SMC (`.sfc`/`.smc` — SMC 512-byte copier header auto-stripped), FDS raw (`.fds`), GEOS CVT (`.cvt`), CP/M-65 relocatable (`.com`), CBM PRG (`.prg`), Atari 2600 (`.a26`), Atari 8-bit cart (`.rom`), Atari XEX (`.xex`), Lynx BLL (`.bll`), PC Engine (`.pce`), Watara Supervision (`.sv`), Neo6502 (`.neo`), Apple IIe ProDOS (`.sys`), OSI Challenger 1P raw binary (detected by filename), mos-sim binary, ELF. HiROM vs LoROM is auto-detected from map-mode byte.

```sh
# Inspect a built NES ROM
bininfo zig-out/bin/hello1.nes --sections

# Dump first 64 bytes of an FDS binary
bininfo zig-out/bin/fds-hello.fds -x --xxd-limit 64

# Disassemble a PRG (auto-skips 2-byte load-address header)
bininfo zig-out/bin/c64-hello.prg -D
```

### `romtool` — NES / SNES ROM analyser

```sh
zig-out/bin/romtool <subcommand> [options] <file>
```

| Subcommand | Description |
|------------|-------------|
| `disasm` | 6502 / 65816 disassembly |
| `unpack` | Extract PRG/CHR banks + `header.txt` |
| `pack nes` | Assemble PRG+CHR banks back into an iNES ROM |
| `pack snes` | Assemble bank binaries into an SFC ROM with correct checksum |

**`disasm` options:**

| Flag | Description |
|------|-------------|
| `--bank N` | NES: PRG bank N (16 KB, 0-based); SNES: 32 KB bank N (0-based) |
| `--base 0xNNNN` | Override load address displayed |
| `--offset N` | Skip N bytes before disassembling (address adjusts automatically) |
| `--length N` | Disassemble at most N bytes |
| `--m8` / `--x8` | SNES: start with M/X flags set (8-bit accumulator/index) |

```sh
# Disassemble NES PRG bank 1 from offset $1234
romtool disasm game.nes --bank 1 --base 0xC000 --offset 0x1234 --length 128

# Disassemble SNES RESET vector (HiROM, bank 1, offset $7F98)
romtool disasm game.smc --bank 1 --base 0x8000 --offset 0x7F98 --m8 --x8 --length 40

# Unpack all banks to a directory
romtool unpack game.nes /path/to/game-banks/

# Reassemble NES ROM from PRG + CHR binaries
romtool pack nes -o repacked.nes prg-bank-00.bin chr-bank-00.bin

# Assemble SNES ROM from 32KB bank binaries (checksum auto-computed)
romtool pack snes -o out.sfc --map lorom bank-00.bin [bank-01.bin ...]

# Same with SMC copier header and custom title
romtool pack snes -o out.smc --map hirom --title "MY GAME" --smc bank-00.bin
```

## Platform notes

- **C64 hello** — uses translated `c64.h` (VIC-II typed struct) via `b.addTranslateC`; cycles VIC-II border colour register.

## References

- [Nesdoug LLVM-MOS tutorial](https://github.com/mysterymath/nesdoug-llvm)
- [llvm-mos-sdk examples](https://github.com/llvm-mos/llvm-mos-sdk/tree/main/examples)
- [rust-mos-hello-world](https://github.com/mrk-its/rust-mos-hello-world)

## License

Apache 2.0 — see LICENSE.
