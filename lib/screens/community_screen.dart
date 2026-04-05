import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../services/firebase_service.dart';
import '../models/animal_sighting.dart';
import 'heatmap_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final _firebaseService = FirebaseService();
  String _filter         = 'all';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Community Sightings')),
      body: Column(
        children: [
          // ── Filter dropdown ───────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const Text(
                  'All sightings from the community',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
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

          // ── Sightings stream ──────────────────────────────
          Expanded(
            child: StreamBuilder<List<AnimalSighting>>(
              stream: _firebaseService.getSightingsStream(
                animalType: _filter == 'all' ? null : _filter,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final sightings = snapshot.data ?? [];

                if (sightings.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.pets, size: 64, color: Colors.grey[300]),
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
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: sightings.length,
                  itemBuilder: (context, index) {
                    return _CommunitySightingCard(
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
}

class _CommunitySightingCard extends StatelessWidget {
  final AnimalSighting  sighting;
  final FirebaseService firebaseService;

  const _CommunitySightingCard({
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
            // Photo
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
                      future: firebaseService
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
                              fontSize: 11, color: Colors.grey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('MMM d, yyyy • h:mm a')
                          .format(sighting.timestamp),
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