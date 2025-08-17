import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:dio/dio.dart';
import 'dart:async';
import 'package:logger/logger.dart';

void main() => runApp(const FiresApp());

class FiresApp extends StatelessWidget {
  const FiresApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stop Fires',
      theme: ThemeData(useMaterial3: true),
      home: const FiresMapPage(),
    );
  }
}

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

class FiresMapPage extends StatefulWidget {
  const FiresMapPage({super.key});
  @override
  State<FiresMapPage> createState() => _FiresMapPageState();
}

class _FiresMapPageState extends State<FiresMapPage> {
  final mapController = MapController();
  final _logger = Logger();
  List<FirePoint> fires = [];
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
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {
              mapReady = true;
              mapInitializing = false;
            });
            _setupMapListeners();
            _loadFires(); // Load fires AFTER map is ready
          }
        });
      }
    });
  }

  void _setupMapListeners() {
    try {
      // Ensure map controller is properly initialized and safe to use
      if (!mounted) {
        _logger.d('Widget not mounted, skipping listener setup');
        return;
      }

      // Add a small delay to ensure FlutterMap is fully rendered
      Future.delayed(const Duration(milliseconds: 100), () {
        if (!mounted) return;

        try {
          // Check if map controller is safe to use
          mapController.mapEventStream.listen(
            (event) {
              try {
                if (event is MapEventMoveEnd) {
                  // Debounce to avoid excessive API calls
                  _debounceTimer?.cancel();
                  setState(() => updatingViewport = true);
                  _debounceTimer = Timer(const Duration(milliseconds: 500), () {
                    if (mounted) {
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
      if (!mapReady) {
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

  Future<void> _loadFires() async {
    setState(() => loading = true);
    try {
      _logger.i('Loading fires for window: $window, sensor: $sensor');
      final data = await fetchFires(window: window, sensor: sensor);
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

      setState(() => fires = data);
      _logger.d('Fires state updated: ${fires.length} fires');
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
    final markers = fires.map((f) {
      return Marker(
        point: LatLng(f.lat, f.lon),
        width: 28,
        height: 28,
        child: GestureDetector(
          onTap: () => _showFireSheet(f),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.85),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      );
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Stop Fires - ${fires.length} fires'),
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
          FlutterMap(
            mapController: mapController,
            options: const MapOptions(
              initialCenter: LatLng(59.437, 24.7536), // Tallinn as default
              initialZoom: 5,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'org.stopfires.app',
              ),
              MarkerLayer(markers: markers),
            ],
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
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (mapReady && _getSafeMapBounds() != null) ...[
                      Text(
                        'Viewport: ${_getSafeMapBounds()!.west.toStringAsFixed(2)}, ${_getSafeMapBounds()!.south.toStringAsFixed(2)} to ${_getSafeMapBounds()!.east.toStringAsFixed(2)}, ${_getSafeMapBounds()!.north.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ] else if (mapReady) ...[
                      Text(
                        'Map ready - waiting for bounds...',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.orange[600],
                        ),
                      ),
                    ] else ...[
                      Text(
                        'Initializing map...',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.blue[600],
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
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
      // Use default bounds if map not ready yet
      if (sensor == 'viirs') {
        url =
            'https://firms.modaps.eosdis.nasa.gov/api/area/csv/a372f5f316a9edc52f4a8726902a3606/VIIRS_SNPP_NRT/23.0,56.0,28.5,60.0/1';
      } else {
        url =
            'https://firms.modaps.eosdis.nasa.gov/api/area/csv/a372f5f316a9edc52f4a8726902a3606/MODIS_NRT/23.0,56.0,28.5,60.0/1';
      }
    } else {
      // Get current map bounds safely
      final bounds = _getSafeMapBounds();

      if (bounds == null) {
        // Fallback to default bounds if map not ready yet
        if (sensor == 'viirs') {
          url =
              'https://firms.modaps.eosdis.nasa.gov/api/area/csv/a372f5f316a9edc52f4a8726902a3606/VIIRS_SNPP_NRT/23.0,56.0,28.5,60.0/1';
        } else {
          url =
              'https://firms.modaps.eosdis.nasa.gov/api/area/csv/a372f5f316a9edc52f4a8726902a3606/MODIS_NRT/23.0,56.0,28.5,60.0/1';
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

    final resp = await dio.get(
      url,
      options: Options(responseType: ResponseType.plain),
    );

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
