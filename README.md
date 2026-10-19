# zig-c64-baseline

Baseline for working on c64 games in zig, using:
- [zig-mos-bootstrap](https://github.com/kassane/zig-mos-bootstrap)
- [llvm-mos-sdk](https://github.com/llvm-mos/llvm-mos-sdk)
- [c64-zig](https://github.com/SimoneFelici/c64-zig)

## Requirements

- [zig-mos-bootstrap](https://github.com/kassane/zig-mos-bootstrap/releases)

```bash
mise use github:kassane/zig-mos-bootstrap@0.17.0
```

## Build

```sh
git clone git@github.com:SimoneFelici/zig-c64-baseline.git
cd zig-c64-baseline
zig build -Doptimize=ReleaseSmall
```
Output files land in `zig-out/bin/`.

## References

- [zig-mos-examples](https://github.com/kassane/zig-mos-examples)

## License

Apache 2.0 — see LICENSE.
