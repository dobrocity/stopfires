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
  String get edit_email_address => 'Edit the email address';

  @override
  String get insert_new_email_address => 'Insert the new email address below.';

  @override
  String get edit_email => 'Edit email';

  @override
  String get back => 'Back';

  @override
  String get verify_email_address => 'Verify your email address';

  @override
  String verify_email_address_description(Object email) {
    return 'We have sent you a 6 digit code to $email. Please enter the code below.';
  }

  @override
  String get submit => 'Submit';

  @override
  String get resend_code => 'Resend code';

  @override
  String get change_email => 'Change email';

  @override
  String greeting(String name) {
    return 'Hi $name';
  }
}
