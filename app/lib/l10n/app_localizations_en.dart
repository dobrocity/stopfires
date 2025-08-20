// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get hello => 'Hello';

  @override
  String get welcome => 'Welcome';

  @override
  String get app_name => 'stopfires.org';

  @override
  String get signup_init_title => 'Let\'s stop fires together';

  @override
  String get email_address => 'Email address';

  @override
  String get signup_init_button => 'Sign up';

  @override
  String get sign_up_already_registered => 'I already have an account';

  @override
  String get welcome_back => 'Welcome back';

  @override
  String get login_init_title => 'Let\'s continue fighting fires together.';

  @override
  String get login_init_button => 'Login';

  @override
  String get create_new_account => 'Create a new account';

  @override
  String greeting(String name) {
    return 'Hi $name';
  }
}
