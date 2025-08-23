// lib/providers/firms_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stopfires/providers/firms_cache.dart';
import 'package:stopfires/providers/firms_repository.dart';
import 'package:stopfires/providers/firms_service.dart';

/// Configure your API key once here (or read from env/config).
const _firmsApiKey = 'a372f5f316a9edc52f4a8726902a3606';

final firmsServiceProvider = Provider<FirmsService>((ref) {
  return FirmsService(apiKey: _firmsApiKey);
});

final firmsCacheProvider = Provider<FirmsCache>((ref) {
  final cache = FirmsCache(ttl: const Duration(minutes: 5));
  ref.onDispose(cache.clear);
  return cache;
});

final firmsRepoProvider = Provider<FirmsRepository>((ref) {
  return FirmsRepository(
    service: ref.read(firmsServiceProvider),
    cache: ref.read(firmsCacheProvider),
  );
});

/// Query object for provider families (value semantics).
class FiresQuery {
  final BBox bbox;
  final FirmsSensor sensor;
  final int days;
  const FiresQuery({required this.bbox, required this.sensor, this.days = 1});

  @override
  bool operator ==(Object other) =>
      other is FiresQuery &&
      bbox.minLon == other.bbox.minLon &&
      bbox.minLat == other.bbox.minLat &&
      bbox.maxLon == other.bbox.maxLon &&
      bbox.maxLat == other.bbox.maxLat &&
      sensor == other.sensor &&
      days == other.days;

  @override
  int get hashCode => Object.hash(
    bbox.minLon,
    bbox.minLat,
    bbox.maxLon,
    bbox.maxLat,
    sensor,
    days,
  );
}

/// Cached fetch (uses TTL). Watch this from your UI.
final firesByBBoxProvider = FutureProvider.family<List<FirePoint>, FiresQuery>((
  ref,
  q,
) async {
  final repo = ref.read(firmsRepoProvider);
  return repo.fetchByBBoxCached(bbox: q.bbox, sensor: q.sensor, days: q.days);
});

/// Force-refresh variant that bypasses cache (use when user taps refresh).
final firesByBBoxRefreshProvider =
    FutureProvider.family<List<FirePoint>, FiresQuery>((ref, q) async {
      final repo = ref.read(firmsRepoProvider);
      return repo.fetchByBBoxCached(
        bbox: q.bbox,
        sensor: q.sensor,
        days: q.days,
        forceRefresh: true,
      );
    });
