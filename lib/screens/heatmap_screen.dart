import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/firebase_service.dart';
import '../models/animal_sighting.dart';

class HeatmapScreen extends StatefulWidget {
  const HeatmapScreen({super.key});

  @override
  State<HeatmapScreen> createState() => _HeatmapScreenState();
}

class _HeatmapScreenState extends State<HeatmapScreen> {
  final _firebaseService = FirebaseService();
  late WebViewController _webController;
  String _filter    = 'all';
  bool   _isLoading = true;

  static const double UPLB_LAT = 14.1650;
  static const double UPLB_LNG = 121.2422;

  // ── REPLACE THIS WITH YOUR ACTUAL GOOGLE MAPS API KEY ─────
  static const String MAPS_API_KEY = 'AIzaSyA3MTYwfOx31ITPSK3DcZQweK9KZMVR2dY';
  // ──────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => setState(() => _isLoading = false),
        ),
      )
      ..loadHtmlString(_buildHeatmapHtml([]));
  }

  String _buildHeatmapHtml(List<AnimalSighting> sightings) {
    final points = sightings
        .map((s) => '{"lat": ${s.latitude}, "lng": ${s.longitude}}')
        .join(',');

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body { margin: 0; padding: 0; }
    #map { width: 100vw; height: 100vh; }
  </style>
</head>
<body>
  <div id="map"></div>
  <script>
    function initMap() {
      const uplb = { lat: $UPLB_LAT, lng: $UPLB_LNG };
      const map = new google.maps.Map(document.getElementById("map"), {
        zoom: 16,
        center: uplb,
        mapTypeId: "roadmap",
      });

      const heatmapData = [$points];
      const latLngPoints = heatmapData.map(
        p => new google.maps.LatLng(p.lat, p.lng)
      );

      new google.maps.visualization.HeatmapLayer({
        data: latLngPoints,
        map: map,
        radius: 30,
        opacity: 0.7,
      });

      heatmapData.forEach(p => {
        new google.maps.Marker({
          position: { lat: p.lat, lng: p.lng },
          map: map,
          icon: {
            path: google.maps.SymbolPath.CIRCLE,
            scale: 6,
            fillColor: "#4CAF50",
            fillOpacity: 0.8,
            strokeColor: "white",
            strokeWeight: 1,
          }
        });
      });
    }
  </script>
  <script async
    src="https://maps.googleapis.com/maps/api/js?key=$MAPS_API_KEY&libraries=visualization&callback=initMap">
  </script>
</body>
</html>
''';
  }

  void _updateMap(List<AnimalSighting> sightings) {
    _webController.loadHtmlString(_buildHeatmapHtml(sightings));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Heatmap'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: DropdownButton<String>(
              value: _filter,
              dropdownColor: const Color(0xFF4CAF50),
              style: const TextStyle(color: Colors.white),
              underline: const SizedBox(),
              icon: const Icon(Icons.filter_list, color: Colors.white),
              items: const [
                DropdownMenuItem(
                  value: 'all',
                  child: Text(
                    'All',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                DropdownMenuItem(
                  value: 'cat',
                  child: Text(
                    'Cats',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                DropdownMenuItem(
                  value: 'dog',
                  child: Text(
                    'Dogs',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
              onChanged: (val) {
                if (val == null) return;
                setState(() => _filter = val);
              },
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<AnimalSighting>>(
        stream: _firebaseService.getSightingsStream(
          animalType: _filter == 'all' ? null : _filter,
        ),
        builder: (context, snapshot) {
          final sightings = snapshot.data ?? [];

          if (snapshot.hasData) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _updateMap(sightings);
            });
          }

          return Stack(
            children: [
              WebViewWidget(controller: _webController),
              if (_isLoading)
                const Center(child: CircularProgressIndicator()),
              Positioned(
                bottom: 16,
                left: 16,
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: Color(0xFF4CAF50),
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${sightings.length} sightings',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}