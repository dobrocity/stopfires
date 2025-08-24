import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as m;
import 'package:stopfires/providers/firms_service.dart';

// --- FireCluster data structure for clustering ---
class FireCluster {
  final List<FirePoint> points;
  final List<m.LatLng> hull;
  final double bufferRadius;
  final Color color;
  final double opacity;

  FireCluster({
    required this.points,
    required this.hull,
    required this.bufferRadius,
    required this.color,
    required this.opacity,
  });
}

class ClusterHelper {
  // --- Clustering algorithm methods ---

  /// Calculate Haversine distance between two points in meters
  static double haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371000; // Earth's radius in meters
    final double dLat = (lat2 - lat1) * math.pi / 180;
    final double dLon = (lon2 - lon1) * math.pi / 180;
    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  // --- Enhanced clustering algorithm matching the HTML version exactly ---
  static List<List<FirePoint>> buildClusters(
    List<FirePoint> points,
    double distanceThreshold,
  ) {
    final visited = <int>{};
    final clusters = <List<FirePoint>>[];

    void dfs(int idx, List<FirePoint> cluster) {
      visited.add(idx);
      cluster.add(points[idx]);

      for (int j = 0; j < points.length; j++) {
        if (!visited.contains(j)) {
          final lat1 = points[idx].lat;
          final lon1 = points[idx].lon;
          final lat2 = points[j].lat;
          final lon2 = points[j].lon;

          if (haversineDistance(lat1, lon1, lat2, lon2) <= distanceThreshold) {
            dfs(j, cluster);
          }
        }
      }
    }

    for (int i = 0; i < points.length; i++) {
      if (!visited.contains(i)) {
        final cluster = <FirePoint>[];
        dfs(i, cluster);
        clusters.add(cluster);
      }
    }

    return clusters;
  }

  // --- Create cluster polygons with static thresholds (only visible at zoom 12+) ---
  static List<FireCluster> createClusters(
    List<FirePoint> fires,
    double currentZoom,
  ) {
    if (fires.isEmpty) {
      return [];
    }

    // Check current zoom level - only show clusters at zoom 12 and higher
    if (currentZoom < 12) {
      return [];
    }

    final List<FireCluster> allClusters = [];

    // Always use original thresholds regardless of zoom level
    final List<double> thresholds = [
      1000,
      2000,
      3000,
      4000,
    ]; // 1km, 2km, 3km, 4km
    final List<double> bufferRadii = [
      500,
      1000,
      1500,
      2000,
    ]; // original buffers

    final List<Color> colors = [
      const Color(0xFFFF0000), // bright red (level 1)
      const Color(0xFFFF6666), // light red (level 2)
      const Color(0xFFFFA500), // orange (level 3)
      const Color(0xFFFFFF00), // yellow (level 4)
    ];
    final List<double> opacities = [0.4, 0.3, 0.25, 0.2]; // opacity values

    // Create clusters at different distance thresholds using static algorithm
    for (int i = 0; i < thresholds.length; i++) {
      final clusterGroups = buildClusters(fires, thresholds[i]);

      for (final clusterGroup in clusterGroups) {
        final hull = createBufferPolygon(clusterGroup, bufferRadii[i]);
        final bufferRadius =
            bufferRadii[i] / 111000; // Convert meters to approximate degrees

        allClusters.add(
          FireCluster(
            points: clusterGroup,
            hull: hull,
            bufferRadius: bufferRadius,
            color: colors[i],
            opacity: opacities[i],
          ),
        );
      }
    }

    return allClusters;
  }

  static List<m.LatLng> createBufferPolygon(
    List<FirePoint> cluster,
    double bufferRadiusMeters,
  ) {
    if (cluster.isEmpty) return [];

    // Convert buffer radius from meters to approximate degrees
    final double bufferRadiusDegrees = bufferRadiusMeters / 111000;

    if (cluster.length == 1) {
      // For single point, create a circle
      return createCircle(cluster[0].lat, cluster[0].lon, bufferRadiusDegrees);
    }

    try {
      // For multiple points, create convex hull with buffer
      final List<m.LatLng> points = cluster
          .map((f) => m.LatLng(f.lat, f.lon))
          .toList();
      final hull = createConvexHull(points);

      if (hull.isNotEmpty) {
        // Create proper buffer around the convex hull
        return createMinkowskiSum(hull, bufferRadiusDegrees);
      }
    } catch (e) {
      // Fallback: create circles around each point and compute union
      final List<m.LatLng> allPoints = [];
      for (final fire in cluster) {
        final circlePoints = createCircle(
          fire.lat,
          fire.lon,
          bufferRadiusDegrees,
        );
        allPoints.addAll(circlePoints);
      }
      return createConvexHull(allPoints);
    }

    return [];
  }

  // --- Create Minkowski sum for proper buffer polygon ---
  static List<m.LatLng> createMinkowskiSum(List<m.LatLng> hull, double radius) {
    if (hull.length < 3) {
      if (hull.length == 2) {
        // For 2 points, create a "pill" shape (line segment with rounded ends)
        return createPillShape(hull[0], hull[1], radius);
      }
      return [];
    }

    final List<m.LatLng> bufferedPoints = [];

    for (int i = 0; i < hull.length; i++) {
      final current = hull[i];
      final next = hull[(i + 1) % hull.length];
      final prev = hull[(i - 1 + hull.length) % hull.length];

      // Calculate edge vectors
      final edgeVector1 = m.LatLng(
        current.latitude - prev.latitude,
        current.longitude - prev.longitude,
      );
      final edgeVector2 = m.LatLng(
        next.latitude - current.latitude,
        next.longitude - current.longitude,
      );

      // Calculate normals pointing outward
      final normal1 = m.LatLng(-edgeVector1.longitude, edgeVector1.latitude);
      final normal2 = m.LatLng(-edgeVector2.longitude, edgeVector2.latitude);

      // Normalize normals
      final len1 = math.sqrt(
        normal1.latitude * normal1.latitude +
            normal1.longitude * normal1.longitude,
      );
      final len2 = math.sqrt(
        normal2.latitude * normal2.latitude +
            normal2.longitude * normal2.longitude,
      );

      if (len1 > 0 && len2 > 0) {
        final norm1 = m.LatLng(
          normal1.latitude / len1,
          normal1.longitude / len1,
        );
        final norm2 = m.LatLng(
          normal2.latitude / len2,
          normal2.longitude / len2,
        );

        // Average the normals for corner offset
        final avgNormal = m.LatLng(
          (norm1.latitude + norm2.latitude) / 2,
          (norm1.longitude + norm2.longitude) / 2,
        );

        final avgLen = math.sqrt(
          avgNormal.latitude * avgNormal.latitude +
              avgNormal.longitude * avgNormal.longitude,
        );

        if (avgLen > 0) {
          final finalNormal = m.LatLng(
            avgNormal.latitude / avgLen,
            avgNormal.longitude / avgLen,
          );

          // Add buffered point
          bufferedPoints.add(
            m.LatLng(
              current.latitude + finalNormal.latitude * radius,
              current.longitude + finalNormal.longitude * radius,
            ),
          );
        }
      }

      // Add arc points at corners for rounded buffer
      final numArcPoints = 8;
      final startAngle = math.atan2(
        -edgeVector1.longitude,
        edgeVector1.latitude,
      );
      final endAngle = math.atan2(-edgeVector2.longitude, edgeVector2.latitude);

      double angleDiff = endAngle - startAngle;
      if (angleDiff < 0) angleDiff += 2 * math.pi;
      if (angleDiff > math.pi) angleDiff -= 2 * math.pi;

      for (int j = 1; j <= numArcPoints; j++) {
        final angle = startAngle + (angleDiff * j) / (numArcPoints + 1);
        bufferedPoints.add(
          m.LatLng(
            current.latitude + radius * math.cos(angle),
            current.longitude + radius * math.sin(angle),
          ),
        );
      }
    }

    // Return convex hull of all buffered points for final shape
    return createConvexHull(bufferedPoints);
  }

  static List<m.LatLng> createConvexHull(
    List<m.LatLng> pts, {
    bool close = false,
  }) {
    if (pts.length < 3) {
      // For 2 points, create a simple line segment
      // For 1 point, return as is
      return List<m.LatLng>.from(pts);
    }

    // 1) pivot: lowest latitude, then leftmost longitude
    int p0 = 0;
    for (int i = 1; i < pts.length; i++) {
      if (pts[i].latitude < pts[p0].latitude ||
          (pts[i].latitude == pts[p0].latitude &&
              pts[i].longitude < pts[p0].longitude)) {
        p0 = i;
      }
    }

    final pivot = pts[p0];
    final others = <m.LatLng>[];
    for (int i = 0; i < pts.length; i++) {
      if (i != p0) others.add(pts[i]);
    }

    // 2) sort by polar angle, then by distance from pivot (ASC),
    // so the farthest collinear point is processed LAST.
    double angle(m.LatLng a) =>
        math.atan2(a.latitude - pivot.latitude, a.longitude - pivot.longitude);
    double dist2(m.LatLng a) {
      final dx = a.longitude - pivot.longitude;
      final dy = a.latitude - pivot.latitude;
      return dx * dx + dy * dy;
    }

    others.sort((a, b) {
      final da = angle(a), db = angle(b);
      if (da != db) return da.compareTo(db);
      return dist2(a).compareTo(dist2(b));
    });

    // 3) build hull (keep only left turns; drop inner collinears)
    final hull = <m.LatLng>[pivot];
    for (final p in others) {
      while (hull.length > 1 &&
          cross(hull[hull.length - 2], hull.last, p) <= 0) {
        hull.removeLast();
      }
      hull.add(p);
    }

    if (close && hull.isNotEmpty) hull.add(hull.first);
    return hull;
  }

  // z-component of cross(AB, AC); positive => left turn (CCW)
  static double cross(m.LatLng a, m.LatLng b, m.LatLng c) {
    final abx = b.longitude - a.longitude;
    final aby = b.latitude - a.latitude;
    final acx = c.longitude - a.longitude;
    final acy = c.latitude - a.latitude;
    return abx * acy - aby * acx;
  }

  // --- Create pill shape for 2-point line segments ---
  static List<m.LatLng> createPillShape(
    m.LatLng p1,
    m.LatLng p2,
    double radius,
  ) {
    // Calculate the vector from p1 to p2
    final dx = p2.longitude - p1.longitude;
    final dy = p2.latitude - p1.latitude;

    // Calculate the length of the line segment
    final length = math.sqrt(dx * dx + dy * dy);

    if (length == 0) {
      // If points are identical, create a circle
      return createCircle(p1.latitude, p1.longitude, radius);
    }

    // Normalize the direction vector
    final unitX = dx / length;
    final unitY = dy / length;

    // Perpendicular vector (normal) pointing outward
    final perpX = -unitY;
    final perpY = unitX;

    // Create the pill shape with rounded ends
    final List<m.LatLng> points = [];
    const int segments = 16; // Reduced segments for smoother appearance

    // Start from the right side of p1 and go clockwise around the shape
    // Right side edge from p1 to p2
    points.add(
      m.LatLng(p1.latitude + perpY * radius, p1.longitude + perpX * radius),
    );
    points.add(
      m.LatLng(p2.latitude + perpY * radius, p2.longitude + perpX * radius),
    );

    // Right rounded end at p2 (semicircle)
    for (int i = 1; i <= segments; i++) {
      final angle = (math.pi * i) / segments;
      final cosAngle = math.cos(angle);
      final sinAngle = math.sin(angle);

      // Rotate the perpendicular vector from right to left
      final rotatedX = perpX * cosAngle + perpY * sinAngle;
      final rotatedY = -perpX * sinAngle + perpY * cosAngle;

      points.add(
        m.LatLng(
          p2.latitude + rotatedY * radius,
          p2.longitude + rotatedX * radius,
        ),
      );
    }

    // Left side edge from p2 to p1
    points.add(
      m.LatLng(p2.latitude - perpY * radius, p2.longitude - perpX * radius),
    );
    points.add(
      m.LatLng(p1.latitude - perpY * radius, p1.longitude - perpX * radius),
    );

    // Left rounded end at p1 (semicircle) to close the shape
    for (int i = 1; i <= segments; i++) {
      final angle = (math.pi * i) / segments;
      final cosAngle = math.cos(angle);
      final sinAngle = math.sin(angle);

      // Rotate the perpendicular vector from left to right
      final rotatedX = perpX * cosAngle - perpY * sinAngle;
      final rotatedY = perpX * sinAngle + perpY * cosAngle;

      points.add(
        m.LatLng(
          p1.latitude + rotatedY * radius,
          p1.longitude + rotatedX * radius,
        ),
      );
    }

    return points;
  }

  // --- Create a circle with smooth edges ---
  static List<m.LatLng> createCircle(
    double centerLat,
    double centerLon,
    double radius,
  ) {
    final List<m.LatLng> points = [];
    const int segments = 128; // Increased segments for very smooth circles

    for (int i = 0; i <= segments; i++) {
      final double angle = (2 * math.pi * i) / segments;
      final double lat = centerLat + radius * math.cos(angle);
      final double lon = centerLon + radius * math.sin(angle);
      points.add(m.LatLng(lat, lon));
    }

    return points;
  }

  /// Check if a point is inside a polygon using ray casting algorithm
  static bool isPointInPolygon(m.LatLng point, List<m.LatLng> polygon) {
    if (polygon.length < 3) return false;

    bool inside = false;
    int j = polygon.length - 1;

    for (int i = 0; i < polygon.length; i++) {
      if (((polygon[i].latitude > point.latitude) !=
              (polygon[j].latitude > point.latitude)) &&
          (point.longitude <
              (polygon[j].longitude - polygon[i].longitude) *
                      (point.latitude - polygon[i].latitude) /
                      (polygon[j].latitude - polygon[i].latitude) +
                  polygon[i].longitude)) {
        inside = !inside;
      }
      j = i;
    }

    return inside;
  }

  /// Calculate the center of a cluster by averaging all point coordinates
  static m.LatLng calculateClusterCenter(FireCluster cluster) {
    double totalLat = 0.0;
    double totalLon = 0.0;

    for (final point in cluster.points) {
      totalLat += point.lat;
      totalLon += point.lon;
    }

    final centerLat = totalLat / cluster.points.length;
    final centerLon = totalLon / cluster.points.length;

    return m.LatLng(centerLat, centerLon);
  }
}

// --- Utility functions for polygon processing ---
const eps = 1e-12;

bool _same(List<double> a, List<double> b, [double epsilon = eps]) =>
    (a[0] - b[0]).abs() < epsilon && (a[1] - b[1]).abs() < epsilon;

// 1) de-dup + cut if first re-appears in the middle
List<List<double>> sanitizeRing(List<List<double>> raw) {
  if (raw.isEmpty) return raw;

  final out = <List<double>>[];
  for (final p in raw) {
    if (out.isEmpty || !_same(out.last, p)) out.add(p);
  }
  final first = out.first;
  final dupIdx = out.indexWhere((p) => _same(p, first), 1);
  if (dupIdx != -1 && dupIdx < out.length - 1) {
    out.removeRange(dupIdx, out.length);
  }
  return out;
}

// 2) remove nearly-collinear vertices (keeps shape but avoids spikes)
List<List<double>> removeCollinear(
  List<List<double>> ring, {
  double eps = 1e-12,
}) {
  if (ring.length < 3) return ring;
  final cleaned = <List<double>>[];
  for (int i = 0; i < ring.length; i++) {
    final a = ring[(i - 1 + ring.length) % ring.length];
    final b = ring[i];
    final c = ring[(i + 1) % ring.length];
    final abx = b[0] - a[0], aby = b[1] - a[1];
    final bcx = c[0] - b[0], bcy = c[1] - b[1];
    final cross = abx * bcy - aby * bcx;
    if (cross.abs() > eps) cleaned.add(b); // keep only if there is a real turn
  }
  return cleaned;
}

// Shoelace signed area: >0 CCW, <0 CW
double signedArea(List<List<double>> ring) {
  double s = 0;
  for (int i = 0; i < ring.length; i++) {
    final j = (i + 1) % ring.length;
    s += ring[i][0] * ring[j][1] - ring[j][0] * ring[i][1];
  }
  return 0.5 * s;
}

List<List<double>> closeRing(List<List<double>> coords) {
  if (coords.isEmpty) return coords;
  final first = coords.first, last = coords.last;
  if ((first[0] - last[0]).abs() > 1e-12 ||
      (first[1] - last[1]).abs() > 1e-12) {
    return [
      ...coords,
      [first[0], first[1]],
    ];
  }
  return coords;
}

/// Ensure orientation: CCW for exterior, CW for holes.
List<List<double>> ensureOrientation(
  List<List<double>> ring, {
  required bool clockwise,
}) {
  var closed = closeRing(ring);
  final area = signedArea(closed); // CCW => area > 0
  final isCW = area < 0;
  if (clockwise && !isCW) closed = closed.reversed.toList();
  if (!clockwise && isCW) closed = closed.reversed.toList();
  return closed;
}

// 3) convex hull in lon/lat (returns open ring)
List<List<double>> convexHullLonLat(List<List<double>> pts) {
  if (pts.length <= 2) return pts;
  // pivot: lowest lat, then lowest lon
  int p0 = 0;
  for (int i = 1; i < pts.length; i++) {
    if (pts[i][1] < pts[p0][1] ||
        (pts[i][1] == pts[p0][1] && pts[i][0] < pts[p0][0]))
      p0 = i;
  }
  final pivot = pts[p0];
  final others = <List<double>>[];
  for (int i = 0; i < pts.length; i++) if (i != p0) others.add(pts[i]);

  double angle(List<double> a) => math.atan2(a[1] - pivot[1], a[0] - pivot[0]);
  double dist2(List<double> a) {
    final dx = a[0] - pivot[0], dy = a[1] - pivot[1];
    return dx * dx + dy * dy;
  }

  others.sort((a, b) {
    final da = angle(a), db = angle(b);
    if (da != db) return da.compareTo(db);
    return dist2(a).compareTo(dist2(b));
  });

  double cross(List<double> a, List<double> b, List<double> c) =>
      (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0]);

  final hull = <List<double>>[pivot];
  for (final p in others) {
    while (hull.length > 1 && cross(hull[hull.length - 2], hull.last, p) <= 0) {
      hull.removeLast();
    }
    hull.add(p);
  }
  return hull; // open; caller orients+closes
}
