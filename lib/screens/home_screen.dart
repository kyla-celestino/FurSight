import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/firebase_service.dart';
import 'submit_screen.dart';
import 'heatmap_screen.dart';
import 'logs_screen.dart';
import 'hotlines_screen.dart';
import 'how_it_works_screen.dart';
import 'search_screen.dart'; // ← NEW

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService     = AuthService();
  final _firebaseService = FirebaseService();
  bool _seedUploaded     = false;

  @override
  void initState() {
    super.initState();
    // _checkAndUploadSeedData();
  }

  Future<void> _checkAndUploadSeedData() async {
    final exists = await _firebaseService.seedDataExists();
    if (!exists && !_seedUploaded) {
      _seedUploaded = true;
      await _firebaseService.uploadSeedEmbeddings();
    }
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

            // ── Search bar shortcut ───────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SearchScreen()),
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
                        'Search by name or characteristics...',
                        style: TextStyle(
                          color: Colors.grey[500], fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Quick Access
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Quick Access',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                      MaterialPageRoute(builder: (_) => const SubmitScreen())),
                  ),
                  _QuickAccessCard(
                    icon: Icons.map,
                    label: 'View\nHeatmap',
                    color: const Color(0xFF2196F3),
                    onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const HeatmapScreen())),
                  ),
                  _QuickAccessCard(
                    icon: Icons.assignment,
                    label: 'Submission\nLogs',
                    color: const Color(0xFFFF9800),
                    onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const LogsScreen())),
                  ),
                  _QuickAccessCard(
                    icon: Icons.emergency,
                    label: 'Emergency\nHotlines',
                    color: const Color(0xFFF44336),
                    onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const HotlinesScreen())),
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
                    MaterialPageRoute(builder: (_) => const HowItWorksScreen())),
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
