// lib/services/firms_service.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:dio/dio.dart';

enum FirmsSensor { viirs, modis }

extension on FirmsSensor {
  String get apiProduct =>
      this == FirmsSensor.viirs ? 'VIIRS_SNPP_NRT' : 'MODIS_NRT';
}

class BBox {
  final double minLon, minLat, maxLon, maxLat;
  const BBox(this.minLon, this.minLat, this.maxLon, this.maxLat);

  /// Optional: round coordinates to N decimal places to improve cache hits
  BBox rounded({int decimals = 3}) {
    double r(double v) {
      final p = math.pow(10, decimals).toDouble();
      return (v * p).round() / p;
    }

    return BBox(r(minLon), r(minLat), r(maxLon), r(maxLat));
  }

  @override
  String toString() => '[$minLon,$minLat,$maxLon,$maxLat]';
}

class FirePoint {
  final double lat, lon;
  final DateTime timeUtc;
  final int? confidence;
  final FirmsSensor sensor;
  const FirePoint({
    required this.lat,
    required this.lon,
    required this.timeUtc,
    required this.sensor,
    this.confidence,
  });
}

class FirmsException implements Exception {
  final String message;
  final int? statusCode;
  FirmsException(this.message, {this.statusCode});
  @override
  String toString() => 'FirmsException($statusCode): $message';
}

class FirmsService {
  final String apiKey;
  final Dio _dio;
  FirmsService({
    required this.apiKey,
    Dio? dio,
    Duration connectTimeout = const Duration(seconds: 10),
    Duration receiveTimeout = const Duration(seconds: 20),
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: connectTimeout,
               receiveTimeout: receiveTimeout,
             ),
           );

  Future<List<FirePoint>> fetchFiresByBBox({
    required BBox bbox,
    required FirmsSensor sensor,
    int days = 1,
  }) async {
    if (days < 1 || days > 3) {
      throw ArgumentError.value(days, 'days', 'FIRMS supports days=1..3');
    }
    final url =
        'https://firms.modaps.eosdis.nasa.gov/api/area/csv/$apiKey/${sensor.apiProduct}/'
        '${bbox.minLon},${bbox.minLat},${bbox.maxLon},${bbox.maxLat}/$days';

    Response<String> resp;
    try {
      resp = await _dio.get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );
    } on DioException catch (e) {
      throw FirmsException(
        e.message ?? 'Network error',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      throw FirmsException('Unexpected error: $e');
    }
    if (resp.statusCode != 200 || resp.data == null) {
      throw FirmsException(
        'Bad status from FIRMS: ${resp.statusCode}',
        statusCode: resp.statusCode,
      );
    }
    return _parseCsv(resp.data!, sensor);
  }

  List<FirePoint> _parseCsv(String csv, FirmsSensor sensor) {
    final lines = csv.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return const [];
    final rows = lines.where((l) => !l.startsWith('latitude')).toList();
    final out = <FirePoint>[];
    for (final line in rows) {
      final cols = line.split(',');
      if (cols.length < 10) continue;
      final lat = double.tryParse(cols[0].trim());
      final lon = double.tryParse(cols[1].trim());
      final date = cols[5].trim();
      final time = cols[6].trim().padLeft(4, '0'); // HHmm
      final confStr = cols[9].trim();
      if (lat == null || lon == null || date.isEmpty || time.length < 4) {
        continue;
      }
      DateTime? ts;
      try {
        ts = DateTime.parse(
          '$date ${time.substring(0, 2)}:${time.substring(2)}:00Z',
        ).toUtc();
      } catch (_) {
        continue;
      }
      out.add(
        FirePoint(
          lat: lat,
          lon: lon,
          timeUtc: ts,
          sensor: sensor,
          confidence: confStr == 'n' ? null : int.tryParse(confStr),
        ),
      );
    }
    return out;
  }
}
