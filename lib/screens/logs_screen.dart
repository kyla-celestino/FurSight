import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../services/firebase_service.dart';
import '../services/auth_service.dart';
import '../models/animal_sighting.dart';
import 'heatmap_screen.dart';
import 'search_screen.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final _firebaseService = FirebaseService();
  final _authService     = AuthService();
  String _filter         = 'all';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Submission Logs')),
      body: Column(
        children: [
          // ── Search bar + Filter dropdown ──────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                // Search bar — navigates to SearchScreen
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
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search,
                            color: Colors.grey[500], size: 20),
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

                // Filter dropdown
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _filter,
                      isDense: true,
                      icon: const Icon(Icons.filter_list, size: 18),
                      items: const [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text('All',
                            style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(
                          value: 'cat',
                          child: Text('🐱 Cats',
                            style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(
                          value: 'dog',
                          child: Text('🐶 Dogs',
                            style: TextStyle(fontSize: 13))),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _filter = val);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Logs list ─────────────────────────────────────
          Expanded(
            child: StreamBuilder<List<AnimalSighting>>(
              stream: _firebaseService.getUserSightings(
                _authService.currentUserId,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allSightings = snapshot.data ?? [];

                // Filter by animal type using dropdown selection
                final sightings = _filter == 'all'
                  ? allSightings
                  : allSightings
                      .where((s) => s.animalType == _filter)
                      .toList();

                if (sightings.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.pets, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          allSightings.isEmpty
                            ? 'No submissions yet'
                            : 'No ${_filter == 'cat' ? 'cat' : 'dog'} submissions',
                          style: TextStyle(
                            color: Colors.grey[600], fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          allSightings.isEmpty
                            ? 'Be the first to report a sighting!'
                            : 'Try switching the filter',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: sightings.length,
                  itemBuilder: (context, index) {
                    return _SightingCard(sighting: sightings[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SightingCard extends StatelessWidget {
  final AnimalSighting sighting;
  const _SightingCard({required this.sighting});

  void _showDetailModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SightingDetailModal(sighting: sighting),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDetailModal(context),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(16)),
              child: sighting.imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: sighting.imageUrl,
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
                        Icon(Icons.pets, size: 16,
                          color: sighting.animalType == 'cat'
                            ? Colors.orange : Colors.brown),
                        const SizedBox(width: 4),
                        Text(sighting.animalType.toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: sighting.isNewIndividual
                              ? Colors.orange[100] : Colors.green[100],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            sighting.isNewIndividual ? 'NEW' : 'KNOWN',
                            style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.bold,
                              color: sighting.isNewIndividual
                                ? Colors.orange[800] : Colors.green[800],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Nickname
                    FutureBuilder<String>(
                      future: FirebaseService()
                          .getNickname(sighting.individualId),
                      builder: (context, snap) {
                        final name = snap.data ?? '...';
                        return Row(
                          children: [
                            const Icon(Icons.badge_outlined,
                              size: 12, color: Colors.grey),
                            const SizedBox(width: 2),
                            Text(name,
                              style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600,
                                color: Colors.black87)),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 4),

                    Row(
                      children: [
                        const Icon(Icons.location_on,
                          size: 12, color: Colors.grey),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(sighting.locationName,
                            style: const TextStyle(
                              fontSize: 12, color: Colors.grey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('MMM d, yyyy • h:mm a')
                          .format(sighting.timestamp),
                      style: const TextStyle(
                        fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(
                      'Confidence: ${(sighting.confidence * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 11, color: Colors.grey)),
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

// ── Detail Modal ──────────────────────────────────────────────
class _SightingDetailModal extends StatefulWidget {
  final AnimalSighting sighting;
  const _SightingDetailModal({required this.sighting});

  @override
  State<_SightingDetailModal> createState() => _SightingDetailModalState();
}

class _SightingDetailModalState extends State<_SightingDetailModal> {
  final _firebaseService = FirebaseService();
  String _nickname        = '...';
  String _characteristics = '';
  bool   _loadingMap      = false;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    final name       = await _firebaseService
        .getNickname(widget.sighting.individualId);
    final individual = await _firebaseService
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
    final sightings = await _firebaseService
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

          // Large image
          if (s.imageUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: s.imageUrl,
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
                // Name + badge
                Row(
                  children: [
                    Expanded(
                      child: Text(_nickname,
                        style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: s.isNewIndividual
                          ? Colors.orange[100] : Colors.green[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        s.isNewIndividual ? 'NEW' : 'KNOWN',
                        style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12,
                          color: s.isNewIndividual
                            ? Colors.orange[800] : Colors.green[800],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.pets, size: 14, color: color),
                    const SizedBox(width: 4),
                    Text(s.animalType.toUpperCase(),
                      style: TextStyle(
                        color: color, fontWeight: FontWeight.w600,
                        fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),

                // Characteristics (if set)
                if (_characteristics.isNotEmpty) ...[
                  _InfoRow(
                    icon: Icons.info_outline,
                    label: 'Characteristics',
                    value: _characteristics,
                  ),
                  const SizedBox(height: 8),
                ],

                _InfoRow(
                  icon: Icons.location_on,
                  label: 'Location',
                  value: s.locationName,
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.access_time,
                  label: 'Sighted',
                  value: DateFormat('MMM d, yyyy • h:mm a')
                      .format(s.timestamp),
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.analytics_outlined,
                  label: 'Confidence',
                  value: '${(s.confidence * 100).toStringAsFixed(1)}%',
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
                      : 'View $_nickname\'s Locations on Map'),
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
