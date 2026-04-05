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
    // Show picker options
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

    // Show loading dialog
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

      // Step 1: Detect animal
      final detection = await _aiService.detectAnimal(imageFile);
      if (!mounted) return;

      if (detection == null) {
        Navigator.pop(context); // close loading
        _showImageSearchError(
          'No animal detected',
          'Make sure a cat or dog is clearly visible in the photo.',
        );
        return;
      }

      // Step 2: Get embedding
      final embedding = await _aiService.getEmbedding(detection.croppedImage);

      // Step 3: Load all embeddings from Firestore
      final allEmbeddings = await _firebaseService.getAllEmbeddings();

      if (allEmbeddings.isEmpty) {
        if (!mounted) return;
        Navigator.pop(context); // close loading
        _showImageSearchError(
          'No animals in database',
          'No animals have been submitted yet. Be the first to report a sighting!',
        );
        return;
      }

      // Step 4: Find top matches
      final topMatches = _aiService.findTopMatches(
        embedding,
        allEmbeddings,
        topN: 5,
        minSimilarity: 0.30,
      );

      // Step 5: Fetch individual details for matches
      final ids = topMatches.map((m) => m['individualId'] as String).toList();
      final individuals = await _firebaseService.getIndividualsByIds(ids);

      if (!mounted) return;
      Navigator.pop(context); // close loading

      if (topMatches.isEmpty || individuals.isEmpty) {
        _showImageSearchError(
          'No matches found',
          'This ${detection.animalType} doesn\'t match any known individual yet.',
        );
        return;
      }

      // Step 6: Show results
      _showImageSearchResults(
        imageFile: imageFile,
        animalType: detection.animalType,
        matches: topMatches,
        individuals: individuals,
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // close loading
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
    // Build a map for quick lookup: id -> individual
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
        snap: true,                          // ← snaps to positions
        snapSizes: const [0.5, 0.75, 0.95], // ← snap points
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // ── Drag handle — connected to scroll controller ──
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

              // Header
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
                              fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            '${matches.length} match${matches.length == 1 ? '' : 'es'} · ${animalType}',
                            style: TextStyle(
                              color: Colors.grey[600], fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Results list
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

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.pets, color: Colors.white),
            SizedBox(width: 8),
            Text('FurFinder',
              style: TextStyle(fontWeight: FontWeight.bold)),
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
            _EmergencyBanner(),
            const SizedBox(height: 16),

            // Welcome
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hello, ${user?.email?.split('@').first ?? 'User'}! 👋',
                    style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Help track campus animals',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Search bar + Image search icon ────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Text search bar
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SearchScreen()),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.search, color: Colors.grey[500]),
                            const SizedBox(width: 10),
                            Text(
                              'Search animals...',
                              style: TextStyle(
                                color: Colors.grey[500], fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Image search icon button
                  GestureDetector(
                    onTap: _startImageSearch,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.image_search,
                        color: Color(0xFF4CAF50),
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Quick Access
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Quick Access',
                style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.1,
                children: [
                  _QuickAccessCard(
                    icon: Icons.add_a_photo,
                    label: 'Spot/Take\na Photo',
                    color: const Color(0xFF4CAF50),
                    onTap: () => Navigator.push(context,
                      MaterialPageRoute(
                        builder: (_) => const SubmitScreen())),
                  ),
                  _QuickAccessCard(
                    icon: Icons.map,
                    label: 'View\nHeatmap',
                    color: const Color(0xFF2196F3),
                    onTap: () => Navigator.push(context,
                      MaterialPageRoute(
                        builder: (_) => const HeatmapScreen())),
                  ),
                  _QuickAccessCard(
                    icon: Icons.assignment,
                    label: 'Submission\nLogs',
                    color: const Color(0xFFFF9800),
                    onTap: () => Navigator.push(context,
                      MaterialPageRoute(
                        builder: (_) => const LogsScreen())),
                  ),
                  _QuickAccessCard(
                    icon: Icons.emergency,
                    label: 'Emergency\nHotlines',
                    color: const Color(0xFFF44336),
                    onTap: () => Navigator.push(context,
                      MaterialPageRoute(
                        builder: (_) => const HotlinesScreen())),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // How it works
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  leading: const Icon(Icons.help_outline,
                    color: Color(0xFF4CAF50)),
                  title: const Text('How it works?',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Learn how to use FurFinder'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => Navigator.push(context,
                    MaterialPageRoute(
                      builder: (_) => const HowItWorksScreen())),
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
    final color = iscat ? Colors.orange : Colors.brown;

    return GestureDetector(
      onTap: () => _showDetailModal(context),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            // Photo
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(16)),
              child: individual.latestImageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: individual.latestImageUrl,
                    width: 90, height: 90, fit: BoxFit.cover,
                    placeholder: (_, __) => _PlaceholderBox(),
                    errorWidget: (_, __, ___) => _PlaceholderBox(),
                  )
                : _PlaceholderBox(),
            ),

            // Details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.pets, size: 14, color: color),
                        const SizedBox(width: 4),
                        Text(
                          individual.animalType.toUpperCase(),
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                        const Spacer(),
                        // Similarity badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _matchColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${(similarity * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
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
                        fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _matchLabel,
                      style: TextStyle(
                        fontSize: 11, color: _matchColor),
                    ),
                    if (individual.characteristics.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        individual.characteristics,
                        style: const TextStyle(
                          fontSize: 11, color: Colors.grey),
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
                color: Colors.grey, size: 20),
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
      width: 90, height: 90,
      color: Colors.grey[200],
      child: const Icon(Icons.pets, color: Colors.grey),
    );
  }
}

// ── Individual detail modal (reused from search_screen) ───────
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
    final color = iscat ? Colors.orange : Colors.brown;

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
                  height: 220, width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    height: 220, color: Colors.grey[200],
                    child: const Center(
                      child: CircularProgressIndicator())),
                  errorWidget: (_, __, ___) => Container(
                    height: 220, color: Colors.grey[200],
                    child: const Icon(Icons.pets,
                      size: 60, color: Colors.grey)),
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ind.nickname.isNotEmpty ? ind.nickname : 'Unnamed',
                  style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.pets, size: 14, color: color),
                    const SizedBox(width: 4),
                    Text(ind.animalType.toUpperCase(),
                      style: TextStyle(
                        color: color, fontWeight: FontWeight.w600,
                        fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),

                if (ind.characteristics.isNotEmpty) ...[
                  _InfoRow(
                    icon: Icons.info_outline,
                    label: 'Characteristics',
                    value: ind.characteristics,
                  ),
                  const SizedBox(height: 8),
                ],
                _InfoRow(
                  icon: Icons.remove_red_eye_outlined,
                  label: 'Total Sightings',
                  value: '${ind.sightingCount} time${ind.sightingCount == 1 ? '' : 's'}',
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
                      : const Icon(Icons.map),
                    label: Text(_loadingMap
                      ? 'Loading...'
                      : "View ${ind.nickname.isNotEmpty ? ind.nickname : 'Animal'}'s Locations on Map"),
                    style: ElevatedButton.styleFrom(
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

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
              Text(value,
                style: const TextStyle(
                  fontSize: 13, color: Colors.black87)),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Existing home screen widgets ──────────────────────────────
class _EmergencyBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFF44336),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.emergency, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('In Emergency call 119',
              style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const HotlinesScreen())),
            child: const Text('See all',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _QuickAccessCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAccessCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
        elevation: 3,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color, color.withOpacity(0.7)],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: Colors.white),
              const SizedBox(height: 8),
              Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                )),
            ],
          ),
        ),
      ),
    );
  }
}
