import 'package:geolocator/geolocator.dart';

Future<void> ensureLocationAccess() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw StateError('Location is off. Enable it in Location settings.');
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.deniedForever) {
    throw StateError(
      'Location permission is blocked. Enable it in App settings.',
    );
  }
  if (permission != LocationPermission.whileInUse &&
      permission != LocationPermission.always) {
    throw StateError(
      'Location permission was not granted. You can still use the map manually.',
    );
  }
}
