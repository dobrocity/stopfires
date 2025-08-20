// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get hello => 'Привет';

  @override
  String get welcome => 'Добро пожаловать';

  @override
  String greeting(String name) {
    return 'Привет $name';
  }
}
