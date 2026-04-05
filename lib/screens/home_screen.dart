import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/auth_service.dart';
import '../services/firebase_service.dart';
import '../services/ai_service.dart';
import '../models/animal_sighting.dart';
import 'submit_screen.dart';
import 'heatmap_screen.dart';
import 'logs_screen.dart';
import 'hotlines_screen.dart';
import 'how_it_works_screen.dart';
import 'search_screen.dart';
import 'community_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService     = AuthService();
  final _firebaseService = FirebaseService();
  final _aiService       = AIService();
  final _picker          = ImagePicker();
  bool _seedUploaded     = false;

  @override
  void initState() {
    super.initState();
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
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Search by Image',
                style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a Photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null || !mounted) return;

    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 1024,
    );
    if (picked == null || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
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

      final embedding = await _aiService.getEmbedding(detection.croppedImage);
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
        embedding,
        allEmbeddings,
        topN: 5,
        minSimilarity: 0.30,
      );

      final ids = topMatches.map((m) => m['individualId'] as String).toList();
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
                      child: Image.file(
                        imageFile,
                        width: 56, height: 56,
                        fit: BoxFit.cover,
                      ),
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
    final user = FirebaseAuth.instance.currentUser;
    final username = user?.email?.split('@').first ?? 'User';

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.pets, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('FurFinder'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async => await _authService.signOut(),
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Green hero section ────────────────────────
            Container(
              width: double.infinity,
              color: const Color(0xFF2e7d32),
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hello, $username!',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Help track campus animals',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Search row ──────────────────────────
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
                              horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.search,
                                  color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Search animals...',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.75),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _startImageSearch,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.image_search,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Section label ─────────────────────────────
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'QUICK ACCESS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF888888),
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // ── Community Sightings tile ──────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: () => Navigator.push(context,
                  MaterialPageRoute(
                    builder: (_) => const CommunityScreen())),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFe8f5e9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFc8e6c9), width: 0.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2e7d32).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.people_outline,
                          color: Color(0xFF2e7d32),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Community Sightings',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1a1a1a),
                              )),
                            SizedBox(height: 1),
                            Text('See all sightings from everyone',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF555555),
                              )),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios,
                        size: 14, color: Color(0xFF2e7d32)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // ── Quick Access 2×2 grid ─────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.4,
                children: [
                  _QuickAccessTile(
                    icon: Icons.add_a_photo,
                    label: 'Spot/Take\na Photo',
                    bgColor: const Color(0xFFe8f5e9),
                    iconColor: const Color(0xFF2e7d32),
                    onTap: () => Navigator.push(context,
                      MaterialPageRoute(
                        builder: (_) => const SubmitScreen())),
                  ),
                  _QuickAccessTile(
                    icon: Icons.map,
                    label: 'View\nHeatmap',
                    bgColor: const Color(0xFFe3f2fd),
                    iconColor: const Color(0xFF1565c0),
                    onTap: () => Navigator.push(context,
                      MaterialPageRoute(
                        builder: (_) => const HeatmapScreen())),
                  ),
                  _QuickAccessTile(
                    icon: Icons.assignment,
                    label: 'Submission\nLogs',
                    bgColor: const Color(0xFFfff8e1),
                    iconColor: const Color(0xFFe65100),
                    onTap: () => Navigator.push(context,
                      MaterialPageRoute(
                        builder: (_) => const LogsScreen())),
                  ),
                  _QuickAccessTile(
                    icon: Icons.emergency,
                    label: 'Emergency\nHotlines',
                    bgColor: const Color(0xFFfce4ec),
                    iconColor: const Color(0xFFb71c1c),
                    onTap: () => Navigator.push(context,
                      MaterialPageRoute(
                        builder: (_) => const HotlinesScreen())),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // ── How it works tile ─────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: () => Navigator.push(context,
                  MaterialPageRoute(
                    builder: (_) => const HowItWorksScreen())),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFe0e0e0), width: 0.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F4F4),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.help_outline,
                          color: Color(0xFF888888),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('How it works?',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1a1a1a),
                              )),
                            SizedBox(height: 1),
                            Text('Learn how to use FurFinder',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF888888),
                              )),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios,
                        size: 14, color: Color(0xFF888888)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ── Quick Access Tile ─────────────────────────────────────────
class _QuickAccessTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bgColor;
  final Color iconColor;
  final VoidCallback onTap;

  const _QuickAccessTile({
    required this.icon,
    required this.label,
    required this.bgColor,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: iconColor.withValues(alpha: 0.25),
            width: 0.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: iconColor,
                height: 1.3,
              ),
            ),
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
    final iscat = individual.animalType == 'cat';
    final typeColor = iscat
      ? const Color(0xFFef6c00)
      : const Color(0xFF795548);

    return GestureDetector(
      onTap: () => _showDetailModal(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFe0e0e0), width: 0.5),
        ),
        child: Row(
          children: [
            // Photo
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(12)),
              child: individual.latestImageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: individual.latestImageUrl,
                    width: 54, height: 54, fit: BoxFit.cover,
                    placeholder: (_, __) => _PlaceholderBox(),
                    errorWidget: (_, __, ___) => _PlaceholderBox(),
                  )
                : _PlaceholderBox(),
            ),

            // Details
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
                            fontWeight: FontWeight.w700,
                            fontSize: 9,
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
                        ? individual.nickname : 'Unnamed',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Color(0xFF1a1a1a),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _matchLabel,
                      style: TextStyle(
                        fontSize: 10, color: _matchColor),
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
      child: const Icon(Icons.pets, color: Color(0xFF2e7d32), size: 22),
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
    final ind    = widget.individual;
    final iscat  = ind.animalType == 'cat';
    final color  = iscat
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
                    borderRadius: BorderRadius.circular(12),
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
                        horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(20),
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
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
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
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, thickness: 0.5),
                const SizedBox(height: 12),

                // Info grid
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
                        value: '${ind.sightingCount} time${ind.sightingCount == 1 ? '' : 's'}',
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
                      : "View ${ind.nickname.isNotEmpty ? ind.nickname : 'Animal'}'s Locations on Map"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2e7d32),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
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

  const _InfoTile({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(8),
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
