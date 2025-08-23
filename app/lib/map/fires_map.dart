import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as m;

class FiresMapPage extends StatefulWidget {
  const FiresMapPage({super.key});

  @override
  State<FiresMapPage> createState() => _FiresMapPageState();
}

class _FiresMapPageState extends State<FiresMapPage> {
  m.MapLibreMapController? _c;

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
        onMapClick: (p, latLng) async {
          final cam = _c?.cameraPosition;
          debugPrint(
            '   camera: z=${cam?.zoom}, tilt=${cam?.tilt}, bearing=${cam?.bearing}',
          );
        },
      ),
    );
  }
}
