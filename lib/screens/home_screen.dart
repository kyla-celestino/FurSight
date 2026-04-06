import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/firebase_service.dart';
import '../services/ai_service.dart';

import '../models/animal_sighting.dart';
import 'submit_screen.dart';
import 'heatmap_screen.dart';
import 'search_screen.dart';

// ─────────────────────────────────────────────────────────────
//  Home / Map tab
// ─────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _firebaseService = FirebaseService();
  final _aiService       = AIService();
  final _picker          = ImagePicker();
  bool  _seedUploaded    = false;
  String _filter         = 'all';

  @override
  void initState() {
    super.initState();
    _checkAndUploadSeedData();
  }

  Future<void> _checkAndUploadSeedData() async {
    final exists = await _firebaseService.seedDataExists();
    if (!exists && !_seedUploaded) {
      _seedUploaded = true;
      await _firebaseService.uploadSeedEmbeddings();
    }
  }

  // ── Image Search ──────────────────────────────────────────
  Future<void> _startImageSearch() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                'Search by Image',
                style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 16,
                  color: Color(0xFF1a1a1a)),
              ),
            ),
            ListTile(
              leading: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.camera_alt,
                    color: Color(0xFF2e7d32), size: 18),
              ),
              title: const Text('Take a Photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.photo_library,
                    color: Color(0xFF2e7d32), size: 18),
              ),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (source == null || !mounted) return;

    final picked = await _picker.pickImage(
      source: source, imageQuality: 90, maxWidth: 1024,
    );
    if (picked == null || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(color: Color(0xFF2e7d32)),
            SizedBox(width: 16),
            Expanded(
              child: Text('Analyzing image...\nThis may take a moment.'),
            ),
          ],
        ),
      ),
    );

    try {
      final imageFile = File(picked.path);
      final detection = await _aiService.detectAnimal(imageFile);
      if (!mounted) return;

      if (detection == null) {
        Navigator.pop(context);
        _showImageSearchError(
          'No animal detected',
          'Make sure a cat or dog is clearly visible in the photo.',
        );
        return;
      }

      final embedding     = await _aiService.getEmbedding(detection.croppedImage);
      final allEmbeddings = await _firebaseService.getAllEmbeddings();

      if (allEmbeddings.isEmpty) {
        if (!mounted) return;
        Navigator.pop(context);
        _showImageSearchError(
          'No animals in database',
          'No animals have been submitted yet. Be the first to report a sighting!',
        );
        return;
      }

      final topMatches = _aiService.findTopMatches(
        embedding, allEmbeddings, topN: 5, minSimilarity: 0.30,
      );

      final ids         = topMatches.map((m) => m['individualId'] as String).toList();
      final individuals = await _firebaseService.getIndividualsByIds(ids);

      if (!mounted) return;
      Navigator.pop(context);

      if (topMatches.isEmpty || individuals.isEmpty) {
        _showImageSearchError(
          'No matches found',
          'This ${detection.animalType} doesn\'t match any known individual yet.',
        );
        return;
      }

      _showImageSearchResults(
        imageFile: imageFile,
        animalType: detection.animalType,
        matches: topMatches,
        individuals: individuals,
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showImageSearchError('Error', e.toString());
    }
  }

  void _showImageSearchError(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showImageSearchResults({
    required File imageFile,
    required String animalType,
    required List<Map<String, dynamic>> matches,
    required List<AnimalIndividual> individuals,
  }) {
    final indMap = {for (final ind in individuals) ind.id: ind};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        snap: true,
        snapSizes: const [0.5, 0.75, 0.95],
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              GestureDetector(
                onVerticalDragUpdate: (details) {
                  scrollController.position.moveTo(
                    scrollController.offset - details.delta.dy,
                  );
                },
                child: Container(
                  width: double.infinity,
                  color: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(imageFile,
                          width: 56, height: 56, fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Image Search Results',
                            style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16,
                              color: Color(0xFF1a1a1a)),
                          ),
                          Text(
                            '${matches.length} match${matches.length == 1 ? '' : 'es'} found',
                            style: const TextStyle(
                              color: Color(0xFF888888), fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: matches.length,
                  itemBuilder: (context, index) {
                    final match = matches[index];
                    final id    = match['individualId'] as String;
                    final sim   = match['similarity'] as double;
                    final ind   = indMap[id];
                    if (ind == null) return const SizedBox.shrink();
                    return _ImageSearchResultCard(
                      individual: ind,
                      similarity: sim,
                      firebaseService: _firebaseService,
                      rank: index + 1,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDCE8D6),
      body: Stack(
        children: [
          // ── Mock map background ──────────────────────────
          Positioned.fill(
            child: CustomPaint(
              painter: _MapPainter(),
            ),
          ),

          // ── Top overlay: header + search + filter chips ──
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // FurFinder header row
                  const Row(
                    children: [
                      Icon(Icons.pets,
                          color: Color(0xFF1b5e20), size: 22),
                      SizedBox(width: 8),
                      Text(
                        'FurFinder',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1b5e20),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Floating search bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(100),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x18000000),
                          blurRadius: 12, offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 16),
                        const Icon(Icons.search,
                            color: Color(0xFF2e7d32), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const SearchScreen()),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              child: Text(
                                'Search parks or breeds...',
                                style: TextStyle(
                                  color: Color(0xFFAAAAAA), fontSize: 14),
                              ),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: _startImageSearch,
                          child: Container(
                            margin: const EdgeInsets.all(5),
                            width: 36, height: 36,
                            decoration: const BoxDecoration(
                              color: Color(0xFF2e7d32),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.tune,
                                color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Filter chips
                  Row(
                    children: [
                      _MapFilterChip(
                        label: 'DOGS',
                        icon: Icons.pets,
                        isActive: _filter == 'dog',
                        onTap: () =>
                            setState(() => _filter = 'dog'),
                      ),
                      const SizedBox(width: 8),
                      _MapFilterChip(
                        label: 'CATS',
                        icon: Icons.pets,
                        isActive: _filter == 'cat',
                        onTap: () =>
                            setState(() => _filter = 'cat'),
                      ),
                      const SizedBox(width: 8),
                      _MapFilterChip(
                        label: 'ALL',
                        icon: Icons.location_on,
                        isActive: _filter == 'all',
                        onTap: () =>
                            setState(() => _filter = 'all'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── GPS button (above sheet) ──────────────────────
          Positioned(
            right: 16,
            bottom: MediaQuery.of(context).size.height * 0.36 + 12,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x18000000),
                    blurRadius: 8, offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.gps_fixed,
                  color: Color(0xFF2e7d32), size: 20),
            ),
          ),

          // ── FAB: Report sighting ──────────────────────────
          Positioned(
            right: 16,
            bottom: MediaQuery.of(context).size.height * 0.36 + 60,
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubmitScreen()),
              ),
              child: Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF2e7d32),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2e7d32).withValues(alpha: 0.35),
                      blurRadius: 12, offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 24),
              ),
            ),
          ),

          // ── Bottom sightings sheet ────────────────────────
          DraggableScrollableSheet(
            initialChildSize: 0.36,
            minChildSize: 0.12,
            maxChildSize: 0.88,
            snap: true,
            snapSizes: const [0.12, 0.36, 0.88],
            builder: (_, scrollController) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 20, offset: Offset(0, -4),
                  ),
                ],
              ),
              child: StreamBuilder<List<AnimalSighting>>(
                stream: _firebaseService.getSightingsStream(
                  animalType: _filter == 'all' ? null : _filter,
                ),
                builder: (context, snapshot) {
                  final sightings = snapshot.data ?? [];
                  return CustomScrollView(
                    controller: scrollController,
                    slivers: [
                      SliverToBoxAdapter(
                        child: Column(
                          children: [
                            // Drag handle
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 10),
                              width: 40, height: 4,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            if (snapshot.connectionState ==
                                ConnectionState.waiting)
                              const Padding(
                                padding: EdgeInsets.all(32),
                                child: CircularProgressIndicator(
                                    color: Color(0xFF2e7d32)),
                              )
                            else if (sightings.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(32),
                                child: Column(
                                  children: [
                                    Icon(Icons.pets,
                                        size: 48, color: Color(0xFFc8e6c9)),
                                    SizedBox(height: 12),
                                    Text(
                                      'No sightings nearby',
                                      style: TextStyle(
                                        color: Color(0xFF888888),
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (sightings.isNotEmpty)
                        SliverToBoxAdapter(
                          child: _FeaturedSightingCard(
                            sighting: sightings[0],
                            firebaseService: _firebaseService,
                          ),
                        ),
                      if (sightings.length > 1)
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, i) => _CompactSightingRow(
                              sighting: sightings[i + 1],
                              firebaseService: _firebaseService,
                            ),
                            childCount: sightings.length - 1,
                          ),
                        ),
                      const SliverToBoxAdapter(child: SizedBox(height: 16)),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mock map background ───────────────────────────────────────
class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFFD8E8D0),
    );

    final roadPaint = Paint()
      ..color = const Color(0xFFCADAC2)
      ..strokeWidth = 5.0;
    final minorPaint = Paint()
      ..color = const Color(0xFFCFDDC7)
      ..strokeWidth = 2.0;

    for (double y = 0; y < size.height; y += 96) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), roadPaint);
    }
    for (double x = 0; x < size.width; x += 108) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), roadPaint);
    }
    for (double y = 48; y < size.height; y += 96) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), minorPaint);
    }
    for (double x = 54; x < size.width; x += 108) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), minorPaint);
    }

    // Green park block
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
            size.width * 0.2, size.height * 0.25,
            size.width * 0.55, size.height * 0.22),
        const Radius.circular(6),
      ),
      Paint()..color = const Color(0xFFC2D9B8),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Filter chip ───────────────────────────────────────────────
class _MapFilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _MapFilterChip({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF2e7d32)
              : Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(100),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 6, offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 13,
                color: isActive
                    ? Colors.white
                    : const Color(0xFF555555)),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isActive
                    ? Colors.white
                    : const Color(0xFF555555),
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Featured sighting card (bottom sheet) ─────────────────────
class _FeaturedSightingCard extends StatelessWidget {
  final AnimalSighting sighting;
  final FirebaseService firebaseService;

  const _FeaturedSightingCard({
    required this.sighting,
    required this.firebaseService,
  });

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final iscat     = sighting.animalType == 'cat';
    final typeColor = iscat
        ? const Color(0xFFef6c00)
        : const Color(0xFF2e7d32);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo + info row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Circular photo
              Container(
                width: 62, height: 62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFe8f5e9),
                  border: Border.all(
                    color: typeColor.withValues(alpha: 0.3), width: 2),
                ),
                child: ClipOval(
                  child: sighting.imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: sighting.imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const Icon(
                          Icons.pets, color: Color(0xFF2e7d32), size: 28),
                        errorWidget: (_, __, ___) => const Icon(
                          Icons.pets, color: Color(0xFF2e7d32), size: 28),
                      )
                    : const Icon(Icons.pets,
                        color: Color(0xFF2e7d32), size: 28),
                ),
              ),
              const SizedBox(width: 12),

              // Name + location + tags
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FutureBuilder<String>(
                      future: firebaseService.getNickname(sighting.individualId),
                      builder: (context, snap) => Text(
                        snap.data ?? '...',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1a1a1a),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            size: 12, color: Color(0xFF888888)),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            '${sighting.locationName} • ${_timeAgo(sighting.timestamp)}',
                            style: const TextStyle(
                              fontSize: 11, color: Color(0xFF888888)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _Pill(
                          text: sighting.animalType.toUpperCase(),
                          bg: typeColor.withValues(alpha: 0.12),
                          fg: typeColor,
                        ),
                        const SizedBox(width: 6),
                        _Pill(
                          text: sighting.isNewIndividual ? 'NEW' : 'KNOWN',
                          bg: sighting.isNewIndividual
                              ? const Color(0xFFFFF8E1)
                              : const Color(0xFFE8F5E9),
                          fg: sighting.isNewIndividual
                              ? const Color(0xFFe65100)
                              : const Color(0xFF2e7d32),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Heart icon
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.favorite,
                    color: Color(0xFF2e7d32), size: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Status + Community tiles
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'STATUS',
                  child: Row(
                    children: [
                      Container(
                        width: 7, height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF2e7d32),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Recently Sighted',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1a1a1a),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  label: 'CONFIDENCE',
                  child: Text(
                    '${(sighting.confidence * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2e7d32),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // CTA button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.location_on, size: 18),
              label: const Text('View on Map'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2e7d32),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
                elevation: 0,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HeatmapScreen(
                      individualSightings: null,
                      individualNickname: null,
                      animalType: sighting.animalType,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final Widget child;

  const _StatTile({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F4F1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Color(0xFF888888),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;

  const _Pill({required this.text, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ── Compact sighting row (below featured) ─────────────────────
class _CompactSightingRow extends StatelessWidget {
  final AnimalSighting sighting;
  final FirebaseService firebaseService;

  const _CompactSightingRow({
    required this.sighting,
    required this.firebaseService,
  });

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final iscat     = sighting.animalType == 'cat';
    final typeColor = iscat
        ? const Color(0xFFef6c00)
        : const Color(0xFF2e7d32);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F6F3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // Thumbnail
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE8F5E9),
              ),
              child: ClipOval(
                child: sighting.imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: sighting.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const Icon(
                        Icons.pets, color: Color(0xFF2e7d32), size: 20),
                      errorWidget: (_, __, ___) => const Icon(
                        Icons.pets, color: Color(0xFF2e7d32), size: 20),
                    )
                  : const Icon(Icons.pets,
                      color: Color(0xFF2e7d32), size: 20),
              ),
            ),
            const SizedBox(width: 10),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${sighting.animalType.toUpperCase()} SPOTTED',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: typeColor,
                      letterSpacing: 0.4,
                    ),
                  ),
                  FutureBuilder<String>(
                    future: firebaseService.getNickname(sighting.individualId),
                    builder: (context, snap) => Text(
                      snap.data ?? '...',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1a1a1a),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    sighting.locationName,
                    style: const TextStyle(
                      fontSize: 10, color: Color(0xFF888888)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Text(
              _timeAgo(sighting.timestamp),
              style: const TextStyle(
                fontSize: 10, color: Color(0xFF888888)),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right,
                size: 16, color: Color(0xFFBBBBBB)),
          ],
        ),
      ),
    );
  }
}

// ── Image Search Result Card ──────────────────────────────────
class _ImageSearchResultCard extends StatelessWidget {
  final AnimalIndividual individual;
  final double           similarity;
  final FirebaseService  firebaseService;
  final int              rank;

  const _ImageSearchResultCard({
    required this.individual,
    required this.similarity,
    required this.firebaseService,
    required this.rank,
  });

  void _showDetailModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _IndividualDetailModal(
        individual: individual,
        firebaseService: firebaseService,
      ),
    );
  }

  Color get _matchColor {
    if (similarity >= 0.65) return Colors.green;
    if (similarity >= 0.45) return Colors.orange;
    return Colors.grey;
  }

  String get _matchLabel {
    if (similarity >= 0.65) return 'Strong match';
    if (similarity >= 0.45) return 'Possible match';
    return 'Weak match';
  }

  @override
  Widget build(BuildContext context) {
    final iscat     = individual.animalType == 'cat';
    final typeColor = iscat
        ? const Color(0xFFef6c00)
        : const Color(0xFF795548);

    return GestureDetector(
      onTap: () => _showDetailModal(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 8, offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(16)),
              child: individual.latestImageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: individual.latestImageUrl,
                    width: 54, height: 54, fit: BoxFit.cover,
                    placeholder: (_, __) => _PlaceholderBox(),
                    errorWidget: (_, __, ___) => _PlaceholderBox(),
                  )
                : _PlaceholderBox(),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.pets, size: 11, color: typeColor),
                        const SizedBox(width: 3),
                        Text(
                          individual.animalType.toUpperCase(),
                          style: TextStyle(
                            color: typeColor,
                            fontWeight: FontWeight.w700, fontSize: 9,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _matchColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${(similarity * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: _matchColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      individual.nickname.isNotEmpty
                          ? individual.nickname
                          : 'Unnamed',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13,
                        color: Color(0xFF1a1a1a),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _matchLabel,
                      style: TextStyle(fontSize: 10, color: _matchColor),
                    ),
                    if (individual.characteristics.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        individual.characteristics,
                        style: const TextStyle(
                            fontSize: 10, color: Color(0xFF888888)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.chevron_right,
                  color: Color(0xFF888888), size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54, height: 54,
      color: const Color(0xFFe8f5e9),
      child: const Icon(Icons.pets,
          color: Color(0xFF2e7d32), size: 22),
    );
  }
}

// ── Individual detail modal ───────────────────────────────────
class _IndividualDetailModal extends StatefulWidget {
  final AnimalIndividual individual;
  final FirebaseService  firebaseService;

  const _IndividualDetailModal({
    required this.individual,
    required this.firebaseService,
  });

  @override
  State<_IndividualDetailModal> createState() =>
      _IndividualDetailModalState();
}

class _IndividualDetailModalState extends State<_IndividualDetailModal> {
  bool _loadingMap = false;

  Future<void> _openIndividualHeatmap() async {
    setState(() => _loadingMap = true);
    final sightings = await widget.firebaseService
        .getSightingsByIndividual(widget.individual.id);
    if (!mounted) return;
    setState(() => _loadingMap = false);
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HeatmapScreen(
          individualSightings: sightings,
          individualNickname:  widget.individual.nickname,
          animalType:          widget.individual.animalType,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ind   = widget.individual;
    final iscat = ind.animalType == 'cat';
    final color = iscat
        ? const Color(0xFFef6c00)
        : const Color(0xFF795548);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          if (ind.latestImageUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: ind.latestImageUrl,
                      height: 200, width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        height: 200, color: const Color(0xFFe8f5e9),
                        child: const Center(
                            child: CircularProgressIndicator())),
                      errorWidget: (_, __, ___) => Container(
                        height: 200, color: const Color(0xFFe8f5e9),
                        child: const Icon(Icons.pets,
                            size: 60, color: Color(0xFF2e7d32))),
                    ),
                  ),
                  Positioned(
                    top: 10, right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: const Text(
                        'KNOWN',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2e7d32),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ind.nickname.isNotEmpty ? ind.nickname : 'Unnamed',
                  style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700,
                    color: Color(0xFF1a1a1a),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.pets, size: 13, color: color),
                    const SizedBox(width: 4),
                    Text(
                      ind.animalType.toUpperCase(),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700, fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, thickness: 0.5),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (ind.characteristics.isNotEmpty) ...[
                      Expanded(
                        child: _InfoTile(
                          label: 'Characteristics',
                          value: ind.characteristics,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: _InfoTile(
                        label: 'Total Sightings',
                        value:
                            '${ind.sightingCount} time${ind.sightingCount == 1 ? '' : 's'}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: _loadingMap
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.map, size: 18),
                    label: Text(_loadingMap
                      ? 'Loading...'
                      : "View ${ind.nickname.isNotEmpty ? ind.nickname : 'Animal'}'s Locations"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2e7d32),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100)),
                    ),
                    onPressed: _loadingMap ? null : _openIndividualHeatmap,
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;

  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F4F1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: Color(0xFF888888))),
          const SizedBox(height: 3),
          Text(value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1a1a1a),
              )),
        ],
      ),
    );
  }
}
