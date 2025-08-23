import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as m;

class FiresMapPage extends StatefulWidget {
  const FiresMapPage({super.key});

  @override
  State<FiresMapPage> createState() => _FiresMapPageState();
}

class _FiresMapPageState extends State<FiresMapPage> {
  final _symbolById = <String, m.Symbol>{};
  bool _iconRegistered = false;
  late m.MapLibreMapController _c;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MapLibre Debug')),
      body: m.MapLibreMap(
        styleString: "assets/styles/style-default.json",
        trackCameraPosition: true,
        initialCameraPosition: const m.CameraPosition(
          target: m.LatLng(42.0814621, 19.0822514),
          zoom: 10,
          tilt: 80,
        ),
        onMapCreated: (c) async {
          _c = c;

          // Set up symbol tap handling
          _c!.onSymbolTapped.add((m.Symbol symbol) {
            if (_symbolById.containsValue(symbol)) {
              final key = _symbolById.entries
                  .firstWhere((entry) => entry.value.id == symbol.id)
                  .key;
              debugPrint('Tapped symbol: $key');
            }
          });
        },
        onStyleLoadedCallback: () async {
          await addClickableSymbol(m.LatLng(42.0814621, 19.0822514));
        },
      ),
    );
  }

  // Call this inside onStyleLoadedCallback
  Future<void> addClickableSymbol(m.LatLng at) async {
    // 1) Ensure style is loaded (call this from onStyleLoadedCallback)
    // 2) Register the icon once
    if (!_iconRegistered) {
      try {
        final ByteData data = await rootBundle.load('assets/images/pin-3d.png');
        final Uint8List bytes = data.buffer.asUint8List();
        await _c.addImage('pin-3d', bytes);
        _iconRegistered = true;
      } catch (e) {
        // If icon fails, we’ll still add a text-only symbol below
        // debugPrint('addImage failed: $e');
      }
    }

    // 3) Add the symbol (use the SAME name you registered)
    try {
      final sym = await _c.addSymbol(
        m.SymbolOptions(
          geometry: at,
          iconImage: _iconRegistered
              ? 'pin-3d'
              : null, // <-- match addImage key
          iconSize: 1.0,
          textField: _iconRegistered ? null : '🔥', // fallback if no icon
          textSize: 24.0,
          textColor: '#FF0000',
          textHaloColor: '#FFFFFF',
          textHaloWidth: 1.0,
        ),
      );
      _symbolById['obj-1'] = sym;
    } catch (e) {
      // debugPrint('addSymbol failed: $e');
    }
  }
}
