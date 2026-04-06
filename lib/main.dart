import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/heatmap_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/community_screen.dart';
import 'screens/submit_screen.dart';
import 'screens/logs_screen.dart';
import 'screens/hotlines_screen.dart';
import 'screens/how_it_works_screen.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const FurFinderApp());
}

class FurFinderApp extends StatelessWidget {
  const FurFinderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FurFinder',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2e7d32),
          primary: const Color(0xFF2e7d32),
          secondary: const Color(0xFFFF9800),
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFFF0EDE8),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF0EDE8),
          foregroundColor: Color(0xFF1b5e20),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(
            color: Color(0xFF1a1a1a),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2e7d32),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(100),
            ),
          ),
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFF0EDE8),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF2e7d32)),
            ),
          );
        }
        if (snapshot.hasData) {
          return const MainShell();
        }
        return const AuthScreen();
      },
    );
  }
}

// ── Main Shell ────────────────────────────────────────────────
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final _screens = <Widget>[
    const HeatmapScreen(),
    const CommunityScreen(),
    const SubmitScreen(),
    const LogsScreen(),
    const _ProfileTab(),
  ];

  static const _tabIcons = <_NavTabData>[
    _NavTabData(Icons.map_outlined, Icons.map, 'MAP'),
    _NavTabData(Icons.people_outline, Icons.people, 'COMMUNITY'),
    _NavTabData(Icons.camera_alt_outlined, Icons.camera_alt, 'REPORT'),
    _NavTabData(Icons.list_alt_outlined, Icons.list_alt, 'HISTORY'),
    _NavTabData(Icons.person_outline, Icons.person, 'PROFILE'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0EDE8),
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        tabs: _tabIcons,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

class _NavTabData {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavTabData(this.icon, this.activeIcon, this.label);
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final List<_NavTabData> tabs;
  final ValueChanged<int> onTap;

  const _BottomNav({
    required this.currentIndex,
    required this.tabs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(
              tabs.length,
              (i) => _NavItem(
                data: tabs[i],
                isActive: i == currentIndex,
                onTap: () => onTap(i),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final _NavTabData data;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.data,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      borderRadius: BorderRadius.circular(100),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFE8F5E9) : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? data.activeIcon : data.icon,
              size: 22,
              color: isActive
                  ? const Color(0xFF2e7d32)
                  : const Color(0xFF888888),
            ),
            const SizedBox(height: 2),
            Text(
              data.label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
                color: isActive
                    ? const Color(0xFF2e7d32)
                    : const Color(0xFF888888),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ── Profile Tab ───────────────────────────────────────────────
class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final user = FirebaseAuth.instance.currentUser;
    final username =
        user?.displayName ?? user?.email?.split('@').first ?? 'User';
    final email = user?.email ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF0EDE8),
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Avatar + name ──────────────────────────────
            Center(
              child: Column(
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1b5e20),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2e7d32).withValues(alpha: 0.28),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.person,
                        color: Colors.white, size: 46),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    username,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1a1a1a),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified,
                          size: 14, color: Color(0xFF2e7d32)),
                      const SizedBox(width: 4),
                      Text(
                        email,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF888888),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Community ──────────────────────────────────
            const _SectionLabel('COMMUNITY'),
            const SizedBox(height: 8),
            _MenuCard(children: [
              _MenuItem(
                icon: Icons.help_outline,
                label: 'How it Works',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const HowItWorksScreen()),
                ),
              ),
              const _MenuDivider(),
              _MenuItem(
                icon: Icons.emergency_outlined,
                label: 'Emergency Hotlines',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HotlinesScreen()),
                ),
              ),
            ]),
            const SizedBox(height: 28),

            // ── Sign out ───────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () async => await authService.signOut(),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFFD32F2F),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Sign Out',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
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

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Color(0xFF888888),
        letterSpacing: 0.8,
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final List<Widget> children;
  const _MenuCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _MenuDivider extends StatelessWidget {
  const _MenuDivider();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, indent: 52, endIndent: 0,
          color: Color(0xFFF0EDE8));
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: const Color(0xFF2e7d32)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1a1a1a),
                ),
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 18, color: Color(0xFFBBBBBB)),
          ],
        ),
      ),
    );
  }
}
