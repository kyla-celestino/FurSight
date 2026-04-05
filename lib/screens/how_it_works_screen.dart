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
    },
    {
      'step': 2,
      'title': 'AI Detects the Animal',
      'description':
        'Our YOLOv8 model automatically detects whether there is '
        'a cat or dog in your photo and draws a bounding box '
        'around it.',
      'icon': Icons.search,
    },
    {
      'step': 3,
      'title': 'Individual Identification',
      'description':
        'The re-identification model compares the animal\'s fur '
        'pattern and body features against known individuals '
        'in the database.',
      'icon': Icons.fingerprint,
    },
    {
      'step': 4,
      'title': 'Location is Recorded',
      'description':
        'Your GPS location is automatically captured and saved '
        'with the sighting, allowing us to track movement patterns.',
      'icon': Icons.location_on,
    },
    {
      'step': 5,
      'title': 'Database Updated',
      'description':
        'If the animal is recognized, the sighting is added to '
        'their record. If it\'s a new individual, they\'re added '
        'to the database.',
      'icon': Icons.cloud_upload,
    },
    {
      'step': 6,
      'title': 'Heatmap Updated',
      'description':
        'The heatmap is updated in real-time to show areas with '
        'high animal activity around the UPLB lower campus.',
      'icon': Icons.map,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(title: const Text('How it Works?')),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: _steps.length,
        itemBuilder: (context, index) {
          final step   = _steps[index];
          final isLast = index == _steps.length - 1;

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timeline column
                SizedBox(
                  width: 24,
                  child: Column(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: Color(0xFF2e7d32),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${step['step']}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Center(
                            child: Container(
                              width: 1.5,
                              color: const Color(0xFFc8e6c9),
                              margin: const EdgeInsets.symmetric(vertical: 4),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Step card
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFe0e0e0), width: 0.5),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: const Color(0xFFe8f5e9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              step['icon'] as IconData,
                              color: const Color(0xFF2e7d32),
                              size: 11,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  step['title'] as String,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                    color: Color(0xFF1a1a1a),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  step['description'] as String,
                                  style: const TextStyle(
                                    color: Color(0xFF888888),
                                    fontSize: 10,
                                    height: 1.4,
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
              ],
            ),
          );
        },
      ),
    );
  }
}
