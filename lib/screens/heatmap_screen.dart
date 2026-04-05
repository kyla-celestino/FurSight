import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/firebase_service.dart';
import '../models/animal_sighting.dart';

class HeatmapScreen extends StatefulWidget {
  final List<AnimalSighting>? individualSightings;
  final String? individualNickname;
  final String? animalType;

  const HeatmapScreen({
    super.key,
    this.individualSightings,
    this.individualNickname,
    this.animalType,
  });

  @override
  State<HeatmapScreen> createState() => _HeatmapScreenState();
}

class _HeatmapScreenState extends State<HeatmapScreen> {
  final _firebaseService = FirebaseService();
  late WebViewController _webController;
  String _filter         = 'all';
  bool   _isLoading      = true;
  List<AnimalSighting> _lastSightings = [];

  bool get _isIndividualMode => widget.individualSightings != null;

  static const double uplbLat    = 14.1650;
  static const double uplbLng    = 121.2422;
  static const String mapsApiKey = 'AIzaSyA3MTYwfOx31ITPSK3DcZQweK9KZMVR2dY';
  static const String mapId      = '9382c9693e221976ab252ab2';

  @override
  void initState() {
    super.initState();
    if (_isIndividualMode) {
      _lastSightings = widget.individualSightings!;
      _filter = widget.animalType ?? 'all';
    }
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
      ..loadHtmlString(
        _isIndividualMode
          ? _buildHeatmapHtml(_lastSightings)
          : _buildHeatmapHtml([]),
      );
  }

  Map<String, double> _computeCenter(List<AnimalSighting> sightings) {
    if (sightings.isEmpty) return {'lat': uplbLat, 'lng': uplbLng};
    final avgLat = sightings.map((s) => s.latitude).reduce((a, b) => a + b)
        / sightings.length;
    final avgLng = sightings.map((s) => s.longitude).reduce((a, b) => a + b)
        / sightings.length;
    return {'lat': avgLat, 'lng': avgLng};
  }

  String _buildHeatmapHtml(List<AnimalSighting> sightings) {
    final filtered = _isIndividualMode
        ? sightings
        : (_filter == 'all'
            ? sightings
            : sightings.where((s) => s.animalType == _filter).toList());

    final Map<String, AnimalSighting> uniqueIndividuals = {};
    for (final s in filtered) {
      if (!uniqueIndividuals.containsKey(s.individualId)) {
        uniqueIndividuals[s.individualId] = s;
      }
    }

    final heatPoints = filtered
        .map((s) => '{lat: ${s.latitude}, lng: ${s.longitude}, '
            'type: "${s.animalType}"}')
        .join(',');

    final markerPoints = uniqueIndividuals.values
        .map((s) => '{lat: ${s.latitude}, lng: ${s.longitude}, '
            'type: "${s.animalType}", '
            'id: "${s.individualId}"}')
        .join(',');

    final center    = _computeCenter(filtered);
    final centerLat = center['lat']!;
    final centerLng = center['lng']!;
    final zoom      = _isIndividualMode ? 17 : 16;
    final individualTitle = _isIndividualMode
        ? (widget.individualNickname ?? 'Individual')
        : '';

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="initial-scale=1.0">
  <meta charset="utf-8">
  <style>
    html, body { height: 100%; margin: 0; padding: 0; }
    #map { height: 100%; width: 100%; }
    .cat-pin {
      background: #FF9800; border: 2px solid #E65100;
      border-radius: 50% 50% 50% 0; width: 32px; height: 32px;
      transform: rotate(-45deg); display: flex; align-items: center;
      justify-content: center; box-shadow: 0 2px 6px rgba(0,0,0,0.3); cursor: pointer;
    }
    .cat-pin span { transform: rotate(45deg); font-size: 16px; line-height: 1; }
    .dog-pin {
      background: #795548; border: 2px solid #3E2723;
      border-radius: 50% 50% 50% 0; width: 32px; height: 32px;
      transform: rotate(-45deg); display: flex; align-items: center;
      justify-content: center; box-shadow: 0 2px 6px rgba(0,0,0,0.3); cursor: pointer;
    }
    .dog-pin span { transform: rotate(45deg); font-size: 16px; line-height: 1; }
    .info-window { font-family: Arial, sans-serif; font-size: 13px; min-width: 120px; }
    .info-window .name { font-weight: bold; font-size: 14px; color: #333; }
    .info-window .type { color: #888; font-size: 11px; text-transform: uppercase; }
  </style>
</head>
<body>
  <div id="map"></div>
  <script>
    let map;
    const heatPoints      = [$heatPoints];
    const markerPoints    = [$markerPoints];
    const isIndividualMode = ${_isIndividualMode ? 'true' : 'false'};
    const individualTitle  = "$individualTitle";
    const nicknameMap = {};

    async function initMap() {
      const { Map } = await google.maps.importLibrary("maps");
      const { AdvancedMarkerElement } = await google.maps.importLibrary("marker");

      map = new Map(document.getElementById("map"), {
        zoom: $zoom,
        center: { lat: $centerLat, lng: $centerLng },
        mapId: "$mapId",
        mapTypeControl: true,
        zoomControl: true,
        fullscreenControl: true,
      });

      const infoWindow = new google.maps.InfoWindow();

      heatPoints.forEach(p => {
        const color = p.type === 'cat' ? '#FF9800' : '#795548';
        new google.maps.Circle({
          strokeColor: color, strokeOpacity: isIndividualMode ? 0.5 : 0.3,
          strokeWeight: isIndividualMode ? 2 : 1,
          fillColor: color, fillOpacity: isIndividualMode ? 0.30 : 0.20,
          map: map, center: { lat: p.lat, lng: p.lng },
          radius: isIndividualMode ? 20 : 25,
        });
      });

      markerPoints.forEach(p => {
        const iscat = p.type === 'cat';
        const emoji = iscat ? '🐱' : '🐶';
        const cls   = iscat ? 'cat-pin' : 'dog-pin';
        const pinEl = document.createElement('div');
        pinEl.className = cls;
        pinEl.innerHTML = '<span>' + emoji + '</span>';

        const marker = new AdvancedMarkerElement({
          position: { lat: p.lat, lng: p.lng },
          map: map, content: pinEl, title: p.id,
        });

        marker.addListener('click', () => {
          const nickname  = isIndividualMode
            ? individualTitle
            : (nicknameMap[p.id] || p.id);
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

      if (isIndividualMode && heatPoints.length > 1) {
        const bounds = new google.maps.LatLngBounds();
        heatPoints.forEach(p => bounds.extend({ lat: p.lat, lng: p.lng }));
        map.fitBounds(bounds, 60);
      }
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
      backgroundColor: const Color(0xFFF0EDE8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF0EDE8),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: !_isIndividualMode ? false : true,
        foregroundColor: const Color(0xFF1b5e20),
        title: _isIndividualMode
          ? Text(
              "${widget.individualNickname ?? 'Animal'}'s Locations",
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1a1a1a),
              ),
            )
          : const Row(
              children: [
                Icon(Icons.pets, color: Color(0xFF1b5e20), size: 20),
                SizedBox(width: 8),
                Text(
                  'FurFinder',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1b5e20),
                  ),
                ),
              ],
            ),
        actions: [
          if (!_isIndividualMode)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: DropdownButton<String>(
                value: _filter,
                dropdownColor: Colors.white,
                underline: const SizedBox(),
                icon: const Icon(Icons.filter_list,
                    color: Color(0xFF2e7d32)),
                items: const [
                  DropdownMenuItem(value: 'all',
                    child: Text('All',
                        style: TextStyle(color: Color(0xFF1a1a1a)))),
                  DropdownMenuItem(value: 'cat',
                    child: Text('🐱 Cats',
                        style: TextStyle(color: Color(0xFF1a1a1a)))),
                  DropdownMenuItem(value: 'dog',
                    child: Text('🐶 Dogs',
                        style: TextStyle(color: Color(0xFF1a1a1a)))),
                ],
                onChanged: (val) {
                  if (val == null) return;
                  setState(() {
                    _filter    = val;
                    _isLoading = true;
                    _webController.loadHtmlString(
                        _buildHeatmapHtml(_lastSightings));
                  });
                },
              ),
            ),
          if (!_isIndividualMode)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.notifications_outlined,
                  color: Color(0xFF777777), size: 22),
            ),
        ],
      ),
      body: _isIndividualMode
        ? _buildMapStack()
        : StreamBuilder<List<AnimalSighting>>(
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
                      _webController.loadHtmlString(_buildHeatmapHtml(sightings));
                    }
                  });
                }
              }
              return _buildMapStack();
            },
          ),
    );
  }

  Widget _buildMapStack() {
    return Stack(
      children: [
        WebViewWidget(controller: _webController),
        if (_isLoading)
          const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Color(0xFF4CAF50)),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on,
                    color: Color(0xFF4CAF50), size: 18),
                  const SizedBox(width: 4),
                  Text(
                    '${_lastSightings.length} sighting${_lastSightings.length == 1 ? '' : 's'}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
