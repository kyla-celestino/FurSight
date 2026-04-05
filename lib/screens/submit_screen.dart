import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
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
  final _aiService       = AIService();
  final _firebaseService = FirebaseService();
  final _locationService = LocationService();
  final _authService     = AuthService();
  final _picker          = ImagePicker();
  final _nicknameController = TextEditingController();

    @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  File?            _imageFile;
  SubmitState      _state          = SubmitState.idle;
  String           _statusMessage  = '';
  DetectionResult? _detectionResult;
  String?          _matchedIndividualId;
  double           _similarity     = 0.0;
  bool             _isNewIndividual = false;

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 1024,
    );
    if (picked == null) return;
    setState(() {
      _imageFile      = File(picked.path);
      _state          = SubmitState.idle;
      _detectionResult = null;
      _statusMessage  = '';
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
        _state          = SubmitState.detecting;
        _statusMessage  = 'Detecting animal...';
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

      final embedding = await _aiService.getEmbedding(detection.croppedImage);
      final knownEmbeddings = await _firebaseService.loadEmbeddings(
        detection.animalType,
      );
      final match = _aiService.findBestMatch(embedding, knownEmbeddings);

      _matchedIndividualId = match['individualId'];
      _similarity          = match['similarity'];
      _isNewIndividual     = _matchedIndividualId == null;

      setState(() {
        _statusMessage = 'Getting location...';
      });

      final position = await _locationService.getCurrentLocation();
      final locationName = await _locationService.getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );

      setState(() {
        _state         = SubmitState.uploading;
        _statusMessage = 'Uploading sighting...';
      });

      final imageUrl = await _firebaseService.uploadImage(
        _imageFile!,
        detection.animalType,
      );

      final individualId = await _firebaseService.updateIndividual(
        existingId:   _matchedIndividualId,
        animalType:   detection.animalType,
        newEmbedding: embedding,
        imageUrl:     imageUrl,
        nickname:     _nicknameController.text,
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
    _state == SubmitState.detecting  ||
    _state == SubmitState.identifying ||
    _state == SubmitState.uploading;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report a Sighting')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image Preview
            GestureDetector(
              onTap: _isProcessing ? null : _showImagePicker,
              child: Container(
                height: 280,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: _imageFile != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(_imageFile!, fit: BoxFit.cover),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo,
                          size: 60, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text(
                          'Tap to take or upload a photo',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
              ),
            ),
            const SizedBox(height: 16),

            // Image Picker Buttons
            if (!_isProcessing) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Camera'),
                      onPressed: () => _pickImage(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Gallery'),
                      onPressed: () => _pickImage(ImageSource.gallery),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Status Card
            if (_statusMessage.isNotEmpty)
              Card(
                color: _state == SubmitState.error
                  ? Colors.red[50]
                  : _state == SubmitState.done
                    ? Colors.green[50]
                    : Colors.blue[50],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (_isProcessing) ...[
                        const CircularProgressIndicator(),
                        const SizedBox(height: 12),
                      ],
                      Text(
                        _statusMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _state == SubmitState.error
                            ? Colors.red
                            : _state == SubmitState.done
                              ? Colors.green
                              : Colors.blue[800],
                          fontWeight: FontWeight.w500,
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
              ),

            const SizedBox(height: 16),

            // Optional nickname — only show when image is selected and not processing
            if (_imageFile != null && !_isProcessing && _state != SubmitState.done) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _nicknameController,
                decoration: InputDecoration(
                  labelText: 'Nickname (optional)',
                  hintText: 'e.g. Whiskers, Brownie...',
                  prefixIcon: const Icon(Icons.pets),
                  helperText: 'Leave blank to auto-assign a name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                textCapitalization: TextCapitalization.words,
                maxLength: 30,
              ),
              const SizedBox(height: 8),
            ],

            // Submit Button
            if (_imageFile != null &&
                !_isProcessing &&
                _state != SubmitState.done)
              ElevatedButton.icon(
                icon: const Icon(Icons.send),
                label: const Text('Submit Sighting'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _runPipeline,
              ),

            if (_state == SubmitState.done)
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Report Another'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  setState(() {
                    _imageFile       = null;
                    _state           = SubmitState.idle;
                    _statusMessage   = '';
                    _detectionResult = null;
                    _nicknameController.clear();
                  });
                },
              ),

            const SizedBox(height: 20),
            _PhotoGuidelines(),
          ],
        ),
      ),
    );
  }

  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }
}

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
            _Stat(
              'Detection',
              '${(confidence * 100).toStringAsFixed(1)}%',
            ),
            _Stat(
              'Status',
              isNew ? 'NEW' : 'KNOWN',
              color: isNew ? Colors.orange : Colors.green,
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
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color ?? Colors.black87,
          ),
        ),
      ],
    );
  }
}

class _PhotoGuidelines extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Colors.amber[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.tips_and_updates, color: Colors.amber),
                SizedBox(width: 8),
                Text(
                  'Photo Tips',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _Tip('Take photos between 8:00 AM and 5:00 PM'),
            _Tip('Make sure the animal is clearly visible'),
            _Tip('Avoid blurry or dark images'),
            _Tip('Animal should fill most of the frame'),
          ],
        ),
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
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 16,
            color: Colors.green,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}