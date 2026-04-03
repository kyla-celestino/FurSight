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
  String _filter        = 'all';
  bool   _isLoading     = true;
  bool   _mapInitialized = false;
  List<AnimalSighting> _lastSightings = [];

  static const double uplbLat = 14.1650;
  static const double uplbLng = 121.2422;
  // ── REPLACE WITH YOUR KEY ────────────────────────────────
  static const String mapsApiKey = 'AIzaSyA3MTYwfOx31ITPSK3DcZQweK9KZMVR2dY';
  // ────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (error) {
            print('WebView error: ${error.description}');
          },
        ),
      )
      ..loadHtmlString(_buildHeatmapHtml([]));
  }

  String _buildHeatmapHtml(List<AnimalSighting> sightings) {
    final points = sightings
        .map((s) => '{lat: ${s.latitude}, lng: ${s.longitude}}')
        .join(',');

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="initial-scale=1.0">
  <meta charset="utf-8">
  <style>
    html, body { 
      height: 100%; 
      margin: 0; 
      padding: 0;
    }
    #map { 
      height: 100%; 
      width: 100%;
    }
  </style>
</head>
<body>
  <div id="map"></div>
  <script>
    let map;
    let heatmap;

    function initMap() {
      map = new google.maps.Map(document.getElementById("map"), {
        zoom: 16,
        center: { lat: $uplbLat, lng: $uplbLng },
        mapTypeId: "roadmap",
        disableDefaultUI: false,
      });

      const heatmapData = [$points];
      const latLngPoints = heatmapData.map(
        p => new google.maps.LatLng(p.lat, p.lng)
      );

      heatmap = new google.maps.visualization.HeatmapLayer({
        data: latLngPoints,
        map: map,
        radius: 40,
        opacity: 0.8,
      });

      heatmapData.forEach(p => {
        new google.maps.Marker({
          position: { lat: p.lat, lng: p.lng },
          map: map,
          icon: {
            path: google.maps.SymbolPath.CIRCLE,
            scale: 8,
            fillColor: "#4CAF50",
            fillOpacity: 0.9,
            strokeColor: "white",
            strokeWeight: 2,
          }
        });
      });
    }

    window.onerror = function(msg, url, line) {
      console.log("Error: " + msg);
    };
  </script>
  <script
    src="https://maps.googleapis.com/maps/api/js?key=$mapsApiKey&libraries=visualization&callback=initMap"
    async defer>
  </script>
</body>
</html>
''';
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
              underline: const SizedBox(),
              icon: const Icon(Icons.filter_list, color: Colors.white),
              items: const [
                DropdownMenuItem(
                  value: 'all',
                  child: Text('All',
                    style: TextStyle(color: Colors.white)),
                ),
                DropdownMenuItem(
                  value: 'cat',
                  child: Text('Cats',
                    style: TextStyle(color: Colors.white)),
                ),
                DropdownMenuItem(
                  value: 'dog',
                  child: Text('Dogs',
                    style: TextStyle(color: Colors.white)),
                ),
              ],
              onChanged: (val) {
                if (val == null) return;
                setState(() {
                  _filter = val;
                  _isLoading = true;
                  _webController.loadHtmlString(
                    _buildHeatmapHtml(_lastSightings),
                  );
                });
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
          if (snapshot.hasData) {
            final sightings = snapshot.data!;
            // Only reload map if data actually changed
            if (sightings.length != _lastSightings.length) {
              _lastSightings = sightings;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _webController.loadHtmlString(
                    _buildHeatmapHtml(sightings),
                  );
                }
              });
            }
          }

          return Stack(
            children: [
              WebViewWidget(controller: _webController),
              if (_isLoading)
                const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        color: Color(0xFF4CAF50),
                      ),
                      SizedBox(height: 16),
                      Text('Loading map...'),
                    ],
                  ),
                ),
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
                          '${_lastSightings.length} sightings',
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