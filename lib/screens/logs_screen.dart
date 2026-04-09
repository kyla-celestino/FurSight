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

  List<AnimalSighting> _allSightings = [];
  bool _loading = true;

  late final _streamSub = _firebaseService
      .getUserSightings(_authService.currentUserId)
      .listen((data) {
        if (mounted) setState(() { _allSightings = data; _loading = false; });
      });

  @override
  void initState() {
    super.initState();
    _streamSub; // initialise
  }

  @override
  void dispose() {
    _streamSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allSightings = _allSightings;
    final sightings    = _filter == 'all'
        ? allSightings
        : allSightings.where((s) => s.animalType == _filter).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF0EDE8),
      appBar: _buildAppBar(),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2e7d32)),
            )
          : CustomScrollView(
              slivers: [
                // ── Scrollable header: title + subtitle + stats ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Submission Logs',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1a1a1a),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Your contribution to the community helps\nbring pets back home.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF888888),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _StatsRow(
                          total: allSightings.length,
                          dogs: allSightings
                              .where((s) => s.animalType == 'dog')
                              .length,
                          cats: allSightings
                              .where((s) => s.animalType == 'cat')
                              .length,
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Sticky: search bar + filter chips ────────────
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _StickyBarDelegate(
                    height: 106,
                    backgroundColor: const Color(0xFFF0EDE8),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
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
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _LogsFilterChip(
                                label: 'All',
                                isActive: _filter == 'all',
                                onTap: () => setState(() => _filter = 'all'),
                              ),
                              const SizedBox(width: 8),
                              _LogsFilterChip(
                                label: 'Dogs',
                                isActive: _filter == 'dog',
                                onTap: () => setState(() => _filter = 'dog'),
                              ),
                              const SizedBox(width: 8),
                              _LogsFilterChip(
                                label: 'Cats',
                                isActive: _filter == 'cat',
                                onTap: () => setState(() => _filter = 'cat'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Empty state ────────────────────────────────
                if (sightings.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.pets,
                              size: 64, color: Color(0xFFc8e6c9)),
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
                    ),
                  ),

                // ── Sightings list ─────────────────────────────
                if (sightings.isNotEmpty)
                  SliverPadding(
                    padding:
                        const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _SightingCard(
                          sighting: sightings[index],
                          isFirst: index == 0,
                        ),
                        childCount: sightings.length,
                      ),
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
      actions: const [],
    );
  }

}

// ── Filter chip (logs) ────────────────────────────────────────
class _LogsFilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _LogsFilterChip({
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
          color: isActive ? const Color(0xFF2e7d32) : Colors.white,
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

// ── Sighting card ─────────────────────────────────────────────
class _SightingCard extends StatelessWidget {
  final AnimalSighting sighting;
  final bool isFirst;

  const _SightingCard({required this.sighting, this.isFirst = false});

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
    // First item — large featured card
    if (isFirst) {
      return GestureDetector(
        onTap: () => _showDetailModal(context),
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
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
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20)),
                    child: sighting.imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: sighting.imageUrl,
                          height: 190, width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            height: 190,
                            color: const Color(0xFFe8f5e9)),
                          errorWidget: (_, __, ___) => Container(
                            height: 190, color: const Color(0xFFe8f5e9),
                            child: const Icon(Icons.pets,
                                size: 60, color: Color(0xFF2e7d32))),
                        )
                      : Container(
                          height: 190, color: const Color(0xFFe8f5e9),
                          child: const Icon(Icons.pets,
                              size: 60, color: Color(0xFF2e7d32))),
                  ),
                  // Status badge on photo
                  Positioned(
                    top: 12, left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: sighting.animalType == 'cat'
                            ? const Color(0xFFef6c00)
                            : const Color(0xFF795548),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6, height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            sighting.animalType.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: FutureBuilder<String>(
                            future: FirebaseService()
                                .getNickname(sighting.individualId),
                            builder: (context, snap) => Text(
                              snap.data ?? '...',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1a1a1a),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            size: 12, color: Color(0xFF888888)),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            '${sighting.locationName} · ${_timeAgo(sighting.timestamp)}',
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
            ],
          ),
        ),
      );
    }

    // Subsequent items — compact row
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
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: ClipOval(
                child: sighting.imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: sighting.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: const Color(0xFFe8f5e9),
                        child: const Icon(Icons.pets,
                            color: Color(0xFF2e7d32), size: 22)),
                      errorWidget: (_, __, ___) => Container(
                        color: const Color(0xFFe8f5e9),
                        child: const Icon(Icons.pets,
                            color: Color(0xFF2e7d32), size: 22)),
                    )
                  : Container(
                      color: const Color(0xFFe8f5e9),
                      child: const Icon(Icons.pets,
                          color: Color(0xFF2e7d32), size: 22)),
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: sighting.animalType == 'cat'
                              ? const Color(0xFFFFF3E0)
                              : const Color(0xFFEFEBE9),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          sighting.animalType.toUpperCase(),
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: sighting.animalType == 'cat'
                                ? const Color(0xFFef6c00)
                                : const Color(0xFF795548),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _timeAgo(sighting.timestamp),
                        style: const TextStyle(
                          fontSize: 10, color: Color(0xFF888888)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  FutureBuilder<String>(
                    future: FirebaseService()
                        .getNickname(sighting.individualId),
                    builder: (context, snap) => Text(
                      snap.data ?? '...',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14,
                        color: Color(0xFF1a1a1a),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    sighting.locationName,
                    style: const TextStyle(
                      fontSize: 11, color: Color(0xFF888888)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.more_vert,
                color: Color(0xFFBBBBBB), size: 18),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ── Detail Modal ──────────────────────────────────────────────
class _SightingDetailModal extends StatefulWidget {
  final AnimalSighting sighting;
  const _SightingDetailModal({required this.sighting});

  @override
  State<_SightingDetailModal> createState() =>
      _SightingDetailModalState();
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

  Future<void> _renameAnimal() async {
    final controller = TextEditingController(text: _nickname);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename Animal'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Enter new name'),
          textCapitalization: TextCapitalization.words,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty && mounted) {
      await _firebaseService
          .renameIndividual(widget.sighting.individualId, newName);
      setState(() => _nickname = newName);
    }
  }

  static const _reportReasons = [
    'Wrong animal type (cat vs dog)',
    'Wrong individual (matched wrong animal)',
    'Same animal, different individual entry (duplicate)',
    'Animal not clearly visible in photo',
    'No animal present in the photo',
    'Animal present but AI could not find it',
    'Other',
  ];

  Future<void> _showReportSheet() async {
    final selected = <String>{};
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Text(
                  'Report Sighting',
                  style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700,
                    color: Color(0xFF1a1a1a),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  'Select all reasons that apply. This helps improve the AI.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF888888)),
                ),
              ),
              const Divider(height: 1),
              ..._reportReasons.map((reason) => CheckboxListTile(
                value: selected.contains(reason),
                onChanged: (val) => setSheetState(() {
                  if (val == true) selected.add(reason);
                  else selected.remove(reason);
                }),
                title: Text(reason,
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF1a1a1a))),
                activeColor: const Color(0xFF2e7d32),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20),
                dense: true,
              )),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: selected.isEmpty ? null : () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFb71c1c),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[300],
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100)),
                    ),
                    child: const Text('Submit Report',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (selected.isEmpty || !mounted) return;

    try {
      await _firebaseService.saveReport(
        sightingId:   widget.sighting.id,
        individualId: widget.sighting.individualId,
        animalType:   widget.sighting.animalType,
        reportedBy:   widget.sighting.submittedBy,
        reasons:      selected.toList(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report submitted. Thank you for the feedback!'),
          backgroundColor: Color(0xFF2e7d32),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to submit report. Please try again.'),
          backgroundColor: Color(0xFFb71c1c),
        ),
      );
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
                          horizontal: 10, vertical: 5),
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(_nickname,
                          style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700,
                            color: Color(0xFF1a1a1a))),
                    ),
                    IconButton(
                      onPressed: _renameAnimal,
                      icon: const Icon(Icons.edit_outlined,
                          size: 18, color: Color(0xFF888888)),
                      tooltip: 'Rename',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
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
                  _InfoTile(
                    label: 'Characteristics',
                    value: _characteristics,
                    fullWidth: true,
                  ),
                  const SizedBox(height: 8),
                ],
                _InfoTile(
                  label: 'Similarity',
                  value: '${(s.confidence * 100).toStringAsFixed(1)}%',
                  fullWidth: true,
                ),
                const SizedBox(height: 8),
                _InfoTile(
                  label: 'Location', value: s.locationName, fullWidth: true),
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
                    onPressed: _loadingMap ? null : _openIndividualHeatmap,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    icon: const Icon(Icons.flag_outlined,
                        size: 16, color: Color(0xFFb71c1c)),
                    label: const Text(
                      'Report Incorrect Classification',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFFb71c1c),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onPressed: _showReportSheet,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                        side: const BorderSide(
                            color: Color(0xFFf48fb1), width: 0.5),
                      ),
                    ),
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

// ── Sticky header delegate ────────────────────────────────────
class _StickyBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;
  final Color backgroundColor;

  const _StickyBarDelegate({
    required this.child,
    required this.height,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      Material(color: backgroundColor, elevation: 0, child: child);

  @override double get maxExtent => height;
  @override double get minExtent => height;
  @override bool shouldRebuild(_StickyBarDelegate old) => true;
}

// ── Stats row ─────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final int total, dogs, cats;
  const _StatsRow({
    required this.total,
    required this.dogs,
    required this.cats,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Total submissions card
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFBDD9A8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome,
                          size: 14, color: Color(0xFF2e7d32)),
                      SizedBox(width: 3),
                      Icon(Icons.auto_awesome,
                          size: 9, color: Color(0xFF2e7d32)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$total',
                    style: const TextStyle(
                      fontSize: 52,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2e7d32),
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'TOTAL\nSUBMISSIONS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2e7d32),
                      letterSpacing: 0.3,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Dogs + cats column
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5E3B0),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$dogs',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF7A5200),
                            height: 1.0,
                          ),
                        ),
                        const Text(
                          'DOGS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF7A5200),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5C8C0),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$cats',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF7A1A1A),
                            height: 1.0,
                          ),
                        ),
                        const Text(
                          'CATS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF7A1A1A),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
  final bool fullWidth;

  const _InfoTile({
    required this.label,
    required this.value,
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