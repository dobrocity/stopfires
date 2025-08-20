import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Firebase Functions provider with emulator support for development
final functionsProvider = Provider<FirebaseFunctions>((ref) {
  final fns = FirebaseFunctions.instanceFor(region: 'europe-west1');
  if (kDebugMode) {
    try {
      fns.useFunctionsEmulator('127.0.0.1', 5001);
    } catch (e) {
      // ignore: avoid_print
      print(e);
    }
  }
  return fns;
});

/// Firebase Auth provider with emulator support for development
final firebaseAuthProvider = Provider<firebase_auth.FirebaseAuth>((ref) {
  final auth = firebase_auth.FirebaseAuth.instance;
  if (kDebugMode) {
    try {
      auth.useAuthEmulator('127.0.0.1', 9099);
    } catch (e) {
      // ignore: avoid_print
      print(e);
    }
  }
  return auth;
});

/// Firestore provider with emulator support for development
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  final firestore = FirebaseFirestore.instance;
  if (kDebugMode) {
    try {
      firestore.useFirestoreEmulator('127.0.0.1', 8080);
    } catch (e) {
      // ignore: avoid_print
      print(e);
    }
  }
  return firestore;
});
