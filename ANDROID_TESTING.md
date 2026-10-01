# Android marker prototype

## Install and test

1. Install the debug APK on an ARCore-supported Android phone (Android 7/API 24 or later; dependency requirements may raise the final minimum). Allow camera access and install/update Google Play Services for AR if prompted.
2. Open `assets/markers/print.html` on your computer. Print the Pokémon pages you want at **100% size**, with no fit-to-page. Measure the actual image: it must be **20 cm wide**. Each image is a tracking marker, not a QR code.
3. Place each marker flat and stationary at its intended encounter location. Use an accessible location you can test. A table is suitable for a first test; the Pokémon will stand on the marker plane.
4. On the phone choose **Set up Pokémon AR**, select a Pokémon, select the floor, enable **Test position**, and tap that marker's location on the map. Confirm the placement.
5. Choose **Scan placed markers** and point the camera at the complete marker in good light. Move slowly. Its assigned Pokémon should appear, with the first embedded clip looping. Models have a maximum rest-pose size of approximately 60 cm.
6. Walk a short distance around it, then point back at the marker to correct alignment. Close and reopen the AR screen to reset the session.

Repeat for at least ten Pokémon. Each of the 13 distinct marker images maps to one Pokémon. Setup assignments persist locally on that phone; clearing app data removes them. Reinstalling with a different signing key can require uninstalling the old app.

## What this prototype does

- Saves exact floor-map positions selected by the operator.
- Recognizes configured image markers, obtains their physical pose from ARCore, and shows the corresponding textured animated model at the marker.
- Displays saved encounters on the existing floor maps.
- Shows one encounter at a time. Rescanning updates its pose.

This is **marker-based placement**, not GPS calibration or a building-wide indoor navigation system. It does not continuously locate the player on the map, infer floors from GPS, or share placements between phones. No default physical locations are invented. iOS AR is disabled pending native setup and testing on Apple hardware.

## Validation limits

Automated tests cover configuration persistence, invalid floor/coordinate rejection, asset catalog presence and the existing map interactions. A built APK does not verify camera rendering, marker recognition, physical scale, tracking drift or animation appearance. These require a supported phone. Generated markers have not yet been evaluated on a phone; if detection is unreliable, replace a marker with a detailed nonrepeating photograph of the same printed dimensions.

## Local AR plugin changes

The MIT-licensed `ar_flutter_plugin_plus` 1.1.3 package is vendored in `packages/` with its license. The Android Filament render loop is patched to play clip 0 and update bone matrices. The upstream image database assumes a 20 cm image width, which is why print size matters. Native plugin code is excluded from the app's Dart lint scope; Android compilation checks its Kotlin code.

Models were decoded from Draco, converted from WebP to PNG textures, centered at their base, and scaled to a 60 cm maximum rest-pose dimension for this prototype. All source clips are retained. The mobile manifest records converted checksums plus original source checksums. Source licensing notices are included; no commercial Pokémon IP permission is conveyed.
