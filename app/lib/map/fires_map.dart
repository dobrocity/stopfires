import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as m;

class FiresMapPage extends StatefulWidget {
  const FiresMapPage({super.key});

  @override
  State<FiresMapPage> createState() => _FiresMapPageState();
}

class _FiresMapPageState extends State<FiresMapPage> {
  m.MapLibreMapController? _c;
  int idx = 0;

  String styleUrl() {
    return "assets/styles/style-default.json";
  }

  void _reload() async {
    if (_c == null) return;
    final s = styleUrl();
    debugPrint(
      '🔄 setStyleString(${s.length} chars / ${s.startsWith('http') ? 'URL' : 'JSON'})',
    );
    // await _c!.setStyleString(s);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MapLibre Debug'),
        actions: [
          IconButton(
            tooltip: 'Swap style',
            icon: const Icon(Icons.layers),
            onPressed: () {
              setState(() => idx++);
              _reload();
            },
          ),
          IconButton(
            tooltip: 'Log cam',
            icon: const Icon(Icons.center_focus_strong),
            onPressed: () async {
              final cam = _c?.cameraPosition;
              debugPrint(
                '🎥 camera: ${cam?.target.latitude}, '
                '${cam?.target.longitude}, z=${cam?.zoom}, t=${cam?.tilt}, b=${cam?.bearing}',
              );
              final r = await _c?.getVisibleRegion();
              debugPrint('🧭 bounds: ${r?.toString()}');
            },
          ),
        ],
      ),
      body: m.MapLibreMap(
        styleString: styleUrl(),
        trackCameraPosition: true,
        initialCameraPosition: const m.CameraPosition(
          target: m.LatLng(42.0814621, 19.0822514),
          zoom: 10,
          tilt: 80,
        ),
        onMapCreated: (c) async {
          _c = c;
          await Future.delayed(const Duration(milliseconds: 100));
          await _c?.animateCamera(
            m.CameraUpdate.newCameraPosition(
              const m.CameraPosition(
                target: m.LatLng(42.0814621, 19.0822514),
                zoom: 10,
                tilt: 80,
                bearing: 0,
              ),
            ),
          );
        },
        onStyleLoadedCallback: () async {
          debugPrint('🎨 Style loaded (callback fired)');
          final cam = _c?.cameraPosition;
          debugPrint(
            '   camera after style: z=${cam?.zoom}, tilt=${cam?.tilt}',
          );
        },
        onMapIdle: () => debugPrint('🛑 Map idle'),
        onCameraIdle: () => debugPrint('🎬 Camera idle'),
        onMapClick: (p, latLng) =>
            debugPrint('👆 tap: ${latLng.latitude}, ${latLng.longitude}'),
      ),
    );
  }
}
