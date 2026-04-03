import 'package:flutter/material.dart';

class HowItWorksScreen extends StatelessWidget {
  const HowItWorksScreen({super.key});

  static const List<Map<String, dynamic>> _steps = [
    {
      'step': 1,
      'title': 'Take or Upload a Photo',
      'description':
        'Spot a cat or dog on campus? Take a clear photo between '
        '8AM-5PM for best results. Make sure the animal fills '
        'most of the frame.',
      'icon': Icons.add_a_photo,
      'color': Color(0xFF4CAF50),
    },
    {
      'step': 2,
      'title': 'AI Detects the Animal',
      'description':
        'Our YOLOv8 model automatically detects whether there is '
        'a cat or dog in your photo and draws a bounding box '
        'around it.',
      'icon': Icons.search,
      'color': Color(0xFF2196F3),
    },
    {
      'step': 3,
      'title': 'Individual Identification',
      'description':
        'The re-identification model compares the animal\'s fur '
        'pattern and body features against known individuals '
        'in the database.',
      'icon': Icons.fingerprint,
      'color': Color(0xFF9C27B0),
    },
    {
      'step': 4,
      'title': 'Location is Recorded',
      'description':
        'Your GPS location is automatically captured and saved '
        'with the sighting, allowing us to track movement patterns.',
      'icon': Icons.location_on,
      'color': Color(0xFFFF9800),
    },
    {
      'step': 5,
      'title': 'Database Updated',
      'description':
        'If the animal is recognized, the sighting is added to '
        'their record. If it\'s a new individual, they\'re added '
        'to the database.',
      'icon': Icons.cloud_upload,
      'color': Color(0xFF00BCD4),
    },
    {
      'step': 6,
      'title': 'Heatmap Updated',
      'description':
        'The heatmap is updated in real-time to show areas with '
        'high animal activity around the UPLB lower campus.',
      'icon': Icons.map,
      'color': Color(0xFFF44336),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('How it Works?')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _steps.length,
        itemBuilder: (context, index) {
          final step   = _steps[index];
          final isLast = index == _steps.length - 1;

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timeline
                Column(
                  children: [
                    CircleAvatar(
                      backgroundColor: step['color'] as Color,
                      radius: 20,
                      child: Text(
                        '${step['step']}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: Colors.grey[300],
                          margin: const EdgeInsets.symmetric(vertical: 4),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),

                // Content
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              step['icon'] as IconData,
                              color: step['color'] as Color,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    step['title'] as String,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    step['description'] as String,
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}