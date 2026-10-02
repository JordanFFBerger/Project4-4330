# PFT Explorer — Android testing (1.0.4)

## Make Pokémon appear without printables

1. Install the APK over the previous version to preserve placements, calibration, and captures. Use an ARCore-compatible Android phone with a compass. Allow camera/location access and install or update Google Play Services for AR if prompted.
2. Log in or choose **Continue as guest**. Guest access does not need the development login server.
3. Open **Set up Pokémon AR**, select a Pokémon, choose its floor, tap **Test position**, tap its map location, and save. Existing saved placements still work. Alternatively, **Open PFT Map → Shuffle Pokémon** assigns all 13 Pokémon to distinct landmarks.
4. Calibrate each floor once using **Open PFT Map → GPS options → Calibrate floor**. At each of three widely spaced known spots, tap **Add point**, mark your current map position using **Test position**, and remain still while GPS is recorded. Choose a triangle, with points at least 20 m apart and clear sky reception where possible. Save. Existing calibration is reused.
5. Go to **Find Pokémon in GPS AR** from setup or the AR icon on the map. Select your actual floor manually. Walk within 20 m of a saved point. Slowly scan a well-lit, textured floor, then hold the camera facing forward.
6. Pokémon appear automatically at estimated GPS-relative positions. No printed image or placement tap is needed. Look around; a target may be beside or behind you. Tap the camera icon to save an AR photo to Gallery.

The in-app **Pokémon AR tutorial** is available on Home, setup, and the AR screen.

## Positioning behavior and limits

- The inverse of the existing three-point floor calibration converts saved normalized map coordinates to latitude/longitude. No new default GPS coordinates are invented. Shuffle updates these same saved points; printed markers no longer need to move.
- GPS offsets, true-north compass bearing (including magnetic declination), and the AR camera pose establish target positions. A detected horizontal surface below the camera supplies estimated floor height. Scan the ground rather than a tabletop.
- New encounters require a GPS fix no older than 10 seconds, horizontal accuracy within 20 m, AR tracking, and a usable compass reading. Nearby targets load within 20 m; existing encounters remain anchored until their reported distance exceeds 35 m to avoid flickering at the edge.
- Placement is approximate. GPS, compass, and map-calibration errors accumulate, especially indoors. The reported ± value describes the phone's GPS estimate, not guaranteed final AR accuracy. Floors are selected manually. This is not VPS/Geospatial API positioning or room-level indoor positioning.
- Loaded models keep stable local AR anchors rather than following every GPS fluctuation. **Realign / retry** recreates them using the latest usable position. Changing floors clears existing models. Backgrounding stops location updates; returning reacquires GPS and realigns.
- If nothing appears, check your floor, calibration, permissions, distance, and the status message. Improve sky reception. Move the phone in a figure eight if compass quality is poor. A phone without a usable compass cannot place these GPS encounters; Gallery previews still work.
- Calibration, positions, and captures remain device-local and are shared by guests and signed-in users on that device. GPS coordinates are not sent to PokéAPI or the login server. No AR cloud service/key is required by this placement implementation.

## Gallery, camera, and Pokémon details

- Gallery includes 13 bundled animated models plus saved photos/videos. Charizard's tail uses repaired yellow/orange unlit flame materials; original geometry, skinning, and animation remain intact.
- The **Pokédex** tab calls HTTPS PokéAPI REST endpoints for description, category, types, height, weight, abilities, and base stats. Successful responses are cached on-device for offline viewing. Uncached network failures offer Retry.
- Camera supports aspect-correct preview, front/back switching, photos, and video with microphone permission. The separate GPS AR screen supports composite photos; AR video recording is not implemented.
- Edit a photo to crop, draw, undo/reset, or apply Original/Mono/Sepia/Bright filters. **Save copy** preserves the original. Captures are stored privately in the app; uninstalling/clearing app data removes them.
- Account login retains the original development backend configuration (`http://10.0.2.2:3000` on Android). Use Guest on a phone until a reachable authentication service is configured. This update does not deploy a server.

## Verification

Automated tests cover map interactions, calibration/inverse projection, compass-to-AR coordinate math, invalid/stale GPS rejection, station persistence and shuffle, guest navigation, PokéAPI caching/retry, media storage/editing, tutorial navigation, and Charizard material integrity. Native Android compilation checks the sensor/AR integration.

Phone tests still required: permission denial/retry, location services off, compass interference, floor detection, multiple nearby Pokémon, moving beyond encounter range, background/resume, floor changes, AR photo capture, and on-site placement accuracy. Test all 13 Pokémon. CI/build success does not prove physical GPS/AR performance.

The vendored MIT-licensed AR plugin uses ARCore and Filament; its renderer loops embedded animation clip 0. Models have a maximum rest-pose size of approximately 60 cm. Source notices and model provenance are retained under `assets/pokemon/`. Legacy printable assets remain for historical compatibility but are not used by the current GPS AR flow. iOS AR remains disabled pending native setup and device testing.
