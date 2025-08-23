import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
            styleString: "assets/styles/style-default.json",
            trackCameraPosition: true,
            initialCameraPosition: const m.CameraPosition(
              target: m.LatLng(42.0814621, 19.0822514),
              zoom: 10,
              tilt: 80,
            ),
            onMapCreated: (c) async {
              _c = c;

              // One tap handler; we'll map symbol.id -> FirePoint
              _c.onSymbolTapped.add((m.Symbol s) {
                final fp = _featureBySymbolId[s.id];
                if (fp != null) _showFireInfo(fp);
              });
            },
            onStyleLoadedCallback: _refreshFromVisibleRegion,
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

          // Simple legend
          Positioned(bottom: 16, right: 16, child: _legend()),
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
        } catch (_) {}
        _symbolById.remove(entry.key);
        _featureBySymbolId.remove(entry.value.id);
      }
    }

    // Optionally register a custom icon once (not required here)
    await _ensureIconRegistered();

    // Add symbols for _fires
    for (int i = 0; i < _fires.length; i++) {
      final fire = _fires[i];
      await _addFireSymbol(fire, i);
    }
  }

  Future<void> _ensureIconRegistered() async {
    if (_iconRegistered) return;
    try {
      final data = await rootBundle.load('assets/images/pin-3d.png');
      final bytes = data.buffer.asUint8List();
      await _c.addImage('pin-3d', bytes);
      _iconRegistered = true;
    } catch (_) {
      // If it fails, we fall back to text-only symbols
    }
  }

  Future<void> _addFireSymbol(FirePoint fire, int index) async {
    // Choose color by confidence
    String markerColor = '#FF6B35';
    final conf = fire.confidence;
    if (conf != null) {
      if (conf >= 80) {
        markerColor = '#FF0000';
      } else if (conf < 50) {
        markerColor = '#FFA500';
      }
    }

    final symbol = await _c.addSymbol(
      m.SymbolOptions(
        geometry: m.LatLng(fire.lat, fire.lon),
        iconImage: _iconRegistered ? 'pin-3d' : null,
        iconSize: 1.0,
        iconColor: _iconRegistered ? null : markerColor,
        textField: _iconRegistered ? null : '🔥',
        textSize: _iconRegistered ? 0 : 16.0,
        textColor: _iconRegistered ? null : markerColor,
        textHaloColor: _iconRegistered ? null : '#FFFFFF',
        textHaloWidth: _iconRegistered ? 0 : 2.0,
      ),
    );

    final key = 'fire-$index';
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

  Widget _legend() {
    Widget item(String label, String hex) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: Color(int.parse(hex.replaceAll('#', '0xFF'))),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Fire Confidence',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          item('High (80%+)', '#FF0000'),
          item('Medium (50–79%)', '#FF6B35'),
          item('Low (<50%)', '#FFA500'),
        ],
      ),
    );
  }
}
