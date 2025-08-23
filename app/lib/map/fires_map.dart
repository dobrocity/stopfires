import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as m;
import 'package:stopfires/providers/firms_provider.dart';
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

class FiresMapPage extends ConsumerStatefulWidget {
  const FiresMapPage({super.key});

  @override
  ConsumerState<FiresMapPage> createState() => _FiresMapPageState();
}

class _FiresMapPageState extends ConsumerState<FiresMapPage> {
  late m.MapLibreMapController _c;
  final Logger _logger = Logger();
  // UI / state
  bool _loading = false;
  String? _error;

  // Data saved in state
  List<FirePoint> _fires = [];
  List<FireCluster> _clusters = [];
  bool _layersAdded = false;
  bool _mapReady = false;

  Timer? _debounce;
  m.CameraPosition? _lastCameraPosition;
  static const Duration _debounceDelay = Duration(milliseconds: 800);

  @override
  void dispose() {
    _debounce?.cancel();
    _clearAllLayers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final busy = _loading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fire Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _manualRefresh,
            tooltip: 'Refresh fires',
          ),
        ],
      ),
      body: Stack(
        children: [
          m.MapLibreMap(
            styleString: kIsWeb && !kDebugMode
                ? '/assets/assets/styles/style-default.json'
                : "assets/styles/style-default.json",
            trackCameraPosition: true,
            initialCameraPosition: const m.CameraPosition(
              target: m.LatLng(42.8339, 19.5261),
              zoom: 11,
              tilt: 55,
            ),
            onMapCreated: (c) async {
              _c = c;
              _mapReady = false; // Reset map ready state
              _layersAdded = false; // Reset layers state
              _logger.i('Map created successfully');
            },

            onStyleLoadedCallback: () {
              _logger.i('Map style loaded successfully');
              _mapReady = true;
              _refreshFromVisibleRegion();
            },
            onCameraIdle: () {
              // Enhanced debouncing with position change detection
              _debounce?.cancel();
              _debounce = Timer(_debounceDelay, () async {
                if (mounted) {
                  try {
                    final currentPosition = _c.cameraPosition;
                    if (currentPosition != null) {
                      // Check if camera position has actually changed significantly
                      if (_lastCameraPosition == null ||
                          _hasSignificantPositionChange(
                            _lastCameraPosition!,
                            currentPosition,
                          )) {
                        _lastCameraPosition = currentPosition;
                        await _refreshFromVisibleRegion();
                      }
                    }
                  } catch (e) {
                    // Map controller not ready yet
                    debugPrint('Camera position check failed: $e');
                  }
                }
              });
            },
          ),

          if (busy)
            const Align(
              alignment: Alignment.topCenter,
              child: LinearProgressIndicator(minHeight: 3),
            ),

          if (_error != null)
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- Loading & state management ---

  /// Checks if the camera position has changed significantly enough to warrant a refresh
  bool _hasSignificantPositionChange(
    m.CameraPosition oldPos,
    m.CameraPosition newPos,
  ) {
    const double minLatChange = 0.01; // Minimum latitude change (roughly 1km)
    const double minLonChange = 0.01; // Minimum longitude change (roughly 1km)
    const double minZoomChange = 0.5; // Minimum zoom change

    final latDiff = (oldPos.target.latitude - newPos.target.latitude).abs();
    final lonDiff = (oldPos.target.longitude - newPos.target.longitude).abs();
    final zoomDiff = (oldPos.zoom - newPos.zoom).abs();

    return latDiff > minLatChange ||
        lonDiff > minLonChange ||
        zoomDiff > minZoomChange;
  }

  /// Manually refresh fires from current visible region (bypasses debouncing)
  Future<void> _manualRefresh() async {
    // Cancel any pending debounced refresh
    _debounce?.cancel();
    await _refreshFromVisibleRegion();
  }

  Future<void> _refreshFromVisibleRegion() async {
    try {
      final bounds = await _c.getVisibleRegion();
      await loadFires(
        bounds.southwest.longitude,
        bounds.southwest.latitude,
        bounds.northeast.longitude,
        bounds.northeast.latitude,
      );
    } catch (e) {
      // Map may not be ready yet
      // ignore
    }
  }

  Future<void> loadFires(
    double west,
    double south,
    double east,
    double north,
  ) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Use repo with caching (from firms_providers.dart)
      final repo = ref.read(firmsRepoProvider);
      final bbox = BBox(west, south, east, north).rounded(decimals: 3);
      final fires = await repo.fetchByBBoxCached(
        bbox: bbox,
        sensor: FirmsSensor.viirs,
        days: 1,
        forceRefresh: false, // set true to bypass cache
      );

      setState(() {
        _fires = fires; // <- saved in state
      });

      // Only rebuild layers if map is ready
      if (_c != null && _mapReady) {
        await _rebuildFireLayers();
      } else {
        _logger.w(
          'Map not ready (controller: ${_c != null}, loaded: $_mapReady), deferring layer rebuild',
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load fires: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // --- Rendering fire layers from state ---

  Future<void> _rebuildFireLayers() async {
    // Ensure map controller is ready and map is loaded
    if (_c == null || !_mapReady) {
      _logger.w(
        'Map not ready (controller: ${_c != null}, loaded: $_mapReady), skipping layer rebuild',
      );
      return;
    }

    // Remove previous fire layers if they exist
    try {
      if (_layersAdded) {
        // Remove layers first, then sources
        final layersToRemove = ['fires-heat', 'fires-point', 'fires-clusters'];
        final sourcesToRemove = ['fires', 'clusters'];

        for (final layerId in layersToRemove) {
          await _safeRemoveLayer(layerId);
        }

        for (final sourceId in sourcesToRemove) {
          await _safeRemoveSource(sourceId);
        }

        // Small delay to ensure sources are fully removed
        await Future.delayed(const Duration(milliseconds: 100));

        _layersAdded = false;
      }
    } catch (e) {
      _logger.e('Failed to remove existing layers: $e');
    }

    if (_fires.isEmpty) return;

    // Create clusters first
    _createClustersHTML();

    // Create GeoJSON data from fire points with proper validation
    final features = <Map<String, dynamic>>[];

    for (final fire in _fires) {
      // Validate coordinates
      if (fire.lat.isNaN ||
          fire.lon.isNaN ||
          fire.lat < -90 ||
          fire.lat > 90 ||
          fire.lon < -180 ||
          fire.lon > 180) {
        _logger.w(
          'Skipping invalid fire coordinates: ${fire.lat}, ${fire.lon}',
        );
        continue;
      }

      features.add({
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [
            fire.lon,
            fire.lat,
          ], // GeoJSON uses [longitude, latitude] order
        },
        'properties': {
          'confidence': fire.confidence ?? 0,
          'sensor': fire.sensor.name,
          // 'time': fire.timeUtc.toIso8601String(),
          // Use confidence as weight, or 50 if no confidence
          'weight': (fire.confidence ?? 50) / 100.0,
        },
      });
    }

    if (features.isEmpty) {
      _logger.w('No valid fire features to display');
      return;
    }

    final geojson = {'type': 'FeatureCollection', 'features': features};

    try {
      // Safely remove source if it exists
      await _safeRemoveSource('fires');

      // Small delay to ensure source is fully removed
      await Future.delayed(const Duration(milliseconds: 50));

      // Add GeoJSON source - pass the object directly, not the JSON string
      await _c.addSource('fires', m.GeojsonSourceProperties(data: geojson));

      // Add large circle layer for heatmap effect (low zoom levels)
      await _c.addLayer(
        'fires',
        'fires-heat',
        m.CircleLayerProperties(
          circleRadius: [
            'interpolate',
            ['linear'],
            ['zoom'],
            0,
            [
              'interpolate',
              ['linear'],
              ['get', 'weight'],
              0,
              4,
              1,
              10,
            ],
            9,
            [
              'interpolate',
              ['linear'],
              ['get', 'weight'],
              0,
              8,
              1,
              20,
            ],
          ],
          circleColor: [
            'interpolate',
            ['linear'],
            ['get', 'weight'],
            0,
            'rgba(255,200,200,0.3)',
            0.2,
            'rgba(255,150,150,0.4)',
            0.4,
            'rgba(255,100,100,0.5)',
            0.6,
            'rgba(255,50,50,0.6)',
            0.8,
            'rgba(220,20,20,0.7)',
            1,
            'rgba(178,24,43,0.8)',
          ],
          circleStrokeColor: [
            'interpolate',
            ['linear'],
            ['get', 'weight'],
            0,
            'rgba(255,200,200,0.8)',
            0.2,
            'rgba(255,150,150,0.8)',
            0.4,
            'rgba(255,100,100,0.8)',
            0.6,
            'rgba(255,50,50,0.8)',
            0.8,
            'rgba(220,20,20,0.8)',
            1,
            'rgba(178,24,43,0.8)',
          ],
          circleStrokeWidth: 1,
          circleOpacity: [
            'interpolate',
            ['linear'],
            ['zoom'],
            0,
            1,
            9,
            0.3,
          ],
        ),
      );

      // Add smaller circle layer for higher zoom levels (point representation)
      await _c.addLayer(
        'fires',
        'fires-point',
        m.CircleLayerProperties(
          circleRadius: [
            'interpolate',
            ['linear'],
            ['zoom'],
            12,
            [
              'interpolate',
              ['linear'],
              ['get', 'weight'],
              0,
              2,
              1,
              5,
            ],
            16,
            [
              'interpolate',
              ['linear'],
              ['get', 'weight'],
              0,
              4,
              1,
              10,
            ],
          ],
          circleColor: [
            'interpolate',
            ['linear'],
            ['get', 'weight'],
            0,
            'rgba(255,200,200,0.9)',
            0.2,
            'rgba(255,150,150,0.9)',
            0.4,
            'rgba(255,100,100,0.9)',
            0.6,
            'rgba(255,50,50,0.9)',
            0.8,
            'rgba(220,20,20,0.9)',
            1,
            'rgba(178,24,43,0.9)',
          ],
          circleStrokeColor: 'white',
          circleStrokeWidth: 2,
          circleOpacity: [
            'interpolate',
            ['linear'],
            ['zoom'],
            12,
            0,
            13,
            1,
          ],
        ),
      );

      // Add cluster layers if clusters exist
      if (_clusters.isNotEmpty) {
        await _addClusterLayers();
      }

      _layersAdded = true;
      _logger.i('Fire layers added successfully');

      // Add feature tap handler for the fire layers
      _c.onFeatureTapped.add((id, point, coordinates, layerId) {
        if (layerId == 'fires-point' || layerId == 'fires-heat') {
          // Find the fire point at this location
          final fire = _fires.firstWhere(
            (f) =>
                (f.lat - coordinates.latitude).abs() < 0.001 &&
                (f.lon - coordinates.longitude).abs() < 0.001,
            orElse: () => _fires.first,
          );
          _showFireInfo(fire);
        } else if (layerId == 'fires-clusters') {
          // Find the cluster at this location
          final cluster = _clusters.firstWhere(
            (c) => _isPointInPolygon(coordinates, c.hull),
            orElse: () => _clusters.first,
          );
          _showClusterInfo(cluster);
        }
      });
    } catch (e) {
      _logger.e('Failed to add fire layers: $e');
      _logger.e('Stack trace: ${StackTrace.current}');
      setState(() {
        _error = 'Failed to render fire layers: $e';
      });
    }
  }

  // --- Clustering algorithm methods ---

  /// Calculate Haversine distance between two points in meters
  double _haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371000; // Earth's radius in meters
    final double dLat = (lat2 - lat1) * pi / 180;
    final double dLon = (lon2 - lon1) * pi / 180;
    final double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  // --- Enhanced clustering algorithm matching the HTML version exactly ---
  List<List<FirePoint>> _buildClustersHTML(
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

          if (_haversineDistance(lat1, lon1, lat2, lon2) <= distanceThreshold) {
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

  // --- Create cluster polygons with exact HTML styling ---
  void _createClustersHTML() {
    if (!mounted) return;

    if (_fires.isEmpty) {
      if (mounted) {
        setState(() => _clusters = []);
      }
      return;
    }

    final List<FireCluster> allClusters = [];

    // Use exact thresholds and styling from HTML version
    final List<double> thresholds = [
      1000,
      2000,
      3000,
      4000,
    ]; // meters (1km, 2km, 3km, 4km)
    final List<Color> colors = [
      const Color(0xFFFF0000), // bright red (level 1)
      const Color(0xFFFF6666), // light red (level 2)
      const Color(0xFFFFA500), // orange (level 3)
      const Color(0xFFFFFF00), // yellow (level 4)
    ];
    final List<double> opacities = [0.4, 0.3, 0.25, 0.2]; // HTML opacity values
    final List<double> bufferRadii = [
      500,
      1000,
      1500,
      2000,
    ]; // meters - exact HTML values

    _logger.d(
      'Creating clusters for ${_fires.length} fires using HTML algorithm',
    );
    _logger.d('Distance thresholds: $thresholds meters');
    _logger.d('Buffer radii: $bufferRadii meters');

    // Create clusters at different distance thresholds using HTML algorithm
    for (int i = 0; i < thresholds.length; i++) {
      final clusterGroups = _buildClustersHTML(_fires, thresholds[i]);
      _logger.d(
        'Threshold ${thresholds[i]}m: created ${clusterGroups.length} cluster groups',
      );

      for (final cluster in clusterGroups) {
        _logger.d(
          'Cluster ${clusterGroups.indexOf(cluster)}: ${cluster.length} points',
        );

        final hull = _createBufferPolygon(cluster, bufferRadii[i]);
        _logger.d(
          'Created buffer with ${hull.length} points for cluster of ${cluster.length} fires',
        );

        final bufferRadius =
            bufferRadii[i] / 111000; // Convert meters to approximate degrees

        allClusters.add(
          FireCluster(
            points: cluster,
            hull: hull,
            bufferRadius: bufferRadius,
            color: colors[i],
            opacity: opacities[i],
          ),
        );
      }
    }

    if (mounted) {
      setState(() => _clusters = allClusters);
      _logger.i(
        'Created ${allClusters.length} clusters from ${_fires.length} fires using HTML algorithm',
      );
    }
  }

  List<m.LatLng> _createBufferPolygon(
    List<FirePoint> cluster,
    double bufferRadiusMeters,
  ) {
    if (cluster.isEmpty) return [];

    // Convert buffer radius from meters to approximate degrees
    final double bufferRadiusDegrees = bufferRadiusMeters / 111000;

    if (cluster.length == 1) {
      // For single point, create a circle
      return _createCircle(cluster[0].lat, cluster[0].lon, bufferRadiusDegrees);
    }

    try {
      // For multiple points, create convex hull with buffer
      final List<m.LatLng> points = cluster
          .map((f) => m.LatLng(f.lat, f.lon))
          .toList();
      final hull = _createConvexHull(points);

      if (hull.isNotEmpty) {
        // Create proper buffer around the convex hull
        return _createMinkowskiSum(hull, bufferRadiusDegrees);
      }
    } catch (e) {
      _logger.w(
        'Error creating cluster buffer, falling back to simple circles: $e',
      );
    }

    // Fallback: create circles around each point and compute union
    final List<m.LatLng> allPoints = [];
    for (final fire in cluster) {
      final circlePoints = _createCircle(
        fire.lat,
        fire.lon,
        bufferRadiusDegrees,
      );
      allPoints.addAll(circlePoints);
    }
    return _createConvexHull(allPoints);
  }

  // --- Create Minkowski sum for proper buffer polygon ---
  List<m.LatLng> _createMinkowskiSum(List<m.LatLng> hull, double radius) {
    if (hull.length < 3) return [];

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
      final len1 = sqrt(
        normal1.latitude * normal1.latitude +
            normal1.longitude * normal1.longitude,
      );
      final len2 = sqrt(
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

        final avgLen = sqrt(
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
      final startAngle = atan2(-edgeVector1.longitude, edgeVector1.latitude);
      final endAngle = atan2(-edgeVector2.longitude, edgeVector2.latitude);

      double angleDiff = endAngle - startAngle;
      if (angleDiff < 0) angleDiff += 2 * pi;
      if (angleDiff > pi) angleDiff -= 2 * pi;

      for (int j = 1; j <= numArcPoints; j++) {
        final angle = startAngle + (angleDiff * j) / (numArcPoints + 1);
        bufferedPoints.add(
          m.LatLng(
            current.latitude + radius * cos(angle),
            current.longitude + radius * sin(angle),
          ),
        );
      }
    }

    // Return convex hull of all buffered points for final shape
    return _createConvexHull(bufferedPoints);
  }

  // --- Create convex hull from points ---
  List<m.LatLng> _createConvexHull(List<m.LatLng> points) {
    if (points.length < 3) return points;

    // Graham scan algorithm for convex hull
    // Find the point with lowest y-coordinate (and leftmost if tied)
    int lowest = 0;
    for (int i = 1; i < points.length; i++) {
      if (points[i].latitude < points[lowest].latitude ||
          (points[i].latitude == points[lowest].latitude &&
              points[i].longitude < points[lowest].longitude)) {
        lowest = i;
      }
    }

    // Sort points by polar angle with respect to lowest point
    final sortedPoints = List<m.LatLng>.from(points);
    final lowestPoint = sortedPoints[lowest];
    sortedPoints.removeAt(lowest);

    sortedPoints.sort((a, b) {
      final angleA = atan2(
        a.latitude - lowestPoint.latitude,
        a.longitude - lowestPoint.longitude,
      );
      final angleB = atan2(
        b.latitude - lowestPoint.latitude,
        b.longitude - lowestPoint.longitude,
      );
      return angleA.compareTo(angleB);
    });

    // Build convex hull
    final hull = <m.LatLng>[lowestPoint];
    for (final point in sortedPoints) {
      while (hull.length > 1 &&
          _crossProduct(hull[hull.length - 2], hull.last, point) <= 0) {
        hull.removeLast();
      }
      hull.add(point);
    }

    return hull;
  }

  // --- Calculate cross product for convex hull ---
  double _crossProduct(m.LatLng a, m.LatLng b, m.LatLng c) {
    return (b.longitude - a.longitude) * (c.latitude - a.latitude) -
        (b.latitude - a.latitude) * (c.longitude - a.longitude);
  }

  // --- Create a circle with smooth edges ---
  List<m.LatLng> _createCircle(
    double centerLat,
    double centerLon,
    double radius,
  ) {
    final List<m.LatLng> points = [];
    const int segments = 128; // Increased segments for very smooth circles

    for (int i = 0; i <= segments; i++) {
      final double angle = (2 * pi * i) / segments;
      final double lat = centerLat + radius * cos(angle);
      final double lon = centerLon + radius * sin(angle);
      points.add(m.LatLng(lat, lon));
    }

    return points;
  }

  /// Add cluster layers to the map
  Future<void> _addClusterLayers() async {
    // Ensure map controller is ready and map is loaded
    if (_c == null || !_mapReady) {
      _logger.w(
        'Map not ready (controller: ${_c != null}, loaded: $_mapReady), skipping cluster layer addition',
      );
      return;
    }

    try {
      // Create GeoJSON for clusters
      final clusterFeatures = <Map<String, dynamic>>[];

      for (final cluster in _clusters) {
        if (cluster.hull.isNotEmpty) {
          // Convert hull points to GeoJSON format [longitude, latitude]
          final coordinates = cluster.hull
              .map((point) => [point.longitude, point.latitude])
              .toList();

          clusterFeatures.add({
            'type': 'Feature',
            'geometry': {
              'type': 'Polygon',
              'coordinates': [coordinates], // Polygon requires array of arrays
            },
            'properties': {
              'clusterId': _clusters.indexOf(cluster),
              'fireCount': cluster.points.length,
              'color':
                  '#${cluster.color.toARGB32().toRadixString(16).substring(2)}',
              'opacity': cluster.opacity,
            },
          });
        }
      }

      if (clusterFeatures.isNotEmpty) {
        final clusterGeojson = {
          'type': 'FeatureCollection',
          'features': clusterFeatures,
        };

        // Safely remove cluster source if it exists
        await _safeRemoveSource('clusters');

        // Small delay to ensure source is fully removed
        await Future.delayed(const Duration(milliseconds: 50));

        // Add cluster source
        await _c.addSource(
          'clusters',
          m.GeojsonSourceProperties(data: clusterGeojson),
        );

        // Add cluster fill layer
        await _c.addLayer(
          'clusters',
          'fires-clusters',
          m.FillLayerProperties(
            fillColor: [
              'case',
              [
                '==',
                ['get', 'clusterId'],
                0,
              ],
              'rgba(255, 0, 0, 0.4)',
              [
                '==',
                ['get', 'clusterId'],
                1,
              ],
              'rgba(255, 102, 102, 0.3)',
              [
                '==',
                ['get', 'clusterId'],
                2,
              ],
              'rgba(255, 165, 0, 0.25)',
              [
                '==',
                ['get', 'clusterId'],
                3,
              ],
              'rgba(255, 255, 0, 0.2)',
              'rgba(255, 0, 0, 0.4)', // default
            ],
            fillOpacity: [
              'interpolate',
              ['linear'],
              ['zoom'],
              0,
              1,
              9,
              0.5,
            ],
          ),
        );

        _logger.i('Cluster layers added successfully');
      }
    } catch (e) {
      _logger.e('Failed to add cluster layers: $e');
    }
  }

  /// Safely remove a source if it exists
  Future<void> _safeRemoveSource(String sourceId) async {
    try {
      await _c.removeSource(sourceId);
      _logger.d('Successfully removed source: $sourceId');
    } catch (e) {
      // Source doesn't exist, which is fine
      _logger.d('Source $sourceId does not exist: $e');
    }
  }

  /// Safely remove a layer if it exists
  Future<void> _safeRemoveLayer(String layerId) async {
    try {
      await _c.removeLayer(layerId);
      _logger.d('Successfully removed layer: $layerId');
    } catch (e) {
      // Layer doesn't exist, which is fine
      _logger.d('Layer $layerId does not exist: $e');
    }
  }

  /// Clear all layers and sources safely
  Future<void> _clearAllLayers() async {
    if (_c == null) return;

    try {
      final layersToRemove = ['fires-heat', 'fires-point', 'fires-clusters'];
      final sourcesToRemove = ['fires', 'clusters'];

      for (final layerId in layersToRemove) {
        await _safeRemoveLayer(layerId);
      }

      for (final sourceId in sourcesToRemove) {
        await _safeRemoveSource(sourceId);
      }

      _layersAdded = false;
      _logger.i('All layers and sources cleared');
    } catch (e) {
      _logger.e('Error clearing layers: $e');
    }
  }

  /// Check if a point is inside a polygon using ray casting algorithm
  bool _isPointInPolygon(m.LatLng point, List<m.LatLng> polygon) {
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

  // --- UI helpers ---

  void _showFireInfo(FirePoint fire) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Fire Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Location: ${fire.lat.toStringAsFixed(4)}, ${fire.lon.toStringAsFixed(4)}',
            ),
            Text('Time: ${fire.timeUtc.toLocal().toString().split('.').first}'),
            Text('Sensor: ${fire.sensor.name.toUpperCase()}'),
            if (fire.confidence != null)
              Text('Confidence: ${fire.confidence}%'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showClusterInfo(FireCluster cluster) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Fire Cluster Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Number of fires: ${cluster.points.length}'),
            Text(
              'Buffer radius: ${(cluster.bufferRadius * 111000).toStringAsFixed(0)}m',
            ),
            Text('Color: ${cluster.color.toString()}'),
            Text('Opacity: ${cluster.opacity.toStringAsFixed(2)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
