import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:logger/logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stopfires/providers/auth_provider.dart';
import 'firebase_providers.dart';

/// Simple geohash implementation
String _generateGeohash(double lat, double lng, {int precision = 9}) {
  const String base32 = '0123456789bcdefghjkmnpqrstuvwxyz';
  int bit = 0;
  int ch = 0;
  String geohash = '';

  double minLat = -90.0;
  double maxLat = 90.0;
  double minLng = -180.0;
  double maxLng = 180.0;

  while (geohash.length < precision) {
    if (bit % 2 == 0) {
      double mid = (minLng + maxLng) / 2;
      if (lng >= mid) {
        ch |= 1 << (4 - bit % 5);
        minLng = mid;
      } else {
        maxLng = mid;
      }
    } else {
      double mid = (minLat + maxLat) / 2;
      if (lat >= mid) {
        ch |= 1 << (4 - bit % 5);
        minLat = mid;
      } else {
        maxLat = mid;
      }
    }

    bit++;
    if (bit % 5 == 0) {
      geohash += base32[ch];
      ch = 0;
    }
  }

  return geohash;
}

/// Provider that handles location updates and writes them to Firestore
final locationFirestoreProvider = StreamProvider<Position?>((ref) async* {
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
      await _writeLocationToFirestore(current, logger, ref);
      yield current;
    } catch (e) {
      logger.w('Failed to get current position: $e');
    }

    // Then continue emitting updates from the position stream
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 100,
    );

    yield* Geolocator.getPositionStream(locationSettings: settings)
        .handleError((e) {
          logger.e('Error in position stream: $e');
        })
        .asyncMap((position) async {
          await _writeLocationToFirestore(position, logger, ref);
          return position;
        });
  } catch (e) {
    Logger().e('Unexpected error in locationFirestoreProvider: $e');
    yield null;
  }
});

/// Helper function to write location data to Firestore
Future<void> _writeLocationToFirestore(
  Position position,
  Logger logger,
  Ref ref,
) async {
  try {
    final user = ref.read(userProvider);
    final uid = user.value?.firebase?.uid;
    if (uid == null) {
      logger.w('No authenticated user found, skipping Firestore write');
      return;
    }

    final firestore = ref.read(firestoreProvider);
    final latestRef = firestore.doc('users/$uid/status/current_location');
    final latest = await latestRef.get();
    if (latest.exists) {
      logger.d('Latest location: ${latest.data()}');
    } else {
      logger.d('No latest location found');
    }
    // Generate geohash
    final geoHash = _generateGeohash(position.latitude, position.longitude);

    await latestRef.set({
      'lat': position.latitude,
      'lng': position.longitude,
      'accuracy': position.accuracy,
      'speed': position.speed,
      'heading': position.heading,
      'geohash': geoHash,
      'ts': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    logger.d(
      'Location updated in Firestore: ${position.latitude}, ${position.longitude}',
    );
  } catch (e) {
    logger.e('Failed to write location to Firestore: $e');
  }
}
