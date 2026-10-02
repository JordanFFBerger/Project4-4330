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

## Gallery and camera update (1.0.1)

- The home screen now has Gallery in place of the old Downloaded Items section.
- The Pokémon tab includes all 13 bundled Pokémon, with artwork and animated 3D previews. Drag to rotate and pinch to zoom. Previewing models does not require camera access.
- Photos & videos contains your saved camera and AR photos, edited copies, and camera videos. Tap a photo to view it, then Edit to crop, draw, or apply Original/Mono/Sepia/Bright filters. Save copy preserves the original. Videos have playback and seeking controls.
- Camera uses the plugin's orientation-aware preview and requests the very-high resolution preset. Switch lenses using the front/back button. Choose Photo or Video; video mode requests microphone access. Stop and save finishes a recording. Leaving the camera or backgrounding the app attempts to stop and save an active recording.
- Crop handles are at the image corners. Drag a corner to resize, or drag inside to move the crop. Drawing supports colors, brush width, undo, and reset.
- The AR screen has a camera button to save a composite AR photo once a Pokémon is placed. AR video recording is not part of this update; video recording is in the regular Camera screen.
- Captures are stored privately inside the app, not uploaded or automatically added to the system Photos app. Updating the APK with the same signature preserves them; uninstalling or clearing app data removes them.
- Install the new APK over the old version. Verify portrait/landscape preview, both lenses, video audio, background/resume, playback, all editor tools, and AR photo composition on the phone. Camera hardware and WebView rendering still require device testing.
# Login and Pokédex integration (1.0.2)

## Live GPS and Shuffle

- **Open PFT Map → Shuffle Pokémon** assigns all 13 Pokémon to distinct randomly selected landmarks and replaces the device's previous placements after confirmation. Floor coordinates and Pokémon identities persist. These are approximate landmark positions, not a guarantee of public access. Move the Pokémon-specific printed markers to match before scanning AR encounters.
- Tap a Pokémon pin to open its animated model and Pokédex entry.
- Select your floor, open **GPS options → Calibrate floor**, and record three points. At each point, stand at a known position, choose **Add point**, tap **Test position** on the floor map, and mark your position. Remain still while the phone records GPS. Choose widely spaced points forming a triangle (at least 20 m apart); low-quality, closely spaced or collinear fixes are rejected. Save calibration, then return to **GPS options → Start GPS**. Repeat calibration on each floor you use.
- Calibration and locations stay on this device. No live GPS coordinates are sent to PokéAPI or the login server. Location permission is requested when GPS is used. GPS stops when the app goes into the background; restart it from the menu on return.
- GPS is approximate, particularly indoors. Select your floor manually. The displayed ± value is the phone's reported horizontal accuracy; calibration may add error. Fixes older than 30 seconds, with reported accuracy worse than 50 m, or outside the calibrated image do not display a live dot. No route guidance or room-level positioning is claimed.
- Phone checks: deny/allow permission, disable location services, record and reload a calibration, walk between known points, switch floors, background the app, and verify Shuffle persists after restart. Automated checks cover coordinate projection, invalid calibration, distinct landmark assignment, persistence and phone layouts. Actual GPS accuracy still requires on-site validation.

- Startup preserves the login/registration screen from the login branch. **Continue as guest** opens the full local app without an account or login-server connection. Saved captures and placements remain device-local and are shared by guests and signed-in users on that device.
- Existing account login still uses the development server configuration (Android emulator: `http://10.0.2.2:3000`). For a physical phone, use Guest until a reachable authentication service is configured. This update does not deploy an authentication server.
- In Gallery → Pokémon, select a Pokémon and open **Pokédex**. All 13 models have REST lookups against `https://pokeapi.co/api/v2/pokemon/{id}/` and `pokemon-species/{id}/` for English descriptions, category, types, metric height/weight, abilities and base stats.
- PokéAPI responses are cached on the device. Open a Pokémon's details online once, then reopen offline to verify the cached entry. An uncached offline entry offers Retry; 3D models remain bundled offline.
- Verify startup guest access, registration validation, the 3D/Pokédex tabs, and an uncached network failure/retry. Automated tests cover guest navigation, validation, response conversion, cache reuse and retry behavior.
