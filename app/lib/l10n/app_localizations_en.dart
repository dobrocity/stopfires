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
  String get passkey_verify_title => 'Login with passkey';

  @override
  String get profile_page_description => 'Ready to fight fires together?';

  @override
  String get edit_profile => 'Edit profile';

  @override
  String get passkey_list => 'Passkey list';

  @override
  String get sign_out => 'Sign out';

  @override
  String get full_name => 'Full name';

  @override
  String get email => 'Email';

  @override
  String get save_changes => 'Save changes';

  @override
  String get full_name_has_been_changed_successfully => 'Full name has been changed successfully.';

  @override
  String get check_your_passkeys => 'Check your passkeys';

  @override
  String get passkey_has_been_deleted_successfully => 'Passkey has been deleted successfully.';

  @override
  String get passkey_has_been_created_successfully => 'Passkey has been created successfully.';

  @override
  String get add_passkey => 'Add passkey';

  @override
  String get set_up_your_passkey => 'Set up your passkey';

  @override
  String get set_up_your_passkey_description => 'Quick and secure login using Apple Touch ID or Face ID instead of passwords.';

  @override
  String get create_passkey => 'Create passkey';

  @override
  String get maybe_later => 'Maybe later';

  @override
  String get delete => 'Delete';

  @override
  String get shared_map => 'Shared map';

  @override
  String fire_clusters_title(Object fires, Object clusters) {
    return 'Fire clusters - $fires fires, $clusters clusters';
  }

  @override
  String greeting(String name) {
    return 'Hi $name';
  }
}
