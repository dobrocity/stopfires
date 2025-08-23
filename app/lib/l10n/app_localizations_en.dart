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
  String get edit_profile => 'Profile';

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

  @override
  String help_improve_app_location(String appName) {
    return 'Help improve $appName by sharing your location. We only collect what we need, and you can pause at any time.';
  }

  @override
  String get what_we_collect => 'What we collect';

  @override
  String get gps_coordinates => 'GPS coordinates (latitude & longitude)';

  @override
  String get timestamp_and_accuracy => 'Timestamp and accuracy';

  @override
  String get speed_and_heading => 'Speed and heading (if available)';

  @override
  String get hashed_region => 'Hashed region (geohash) for nearby features';

  @override
  String get how_we_use_it => 'How we use it';

  @override
  String get show_current_position => 'Show your current position in the app';

  @override
  String get generate_trip_history => 'Generate trip history (time series)';

  @override
  String get enable_background_updates => 'Enable optional background updates (if you opt in)';

  @override
  String get your_choices => 'Your choices';

  @override
  String get enable_location_tracking => 'Enable location tracking';

  @override
  String get can_pause_later => 'You can pause or disable later in Settings';

  @override
  String get allow_background_updates => 'Allow background updates';

  @override
  String get required_android_foreground => 'Required for background service';

  @override
  String get use_approximate_location => 'Use approximate location';

  @override
  String get lower_precision_privacy => 'Lower precision to improve privacy and battery';

  @override
  String get data_retention => 'Data retention';

  @override
  String get trip_history_storage => 'How long your trip history is stored';

  @override
  String get days_7 => '7 days';

  @override
  String get days_14 => '14 days';

  @override
  String get days_30 => '30 days';

  @override
  String get days_90 => '90 days';

  @override
  String get privacy => 'Privacy';

  @override
  String get settings => 'Settings';

  @override
  String get privacy_policy => 'Privacy Policy';

  @override
  String get terms_of_service => 'Terms of Service';

  @override
  String get i_agree_to_above => 'I have read and agree to the Privacy Policy.';

  @override
  String get can_change_settings => 'You can change these settings at any time.';

  @override
  String get decline => 'Decline';

  @override
  String get accept_continue => 'Accept';

  @override
  String get could_not_open_link => 'Could not open link';

  @override
  String get location_consent_title => 'Location Permission';

  @override
  String get location_sharing_disclaimer => 'Location Sharing Notice';

  @override
  String get location_sharing_disclaimer_text => 'Important: All users can see the recent locations of other online users on the shared map. Your location will be visible to help coordinate firefighting efforts and improve community safety.';

  @override
  String get location_sharing_disclaimer_acknowledge => 'I understand that my location will be visible to other users';

  @override
  String get location_sharing_disclaimer_privacy => 'Your exact location is only shared while you\'re actively using the app. You can disable location sharing at any time in settings.';
}
