import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../models/animal_sighting.dart';

class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final _uuid = const Uuid();

  CollectionReference get _sightings => _db.collection('sightings');
  CollectionReference get _individuals => _db.collection('individuals');

  Future<Map<String, List<double>>> loadEmbeddings(String animalType) async {
    try {
      final snapshot = await _individuals
          .where('animalType', isEqualTo: animalType)
          .get();
      final Map<String, List<double>> embeddings = {};
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final embedding = List<double>.from(data['avgEmbedding'] ?? []);
        if (embedding.isNotEmpty) embeddings[doc.id] = embedding;
      }
      return embeddings;
    } catch (e) {
      return {};
    }
  }

  // ── Load ALL embeddings across cat + dog (for image search) ─
  Future<Map<String, List<double>>> getAllEmbeddings() async {
    try {
      final snapshot = await _individuals.get();
      final Map<String, List<double>> embeddings = {};
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final embedding = List<double>.from(data['avgEmbedding'] ?? []);
        if (embedding.isNotEmpty) embeddings[doc.id] = embedding;
      }
      return embeddings;
    } catch (e) {
      return {};
    }
  }

  // ── Fetch multiple individuals by their IDs ───────────────
  Future<List<AnimalIndividual>> getIndividualsByIds(
      List<String> ids) async {
    if (ids.isEmpty) return [];
    try {
      final results = <AnimalIndividual>[];
      for (final id in ids) {
        final doc = await _individuals.doc(id).get();
        if (doc.exists) {
          results.add(AnimalIndividual.fromFirestore(doc));
        }
      }
      return results;
    } catch (e) {
      return [];
    }
  }

  Future<void> uploadSeedEmbeddings() async {
    try {
      final jsonStr = await rootBundle.loadString(
        'assets/models/seed_embeddings_v3.json',
      );
      final Map<String, dynamic> seedData = json.decode(jsonStr);
      WriteBatch batch = _db.batch();
      int count = 0;
      for (final entry in seedData.entries) {
        final data = entry.value as Map<String, dynamic>;
        final docRef = _individuals.doc(
          entry.key.replaceAll('/', '_'),
        );
        batch.set(docRef, {
          'animalType': data['animal_type'] as String,
          'avgEmbedding': List<double>.from(data['embedding']),
          'sightingCount': 0,
          'firstSeen': Timestamp.now(),
          'lastSeen': Timestamp.now(),
          'latestImageUrl': '',
          'nickname': '',
          'characteristics': '',
        });
        count++;
        if (count % 400 == 0) {
          await batch.commit();
          batch = _db.batch();
        }
      }
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to upload seed embeddings: $e');
    }
  }

  Future<String> uploadImage(File imageFile, String animalType) async {
    final fileName = '${_uuid.v4()}.jpg';
    final ref = _storage.ref().child('sightings/$animalType/$fileName');
    await ref.putFile(imageFile);
    return await ref.getDownloadURL();
  }

  Future<String> saveSighting(AnimalSighting sighting) async {
    final docRef = await _sightings.add(sighting.toMap());
    return docRef.id;
  }

  Future<String> updateIndividual({
    required String? existingId,
    required String animalType,
    required List<double> newEmbedding,
    required String imageUrl,
    String? nickname,
    String? characteristics,
  }) async {
    if (existingId != null) {
      final docRef = _individuals.doc(existingId);
      final doc = await docRef.get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final oldEmbedding = List<double>.from(data['avgEmbedding'] ?? []);
        final count = (data['sightingCount'] ?? 0) as int;

        List<double> updatedEmbedding = oldEmbedding;
        if (oldEmbedding.length == newEmbedding.length) {
          updatedEmbedding = List.generate(
            newEmbedding.length,
            (i) => (oldEmbedding[i] * count + newEmbedding[i]) / (count + 1),
          );
        }

        final updateData = <String, dynamic>{
          'avgEmbedding': updatedEmbedding,
          'sightingCount': FieldValue.increment(1),
          'lastSeen': Timestamp.now(),
          'latestImageUrl': imageUrl,
        };
        if (nickname != null && nickname.trim().isNotEmpty) {
          updateData['nickname'] = nickname.trim();
        }
        if (characteristics != null && characteristics.trim().isNotEmpty) {
          updateData['characteristics'] = characteristics.trim();
        }

        await docRef.update(updateData);
        return existingId;
      }
    }

    final autoName = await _generateNickname(animalType, nickname);
    final docRef = await _individuals.add({
      'animalType': animalType,
      'avgEmbedding': newEmbedding,
      'sightingCount': 1,
      'firstSeen': Timestamp.now(),
      'lastSeen': Timestamp.now(),
      'latestImageUrl': imageUrl,
      'nickname': autoName,
      'characteristics': characteristics?.trim() ?? '',
    });
    return docRef.id;
  }

  Future<String> getNickname(String individualId) async {
    try {
      if (individualId.isEmpty) return 'Unknown';
      final doc = await _individuals.doc(individualId).get();
      if (!doc.exists) return 'Unknown';
      final data = doc.data() as Map<String, dynamic>;
      return data['nickname'] ?? 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }

  Future<List<AnimalIndividual>> searchIndividuals(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final snapshot = await _individuals.get();
      final q = query.trim().toLowerCase();
      return snapshot.docs
          .map((doc) => AnimalIndividual.fromFirestore(doc))
          .where((ind) {
            final nameMatch = ind.nickname.toLowerCase().contains(q);
            final charMatch = ind.characteristics.toLowerCase().contains(q);
            return nameMatch || charMatch;
          })
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<String> _generateNickname(
      String animalType, String? userNickname) async {
    if (userNickname != null && userNickname.trim().isNotEmpty) {
      return userNickname.trim();
    }
    final snapshot = await _individuals
        .where('animalType', isEqualTo: animalType)
        .get();
    final count = snapshot.docs.length + 1;
    final prefix = animalType == 'cat' ? 'Cat' : 'Dog';
    return '$prefix ${count.toString().padLeft(2, '0')}';
  }

  Stream<List<AnimalSighting>> getSightingsStream({String? animalType}) {
    Query query = _sightings.orderBy('timestamp', descending: true);
    if (animalType != null) {
      query = query.where('animalType', isEqualTo: animalType);
    }
    return query.snapshots().map((snap) =>
        snap.docs.map((doc) => AnimalSighting.fromFirestore(doc)).toList());
  }

  Stream<List<AnimalSighting>> getUserSightings(String userId) {
    return _sightings
        .where('submittedBy', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .handleError((error) => print('Firestore error: $error'))
        .map((snap) =>
            snap.docs.map((doc) => AnimalSighting.fromFirestore(doc)).toList());
  }

  Future<List<AnimalSighting>> getSightingsByIndividual(
      String individualId) async {
    try {
      final snapshot = await _sightings
          .where('individualId', isEqualTo: individualId)
          .orderBy('timestamp', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => AnimalSighting.fromFirestore(doc))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<AnimalIndividual?> getIndividual(String id) async {
    final doc = await _individuals.doc(id).get();
    if (!doc.exists) return null;
    return AnimalIndividual.fromFirestore(doc);
  }

  Future<bool> seedDataExists() async {
    final snapshot = await _individuals.limit(1).get();
    return snapshot.docs.isNotEmpty;
  }
}
