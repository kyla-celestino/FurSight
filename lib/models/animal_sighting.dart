import 'package:cloud_firestore/cloud_firestore.dart';

class AnimalSighting {
  final String id;
  final String animalType;
  final String individualId;
  final String imageUrl;
  final double latitude;
  final double longitude;
  final String locationName;
  final DateTime timestamp;
  final String submittedBy;
  final double confidence;
  final double similarity;
  final bool isNewIndividual;
  final List<double> embedding;

  AnimalSighting({
    required this.id,
    required this.animalType,
    required this.individualId,
    required this.imageUrl,
    required this.latitude,
    required this.longitude,
    required this.locationName,
    required this.timestamp,
    required this.submittedBy,
    required this.confidence,
    required this.similarity,
    required this.isNewIndividual,
    required this.embedding,
  });

  factory AnimalSighting.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AnimalSighting(
      id: doc.id,
      animalType: data['animalType'] ?? '',
      individualId: data['individualId'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      latitude: (data['latitude'] ?? 0.0).toDouble(),
      longitude: (data['longitude'] ?? 0.0).toDouble(),
      locationName: data['locationName'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      submittedBy: data['submittedBy'] ?? '',
      confidence: (data['confidence'] ?? 0.0).toDouble(),
      similarity: (data['similarity'] ?? 0.0).toDouble(),
      isNewIndividual: data['isNewIndividual'] ?? false,
      embedding: List<double>.from(data['embedding'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'animalType': animalType,
      'individualId': individualId,
      'imageUrl': imageUrl,
      'latitude': latitude,
      'longitude': longitude,
      'locationName': locationName,
      'timestamp': Timestamp.fromDate(timestamp),
      'submittedBy': submittedBy,
      'confidence': confidence,
      'similarity': similarity,
      'isNewIndividual': isNewIndividual,
      'embedding': embedding,
    };
  }
}

class AnimalIndividual {
  final String id;
  final String animalType;
  final List<double> avgEmbedding;
  final int sightingCount;
  final DateTime firstSeen;
  final DateTime lastSeen;
  final String latestImageUrl;

  AnimalIndividual({
    required this.id,
    required this.animalType,
    required this.avgEmbedding,
    required this.sightingCount,
    required this.firstSeen,
    required this.lastSeen,
    required this.latestImageUrl,
  });

  factory AnimalIndividual.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AnimalIndividual(
      id: doc.id,
      animalType: data['animalType'] ?? '',
      avgEmbedding: List<double>.from(data['avgEmbedding'] ?? []),
      sightingCount: data['sightingCount'] ?? 0,
      firstSeen: (data['firstSeen'] as Timestamp).toDate(),
      lastSeen: (data['lastSeen'] as Timestamp).toDate(),
      latestImageUrl: data['latestImageUrl'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'animalType': animalType,
      'avgEmbedding': avgEmbedding,
      'sightingCount': sightingCount,
      'firstSeen': Timestamp.fromDate(firstSeen),
      'lastSeen': Timestamp.fromDate(lastSeen),
      'latestImageUrl': latestImageUrl,
    };
  }
}