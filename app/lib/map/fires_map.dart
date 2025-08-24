import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as m;
import 'package:stopfires/providers/firms_provider.dart';
import 'package:stopfires/providers/firms_service.dart';
import 'package:stopfires/map/cluster_helper.dart';
import 'package:stopfires/providers/geolocation_provider.dart';
import 'package:stopfires/providers/other_users_provider.dart';
import 'package:geolocator/geolocator.dart';

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

  // Other users tracking
  List<OtherUserLocation> _otherUsersInViewport = [];
  List<m.Circle> _otherUserMarkers = [];
  Map<m.Circle, OtherUserLocation> _markerToUserMap = {};
  StreamSubscription<Map<String, OtherUserLocation>>?
  _otherUsersStreamSubscription;

  // Location tracking
  StreamSubscription<Position?>? _locationSubscription;
  Position? _currentPosition;
  m.Circle? _currentLocationCircle;

  Timer? _debounce;
  m.CameraPosition? _lastCameraPosition;
  static const Duration _debounceDelay = Duration(milliseconds: 800);

  @override
  void initState() {
    super.initState();
    _setupLocationListener();
    _setupOtherUsersStream();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _locationSubscription?.cancel();
    _otherUsersStreamSubscription?.cancel();

    // Clean up other user markers
    for (final marker in _otherUserMarkers) {
      try {
        _c.removeCircle(marker);
      } catch (e) {
        // Ignore errors during cleanup
      }
    }
    _otherUserMarkers.clear();
    _markerToUserMap.clear();

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
              target: m.LatLng(42.3020, 18.8890),
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

              // Add current location marker if available
              if (_currentPosition != null) {
                _updateCurrentLocationMarker(_currentPosition!);
              }

              // Initialize other users in the current viewport
              _updateOtherUsersInViewport();
            },
            onCameraIdle: () {
              final currentPosition = _c.cameraPosition;
              if (currentPosition != null) {
                _logger.i('Zoom: ${currentPosition.zoom}');
              }
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
                        // Also update other users in the new viewport
                        await _updateOtherUsersOnViewportChange();
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

    // Zoom changes trigger cluster recalculation to show/hide clusters at zoom 12+
    if (zoomDiff > minZoomChange) {
      // Trigger cluster recalculation for zoom-based visibility
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (mounted && _layersAdded) {
          _createClusters();
          // Rebuild cluster layers to show/hide based on new zoom level
          await _addClusterLayers();
        }
      });
    }

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
      if (_mapReady) {
        await _rebuildFireLayers();
      } else {
        _logger.w(
          'Map not ready (loaded: $_mapReady), deferring layer rebuild',
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

  /// Update other users in the current viewport when camera changes
  Future<void> _updateOtherUsersInViewport() async {
    try {
      final bounds = await _c.getVisibleRegion();

      // Get other users in the current bounding box
      final bbox = {
        'minLat': bounds.southwest.latitude,
        'maxLat': bounds.northeast.latitude,
        'minLng': bounds.southwest.longitude,
        'maxLng': bounds.northeast.longitude,
      };

      // Use the otherUsersInBBoxProvider to get users in viewport
      final otherUsers = ref.read(otherUsersInBBoxProvider(bbox));

      setState(() {
        _otherUsersInViewport = otherUsers;
      });

      // Update other user markers on the map
      if (_mapReady) {
        await _updateOtherUserMarkers();
      }
    } catch (e) {
      _logger.e('Failed to update other users in viewport: $e');
    }
  }

  /// Update other users when viewport changes (called from camera idle)
  Future<void> _updateOtherUsersOnViewportChange() async {
    try {
      final bounds = await _c.getVisibleRegion();

      // Get other users in the current bounding box
      final bbox = {
        'minLat': bounds.southwest.latitude,
        'maxLat': bounds.northeast.latitude,
        'minLng': bounds.southwest.longitude,
        'maxLng': bounds.northeast.longitude,
      };

      // Use the otherUsersInBBoxProvider to get users in viewport
      final otherUsers = ref.read(otherUsersInBBoxProvider(bbox));

      setState(() {
        _otherUsersInViewport = otherUsers;
      });

      // Update other user markers on the map
      if (_mapReady) {
        await _updateOtherUserMarkers();
      }
    } catch (e) {
      _logger.e('Failed to update other users on viewport change: $e');
    }
  }

  /// Update other user markers on the map
  Future<void> _updateOtherUserMarkers() async {
    try {
      // Create a map of existing markers by user ID for efficient updates
      final existingMarkers = <String, m.Circle>{};
      for (int i = 0; i < _otherUserMarkers.length; i++) {
        if (i < _otherUsersInViewport.length) {
          existingMarkers[_otherUsersInViewport[i].uid] = _otherUserMarkers[i];
        }
      }

      // Clear the markers list to rebuild it
      _otherUserMarkers.clear();

      // Update or add markers for users in viewport
      for (final user in _otherUsersInViewport) {
        try {
          if (existingMarkers.containsKey(user.uid)) {
            // Update existing marker position
            final existingMarker = existingMarkers[user.uid]!;
            await _c.updateCircle(
              existingMarker,
              m.CircleOptions(
                geometry: m.LatLng(user.latitude, user.longitude),
              ),
            );
            _otherUserMarkers.add(existingMarker);
            _markerToUserMap[existingMarker] = user;
            existingMarkers.remove(user.uid); // Mark as used
          } else {
            // Add new marker
            final circle = await _c.addCircle(
              m.CircleOptions(
                geometry: m.LatLng(user.latitude, user.longitude),
                circleRadius: 10.0,
                circleColor: "#4CAF50", // Green color for other users
                circleStrokeColor: "#FFFFFF", // White border
                circleStrokeWidth: 2.0,
                circleOpacity: 0.8,
              ),
            );

            // Add tap handler for the circle
            _c.onCircleTapped.add((m.Circle tappedCircle) {
              if (tappedCircle == circle) {
                _showUserTooltip(user);
              }
            });

            _otherUserMarkers.add(circle);
            _markerToUserMap[circle] = user;
          }
        } catch (e) {
          _logger.e('Failed to update/add marker for user ${user.uid}: $e');
        }
      }

      // Remove markers for users no longer in viewport
      for (final marker in existingMarkers.values) {
        try {
          await _c.removeCircle(marker);
          _markerToUserMap.remove(marker);
        } catch (e) {
          _logger.e('Failed to remove marker: $e');
        }
      }

      _logger.d('Updated ${_otherUserMarkers.length} other user markers');
    } catch (e) {
      _logger.e('Failed to update other user markers: $e');
    }
  }

  // --- User tooltip methods ---

  void _showUserTooltip(OtherUserLocation user) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('User ID: ${user.uid}'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // --- Rendering fire layers from state ---

  Future<void> _rebuildFireLayers() async {
    // Ensure map controller is ready and map is loaded
    if (!_mapReady) {
      _logger.w('Map not ready (loaded: $_mapReady), skipping layer rebuild');
      return;
    }

    // Remove previous fire layers if they exist
    try {
      if (_layersAdded) {
        _layersAdded = false;
      }
    } catch (e) {
      _logger.e('Failed to remove existing layers: $e');
    }

    if (_fires.isEmpty) return;

    // Create clusters first
    _createClusters();

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
      // Add GeoJSON source - pass the object directly, not the JSON string
      final sourceIds = await _c.getSourceIds();
      if (sourceIds.contains('fires')) {
        await _c.setGeoJsonSource('fires', geojson); // update data in place
      } else {
        await _c.addSource('fires', m.GeojsonSourceProperties(data: geojson));
      }

      // Add large circle layer for heatmap effect (low zoom levels)
      final layerIds = await _c.getLayerIds();

      final heatLayerProperties = m.CircleLayerProperties(
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
      );

      if (layerIds.contains('fires-heat')) {
        await _c.setLayerProperties('fires-heat', heatLayerProperties);
      } else {
        await _c.addLayer('fires', 'fires-heat', heatLayerProperties);
      }

      // Add smaller circle layer for higher zoom levels (point representation)
      final pointLayerProperties = m.CircleLayerProperties(
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
      );

      if (layerIds.contains('fires-point')) {
        await _c.setLayerProperties('fires-point', pointLayerProperties);
      } else {
        await _c.addLayer('fires', 'fires-point', pointLayerProperties);
      }

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
            (c) => ClusterHelper.isPointInPolygon(coordinates, c.hull),
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

  // --- Clustering logic moved to ClusterHelper ---
  void _createClusters() {
    if (!mounted) return;

    if (_fires.isEmpty) {
      if (mounted) {
        setState(() => _clusters = []);
      }
      return;
    }

    // Check current zoom level - only show clusters at zoom 12 and higher
    final currentZoom = _c.cameraPosition?.zoom ?? 0;
    if (currentZoom < 12) {
      if (mounted) {
        setState(() => _clusters = []);
      }
      _logger.d('Zoom level $currentZoom < 12, hiding clusters');
      return;
    }

    _logger.d('Zoom level $currentZoom >= 12, showing clusters');

    final allClusters = ClusterHelper.createClusters(_fires, currentZoom);

    if (mounted) {
      setState(() => _clusters = allClusters);
      _logger.i(
        'Created ${allClusters.length} clusters from ${_fires.length} fires using ClusterHelper',
      );
    }
  }

  /// Add cluster layers to the map
  Future<void> _addClusterLayers() async {
    // Ensure map controller is ready and map is loaded
    if (!_mapReady) {
      _logger.w(
        'Map not ready (loaded: $_mapReady), skipping cluster layer addition',
      );
      return;
    }

    try {
      // Create GeoJSON for clusters
      final clusterFeatures = <Map<String, dynamic>>[];

      for (final cluster in _clusters) {
        if (cluster.hull.isEmpty) continue;

        // 0) lon/lat pairs
        final raw = cluster.hull.map((p) => [p.longitude, p.latitude]).toList();

        // 1–2) sanitize + simplify
        var ring = removeCollinear(sanitizeRing(raw));

        if (ring.length < 3) continue;

        // 3) force a simple shape – convex hull (prevents self-intersections)
        ring = convexHullLonLat(ring);
        if (ring.length < 3) continue;

        // 4) CCW (RFC 7946) + close
        ring = ensureOrientation(ring, clockwise: false);
        ring = closeRing(ring);
        if (ring.length < 4) continue;

        clusterFeatures.add({
          'type': 'Feature',
          'geometry': {
            'type': 'Polygon',
            'coordinates': [ring],
          },
          'properties': {
            'clusterId': _clusters.indexOf(cluster),
            'fireCount': cluster.points.length,
            'color':
                'rgba(${cluster.color.red}, ${cluster.color.green}, ${cluster.color.blue}, ${cluster.opacity})',
          },
        });
      }

      if (clusterFeatures.isNotEmpty) {
        final clusterGeojson = {
          'type': 'FeatureCollection',
          'features': clusterFeatures,
        };

        // Add cluster source
        final sourceIds = await _c.getSourceIds();
        if (sourceIds.contains('clusters')) {
          await _c.setGeoJsonSource(
            'clusters',
            clusterGeojson,
          ); // update data in place
        } else {
          await _c.addSource(
            'clusters',
            m.GeojsonSourceProperties(data: clusterGeojson),
          );
        }

        // Add cluster fill layer
        final layerIds = await _c.getLayerIds();
        if (layerIds.contains('fires-clusters')) {
          await _c.setLayerProperties(
            'fires-clusters',
            m.FillLayerProperties(fillColor: ['get', 'color']),
          );
        } else {
          await _c.addLayer(
            'clusters',
            'fires-clusters',
            m.FillLayerProperties(fillColor: ['get', 'color']),
            belowLayerId: 'fires-point',
            enableInteraction: false,
          );
        }

        _logger.i('Cluster layers added successfully');
      }
    } catch (e) {
      _logger.e('Failed to add cluster layers: $e');
    }
  }

  // --- UI helpers ---

  void _showFireInfo(FirePoint fire) {
    // Animate camera to center on the fire point with 60-degree tilt
    _c.animateCamera(
      m.CameraUpdate.newCameraPosition(
        m.CameraPosition(
          target: m.LatLng(fire.lat, fire.lon),
          zoom: 12.0, // Higher zoom for individual fire points
          tilt: 60.0, // Apply 60-degree tilt as requested
        ),
      ),
    );
  }

  void _showClusterInfo(FireCluster cluster) {
    // Calculate the center of the cluster using the helper
    final center = ClusterHelper.calculateClusterCenter(cluster);

    // Animate camera to center the cluster with 60-degree tilt
    _c.animateCamera(
      m.CameraUpdate.newCameraPosition(
        m.CameraPosition(
          target: center,
          zoom: 12.0, // Adjust zoom level as needed
          tilt: 60.0, // Apply 60-degree tilt as requested
        ),
      ),
    );
  }

  /// Set the initial map position to the user's current location
  /// This is called when we first get a location from the location stream
  void _setInitialPosition(Position position) {
    if (!_mapReady) {
      _logger.d('Map not ready yet, skipping initial position set');
      return;
    }

    try {
      _logger.d(
        'Setting initial map position to user location: ${position.latitude}, ${position.longitude}',
      );

      // Animate camera to the user's current location with a reasonable zoom level
      _c.animateCamera(
        m.CameraUpdate.newCameraPosition(
          m.CameraPosition(
            target: m.LatLng(position.latitude, position.longitude),
            zoom: 11.0, // Good zoom level for seeing local area
            tilt: 45.0, // Moderate tilt for better perspective
          ),
        ),
      );
    } catch (e) {
      _logger.e('Failed to set initial position: $e');
    }
  }

  // --- Location tracking methods ---

  void _setupLocationListener() {
    _locationSubscription = ref
        .read(locationFirestoreProvider.stream)
        .listen(
          (position) {
            if (position != null && mounted) {
              // first time we get a position, update the current location marker
              if (_currentPosition == null) {
                _setInitialPosition(position);
              }
              setState(() {
                _currentPosition = position;
              });

              // Update the current location marker if map is ready
              if (_mapReady) {
                _updateCurrentLocationMarker(position);
              }
            }
          },
          onError: (error) {
            _logger.e('Location stream error: $error');
          },
        );
  }

  /// Set up stream subscription for other users updates
  void _setupOtherUsersStream() {
    _otherUsersStreamSubscription = ref
        .read(otherUsersStreamProvider.stream)
        .listen(
          (allUsers) {
            if (mounted) {
              // Filter users to only those in the current viewport
              _filterAndUpdateOtherUsers(allUsers);
            }
          },
          onError: (error) {
            _logger.e('Other users stream error: $error');
          },
        );
  }

  /// Filter users to current viewport and update markers
  void _filterAndUpdateOtherUsers(Map<String, OtherUserLocation> allUsers) {
    if (!_mapReady) return;

    try {
      // Get current viewport bounds
      _c.getVisibleRegion().then((bounds) {
        final bbox = {
          'minLat': bounds.southwest.latitude,
          'maxLat': bounds.northeast.latitude,
          'minLng': bounds.southwest.longitude,
          'maxLng': bounds.northeast.longitude,
        };

        // Filter users to current viewport
        final usersInViewport = ref.read(otherUsersInBBoxProvider(bbox));

        setState(() {
          _otherUsersInViewport = usersInViewport;
        });

        // Update markers on the map
        _updateOtherUserMarkers();
      });
    } catch (e) {
      _logger.e('Failed to filter other users to viewport: $e');
    }
  }

  Future<void> _updateCurrentLocationMarker(Position position) async {
    if (!_mapReady) return;

    try {
      final ll = m.LatLng(position.latitude, position.longitude);

      if (_currentLocationCircle == null) {
        // Create a circle annotation as the "current location" marker
        _currentLocationCircle = await _c.addCircle(
          m.CircleOptions(
            geometry: ll,
            circleRadius: 10.0,
            circleColor: "#4285F4", // blue dot
            circleStrokeColor: "#FFFFFF", // white ring
            circleStrokeWidth: 2.0,
            circleOpacity: 1.0,
          ),
        );
        _logger.d(
          'Current location circle created at ${position.latitude}, ${position.longitude}',
        );
      } else {
        // Move the existing annotation
        await _c.updateCircle(
          _currentLocationCircle!,
          m.CircleOptions(geometry: ll),
        );
      }
    } catch (e, st) {
      _logger.e('Failed to update current location marker: $e\n$st');
    }
  }
}
