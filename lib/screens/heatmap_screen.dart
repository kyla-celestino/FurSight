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
  String _filter         = 'all';
  bool   _isLoading      = true;
  List<AnimalSighting> _lastSightings = [];

  static const double uplbLat    = 14.1650;
  static const double uplbLng    = 121.2422;
  static const String mapsApiKey = 'AIzaSyA3MTYwfOx31ITPSK3DcZQweK9KZMVR2dY';
  // ── PASTE YOUR MAP ID HERE ───────────────────────────────
  static const String mapId      = '9382c9693e221976ab252ab2';
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
            debugPrint('WebView error: ${error.description}');
          },
        ),
      )
      ..loadHtmlString(_buildHeatmapHtml([]));
  }

  String _buildHeatmapHtml(List<AnimalSighting> sightings) {
    // Build JS array of sighting objects with nickname fetched from Firestore
    // We pass lat, lng, animalType, nickname, and individualId
    final filtered = _filter == 'all'
        ? sightings
        : sightings.where((s) => s.animalType == _filter).toList();

    // Group sightings by individualId to get unique locations per individual
    final Map<String, AnimalSighting> uniqueIndividuals = {};
    for (final s in filtered) {
      if (!uniqueIndividuals.containsKey(s.individualId)) {
        uniqueIndividuals[s.individualId] = s;
      }
    }

    // Build heatmap points (all sightings for heat circles)
    final heatPoints = filtered
        .map((s) => '{lat: ${s.latitude}, lng: ${s.longitude}, '
            'type: "${s.animalType}"}')
        .join(',');

    // Build marker points (one per unique individual, latest sighting)
    final markerPoints = uniqueIndividuals.values
        .map((s) => '{lat: ${s.latitude}, lng: ${s.longitude}, '
            'type: "${s.animalType}", '
            'id: "${s.individualId}"}')
        .join(',');

    // Nickname map: individualId -> nickname (fetched async in JS via Flutter channel)
    // We pass nicknames as a JS object built from Firestore data
    // Since we can't do async Firestore in HTML, we build the nickname map in Dart
    final nicknameMapEntries = _lastSightings
        .map((s) => '"${s.individualId}": "${s.individualId}"')
        .toList();
    // We'll fetch nicknames via a separate approach — pass individualId as label for now
    // and have the JS show a loading state that gets replaced

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
    .cat-pin {
      background: #FF9800;
      border: 2px solid #E65100;
      border-radius: 50% 50% 50% 0;
      width: 32px;
      height: 32px;
      transform: rotate(-45deg);
      display: flex;
      align-items: center;
      justify-content: center;
      box-shadow: 0 2px 6px rgba(0,0,0,0.3);
      cursor: pointer;
    }
    .cat-pin span {
      transform: rotate(45deg);
      font-size: 16px;
      line-height: 1;
    }
    .dog-pin {
      background: #795548;
      border: 2px solid #3E2723;
      border-radius: 50% 50% 50% 0;
      width: 32px;
      height: 32px;
      transform: rotate(-45deg);
      display: flex;
      align-items: center;
      justify-content: center;
      box-shadow: 0 2px 6px rgba(0,0,0,0.3);
      cursor: pointer;
    }
    .dog-pin span {
      transform: rotate(45deg);
      font-size: 16px;
      line-height: 1;
    }
    .info-window {
      font-family: Arial, sans-serif;
      font-size: 13px;
      min-width: 120px;
    }
    .info-window .name {
      font-weight: bold;
      font-size: 14px;
      color: #333;
    }
    .info-window .type {
      color: #888;
      font-size: 11px;
      text-transform: uppercase;
    }
  </style>
</head>
<body>
  <div id="map"></div>
  <script>
    let map;
    const heatPoints  = [$heatPoints];
    const markerPoints = [$markerPoints];

    // Nickname map passed from Flutter — individualId -> nickname
    // Updated each time map reloads
    const nicknameMap = {};

    async function initMap() {
      const { Map } = await google.maps.importLibrary("maps");
      const { AdvancedMarkerElement } = await google.maps.importLibrary("marker");

      map = new Map(document.getElementById("map"), {
        zoom: 16,
        center: { lat: $uplbLat, lng: $uplbLng },
        mapId: "$mapId",
        mapTypeControl: true,
        zoomControl: true,
        fullscreenControl: true,
      });

      const infoWindow = new google.maps.InfoWindow();

      // ── Draw heat circles ────────────────────────────────
      heatPoints.forEach(p => {
        const color = p.type === 'cat' ? '#FF9800' : '#795548';
        new google.maps.Circle({
          strokeColor:   color,
          strokeOpacity: 0.3,
          strokeWeight:  1,
          fillColor:     color,
          fillOpacity:   0.20,
          map:           map,
          center:        { lat: p.lat, lng: p.lng },
          radius:        25,
        });
      });

      // ── Draw custom pins per unique individual ───────────
      markerPoints.forEach(p => {
        const iscat  = p.type === 'cat';
        const emoji  = iscat ? '🐱' : '🐶';
        const cls    = iscat ? 'cat-pin' : 'dog-pin';

        const pinEl  = document.createElement('div');
        pinEl.className = cls;
        pinEl.innerHTML = '<span>' + emoji + '</span>';

        const marker = new AdvancedMarkerElement({
          position: { lat: p.lat, lng: p.lng },
          map:      map,
          content:  pinEl,
          title:    p.id,
        });

        marker.addListener('click', () => {
          const nickname = nicknameMap[p.id] || p.id;
          const typeLabel = iscat ? 'Cat' : 'Dog';
          infoWindow.setContent(
            '<div class="info-window">' +
            '<div class="type">' + typeLabel + '</div>' +
            '<div class="name">' + nickname + '</div>' +
            '</div>'
          );
          infoWindow.open(map, marker);
        });
      });
    }

    window.onerror = function(msg, url, line) {
      console.log("JS Error: " + msg + " at line " + line);
    };

    window.initMap = initMap;
  </script>
  <script
    src="https://maps.googleapis.com/maps/api/js?key=$mapsApiKey&v=beta&libraries=maps,marker&callback=initMap"
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
                  child: Text('🐱 Cats',
                    style: TextStyle(color: Colors.white)),
                ),
                DropdownMenuItem(
                  value: 'dog',
                  child: Text('🐶 Dogs',
                    style: TextStyle(color: Colors.white)),
                ),
              ],
              onChanged: (val) {
                if (val == null) return;
                setState(() {
                  _filter    = val;
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
