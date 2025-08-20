// Minimal geohash encoder + bbox cover (pure Dart)

const _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

String geohashEncode(double latitude, double longitude, {int precision = 6}) {
  // precision 5–7 is good for map viewports; tune per zoom
  double latMin = -90, latMax = 90, lonMin = -180, lonMax = 180;
  final buffer = StringBuffer();
  bool isLon = true;
  int bit = 0, ch = 0;

  while (buffer.length < precision) {
    if (isLon) {
      final mid = (lonMin + lonMax) / 2;
      if (longitude > mid) {
        ch |= 1 << (4 - bit);
        lonMin = mid;
      } else {
        lonMax = mid;
      }
    } else {
      final mid = (latMin + latMax) / 2;
      if (latitude > mid) {
        ch |= 1 << (4 - bit);
        latMin = mid;
      } else {
        latMax = mid;
      }
    }
    isLon = !isLon;
    if (bit < 4) {
      bit++;
    } else {
      buffer.write(_base32[ch]);
      bit = 0;
      ch = 0;
    }
  }
  return buffer.toString();
}

/// Returns the minimal set of geohash prefixes (at `precision`) that
/// cover the axis-aligned bbox. If bbox crosses the antimeridian, split it first.
List<String> geohashCoveringPrefixes({
  required double north,
  required double south,
  required double east,
  required double west,
  int precision = 6,
}) {
  // Walk a grid of geohashes that intersect the bbox.
  // We step across the bbox by moving to the next geohash cell at `precision`.
  final visited = <String>{};

  // Helper to get the cell bounds for a lat/lon at this precision
  Map<String, double> cellBounds0(double lat, double lon) {
    double latMin = -90, latMax = 90, lonMin = -180, lonMax = 180;
    bool isLon = true;
    int bits = precision * 5;
    for (int i = 0; i < bits; i++) {
      if (isLon) {
        final mid = (lonMin + lonMax) / 2;
        if (lon > mid) {
          lonMin = mid;
        } else {
          lonMax = mid;
        }
      } else {
        final mid = (latMin + latMax) / 2;
        if (lat > mid) {
          latMin = mid;
        } else {
          latMax = mid;
        }
      }
      isLon = !isLon;
    }
    return {
      'latMin': latMin,
      'latMax': latMax,
      'lonMin': lonMin,
      'lonMax': lonMax,
    };
  }

  // Start at SW corner and sweep
  double y = south;
  while (y <= north) {
    // Find the first cell on this row (west edge)
    final startHash = geohashEncode(y, west, precision: precision);
    final rowStart = cellBounds0(y, west);
    double x = west;
    String cell = startHash;
    var cellBounds = rowStart;

    while (true) {
      visited.add(cell);

      // Move east to the next cell:
      // Jump to a point slightly to the east of current cell's east edge
      final nextX = cellBounds['lonMax']! + 1e-9;
      if (nextX > east) break;
      x = nextX;
      cell = geohashEncode(y, x, precision: precision);
      cellBounds = cellBounds0(y, x);
    }

    // Move north to next row (just above current cell's north edge)
    final nextY = cellBounds0(y, west)['latMax']! + 1e-9;
    if (nextY > north) break;
    y = nextY;
  }

  return visited.toList();
}
