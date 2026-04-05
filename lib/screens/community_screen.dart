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
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(title: const Text('Community Sightings')),
      body: Column(
        children: [
          // ── Filter row ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const Text(
                  'All community sightings',
                  style: TextStyle(
                    color: Color(0xFF888888), fontSize: 12),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _showFilterSheet(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFe0e0e0), width: 0.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.filter_list,
                          size: 16, color: Color(0xFF555555)),
                        const SizedBox(width: 6),
                        Text(
                          _filterLabel,
                          style: const TextStyle(
                            fontSize: 12, color: Color(0xFF555555)),
                        ),
                      ],
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
                        const Icon(Icons.pets, size: 64,
                          color: Color(0xFFc8e6c9)),
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
                  padding: const EdgeInsets.only(bottom: 16),
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

  String get _filterLabel {
    switch (_filter) {
      case 'cat': return 'Cats';
      case 'dog': return 'Dogs';
      default:    return 'All';
    }
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              title: const Text('All'),
              trailing: _filter == 'all'
                ? const Icon(Icons.check, color: Color(0xFF2e7d32))
                : null,
              onTap: () {
                setState(() => _filter = 'all');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Cats'),
              trailing: _filter == 'cat'
                ? const Icon(Icons.check, color: Color(0xFF2e7d32))
                : null,
              onTap: () {
                setState(() => _filter = 'cat');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Dogs'),
              trailing: _filter == 'dog'
                ? const Icon(Icons.check, color: Color(0xFF2e7d32))
                : null,
              onTap: () {
                setState(() => _filter = 'dog');
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
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
    final iscat     = sighting.animalType == 'cat';
    final typeColor = iscat
      ? const Color(0xFFef6c00)
      : const Color(0xFF795548);
    final isNew     = sighting.isNewIndividual;

    return GestureDetector(
      onTap: () => _showDetailModal(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFe0e0e0), width: 0.5),
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(12)),
              child: sighting.imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: sighting.imageUrl,
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
                    // Type + badge
                    Row(
                      children: [
                        Icon(Icons.pets, size: 11, color: typeColor),
                        const SizedBox(width: 3),
                        Text(
                          sighting.animalType.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: typeColor,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isNew
                              ? const Color(0xFFfff8e1)
                              : const Color(0xFFe8f5e9),
                            borderRadius: BorderRadius.circular(20),
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
                      ],
                    ),
                    const SizedBox(height: 3),

                    // Name
                    FutureBuilder<String>(
                      future: firebaseService
                          .getNickname(sighting.individualId),
                      builder: (context, snap) {
                        final name = snap.data ?? '...';
                        return Text(
                          name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1a1a1a),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                    const SizedBox(height: 3),

                    // Meta: location · date
                    Text(
                      '📍 ${sighting.locationName} · '
                      '${DateFormat('MMM d, h:mm a').format(sighting.timestamp)}',
                      style: const TextStyle(
                        fontSize: 10, color: Color(0xFF888888)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),

            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.chevron_right,
                color: Color(0xFF888888), size: 16),
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
    final s      = widget.sighting;
    final iscat  = s.animalType == 'cat';
    final color  = iscat
      ? const Color(0xFFef6c00)
      : const Color(0xFF795548);
    final isNew  = s.isNewIndividual;

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
                    borderRadius: BorderRadius.circular(12),
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
                        horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(20),
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
                        color: color, fontWeight: FontWeight.w700,
                        fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, thickness: 0.5),
                const SizedBox(height: 12),

                // Info grid
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
                          value: '${(s.confidence * 100).toStringAsFixed(1)}%',
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
                  fullWidth: true,
                ),
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
