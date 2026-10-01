# Project 4 - PFT Explorer

Flutter app for the CSC 4330 team's Pokemon/AR project at LSU. This branch adds
Gavin's PFT map to Chloe's `Chloe-camera` home screen and camera foundation.

## Run

Use Flutter 3.47.2 or newer with Dart 3.13.2 or newer:

```sh
flutter pub get
flutter run
```

Choose **Open PFT Map** on the home screen. The map works offline and includes:

- All three floors of Patrick F. Taylor Hall, with room labels from LSU's plans.
- Pinch/pan, zoom buttons, fit-to-screen, and floor switching.
- Searchable landmarks and room numbers, including elevators and the main entrance.
- A manual **Test position** mode to exercise the player marker.
- Encounter overlays and callbacks for the game component.

Android project files and the camera permission are included. Building an APK
requires a configured Android SDK and Java toolchain:

```sh
flutter build apk --debug
```

The web target is useful for checking the map without an Android device:

```sh
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8765
```

## Map integration

The map data is in `assets/maps/pft-map.json`. Each position is
`{floor, x, y}`, with `x` and `y` between 0 and 1 relative to the **cropped floor
image**. The origin is the top-left corner, x increases rightward, and y increases
downward. North points left on these plans. The image, landmarks, encounters, and
player marker share the same transform, including after zooming or resizing.

The JSON is the single source of truth for floor assets and landmark positions.
Room markers are approximate location references; they are not approved spawn
points or permission to enter a room. There is no walkability mask, corridor
graph, route guidance, or measured distance calculation yet. Verify proposed
encounters in public corridors on site before using them in the game.

Import `lib/map/pft_map_data.dart` and `lib/map/pft_map_screen.dart`. Supply
game-owned encounters and an optional floor-relative player position:

```dart
PftMapScreen(
  encounters: [
    PftEncounter(
      id: 'encounter-001',
      name: 'Bulbasaur',
      position: PftMapPosition(floor: 1, x: 0.25, y: 0.405),
    ),
  ],
  playerPosition: currentIndoorPosition,
  allowManualPositioning: false,
  onEncounterSelected: (encounter) {
    // Open the team's capture/AR screen using encounter.id.
  },
)
```

Rebuild `PftMapScreen` when the position or encounter list changes. Encounters
and the player marker appear only on their assigned floor. The default map has
no Pokemon encounters; the game owns spawning, collection, and persistence.
`onOpenCamera` opens the existing camera route when supplied.

`onManualPositionChanged` returns a `PftMapPosition` after a tap in Test position
mode. `position.toJson()` exports normalized coordinates for test fixtures.
This mode accepts any point inside the image, including rooms and blank space;
it does not validate walkability. Switching floors does not move the player.

Automatic positioning is a separate team task. These plans are **not
georeferenced**. Do not pass GPS latitude/longitude directly as x/y, infer a
floor from this map, or treat normalized distances as meters. A positioning
provider needs calibration and explicit floor selection/detection.

## Source and asset regeneration

The bundled images are map-region renders of pages 2-4 of the
[LSU College of Engineering PFT Building Guide (2021)](https://www.lsu.edu/eng/images/pft_floorplan_guide2_webupdated2021.pdf).
Landmarks are approximate and should be checked against the current building.
The source information and rendering crop are recorded in the JSON. Original
floor plan colors and room labels are retained; a small fragment of the
brochure's legend outside the first-floor building outline is hidden in the UI.
No floor geometry is invented.

To reproduce the images, install Poppler (`pdftoppm`), then run:

```sh
python3 tool/render_pft_maps.py
```

The script verifies the original PDF's SHA-256 before rendering. If LSU replaces
the PDF, inspect the new plans and recheck landmark coordinates before updating
the recorded digest or crop.

## Verify

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build web
```

Tests cover map-image dimensions, valid coordinates, floor isolation, searching
across floors, placement after zoom/pan, encounter callbacks, and small screens.
