import 'package:flutter/material.dart';

class HotlinesScreen extends StatelessWidget {
  const HotlinesScreen({super.key});

  static const List<Map<String, String>> _hotlines = [
    {
      'name': 'Emergency Hotline',
      'number': '119',
      'description': 'National Emergency Hotline',
      'icon': 'emergency',
    },
    {
      'name': 'UPLB Security Office',
      'number': '(049) 536-2354',
      'description': 'UPLB Campus Security',
      'icon': 'security',
    },
    {
      'name': 'UPLB Health Service',
      'number': '(049) 536-2387',
      'description': 'Campus Health Center',
      'icon': 'health',
    },
    {
      'name': 'PAWS Philippines',
      'number': '(02) 475-1688',
      'description': 'Philippine Animal Welfare Society',
      'icon': 'pets',
    },
    {
      'name': 'CARA Welfare Philippines',
      'number': '0917-548-2272',
      'description': 'Compassion and Responsibility for Animals',
      'icon': 'pets',
    },
    {
      'name': 'Bureau of Animal Industry',
      'number': '(02) 8525-5842',
      'description': 'Government Animal Authority',
      'icon': 'business',
    },
  ];

  IconData _getIcon(String iconName) {
    switch (iconName) {
      case 'emergency': return Icons.emergency;
      case 'security':  return Icons.security;
      case 'health':    return Icons.local_hospital;
      case 'business':  return Icons.business;
      default:          return Icons.pets;
    }
  }

  List<Color> _getTint(String iconName) {
    switch (iconName) {
      case 'emergency':
        return [const Color(0xFFFCEDE8), const Color(0xFFc62828)];
      case 'security':
        return [const Color(0xFFE3F2FD), const Color(0xFF1565c0)];
      case 'health':
        return [const Color(0xFFE8F5E9), const Color(0xFF2e7d32)];
      case 'business':
        return [const Color(0xFFEDE7F6), const Color(0xFF6a1b9a)];
      default:
        return [const Color(0xFFFFF8E1), const Color(0xFFe65100)];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0EDE8),
      appBar: AppBar(
        title: const Text('Emergency Hotlines'),
        backgroundColor: const Color(0xFFF0EDE8),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: const Color(0xFF1a1a1a),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Text(
              'Reach out to these organizations\nfor urgent animal-related help.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF888888),
                height: 1.4,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              itemCount: _hotlines.length,
              itemBuilder: (context, index) {
                final hotline   = _hotlines[index];
                final tint      = _getTint(hotline['icon']!);
                final bgColor   = tint[0];
                final iconColor = tint[1];

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 42, height: 42,
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            _getIcon(hotline['icon']!),
                            color: iconColor, size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hotline['name']!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1a1a1a),
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                hotline['description']!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF888888),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                hotline['number']!,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: iconColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.call_outlined,
                            size: 18, color: iconColor),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
