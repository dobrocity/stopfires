import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as m;
import 'package:stopfires/providers/firms_provider.dart';
import 'package:stopfires/providers/firms_service.dart';

class FiresMapPage extends ConsumerStatefulWidget {
  const FiresMapPage({super.key});

  @override
  ConsumerState<FiresMapPage> createState() => _FiresMapPageState();
}

class _FiresMapPageState extends ConsumerState<FiresMapPage> {
  late m.MapLibreMapController _c;
  final Logger _logger = Logger();
  // UI / state
  final _symbolById = <String, m.Symbol>{};
  final _featureBySymbolId = <String, FirePoint>{};
  bool _iconRegistered = false;
  bool _loading = false;
  String? _error;

  // Data saved in state
  List<FirePoint> _fires = [];

  Timer? _debounce;
  m.CameraPosition? _lastCameraPosition;
  static const Duration _debounceDelay = Duration(milliseconds: 800);

  @override
  void dispose() {
    _debounce?.cancel();
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
              target: m.LatLng(42.0814621, 19.0822514),
              zoom: 10,
              tilt: 60,
            ),
            onMapCreated: (c) async {
              _c = c;
              _logger.i('Map created successfully');

              // One tap handler; we'll map symbol.id -> FirePoint
              _c.onSymbolTapped.add((m.Symbol s) {
                final fp = _featureBySymbolId[s.id];
                if (fp != null) _showFireInfo(fp);
              });
            },

            onStyleLoadedCallback: () {
              _logger.i('Map style loaded successfully');
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
                    color: Colors.red.withOpacity(0.9),
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

      await _rebuildFireSymbols();
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

  // --- Rendering symbols from state ---

  Future<void> _rebuildFireSymbols() async {
    // Remove previous “fire-” symbols only
    for (final entry in _symbolById.entries.toList()) {
      if (entry.key.startsWith('fire-')) {
        try {
          await _c.removeSymbol(entry.value);
        } catch (e) {
          _logger.e('Failed to remove symbol: $e');
        }
        _symbolById.remove(entry.key);
        _featureBySymbolId.remove(entry.value.id);
      }
    }
    // Optionally register a custom icon once (not required here)
    await _ensureIconRegistered();

    // Add symbols for _fires
    for (int i = 0; i < _fires.length; i++) {
      final fire = _fires[i];
      try {
        await _addFireSymbol(fire, i);
      } catch (e) {
        _logger.e('Failed to add fire symbol: $e');
      }
    }
  }

  Future<void> _ensureIconRegistered() async {
    if (_iconRegistered) return;
    try {
      final data = await rootBundle.load('assets/images/map_fire_icon.png');
      final bytes = data.buffer.asUint8List();
      await _c.addImage('map_fire_icon', bytes);
      _iconRegistered = true;
      _logger.i('Fire icon registered successfully');
    } catch (e) {
      // If it fails, we fall back to text-only symbols (except on web)
      _logger.w('Failed to register fire icon: $e');
      if (kIsWeb) {
        // On web, we'll use a simple colored circle instead of text
        _iconRegistered = false;
        _logger.i('Using web fallback (marker icon)');
      }
    }
  }

  Future<void> _addFireSymbol(FirePoint fire, int index) async {
    final key = 'fire-${fire.lat.toString()}-${fire.lon.toString()}';
    if (_symbolById.containsKey(key)) {
      return;
    }

    // Create symbol options with conditional text properties
    final symbolOptions = m.SymbolOptions(
      geometry: m.LatLng(fire.lat, fire.lon),
      iconImage: _iconRegistered ? 'map_fire_icon' : null,
      iconSize: (!_iconRegistered) ? 0.8 : 1.0,
      textField: (!_iconRegistered) ? '🔥' : null,
      textSize: (!_iconRegistered) ? 16.0 : 0,
      textHaloColor: (!_iconRegistered) ? '#FFFFFF' : null,
      textHaloWidth: (!_iconRegistered) ? 2.0 : 0,
      // For web fallback, use a simple colored circle
      iconColor: (!_iconRegistered) ? '#FF4444' : null,
    );

    _logger.d(
      'Adding fire symbol with options: iconImage=${symbolOptions.iconImage}, textField=${symbolOptions.textField}',
    );

    final symbol = await _c.addSymbol(symbolOptions);

    _symbolById[key] = symbol;
    _featureBySymbolId[symbol.id] = fire;
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
}
