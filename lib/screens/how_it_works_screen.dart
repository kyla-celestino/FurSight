import 'package:flutter/material.dart';

class HowItWorksScreen extends StatelessWidget {
  const HowItWorksScreen({super.key});

  static const List<Map<String, dynamic>> _steps = [
    {
      'step': 1,
      'title': 'Take or Upload a Photo',
      'description':
          'Spot a cat or dog on campus? Take a clear photo between '
          '8AM–5PM for best results. Make sure the animal fills '
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
      backgroundColor: const Color(0xFFF0EDE8),
      appBar: AppBar(
        title: const Text('How it Works'),
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
              'Follow these steps to contribute\nto the FurFinder community.',
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
                        width: 32,
                        child: Column(
                          children: [
                            Container(
                              width: 32, height: 32,
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
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                            if (!isLast)
                              Expanded(
                                child: Center(
                                  child: Container(
                                    width: 2,
                                    color: const Color(0xFFc8e6c9),
                                    margin: const EdgeInsets.symmetric(
                                        vertical: 4),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Step card
                      Expanded(
                        child: Padding(
                          padding:
                              EdgeInsets.only(bottom: isLast ? 0 : 12),
                          child: Container(
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
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 32, height: 32,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F5E9),
                                    borderRadius:
                                        BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    step['icon'] as IconData,
                                    color: const Color(0xFF2e7d32),
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        step['title'] as String,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: Color(0xFF1a1a1a),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        step['description'] as String,
                                        style: const TextStyle(
                                          color: Color(0xFF888888),
                                          fontSize: 11,
                                          height: 1.5,
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
          ),
        ],
      ),
    );
  }
}
