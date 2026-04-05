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

  // Returns [bgColor, iconColor]
  List<Color> _getTint(String iconName) {
    switch (iconName) {
      case 'emergency':
        return [const Color(0xFFfce4ec), const Color(0xFFc62828)];
      case 'security':
        return [const Color(0xFFe3f2fd), const Color(0xFF1565c0)];
      case 'health':
        return [const Color(0xFFe8f5e9), const Color(0xFF2e7d32)];
      case 'business':
        return [const Color(0xFFede7f6), const Color(0xFF6a1b9a)];
      default: // pets → amber
        return [const Color(0xFFfff8e1), const Color(0xFFe65100)];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(title: const Text('Emergency Hotlines')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _hotlines.length,
        itemBuilder: (context, index) {
          final hotline = _hotlines[index];
          final tint    = _getTint(hotline['icon']!);
          final bgColor   = tint[0];
          final iconColor = tint[1];

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFe0e0e0), width: 0.5),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _getIcon(hotline['icon']!),
                      color: iconColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hotline['name']!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1a1a1a),
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          hotline['description']!,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF888888),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          hotline['number']!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: iconColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
