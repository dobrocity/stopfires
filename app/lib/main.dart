import 'package:flutter/foundation.dart';
import 'package:stopfires/auth_provider.dart';
import 'package:stopfires/corbado/corbado_auth_firebase.dart';
import 'package:stopfires/firebase_options.dart';
import 'package:stopfires/pages/loading_page.dart';
import 'package:stopfires/router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';

final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (kDebugMode) {
    try {
      await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
      functions.useFunctionsEmulator('localhost', 5001);
    } catch (e) {
      // ignore: avoid_print
      print(e);
    }
  }

  runApp(const LoadingPage());

  // Now we do the initialization.
  final corbadoAuth = CorbadoAuthFirebase();
  await corbadoAuth.init('europe-west1');

  // Finally we override the providers that needed initialization.
  // Now the real app can be loaded.
  runApp(
    ProviderScope(
      overrides: [corbadoAuthProvider.overrideWithValue(corbadoAuth)],
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'StopFires',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) {
        return KeyboardHandler(child: child!);
      },
    );
  }
}

class KeyboardHandler extends StatefulWidget {
  final Widget child;

  const KeyboardHandler({super.key, required this.child});

  @override
  State<KeyboardHandler> createState() => _KeyboardHandlerState();
}

class _KeyboardHandlerState extends State<KeyboardHandler> {
  @override
  void initState() {
    super.initState();

    // Add a global keyboard listener to handle potential state issues
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // This helps prevent keyboard state inconsistencies
        SystemChannels.textInput.invokeMethod('TextInput.clearClient');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
