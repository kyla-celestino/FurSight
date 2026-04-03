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

  Color _getColor(String iconName) {
    switch (iconName) {
      case 'emergency': return Colors.red;
      case 'security':  return Colors.blue;
      case 'health':    return Colors.green;
      case 'business':  return Colors.purple;
      default:          return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency Hotlines')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _hotlines.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final hotline = _hotlines[index];
          final color   = _getColor(hotline['icon']!);
          return Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: color.withOpacity(0.1),
                child: Icon(
                  _getIcon(hotline['icon']!),
                  color: color,
                ),
              ),
              title: Text(
                hotline['name']!,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(hotline['description']!),
                  const SizedBox(height: 2),
                  Text(
                    hotline['number']!,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              isThreeLine: true,
            ),
          );
        },
      ),
    );
  }
}