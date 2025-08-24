import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:stopfires/providers/firebase_providers.dart';

/// Represents a user's current location data
class OtherUserLocation {
  final String uid;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final Map<String, dynamic>? additionalData;

  const OtherUserLocation({
    required this.uid,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.additionalData,
  });

  factory OtherUserLocation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OtherUserLocation(
      uid: doc.id,
      latitude: (data['lat'] as num).toDouble(),
      longitude: (data['lng'] as num).toDouble(),
      timestamp: (data['ts'] as Timestamp).toDate(),
      additionalData: data,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OtherUserLocation &&
          runtimeType == other.runtimeType &&
          uid == other.uid &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          timestamp == other.timestamp;

  @override
  int get hashCode => Object.hash(uid, latitude, longitude, timestamp);

  @override
  String toString() =>
      'OtherUserLocation(uid: $uid, lat: $latitude, lng: $longitude, ts: $timestamp)';
}

/// State class to hold both the stream data and cached users
class OtherUsersState {
  final Map<String, OtherUserLocation> cachedUsers;
  final bool isLoading;
  final String? error;

  const OtherUsersState({
    this.cachedUsers = const {},
    this.isLoading = false,
    this.error,
  });

  OtherUsersState copyWith({
    Map<String, OtherUserLocation>? cachedUsers,
    bool? isLoading,
    String? error,
  }) {
    return OtherUsersState(
      cachedUsers: cachedUsers ?? this.cachedUsers,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OtherUsersState &&
          runtimeType == other.runtimeType &&
          cachedUsers == other.cachedUsers &&
          isLoading == other.isLoading &&
          error == other.error;

  @override
  int get hashCode => Object.hash(cachedUsers, isLoading, error);
}

/// Notifier that manages other users' location data and state
class OtherUsersNotifier extends StateNotifier<OtherUsersState> {
  OtherUsersNotifier(this._ref) : super(const OtherUsersState());

  final Ref _ref;
  final Logger _logger = Logger();
  StreamSubscription<QuerySnapshot>? _otherUsersSub;

  @override
  void dispose() {
    _otherUsersSub?.cancel();
    super.dispose();
  }

  /// Subscribe to other users' locations
  void subscribeToOtherUsers() {
    // Cancel any previous subscription
    _otherUsersSub?.cancel();

    // Set loading state
    state = state.copyWith(isLoading: true, error: null);

    try {
      final firestore = _ref.read(firestoreProvider);
      final me = _ref.read(firebaseAuthProvider).currentUser?.uid;

      // Only show fresh markers (last 30 min)
      final sinceTs = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(minutes: 30)),
      );

      final q = firestore
          .collection('public')
          .doc('current_locations')
          .collection('users')
          .where('ts', isGreaterThan: sinceTs) // recent only
          .orderBy('ts', descending: true); // newest first (single-field index)

      _otherUsersSub = q.snapshots().listen(
        (snap) {
          final newUsers = <String, OtherUserLocation>{};

          for (final d in snap.docs) {
            final uid = d.id; // doc id is the user id in the mirror
            if (uid == me) continue; // skip my own marker

            try {
              final userLocation = OtherUserLocation.fromFirestore(d);
              newUsers[uid] = userLocation;
            } catch (e, st) {
              _logger.e(
                'Error parsing user location for uid: $uid',
                error: e,
                stackTrace: st,
              );
            }
          }

          // Update state with new users and clear loading
          state = state.copyWith(
            cachedUsers: newUsers,
            isLoading: false,
            error: null,
          );
        },
        onError: (error, stackTrace) {
          _logger.e(
            'Error listening to other users locations',
            error: error,
            stackTrace: stackTrace,
          );
          state = state.copyWith(
            isLoading: false,
            error: 'Failed to load other users: ${error.toString()}',
          );
        },
      );
    } catch (e, st) {
      _logger.e(
        'Failed to subscribe to other users locations',
        error: e,
        stackTrace: st,
      );
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to subscribe: ${e.toString()}',
      );
    }
  }

  /// Unsubscribe from other users' locations
  void unsubscribeFromOtherUsers() {
    _otherUsersSub?.cancel();
    _otherUsersSub = null;
    state = state.copyWith(cachedUsers: {}, isLoading: false, error: null);
  }

  /// Get other users within a specific bounding box
  List<OtherUserLocation> getUsersInBBox({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
  }) {
    return state.cachedUsers.values.where((user) {
      return user.latitude >= minLat &&
          user.latitude <= maxLat &&
          user.longitude >= minLng &&
          user.longitude <= maxLng;
    }).toList();
  }

  /// Get other users within a radius of a specific point
  List<OtherUserLocation> getUsersInRadius({
    required double centerLat,
    required double centerLng,
    required double radiusKm,
  }) {
    return state.cachedUsers.values.where((user) {
      final distance = _calculateDistance(
        centerLat,
        centerLng,
        user.latitude,
        user.longitude,
      );
      return distance <= radiusKm;
    }).toList();
  }

  /// Calculate distance between two points using Haversine formula
  double _calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    final dLat = _degreesToRadians(lat2 - lat1);
    final dLng = _degreesToRadians(lng2 - lng1);

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        sin(lat1 * pi / 180) *
            sin(lat2 * pi / 180) *
            sin(dLng / 2) *
            sin(dLng / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }
}

/// Stream provider that exposes other users' locations as a stream
final otherUsersStreamProvider = StreamProvider<Map<String, OtherUserLocation>>(
  (ref) {
    final firestore = ref.read(firestoreProvider);
    final me = ref.read(firebaseAuthProvider).currentUser?.uid;

    // Only show fresh markers (last 30 min)
    final sinceTs = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(minutes: 30)),
    );

    final q = firestore
        .collection('public')
        .doc('current_locations')
        .collection('users')
        .where('ts', isGreaterThan: sinceTs) // recent only
        .orderBy('ts', descending: true); // newest first (single-field index)

    return q.snapshots().map((snap) {
      final users = <String, OtherUserLocation>{};

      for (final d in snap.docs) {
        final uid = d.id; // doc id is the user id in the mirror
        if (uid == me) continue; // skip my own marker

        try {
          final userLocation = OtherUserLocation.fromFirestore(d);
          users[uid] = userLocation;
        } catch (e) {
          // Log error but continue processing other users
          print('Error parsing user location for uid: $uid: $e');
        }
      }

      return users;
    });
  },
);

/// Provider for the OtherUsersNotifier that manages state
final otherUsersProvider =
    StateNotifierProvider<OtherUsersNotifier, OtherUsersState>(
      (ref) => OtherUsersNotifier(ref),
    );

/// Provider that combines stream data with state management
final otherUsersCombinedProvider =
    Provider<AsyncValue<Map<String, OtherUserLocation>>>((ref) {
      // Watch the stream provider
      final streamAsync = ref.watch(otherUsersStreamProvider);

      // Watch the state notifier for cached data
      final state = ref.watch(otherUsersProvider);

      // Return stream data if available, otherwise return cached data
      if (streamAsync.hasValue) {
        return streamAsync;
      } else if (streamAsync.hasError) {
        // If stream has error, return cached data if available
        if (state.cachedUsers.isNotEmpty) {
          return AsyncValue.data(state.cachedUsers);
        }
        return streamAsync;
      } else {
        // If stream is loading, return cached data if available
        if (state.cachedUsers.isNotEmpty) {
          return AsyncValue.data(state.cachedUsers);
        }
        return streamAsync;
      }
    });

/// Provider for other users in a specific bounding box
final otherUsersInBBoxProvider =
    Provider.family<List<OtherUserLocation>, Map<String, double>>((ref, bbox) {
      final usersAsync = ref.watch(otherUsersCombinedProvider);
      final users = usersAsync.value ?? {};

      final minLat = bbox['minLat']!;
      final maxLat = bbox['maxLat']!;
      final minLng = bbox['minLng']!;
      final maxLng = bbox['maxLng']!;

      return users.values.where((user) {
        return user.latitude >= minLat &&
            user.latitude <= maxLat &&
            user.longitude >= minLng &&
            user.longitude <= maxLng;
      }).toList();
    });

/// Provider for other users within a radius of a point
final otherUsersInRadiusProvider =
    Provider.family<List<OtherUserLocation>, Map<String, double>>((
      ref,
      params,
    ) {
      final usersAsync = ref.watch(otherUsersCombinedProvider);
      final users = usersAsync.value ?? {};

      final centerLat = params['centerLat']!;
      final centerLng = params['centerLng']!;
      final radiusKm = params['radiusKm']!;

      return users.values.where((user) {
        final distance = _calculateDistance(
          centerLat,
          centerLng,
          user.latitude,
          user.longitude,
        );
        return distance <= radiusKm;
      }).toList();
    });

/// Helper function to calculate distance between two points
double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
  const double earthRadius = 6371; // Earth's radius in kilometers

  final dLat = _degreesToRadians(lat2 - lat1);
  final dLng = _degreesToRadians(lng2 - lng1);

  final a =
      sin(dLat / 2) * sin(dLat / 2) +
      sin(lat1 * pi / 180) *
          sin(lat2 * pi / 180) *
          sin(dLng / 2) *
          sin(dLng / 2);

  final c = 2 * atan2(sqrt(a), sqrt(1 - a));

  return earthRadius * c;
}

double _degreesToRadians(double degrees) {
  return degrees * (pi / 180);
}
