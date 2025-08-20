import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:logger/logger.dart';

/// Provides continuous geolocation updates (or null when unavailable).
final geolocationProvider = StreamProvider<Position?>((ref) async* {
  final logger = Logger();

  try {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      logger.w('Location services are disabled');
      yield null;
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      logger.w('Location permission denied');
      yield null;
      return;
    }

    // Emit the current position immediately, if available
    try {
      final current = await Geolocator.getCurrentPosition();
      yield current;
    } catch (e) {
      logger.w('Failed to get current position: $e');
    }

    // Then continue emitting updates from the position stream
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 100,
    );

    yield* Geolocator.getPositionStream(locationSettings: settings).handleError(
      (e) {
        logger.e('Error in position stream: $e');
      },
    );
  } catch (e) {
    Logger().e('Unexpected error in geolocationProvider: $e');
    yield null;
  }
});
