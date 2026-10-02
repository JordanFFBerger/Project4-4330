# Mobile Pokémon assets

13 GLB models with embedded animation clips, converted for this Android prototype.
See ../../ANDROID_TESTING.md from the repository root for testing instructions.
The manifest includes converted checksums and original source hashes. These versions
have decoded geometry, PNG textures, and a 60 cm maximum rest-pose dimension.
The Android renderer loops clip 0. Source notices are preserved in this directory.

Charizard's original grayscale game-effect flame materials are replaced with a
yellow unlit/emissive core and translucent orange envelope. The original mesh,
skin, body textures, and animation binary data are unchanged. Reproduce the
material repair with `node tool/fix_charizard_flame.cjs` from the repository root.
