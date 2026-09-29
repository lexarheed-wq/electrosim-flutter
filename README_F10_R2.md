# ElectroSim F10-R2

Correction targeted after F10-R1 gate:

- FNV-1a 64-bit validation digest now uses `BigInt` masked to 64 bits, preventing signed negative hex output on native Dart.
- The F10 gate restores the approved F9 golden references automatically from a validated sibling candidate when they are absent from the package.
- No F9 production code, solver, or golden expectation is weakened.

Expected F10 digest format: exactly 16 lowercase hexadecimal characters.
