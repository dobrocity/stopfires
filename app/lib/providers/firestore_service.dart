import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'firebase_providers.dart';

/// Service class for Firestore operations using Riverpod providers
class FirestoreService {
  final FirebaseFirestore _firestore;
  final firebase_auth.FirebaseAuth _auth;
  final Logger _logger = Logger();

  FirestoreService(this._firestore, this._auth);

  /// Get current user document reference
  DocumentReference<Map<String, dynamic>>? get currentUserDoc {
    final user = _auth.currentUser;
    if (user == null) return null;
    return _firestore.collection('users').doc(user.uid);
  }

  /// Get user profile data
  Future<Map<String, dynamic>?> getUserProfile() async {
    final userDoc = currentUserDoc;
    if (userDoc == null) return null;

    try {
      final doc = await userDoc.get();
      return doc.data();
    } catch (e) {
      _logger.e('Error getting user profile: $e');
      return null;
    }
  }

  /// Update user profile data
  Future<void> updateUserProfile(Map<String, dynamic> data) async {
    final userDoc = currentUserDoc;
    if (userDoc == null) return;

    try {
      await userDoc.update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _logger.e('Error updating user profile: $e');
      rethrow;
    }
  }

  /// Get collection with real-time updates
  Stream<QuerySnapshot<Map<String, dynamic>>> getCollectionStream(
    String collectionPath, {
    Query<Map<String, dynamic>> Function(Query<Map<String, dynamic>> query)?
    queryBuilder,
  }) {
    Query<Map<String, dynamic>> query = _firestore.collection(collectionPath);

    if (queryBuilder != null) {
      query = queryBuilder(query);
    }

    return query.snapshots();
  }

  /// Add document to collection
  Future<DocumentReference<Map<String, dynamic>>> addDocument(
    String collectionPath,
    Map<String, dynamic> data,
  ) async {
    try {
      return await _firestore.collection(collectionPath).add({
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _logger.e('Error adding document: $e');
      rethrow;
    }
  }

  /// Update document
  Future<void> updateDocument(
    String documentPath,
    Map<String, dynamic> data,
  ) async {
    try {
      await _firestore.doc(documentPath).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _logger.e('Error updating document: $e');
      rethrow;
    }
  }

  /// Delete document
  Future<void> deleteDocument(String documentPath) async {
    try {
      await _firestore.doc(documentPath).delete();
    } catch (e) {
      _logger.e('Error deleting document: $e');
      rethrow;
    }
  }
}

/// Provider for FirestoreService
final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final auth = ref.watch(firebaseAuthProvider);
  return FirestoreService(firestore, auth);
});

/// Provider for user profile data
final userProfileProvider = StreamProvider<Map<String, dynamic>?>((ref) async* {
  final service = ref.watch(firestoreServiceProvider);
  final logger = Logger();

  try {
    final profile = await service.getUserProfile();
    yield profile;
  } catch (e) {
    logger.e('Error in userProfileProvider: $e');
    yield null;
  }
});

/// Provider for a specific collection
final collectionProvider =
    StreamProvider.family<QuerySnapshot<Map<String, dynamic>>, String>((
      ref,
      collectionPath,
    ) {
      final service = ref.watch(firestoreServiceProvider);
      return service.getCollectionStream(collectionPath);
    });
