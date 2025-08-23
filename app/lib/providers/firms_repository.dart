import 'package:stopfires/providers/firms_cache.dart';
import 'package:stopfires/providers/firms_service.dart';

class FirmsRepository {
  final FirmsService service;
  final FirmsCache cache;
  FirmsRepository({required this.service, required this.cache});

  Future<List<FirePoint>> fetchByBBoxCached({
    required BBox bbox,
    required FirmsSensor sensor,
    int days = 1,
    bool forceRefresh = false,
  }) async {
    final key = cache.makeKey(bbox: bbox, sensor: sensor, days: days);
    if (!forceRefresh) {
      final cached = cache.get(key);
      if (cached != null) return cached;
    }
    final data = await service.fetchFiresByBBox(
      bbox: bbox,
      sensor: sensor,
      days: days,
    );
    cache.set(key, data);
    return data;
  }
}
