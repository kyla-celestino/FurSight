import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../services/firebase_service.dart';
import '../services/ai_service.dart';
import '../models/animal_sighting.dart';
import 'heatmap_screen.dart';
import 'search_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final _firebaseService = FirebaseService();
  final _picker          = ImagePicker();
  final _aiService       = AIService();
  String _filter         = 'all';

  // ── Image Search ──────────────────────────────────────────────
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
            Expanded(child: Text('Analyzing image...\nThis may take a moment.')),
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
              Container(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0EDE8),
      appBar: _buildAppBar(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'RECENT ACTIVITY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2e7d32),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Community Sightings',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1a1a1a),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Help neighbors find their lost companions by\nverifying recent sightings in your area.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF888888),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),

                // Search bar + camera button
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SearchScreen()),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(100),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x0F000000),
                                blurRadius: 8, offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.search,
                                  color: Color(0xFF888888), size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Search animals...',
                                style: TextStyle(
                                    color: Color(0xFFBBBBBB), fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _startImageSearch,
                      child: Container(
                        width: 44, height: 44,
                        decoration: const BoxDecoration(
                          color: Color(0xFF2e7d32),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x1A2e7d32),
                              blurRadius: 8, offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.camera_alt,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Filter chips row
                Row(
                  children: [
                    _FilterChip(
                      label: 'All',
                      isActive: _filter == 'all',
                      onTap: () => setState(() => _filter = 'all'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Dogs',
                      isActive: _filter == 'dog',
                      onTap: () => setState(() => _filter = 'dog'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Cats',
                      isActive: _filter == 'cat',
                      onTap: () => setState(() => _filter = 'cat'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),

          // ── Sightings stream ────────────────────────────────
          Expanded(
            child: StreamBuilder<List<AnimalSighting>>(
              stream: _firebaseService.getSightingsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF2e7d32)),
                  );
                }

                final all = snapshot.data ?? [];
                final sightings = _filter == 'all'
                    ? all
                    : all.where((s) => s.animalType == _filter).toList();

                if (sightings.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.pets,
                            size: 64, color: Color(0xFFc8e6c9)),
                        const SizedBox(height: 16),
                        Text(
                          'No community sightings yet',
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Be the first to report a sighting!',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: sightings.length,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _FeaturedSightingCard(
                        sighting: sightings[0],
                        firebaseService: _firebaseService,
                      );
                    }
                    return _CompactSightingCard(
                      sighting: sightings[index],
                      firebaseService: _firebaseService,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFFF0EDE8),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      title: const Row(
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
      actions: const [
        Padding(
          padding: EdgeInsets.only(right: 12),
          child: Icon(Icons.notifications_outlined,
              color: Color(0xFF777777), size: 22),
        ),
      ],
    );
  }
}

// ── Filter chip ───────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF2e7d32)
              : Colors.white,
          borderRadius: BorderRadius.circular(100),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 6, offset: Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : const Color(0xFF555555),
          ),
        ),
      ),
    );
  }
}

// ── Featured card (first sighting) ───────────────────────────
class _FeaturedSightingCard extends StatelessWidget {
  final AnimalSighting sighting;
  final FirebaseService firebaseService;

  const _FeaturedSightingCard({
    required this.sighting,
    required this.firebaseService,
  });

  void _showDetailModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommunitySightingDetailModal(
        sighting: sighting,
        firebaseService: firebaseService,
      ),
    );
  }

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
    final isNew     = sighting.isNewIndividual;

    return GestureDetector(
      onTap: () => _showDetailModal(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 8, offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo with overlaid badges
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20)),
                  child: sighting.imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: sighting.imageUrl,
                        height: 200, width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          height: 200, color: const Color(0xFFe8f5e9),
                          child: const Center(
                              child: CircularProgressIndicator(
                                  color: Color(0xFF2e7d32)))),
                        errorWidget: (_, __, ___) => Container(
                          height: 200, color: const Color(0xFFe8f5e9),
                          child: const Icon(Icons.pets,
                              size: 60, color: Color(0xFF2e7d32))),
                      )
                    : Container(
                        height: 200, color: const Color(0xFFe8f5e9),
                        child: const Icon(Icons.pets,
                            size: 60, color: Color(0xFF2e7d32))),
                ),
                // Animal type badge — top left
                Positioned(
                  top: 12, left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: typeColor,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.pets,
                            size: 11, color: Colors.white),
                        const SizedBox(width: 5),
                        Text(
                          sighting.animalType.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Time badge — top right
                Positioned(
                  top: 12, right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      _timeAgo(sighting.timestamp),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF555555),
                      ),
                    ),
                  ),
                ),
                // Urgent badge if new
                if (isNew)
                  Positioned(
                    bottom: 12, right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF8F00),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'NEW',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

            // Content below photo
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name row with avatar
                  Row(
                    children: [
                      Expanded(
                        child: FutureBuilder<String>(
                          future: firebaseService
                              .getNickname(sighting.individualId),
                          builder: (context, snap) => Text(
                            snap.data ?? '...',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1a1a1a),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: typeColor.withValues(alpha: 0.1),
                          border: Border.all(
                              color: typeColor.withValues(alpha: 0.3), width: 1.5),
                        ),
                        child: Icon(Icons.person,
                            size: 18, color: typeColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Location
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          size: 13, color: Color(0xFF888888)),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          sighting.locationName,
                          style: const TextStyle(
                            fontSize: 12, color: Color(0xFF888888)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Description / confidence
                  Text(
                    'Spotted here with ${(sighting.confidence * 100).toStringAsFixed(0)}% confidence. '
                    '${isNew ? 'This appears to be a new individual not yet in our database.' : 'Matched with a known individual in our database.'}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF555555),
                      height: 1.4,
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),

                  // Bottom row: likes / comments / share
                  Row(
                    children: [
                      const Icon(Icons.favorite_border,
                          size: 18, color: Color(0xFF888888)),
                      const SizedBox(width: 5),
                      const Text('–',
                          style: TextStyle(
                              fontSize: 13, color: Color(0xFF888888))),
                      const SizedBox(width: 14),
                      const Icon(Icons.chat_bubble_outline,
                          size: 17, color: Color(0xFF888888)),
                      const SizedBox(width: 5),
                      const Text('–',
                          style: TextStyle(
                              fontSize: 13, color: Color(0xFF888888))),
                      const Spacer(),
                      const Icon(Icons.share_outlined,
                          size: 18, color: Color(0xFF888888)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Compact row card ──────────────────────────────────────────
class _CompactSightingCard extends StatelessWidget {
  final AnimalSighting sighting;
  final FirebaseService firebaseService;

  const _CompactSightingCard({
    required this.sighting,
    required this.firebaseService,
  });

  void _showDetailModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommunitySightingDetailModal(
        sighting: sighting,
        firebaseService: firebaseService,
      ),
    );
  }

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

    return GestureDetector(
      onTap: () => _showDetailModal(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 8, offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Circular thumbnail
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFe8f5e9),
              ),
              child: ClipOval(
                child: sighting.imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: sighting.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const Icon(
                        Icons.pets, color: Color(0xFF2e7d32), size: 22),
                      errorWidget: (_, __, ___) => const Icon(
                        Icons.pets, color: Color(0xFF2e7d32), size: 22),
                    )
                  : const Icon(Icons.pets,
                      color: Color(0xFF2e7d32), size: 22),
              ),
            ),
            const SizedBox(width: 12),

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
                    future:
                        firebaseService.getNickname(sighting.individualId),
                    builder: (context, snap) => Text(
                      snap.data ?? '...',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1a1a1a),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.near_me,
                          size: 10, color: Color(0xFF888888)),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          sighting.locationName,
                          style: const TextStyle(
                            fontSize: 11, color: Color(0xFF888888)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Time + chevron
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _timeAgo(sighting.timestamp),
                  style: const TextStyle(
                    fontSize: 10, color: Color(0xFF888888)),
                ),
                const SizedBox(height: 4),
                const Icon(Icons.chevron_right,
                    size: 18, color: Color(0xFFBBBBBB)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Detail Modal ──────────────────────────────────────────────
class _CommunitySightingDetailModal extends StatefulWidget {
  final AnimalSighting  sighting;
  final FirebaseService firebaseService;

  const _CommunitySightingDetailModal({
    required this.sighting,
    required this.firebaseService,
  });

  @override
  State<_CommunitySightingDetailModal> createState() =>
      _CommunitySightingDetailModalState();
}

class _CommunitySightingDetailModalState
    extends State<_CommunitySightingDetailModal> {
  String _nickname        = '...';
  String _characteristics = '';
  bool   _loadingMap      = false;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    final name       = await widget.firebaseService
        .getNickname(widget.sighting.individualId);
    final individual = await widget.firebaseService
        .getIndividual(widget.sighting.individualId);
    if (mounted) {
      setState(() {
        _nickname        = name;
        _characteristics = individual?.characteristics ?? '';
      });
    }
  }

  Future<void> _openIndividualHeatmap() async {
    setState(() => _loadingMap = true);
    final sightings = await widget.firebaseService
        .getSightingsByIndividual(widget.sighting.individualId);
    if (!mounted) return;
    setState(() => _loadingMap = false);
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HeatmapScreen(
          individualSightings: sightings,
          individualNickname:  _nickname,
          animalType:          widget.sighting.animalType,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s     = widget.sighting;
    final iscat = s.animalType == 'cat';
    final color = iscat
        ? const Color(0xFFef6c00)
        : const Color(0xFF795548);
    final isNew = s.isNewIndividual;

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
          if (s.imageUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: s.imageUrl,
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
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        isNew ? 'NEW' : 'KNOWN',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: isNew
                              ? const Color(0xFFe65100)
                              : const Color(0xFF2e7d32),
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
                Text(_nickname,
                    style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700,
                      color: Color(0xFF1a1a1a))),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.pets, size: 13, color: color),
                    const SizedBox(width: 4),
                    Text(s.animalType.toUpperCase(),
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, thickness: 0.5),
                const SizedBox(height: 12),
                if (_characteristics.isNotEmpty) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _InfoTile(
                          label: 'Characteristics',
                          value: _characteristics,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _InfoTile(
                          label: 'Confidence',
                          value:
                              '${(s.confidence * 100).toStringAsFixed(1)}%',
                          valueColor: const Color(0xFF2e7d32),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ] else ...[
                  _InfoTile(
                    label: 'Confidence',
                    value: '${(s.confidence * 100).toStringAsFixed(1)}%',
                    valueColor: const Color(0xFF2e7d32),
                  ),
                  const SizedBox(height: 8),
                ],
                _InfoTile(
                    label: 'Location',
                    value: s.locationName,
                    fullWidth: true),
                const SizedBox(height: 8),
                _InfoTile(
                  label: 'Sighted',
                  value: DateFormat('MMM d, yyyy • h:mm a')
                      .format(s.timestamp),
                  fullWidth: true,
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
                        : 'View $_nickname\'s Locations on Map'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2e7d32),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100)),
                    ),
                    onPressed:
                        _loadingMap ? null : _openIndividualHeatmap,
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

  Color get _matchColor {
    if (similarity >= 0.65) return const Color(0xFF2e7d32);
    if (similarity >= 0.45) return const Color(0xFFef6c00);
    return const Color(0xFF888888);
  }

  String get _matchLabel {
    if (similarity >= 0.65) return 'Strong match';
    if (similarity >= 0.45) return 'Possible match';
    return 'Weak match';
  }

  void _showDetailModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ImageSearchIndividualModal(
        individual: individual,
        firebaseService: firebaseService,
      ),
    );
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
                    width: 60, height: 60, fit: BoxFit.cover,
                    placeholder: (_, __) => _SearchPlaceholderBox(),
                    errorWidget: (_, __, ___) => _SearchPlaceholderBox(),
                  )
                : _SearchPlaceholderBox(),
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

class _SearchPlaceholderBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60, height: 60,
      color: const Color(0xFFe8f5e9),
      child: const Icon(Icons.pets, color: Color(0xFF2e7d32), size: 24),
    );
  }
}

// ── Individual detail modal (image search) ───────────────────
class _ImageSearchIndividualModal extends StatefulWidget {
  final AnimalIndividual individual;
  final FirebaseService  firebaseService;

  const _ImageSearchIndividualModal({
    required this.individual,
    required this.firebaseService,
  });

  @override
  State<_ImageSearchIndividualModal> createState() =>
      _ImageSearchIndividualModalState();
}

class _ImageSearchIndividualModalState
    extends State<_ImageSearchIndividualModal> {
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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: ind.latestImageUrl,
                  height: 200, width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    height: 200, color: const Color(0xFFe8f5e9),
                    child: const Center(child: CircularProgressIndicator())),
                  errorWidget: (_, __, ___) => Container(
                    height: 200, color: const Color(0xFFe8f5e9),
                    child: const Icon(Icons.pets,
                        size: 60, color: Color(0xFF2e7d32))),
                ),
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
                    color: Color(0xFF1a1a1a)),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.pets, size: 13, color: color),
                    const SizedBox(width: 4),
                    Text(ind.animalType.toUpperCase(),
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700, fontSize: 11)),
                    const SizedBox(width: 12),
                    Icon(Icons.remove_red_eye_outlined,
                        size: 13, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      '${ind.sightingCount} sighting${ind.sightingCount == 1 ? '' : 's'}',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[500])),
                  ],
                ),
                if (ind.characteristics.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6F4F1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Characteristics',
                            style: TextStyle(
                                fontSize: 10, color: Color(0xFF888888))),
                        const SizedBox(height: 3),
                        Text(ind.characteristics,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF1a1a1a))),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
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
                        : "View ${ind.nickname.isNotEmpty ? ind.nickname : 'Animal'}'s Locations on Map"),
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
  final Color? valueColor;
  final bool   fullWidth;

  const _InfoTile({
    required this.label,
    required this.value,
    this.valueColor,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: fullWidth ? double.infinity : null,
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
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: valueColor ?? const Color(0xFF1a1a1a),
              )),
        ],
      ),
    );
  }
}
