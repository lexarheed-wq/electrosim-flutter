# ElectroSim offline Flutter toolchain

Pinned by `ci/TOOLCHAIN_LOCK.json`.

For the current project:
- Flutter 3.38.10
- Dart 3.10.9

`./bootstrap_local_toolchain.sh` never downloads from the network. It accepts the locked archive from:
1. `ELECTROSIM_FLUTTER_ARCHIVE=/absolute/path/to/archive`
2. `toolchain/archives/`
3. `.toolchain/`
4. a sibling ElectroSim candidate's `.toolchain/`

Run `./tools/prepare_offline_toolchain_bundle.sh` on the validation Mac once to copy the already-downloaded official Flutter archive into `toolchain/archives/` with SHA-256 verification.
