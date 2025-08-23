// lib/services/firms_cache.dart
import 'package:stopfires/providers/firms_service.dart';

class _FirmsCacheEntry {
  final List<FirePoint> data;
  final DateTime fetchedAt;
  _FirmsCacheEntry(this.data, this.fetchedAt);
}

class FirmsCache {
  final Duration ttl;
  final _store = <String, _FirmsCacheEntry>{};
  FirmsCache({this.ttl = const Duration(minutes: 5)});

  String makeKey({
    required BBox bbox,
    required FirmsSensor sensor,
    required int days,
  }) => 'sensor=${sensor.name};days=$days;bbox=${bbox.rounded(decimals: 3)}';

  List<FirePoint>? get(String key) {
    final e = _store[key];
    if (e == null) return null;
    if (DateTime.now().difference(e.fetchedAt) > ttl) {
      _store.remove(key);
      return null;
    }
    return e.data;
  }

  void set(String key, List<FirePoint> data) {
    _store[key] = _FirmsCacheEntry(data, DateTime.now());
  }

  void invalidate(String key) => _store.remove(key);
  void clear() => _store.clear();
}
