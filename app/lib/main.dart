import 'package:corbado_auth/corbado_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:stopfires/auth_provider.dart';
import 'package:stopfires/firebase_options.dart';
import 'package:stopfires/l10n/app_localizations.dart';
import 'package:stopfires/pages/loading_page.dart';
import 'package:stopfires/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:overlay_support/overlay_support.dart';

import 'config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // This is a nice pattern if you need to initialize some of your services
  // before the app starts.
  // As we are using riverpod this initialization happens inside providers.
  // First we show a loading page.
  runApp(const LoadingPage());

  // Now we do the initialization.
  final projectId = getProjectID();

  final corbadoAuth = CorbadoAuth();
  await corbadoAuth.init(projectId: projectId, telemetryDisabled: true);

  // Finally we override the providers that needed initialization.
  // Now the real app can be loaded.
  runApp(
    ProviderScope(
      overrides: [corbadoProvider.overrideWithValue(corbadoAuth)],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return OverlaySupport.global(
      child: MaterialApp.router(
        routeInformationParser: router.routeInformationParser,
        routerDelegate: router.routerDelegate,
        routeInformationProvider: router.routeInformationProvider,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ru'),
        theme: ThemeData(
          useMaterial3: false,
          colorScheme: const ColorScheme(
            brightness: Brightness.light,
            primary: Color(0xFF1953ff),
            onPrimary: Colors.white,
            secondary: Colors.white,
            onSecondary: Color(0xFF1953ff),
            error: Colors.redAccent,
            onError: Colors.white,
            surface: Color(0xFF1953ff),
            onSurface: Color(0xFF1953ff),
          ),
        ),
      ),
    );
  }
}
