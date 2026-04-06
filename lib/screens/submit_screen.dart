import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/ai_service.dart';
import '../services/firebase_service.dart';
import '../services/location_service.dart';
import '../services/auth_service.dart';
import '../models/animal_sighting.dart';

enum SubmitState { idle, detecting, identifying, uploading, done, error }

class SubmitScreen extends StatefulWidget {
  const SubmitScreen({super.key});

  @override
  State<SubmitScreen> createState() => _SubmitScreenState();
}

class _SubmitScreenState extends State<SubmitScreen> {
  final _aiService              = AIService();
  final _firebaseService        = FirebaseService();
  final _locationService        = LocationService();
  final _authService            = AuthService();
  final _picker                 = ImagePicker();
  final _nicknameController     = TextEditingController();
  final _characteristicsController = TextEditingController();

  @override
  void dispose() {
    _nicknameController.dispose();
    _characteristicsController.dispose();
    super.dispose();
  }

  File?            _imageFile;
  SubmitState      _state         = SubmitState.idle;
  String           _statusMessage = '';
  DetectionResult? _detectionResult;
  String?          _matchedIndividualId;
  double           _similarity    = 0.0;
  bool             _isNewIndividual = false;

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source, imageQuality: 90, maxWidth: 1024,
    );
    if (picked == null) return;
    setState(() {
      _imageFile       = File(picked.path);
      _state           = SubmitState.idle;
      _detectionResult = null;
      _statusMessage   = '';
    });
  }

  Future<void> _runPipeline() async {
    if (_imageFile == null) return;
    final hour = DateTime.now().hour;
    if (hour < 8 || hour >= 17) {
      _showWarning(
        'Photo Quality Warning',
        'For best results, please take photos between 8:00 AM and 5:00 PM when lighting is optimal.',
      );
      return;
    }
    await _runPipelineInternal();
  }

  Future<void> _runPipelineInternal() async {
    if (_imageFile == null) return;
    try {
      setState(() {
        _state         = SubmitState.detecting;
        _statusMessage = 'Detecting animal...';
      });

      final detection = await _aiService.detectAnimal(_imageFile!);
      if (detection == null) {
        setState(() {
          _state         = SubmitState.error;
          _statusMessage = 'No cat or dog detected. Please try another photo.';
        });
        return;
      }
      _detectionResult = detection;

      setState(() {
        _state         = SubmitState.identifying;
        _statusMessage =
            'Identified as ${detection.animalType}! Checking identity...';
      });

      final embedding      = await _aiService.getEmbedding(detection.croppedImage);
      final knownEmbeddings = await _firebaseService.loadEmbeddings(
        detection.animalType,
      );
      final match = _aiService.findBestMatch(embedding, knownEmbeddings);

      _matchedIndividualId = match['individualId'];
      _similarity          = match['similarity'];
      _isNewIndividual     = _matchedIndividualId == null;

      setState(() { _statusMessage = 'Getting location...'; });

      final position     = await _locationService.getCurrentLocation();
      final locationName = await _locationService.getAddressFromCoordinates(
        position.latitude, position.longitude,
      );

      setState(() {
        _state         = SubmitState.uploading;
        _statusMessage = 'Uploading sighting...';
      });

      final imageUrl = await _firebaseService.uploadImage(
        _imageFile!, detection.animalType,
      );

      final individualId = await _firebaseService.updateIndividual(
        existingId:      _matchedIndividualId,
        animalType:      detection.animalType,
        newEmbedding:    embedding,
        imageUrl:        imageUrl,
        nickname:        _nicknameController.text,
        characteristics: _characteristicsController.text,
      );

      final sighting = AnimalSighting(
        id:              '',
        animalType:      detection.animalType,
        individualId:    individualId,
        imageUrl:        imageUrl,
        latitude:        position.latitude,
        longitude:       position.longitude,
        locationName:    locationName,
        timestamp:       DateTime.now(),
        submittedBy:     _authService.currentUserId,
        confidence:      detection.confidence,
        similarity:      _similarity,
        isNewIndividual: _isNewIndividual,
        embedding:       embedding,
      );

      await _firebaseService.saveSighting(sighting);

      setState(() {
        _state         = SubmitState.done;
        _statusMessage = _isNewIndividual
            ? '🐾 New ${detection.animalType} added to the database!'
            : '✅ Matched with a known ${detection.animalType}!';
      });
    } catch (e) {
      setState(() {
        _state         = SubmitState.error;
        _statusMessage = 'Error: ${e.toString()}';
      });
    }
  }

  void _showWarning(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _runPipelineInternal();
            },
            child: const Text('Submit Anyway'),
          ),
        ],
      ),
    );
  }

  bool get _isProcessing =>
      _state == SubmitState.detecting ||
      _state == SubmitState.identifying ||
      _state == SubmitState.uploading;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0EDE8),
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Page title ───────────────────────────────────
            const Text(
              'Report a Sighting',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1a1a1a),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Help the community by documenting found\nor wandering pets with clarity.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF888888),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),

            // ── Viewfinder card ──────────────────────────────
            GestureDetector(
              onTap: _isProcessing ? null : _showImagePicker,
              child: AspectRatio(
                aspectRatio: 4 / 3,
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
                child: _imageFile != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.file(_imageFile!, fit: BoxFit.cover,
                          width: double.infinity, height: double.infinity),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 60, height: 60,
                          decoration: const BoxDecoration(
                            color: Color(0xFF2e7d32),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt,
                              color: Colors.white, size: 28),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'LIVE VIEWFINDER',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFAAAAAA),
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ── Photo picker buttons ─────────────────────────
            if (!_isProcessing) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: const Text('Take Photo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2e7d32),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  onPressed: () => _pickImage(ImageSource.camera),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  icon: const Icon(Icons.image_outlined, size: 18),
                  label: const Text('Upload from Gallery'),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF2e7d32),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  onPressed: () => _pickImage(ImageSource.gallery),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ── Status card ──────────────────────────────────
            if (_statusMessage.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _state == SubmitState.error
                    ? const Color(0xFFFCEDE8)
                    : _state == SubmitState.done
                      ? const Color(0xFFE8F5E9)
                      : const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    if (_isProcessing) ...[
                      const CircularProgressIndicator(
                          color: Color(0xFF2e7d32)),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      _statusMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _state == SubmitState.error
                          ? const Color(0xFFD32F2F)
                          : _state == SubmitState.done
                            ? const Color(0xFF2e7d32)
                            : const Color(0xFF1565c0),
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                    if (_state == SubmitState.done &&
                        _detectionResult != null) ...[
                      const SizedBox(height: 12),
                      _ResultDetails(
                        animalType: _detectionResult!.animalType,
                        confidence: _detectionResult!.confidence,
                        similarity: _similarity,
                        isNew: _isNewIndividual,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Form fields ──────────────────────────────────
            if (_imageFile != null &&
                !_isProcessing &&
                _state != SubmitState.done) ...[
              _FieldLabel('PET NAME (OPTIONAL)'),
              const SizedBox(height: 6),
              _FormField(
                controller: _nicknameController,
                hint: 'e.g. Buddy',
                capitalization: TextCapitalization.words,
                maxLength: 30,
              ),
              const SizedBox(height: 14),
              _FieldLabel('CHARACTERISTICS (OPTIONAL)'),
              const SizedBox(height: 6),
              _FormField(
                controller: _characteristicsController,
                hint: 'e.g. white patch on chest, limps on left leg',
                maxLength: 120,
              ),
              const SizedBox(height: 24),

              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('Submit Sighting'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2e7d32),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  onPressed: _runPipeline,
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Done — report another ────────────────────────
            if (_state == SubmitState.done) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Report Another'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2e7d32),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      _imageFile                = null;
                      _state                   = SubmitState.idle;
                      _statusMessage           = '';
                      _detectionResult         = null;
                      _nicknameController.clear();
                      _characteristicsController.clear();
                    });
                  },
                ),
              ),
            ],

            // ── Always-visible photo tips ─────────────────────
            const SizedBox(height: 8),
            _PhotoGuidelinesCard(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.camera_alt,
                    color: Color(0xFF2e7d32), size: 18),
              ),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.photo_library,
                    color: Color(0xFF2e7d32), size: 18),
              ),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
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
      actions: const [
        Padding(
          padding: EdgeInsets.only(right: 12),
          child: Icon(Icons.notifications_outlined,
              color: Color(0xFF777777), size: 22),
        ),
      ],
    );
  }
}

// ── Shared form widgets ───────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Color(0xFF888888),
        letterSpacing: 0.6,
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextCapitalization capitalization;
  final int? maxLength;
  const _FormField({
    required this.controller,
    required this.hint,
    this.capitalization = TextCapitalization.none,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE8E5E0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: controller,
        maxLength: maxLength,

        textCapitalization: capitalization,
        style: const TextStyle(fontSize: 14, color: Color(0xFF1a1a1a)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
              color: Color(0xFFAAAAAA), fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 14),
          counterText: '',
        ),
      ),
    );
  }
}

// ── Result details ────────────────────────────────────────────
class _ResultDetails extends StatelessWidget {
  final String animalType;
  final double confidence;
  final double similarity;
  final bool isNew;

  const _ResultDetails({
    required this.animalType,
    required this.confidence,
    required this.similarity,
    required this.isNew,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Divider(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _Stat('Animal', animalType.toUpperCase()),
            _Stat('Detection',
                '${(confidence * 100).toStringAsFixed(1)}%'),
            _Stat(
              'Status',
              isNew ? 'NEW' : 'KNOWN',
              color: isNew
                  ? const Color(0xFFe65100)
                  : const Color(0xFF2e7d32),
            ),
          ],
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _Stat(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: Color(0xFF888888))),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color ?? const Color(0xFF1a1a1a),
          ),
        ),
      ],
    );
  }
}

// ── Photo guidelines card ─────────────────────────────────────
class _PhotoGuidelinesCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E8),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 8, offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tips_and_updates,
                  color: Color(0xFFe65100), size: 18),
              SizedBox(width: 8),
              Text(
                'Photo Tips',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Color(0xFF1a1a1a),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _Tip('Take photos between 8:00 AM and 5:00 PM'),
          _Tip('Make sure the animal is clearly visible'),
          _Tip('Avoid blurry or dark images'),
          _Tip('Animal should fill most of the frame'),
        ],
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  final String text;
  const _Tip(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline,
              size: 15, color: Color(0xFF2e7d32)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF555555))),
          ),
        ],
      ),
    );
  }
}
