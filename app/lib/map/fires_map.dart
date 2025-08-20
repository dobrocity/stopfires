import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:dio/dio.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:stopfires/config.dart';
import 'package:stopfires/providers/geolocation_provider.dart';

class FirePoint {
  final double lat;
  final double lon;
  final DateTime time;
  final int? confidence;
  final String sensor;
  FirePoint({
    required this.lat,
    required this.lon,
    required this.time,
    this.confidence,
    required this.sensor,
  });
}

class FireCluster {
  final List<FirePoint> points;
  final List<LatLng> hull;
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
  final mapController = MapController();
  final _logger = Logger();
  List<FirePoint> fires = [];
  List<FireCluster> clusters = [];
  String window = '24h'; // 24h | 48h | 72h
  String sensor = 'viirs'; // viirs | modis
  bool loading = false;
  bool updatingViewport = false;
  bool mapReady = false;
  bool mapInitializing = true;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();

    // Wait for the map to be ready before setting up event listeners and loading fires
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Add additional delay to ensure FlutterMap is fully rendered and initialized
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) {
            setState(() {
              mapReady = true;
              mapInitializing = false;
            });
            _setupMapListeners();
            // Add another small delay before loading fires to ensure map is fully stable
            Future.delayed(const Duration(milliseconds: 1000), () {
              if (mounted) {
                _loadFires(); // Load fires AFTER map is ready

                // Set up automatic refresh every 5 minutes (300000ms) like in HTML version
                Timer.periodic(const Duration(minutes: 5), (timer) {
                  if (mounted) {
                    _loadFires();
                  } else {
                    timer.cancel();
                  }
                });
              }
            });
          }
        });
      }
    });
  }

  void _setupMapListeners() {
    try {
      // Ensure map controller is properly initialized and safe to use
      if (!mounted || !mapReady) {
        _logger.d(
          'Widget not mounted or map not ready, skipping listener setup',
        );
        return;
      }

      // Add a small delay to ensure FlutterMap is fully rendered
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!mounted || !mapReady) return;

        try {
          // Check if map controller is safe to use
          mapController.mapEventStream.listen(
            (event) {
              try {
                if (event is MapEventMoveEnd) {
                  // Debounce to avoid excessive API calls
                  _debounceTimer?.cancel();
                  if (mounted) {
                    setState(() => updatingViewport = true);
                  }
                  _debounceTimer = Timer(const Duration(seconds: 2), () {
                    if (mounted && mapReady) {
                      _loadFires()
                          .then((_) {
                            if (mounted) {
                              setState(() => updatingViewport = false);
                            }
                          })
                          .catchError((e) {
                            if (mounted) {
                              setState(() => updatingViewport = false);
                              _logger.e(
                                'Error loading fires after map movement: $e',
                              );
                            }
                          });
                    }
                  });
                }
              } catch (e) {
                _logger.e('Error handling map event: $e');
              }
            },
            onError: (e) {
              _logger.e('Error in map event stream: $e');
            },
          );
        } catch (e) {
          _logger.e('Error accessing map controller: $e');
        }
      });
    } catch (e) {
      _logger.e('Error setting up map listeners: $e');
    }
  }

  // Safe method to get map bounds without crashing
  LatLngBounds? _getSafeMapBounds() {
    try {
      if (!mounted || !mapReady) {
        return null;
      }
      return mapController.camera.visibleBounds;
    } catch (e) {
      _logger.e('Error getting map bounds: $e');
      return null;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  // --- Haversine distance calculation (meters) ---
  double _haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double R = 6371000; // Earth radius in meters
    double toRad(double x) => x * pi / 180;
    final double dLat = toRad(lat2 - lat1);
    final double dLon = toRad(lon2 - lon1);
    final double a =
        pow(sin(dLat / 2), 2) +
        cos(toRad(lat1)) * cos(toRad(lat2)) * pow(sin(dLon / 2), 2);
    return 2 * R * asin(sqrt(a));
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

    if (fires.isEmpty) {
      if (mounted) {
        setState(() => clusters = []);
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
      'Creating clusters for ${fires.length} fires using HTML algorithm',
    );
    _logger.d('Distance thresholds: $thresholds meters');
    _logger.d('Buffer radii: $bufferRadii meters');

    // Create clusters at different distance thresholds using HTML algorithm
    for (int i = 0; i < thresholds.length; i++) {
      final clusterGroups = _buildClustersHTML(fires, thresholds[i]);
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
      setState(() => clusters = allClusters);
      _logger.i(
        'Created ${allClusters.length} clusters from ${fires.length} fires using HTML algorithm',
      );
    }
  }

  List<LatLng> _createBufferPolygon(
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
      final List<LatLng> points = cluster
          .map((f) => LatLng(f.lat, f.lon))
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
    final List<LatLng> allPoints = [];
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
  List<LatLng> _createMinkowskiSum(List<LatLng> hull, double radius) {
    if (hull.length < 3) return [];

    final List<LatLng> bufferedPoints = [];

    for (int i = 0; i < hull.length; i++) {
      final current = hull[i];
      final next = hull[(i + 1) % hull.length];
      final prev = hull[(i - 1 + hull.length) % hull.length];

      // Calculate edge vectors
      final edgeVector1 = LatLng(
        current.latitude - prev.latitude,
        current.longitude - prev.longitude,
      );
      final edgeVector2 = LatLng(
        next.latitude - current.latitude,
        next.longitude - current.longitude,
      );

      // Calculate normals pointing outward
      final normal1 = LatLng(-edgeVector1.longitude, edgeVector1.latitude);
      final normal2 = LatLng(-edgeVector2.longitude, edgeVector2.latitude);

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
        final norm1 = LatLng(normal1.latitude / len1, normal1.longitude / len1);
        final norm2 = LatLng(normal2.latitude / len2, normal2.longitude / len2);

        // Average the normals for corner offset
        final avgNormal = LatLng(
          (norm1.latitude + norm2.latitude) / 2,
          (norm1.longitude + norm2.longitude) / 2,
        );

        final avgLen = sqrt(
          avgNormal.latitude * avgNormal.latitude +
              avgNormal.longitude * avgNormal.longitude,
        );

        if (avgLen > 0) {
          final finalNormal = LatLng(
            avgNormal.latitude / avgLen,
            avgNormal.longitude / avgLen,
          );

          // Add buffered point
          bufferedPoints.add(
            LatLng(
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
          LatLng(
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
  List<LatLng> _createConvexHull(List<LatLng> points) {
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
    final sortedPoints = List<LatLng>.from(points);
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
    final hull = <LatLng>[lowestPoint];
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
  double _crossProduct(LatLng a, LatLng b, LatLng c) {
    return (b.longitude - a.longitude) * (c.latitude - a.latitude) -
        (b.latitude - a.latitude) * (c.longitude - a.longitude);
  }

  // --- Create a circle with smooth edges ---
  List<LatLng> _createCircle(
    double centerLat,
    double centerLon,
    double radius,
  ) {
    final List<LatLng> points = [];
    const int segments = 128; // Increased segments for very smooth circles

    for (int i = 0; i <= segments; i++) {
      final double angle = (2 * pi * i) / segments;
      final double lat = centerLat + radius * cos(angle);
      final double lon = centerLon + radius * sin(angle);
      points.add(LatLng(lat, lon));
    }

    return points;
  }

  Future<void> _loadFires() async {
    if (!mounted) return;

    setState(() => loading = true);
    try {
      _logger.i('Loading fires for window: $window, sensor: $sensor');
      final data = await fetchFires(window: window, sensor: sensor);

      if (!mounted) return;

      _logger.d('Raw API response: ${data.length} fires received');

      // Debug: Print first few fires to see what we're getting
      if (data.isNotEmpty) {
        _logger.d('Sample fire data:');
        for (int i = 0; i < data.length && i < 3; i++) {
          _logger.d(
            '  Fire $i: lat=${data[i].lat}, lon=${data[i].lon}, confidence=${data[i].confidence}',
          );
        }
      }

      if (mounted) {
        setState(() => fires = data);
        _logger.d('Fires state updated: ${fires.length} fires');

        // Debug: Show some fire coordinates
        if (fires.isNotEmpty) {
          _logger.d('Sample fire coordinates:');
          for (int i = 0; i < min(3, fires.length); i++) {
            _logger.d('  Fire $i: lat=${fires[i].lat}, lon=${fires[i].lon}');
          }
        }

        // Create clusters after loading fires using HTML algorithm
        _createClustersHTML();
      }
    } catch (e) {
      _logger.e('Error in _loadFires: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Load error: $e')));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!mounted) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Debug: Log cluster information
    _logger.d(
      'Building with ${fires.length} fires and ${clusters.length} clusters',
    );
    for (int i = 0; i < clusters.length; i++) {
      _logger.d(
        'Cluster $i: ${clusters[i].points.length} points, ${clusters[i].hull.length} hull points',
      );
    }

    final location = ref.watch(locationFirestoreProvider);
    final currentPosition = location.value;

    final markers = fires.map((f) {
      return Marker(
        point: LatLng(f.lat, f.lon),
        width: 8,
        height: 8,
        child: GestureDetector(
          onTap: () => _showFireSheet(f),
          child: Container(
            decoration: BoxDecoration(
              color: Color.fromRGBO(255, 0, 0, 0.85),
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    }).toList();

    // Add current location marker on top if available
    if (currentPosition != null) {
      markers.add(
        Marker(
          point: LatLng(currentPosition.latitude, currentPosition.longitude),
          width: 18,
          height: 18,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: Colors.blueAccent, width: 2),
            ),
            child: Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.blueAccent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Create cluster polygons
    _logger.d('Creating ${clusters.length} cluster polygons');
    final clusterPolygons = clusters
        .where((cluster) => cluster.hull.isNotEmpty)
        .map((cluster) {
          _logger.d(
            'Creating polygon for cluster with ${cluster.hull.length} points',
          );
          return PolygonLayer(
            polygons: [
              Polygon(
                points: cluster.hull,
                color: Color.fromRGBO(
                  (cluster.color.r * 255.0).round() & 0xff,
                  (cluster.color.g * 255.0).round() & 0xff,
                  (cluster.color.b * 255.0).round() & 0xff,
                  cluster.opacity,
                ),
                borderColor: Color.fromRGBO(
                  (cluster.color.r * 255.0).round() & 0xff,
                  (cluster.color.g * 255.0).round() & 0xff,
                  (cluster.color.b * 255.0).round() & 0xff,
                  0.8,
                ),
                borderStrokeWidth: 2,
              ),
            ],
          );
        })
        .toList();
    _logger.d('Created ${clusterPolygons.length} polygon layers');

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.l10n.fire_clusters_title(fires.length, clusters.length),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFires,
            tooltip: 'Refresh fires for current viewport',
          ),
          PopupMenuButton<String>(
            initialValue: sensor,
            onSelected: (v) {
              setState(() => sensor = v);
              _loadFires();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'viirs', child: Text('VIIRS')),
              PopupMenuItem(value: 'modis', child: Text('MODIS')),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          if (mapReady)
            FlutterMap(
              mapController: mapController,
              options: const MapOptions(
                initialCenter: LatLng(42.4410, 19.2627), // Montenegro center
                initialZoom: 8,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'org.stopfires.app',
                ),
                // Add cluster polygons first (behind markers)
                ...clusterPolygons,
                // Add current location accuracy circle (as polygon) behind marker
                if (currentPosition != null && currentPosition.accuracy > 0)
                  PolygonLayer(
                    polygons: [
                      Polygon(
                        points: _createCircle(
                          currentPosition.latitude,
                          currentPosition.longitude,
                          currentPosition.accuracy / 111000.0,
                        ),
                        color: const Color.fromRGBO(33, 150, 243, 0.15),
                        borderColor: const Color.fromRGBO(33, 150, 243, 0.4),
                        borderStrokeWidth: 1.5,
                      ),
                    ],
                  ),
                // Add fire markers on top
                MarkerLayer(markers: markers),
              ],
            )
          else
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Initializing map...'),
                ],
              ),
            ),
          if (loading)
            const Align(
              alignment: Alignment.topCenter,
              child: LinearProgressIndicator(minHeight: 3),
            ),
          if (mapInitializing)
            const Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Initializing map...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue,
                    backgroundColor: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          if (updatingViewport)
            const Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Updating viewport...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    backgroundColor: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          // Recenter to my location button
          if (currentPosition != null)
            Positioned(
              bottom: 88,
              right: 16,
              child: FloatingActionButton(
                mini: true,
                tooltip: 'My location',
                onPressed: () {
                  final zoom = mapController.camera.zoom;
                  mapController.move(
                    LatLng(currentPosition.latitude, currentPosition.longitude),
                    zoom < 13 ? 13 : zoom,
                  );
                },
                child: const Icon(Icons.my_location),
              ),
            ),
        ],
      ),
    );
  }

  void _showFireSheet(FirePoint f) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${f.sensor.toUpperCase()} fire',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text('Time: ${f.time.toLocal()}'),
            Text(
              'Lat/Lon: ${f.lat.toStringAsFixed(4)}, ${f.lon.toStringAsFixed(4)}',
            ),
            if (f.confidence != null) Text('Confidence: ${f.confidence}%'),
          ],
        ),
      ),
    );
  }

  Future<List<FirePoint>> fetchFires({
    required String window,
    required String sensor,
  }) async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
      ),
    );

    // Only try to get map bounds if the map is ready
    String url;
    if (!mapReady) {
      // Use Montenegro bounds if map not ready yet
      if (sensor == 'viirs') {
        url =
            'https://firms.modaps.eosdis.nasa.gov/api/area/csv/a372f5f316a9edc52f4a8726902a3606/VIIRS_SNPP_NRT/18.36,41.8,20.37,43.62/1';
      } else {
        url =
            'https://firms.modaps.eosdis.nasa.gov/api/area/csv/a372f5f316a9edc52f4a8726902a3606/MODIS_NRT/18.36,41.8,20.37,43.62/1';
      }
    } else {
      // Get current map bounds safely
      final bounds = _getSafeMapBounds();

      if (bounds == null) {
        // Fallback to Montenegro bounds if map not ready yet
        if (sensor == 'viirs') {
          url =
              'https://firms.modaps.eosdis.nasa.gov/api/area/csv/a372f5f316a9edc52f4a8726902a3606/VIIRS_SNPP_NRT/18.36,41.8,20.37,43.62/1';
        } else {
          url =
              'https://firms.modaps.eosdis.nasa.gov/api/area/csv/a372f5f316a9edc52f4a8726902a3606/MODIS_NRT/18.36,41.8,20.37,43.62/1';
        }
      } else {
        final minLon = bounds.west;
        final minLat = bounds.south;
        final maxLon = bounds.east;
        final maxLat = bounds.north;

        // Use current map viewport: minLon,minLat,maxLon,maxLat
        if (sensor == 'viirs') {
          url =
              'https://firms.modaps.eosdis.nasa.gov/api/area/csv/a372f5f316a9edc52f4a8726902a3606/VIIRS_SNPP_NRT/$minLon,$minLat,$maxLon,$maxLat/1';
        } else {
          url =
              'https://firms.modaps.eosdis.nasa.gov/api/area/csv/a372f5f316a9edc52f4a8726902a3606/MODIS_NRT/$minLon,$minLat,$maxLon,$maxLat/1';
        }
      }
    }

    _logger.d('Fetching fires from URL: $url');
    _logger.d('Map ready: $mapReady, mapInitializing: $mapInitializing');

    Response resp;
    try {
      resp = await dio.get(
        url,
        options: Options(responseType: ResponseType.plain),
      );
    } catch (e) {
      if (e.toString().contains('AbortError') ||
          e.toString().contains('request aborted') ||
          e.toString().contains('Client is already closed')) {
        _logger.w('Request was aborted or client closed: $e');
        return [];
      }
      rethrow;
    }

    _logger.d('API response status: ${resp.statusCode}');
    _logger.d('API response data length: ${(resp.data as String).length}');
    _logger.d(
      'API response preview: ${(resp.data as String).substring(0, (resp.data as String).length > 200 ? 200 : (resp.data as String).length)}',
    );

    return _parseFiresResponse(resp, sensor);
  }

  List<FirePoint> _parseFiresResponse(Response response, String sensor) {
    try {
      final csvText = response.data as String;
      _logger.d('Parsing CSV response, total length: ${csvText.length}');

      // Split into lines and filter out empty lines
      final lines = csvText
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .toList();
      _logger.d('Total lines after filtering empty: ${lines.length}');
      if (lines.isEmpty) return [];

      // Skip the header line if it exists (starts with "latitude")
      final dataLines = lines
          .where((line) => !line.startsWith('latitude'))
          .toList();
      _logger.d('Data lines after removing header: ${dataLines.length}');
      if (dataLines.isEmpty) return [];

      final List<FirePoint> fires = [];

      for (var line in dataLines) {
        try {
          final row = line.split(',');
          if (row.length < 14) {
            _logger.w(
              'Skipping incomplete row with ${row.length} columns: $line',
            );
            continue; // Skip incomplete rows (expecting 14 columns)
          }

          // Safe parsing with error handling
          final latStr = row[0].trim();
          final lonStr = row[1].trim();
          final confStr = row[9].trim();
          final dateStr = row[5].trim();
          final timeStr = row[6].trim();

          if (latStr.isEmpty ||
              lonStr.isEmpty ||
              dateStr.isEmpty ||
              timeStr.isEmpty) {
            _logger.w(
              'Skipping row with missing data: lat="$latStr", lon="$lonStr", date="$dateStr", time="$timeStr"',
            );
            continue; // Skip rows with missing essential data
          }

          final lat = double.tryParse(latStr);
          final lon = double.tryParse(lonStr);

          if (lat == null || lon == null) {
            _logger.w(
              'Skipping row with invalid coordinates: lat="$latStr", lon="$lonStr"',
            );
            continue; // Skip invalid coordinates
          }

          final conf = confStr == 'n' ? null : int.tryParse(confStr);

          final time = timeStr.padLeft(4, '0'); // acq_time (e.g. "7" -> "0007")

          DateTime parsedTime;
          try {
            parsedTime = DateTime.parse(
              '$dateStr ${time.substring(0, 2)}:${time.substring(2)}:00Z',
            );
          } catch (e) {
            _logger.w(
              'Skipping row with invalid date/time: date="$dateStr", time="$timeStr", error: $e',
            );
            continue; // Skip rows with invalid date/time
          }

          fires.add(
            FirePoint(
              lat: lat,
              lon: lon,
              confidence: conf,
              time: parsedTime,
              sensor: sensor,
            ),
          );
        } catch (e) {
          _logger.e('Error parsing individual row: $e, line: $line');
          // Skip individual rows that cause errors
          continue;
        }
      }

      _logger.i('Successfully parsed ${fires.length} fire points');
      return fires;
    } catch (e) {
      // Return empty list if CSV parsing fails completely
      _logger.e('Error parsing CSV response: $e');
      return [];
    }
  }
}
