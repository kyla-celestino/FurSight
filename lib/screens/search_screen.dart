import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/firebase_service.dart';
import '../services/auth_service.dart';
import '../models/animal_sighting.dart';
import 'heatmap_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _firebaseService    = FirebaseService();
  final _searchController   = TextEditingController();
  List<AnimalIndividual>    _results = [];
  bool                      _isLoading = false;
  bool                      _hasSearched = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
      });
      return;
    }
    setState(() => _isLoading = true);
    final results = await _firebaseService.searchIndividuals(query);
    if (mounted) {
      setState(() {
        _results    = results;
        _isLoading  = false;
        _hasSearched = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search Animals')),
      body: Column(
        children: [
          // ── Search Bar ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search by name or characteristics...',
                hintStyle: const TextStyle(fontSize: 14),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _search('');
                      },
                    )
                  : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              ),
              onChanged: (val) {
                setState(() {}); // rebuild for suffixIcon
                // Debounce — search after user stops typing
                Future.delayed(const Duration(milliseconds: 400), () {
                  if (_searchController.text == val) _search(val);
                });
              },
              onSubmitted: _search,
            ),
          ),

          // ── Hint chips ────────────────────────────────────
          if (!_hasSearched)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Try searching for:',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      'tabby', 'tortie', 'orange', 'black', 'collar',
                      'white', 'calico', 'fluffy',
                    ].map((hint) => ActionChip(
                      label: Text(hint),
                      onPressed: () {
                        _searchController.text = hint;
                        _search(hint);
                      },
                    )).toList(),
                  ),
                ],
              ),
            ),

          // ── Results ───────────────────────────────────────
          Expanded(
            child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _hasSearched && _results.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off,
                          size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          'No animals found for\n"${_searchController.text}"',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[600], fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      return _IndividualCard(
                        individual: _results[index],
                        firebaseService: _firebaseService,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Individual result card ────────────────────────────────────
class _IndividualCard extends StatelessWidget {
  final AnimalIndividual individual;
  final FirebaseService  firebaseService;

  const _IndividualCard({
    required this.individual,
    required this.firebaseService,
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

  @override
  Widget build(BuildContext context) {
    final iscat = individual.animalType == 'cat';
    final color = iscat ? Colors.orange : Colors.brown;

    return GestureDetector(
      onTap: () => _showDetailModal(context),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.hardEdge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: IntrinsicHeight(
          child: Row(
          children: [
            // Photo
            SizedBox(
              width: 90,
              child: individual.latestImageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: individual.latestImageUrl,
                    width: 90,
                    fit: BoxFit.cover,
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
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      individual.nickname.isNotEmpty
                        ? individual.nickname
                        : 'Unnamed',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    if (individual.characteristics.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.info_outline,
                            size: 12, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              individual.characteristics,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      '${individual.sightingCount} sighting${individual.sightingCount == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.chevron_right, color: Colors.grey, size: 20),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _PlaceholderBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      height: 90,
      color: Colors.grey[200],
      child: const Icon(Icons.pets, color: Colors.grey),
    );
  }
}

// ── Individual detail modal (from search) ────────────────────
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

          // Photo
          if (ind.latestImageUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: ind.latestImageUrl,
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    height: 220,
                    color: Colors.grey[200],
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    height: 220,
                    color: Colors.grey[200],
                    child: const Icon(Icons.pets, size: 60, color: Colors.grey),
                  ),
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
                    fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.pets, size: 14, color: color),
                    const SizedBox(width: 4),
                    Text(
                      ind.animalType.toUpperCase(),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
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
                            strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.map),
                    label: Text(
                      _loadingMap
                        ? 'Loading...'
                        : "View ${ind.nickname.isNotEmpty ? ind.nickname : 'Animal'}'s Locations on Map",
                    ),
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
                style: const TextStyle(fontSize: 13, color: Colors.black87)),
            ],
          ),
        ),
      ],
    );
  }
}
