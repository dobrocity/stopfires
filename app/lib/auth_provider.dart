import 'package:cloud_functions/cloud_functions.dart';
import 'package:corbado_auth/corbado_auth.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Corbado SDK provider. This will be used by other providers to
// e.g. expose user state.

final corbadoProvider = Provider<CorbadoAuth>(
  (ref) => throw UnimplementedError("no instance of corbadoAuth"),
);

// // Make the user available throughout the app.
// final userProvider = StreamProvider<User?>((ref) async* {
//   final corbado = ref.watch(corbadoProvider);
//   await for (final value in corbado.userChanges) {
//     yield value;
//   }
// });

// If you use regions, set it here (e.g., 'europe-west1')
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

class UserEntity {
  final User corbado;
  final firebase_auth.User? firebase;

  UserEntity({required this.corbado, required this.firebase});
}

final userProvider = StreamProvider<UserEntity?>((ref) async* {
  final corbado = ref.watch(corbadoProvider);
  final auth = ref.watch(firebaseAuthProvider);
  final functions = ref.watch(functionsProvider);
  final verifyAndMint = functions.httpsCallable('verifyAndMint');

  await for (final extUser in corbado.userChanges) {
    // If user signed out on Corbado, mirror sign-out in Firebase.
    if (extUser == null) {
      if (auth.currentUser != null) {
        await auth.signOut();
      }
      yield null;
      continue;
    }

    // Only proceed if your Corbado user has a valid ID token
    if (!extUser.hasValidToken()) {
      yield null;
      continue;
    }

    // Optional: avoid re-signing the same user repeatedly
    // If you can derive a stable UID from extUser (e.g., extUser.sub),
    // compare to currentUser.uid:
    // final expectedUid = 'corbado:${extUser.sub}';
    // if (auth.currentUser?.uid == expectedUid) {
    //   yield UserEntity(corbado: extUser, firebase: auth.currentUser);
    //   continue;
    // }

    try {
      // 1) Ask backend to verify the Corbado token & mint a Firebase custom token
      final res = await verifyAndMint.call<Map<String, dynamic>>({
        'idToken': extUser.idToken, // <-- Corbado ID token
      });

      final data = res.data;
      final customToken = data['customToken'] as String;

      // 2) Sign in to Firebase with the returned custom token
      final cred = await auth.signInWithCustomToken(customToken);

      yield UserEntity(corbado: extUser, firebase: cred.user);
    } on FirebaseFunctionsException catch (_) {
      // Backend refused (e.g., unauthenticated / invalid token)
      // You may want to surface this via another provider / logger.
      // For now, reflect an unauthenticated state.
      // debugPrint('verifyAndMint failed: ${e.code} ${e.message}');
      if (auth.currentUser != null) {
        await auth.signOut();
      }
      yield null;
    } catch (_) {
      // Any other client-side error
      if (auth.currentUser != null) {
        await auth.signOut();
      }
      yield null;
    }
  }
});
// Make the auth state available throughout the app.
final authStateProvider = StreamProvider((ref) async* {
  final corbado = ref.watch(corbadoProvider);
  await for (final value in corbado.authStateChanges) {
    yield value;
  }
});

// Make the passkeys available throughout the app.
final passkeysProvider = StreamProvider<List<PasskeyInfo>>((ref) async* {
  final corbado = ref.watch(corbadoProvider);
  await for (final value in corbado.passkeysChanges) {
    yield value;
  }
});
