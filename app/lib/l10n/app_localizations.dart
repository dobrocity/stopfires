import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru')
  ];

  /// No description provided for @hello.
  ///
  /// In en, this message translates to:
  /// **'Hello'**
  String get hello;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcome;

  /// No description provided for @app_name.
  ///
  /// In en, this message translates to:
  /// **'stopfires.org'**
  String get app_name;

  /// No description provided for @signup_init_title.
  ///
  /// In en, this message translates to:
  /// **'Let\'s stop fires together'**
  String get signup_init_title;

  /// No description provided for @email_address.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get email_address;

  /// No description provided for @signup_init_button.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get signup_init_button;

  /// No description provided for @sign_up_already_registered.
  ///
  /// In en, this message translates to:
  /// **'I already have an account'**
  String get sign_up_already_registered;

  /// No description provided for @welcome_back.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get welcome_back;

  /// No description provided for @login_init_title.
  ///
  /// In en, this message translates to:
  /// **'Let\'s continue fighting fires together.'**
  String get login_init_title;

  /// No description provided for @login_init_button.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login_init_button;

  /// No description provided for @create_new_account.
  ///
  /// In en, this message translates to:
  /// **'Create a new account'**
  String get create_new_account;

  /// No description provided for @edit_email_address.
  ///
  /// In en, this message translates to:
  /// **'Edit the email address'**
  String get edit_email_address;

  /// No description provided for @insert_new_email_address.
  ///
  /// In en, this message translates to:
  /// **'Insert the new email address below.'**
  String get insert_new_email_address;

  /// No description provided for @edit_email.
  ///
  /// In en, this message translates to:
  /// **'Edit email'**
  String get edit_email;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @verify_email_address.
  ///
  /// In en, this message translates to:
  /// **'Verify your email address'**
  String get verify_email_address;

  /// No description provided for @verify_email_address_description.
  ///
  /// In en, this message translates to:
  /// **'We have sent you a 6 digit code to {email}. Please enter the code below.'**
  String verify_email_address_description(Object email);

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @resend_code.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get resend_code;

  /// No description provided for @change_email.
  ///
  /// In en, this message translates to:
  /// **'Change email'**
  String get change_email;

  /// No description provided for @passkey_verify_title.
  ///
  /// In en, this message translates to:
  /// **'Login with passkey'**
  String get passkey_verify_title;

  /// No description provided for @profile_page_description.
  ///
  /// In en, this message translates to:
  /// **'Ready to fight fires together?'**
  String get profile_page_description;

  /// No description provided for @edit_profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get edit_profile;

  /// No description provided for @passkey_list.
  ///
  /// In en, this message translates to:
  /// **'Passkey list'**
  String get passkey_list;

  /// No description provided for @sign_out.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get sign_out;

  /// No description provided for @full_name.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get full_name;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @save_changes.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get save_changes;

  /// No description provided for @full_name_has_been_changed_successfully.
  ///
  /// In en, this message translates to:
  /// **'Full name has been changed successfully.'**
  String get full_name_has_been_changed_successfully;

  /// No description provided for @check_your_passkeys.
  ///
  /// In en, this message translates to:
  /// **'Check your passkeys'**
  String get check_your_passkeys;

  /// No description provided for @passkey_has_been_deleted_successfully.
  ///
  /// In en, this message translates to:
  /// **'Passkey has been deleted successfully.'**
  String get passkey_has_been_deleted_successfully;

  /// No description provided for @passkey_has_been_created_successfully.
  ///
  /// In en, this message translates to:
  /// **'Passkey has been created successfully.'**
  String get passkey_has_been_created_successfully;

  /// No description provided for @add_passkey.
  ///
  /// In en, this message translates to:
  /// **'Add passkey'**
  String get add_passkey;

  /// No description provided for @set_up_your_passkey.
  ///
  /// In en, this message translates to:
  /// **'Set up your passkey'**
  String get set_up_your_passkey;

  /// No description provided for @set_up_your_passkey_description.
  ///
  /// In en, this message translates to:
  /// **'Quick and secure login using Apple Touch ID or Face ID instead of passwords.'**
  String get set_up_your_passkey_description;

  /// No description provided for @create_passkey.
  ///
  /// In en, this message translates to:
  /// **'Create passkey'**
  String get create_passkey;

  /// No description provided for @maybe_later.
  ///
  /// In en, this message translates to:
  /// **'Maybe later'**
  String get maybe_later;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @shared_map.
  ///
  /// In en, this message translates to:
  /// **'Shared map'**
  String get shared_map;

  /// No description provided for @fire_clusters_title.
  ///
  /// In en, this message translates to:
  /// **'Fire clusters - {fires} fires, {clusters} clusters'**
  String fire_clusters_title(Object fires, Object clusters);

  /// Personal greeting
  ///
  /// In en, this message translates to:
  /// **'Hi {name}'**
  String greeting(String name);

  /// No description provided for @help_improve_app_location.
  ///
  /// In en, this message translates to:
  /// **'Help improve {appName} by sharing your location. We only collect what we need, and you can pause at any time.'**
  String help_improve_app_location(String appName);

  /// No description provided for @what_we_collect.
  ///
  /// In en, this message translates to:
  /// **'What we collect'**
  String get what_we_collect;

  /// No description provided for @gps_coordinates.
  ///
  /// In en, this message translates to:
  /// **'GPS coordinates (latitude & longitude)'**
  String get gps_coordinates;

  /// No description provided for @timestamp_and_accuracy.
  ///
  /// In en, this message translates to:
  /// **'Timestamp and accuracy'**
  String get timestamp_and_accuracy;

  /// No description provided for @speed_and_heading.
  ///
  /// In en, this message translates to:
  /// **'Speed and heading (if available)'**
  String get speed_and_heading;

  /// No description provided for @hashed_region.
  ///
  /// In en, this message translates to:
  /// **'Hashed region (geohash) for nearby features'**
  String get hashed_region;

  /// No description provided for @how_we_use_it.
  ///
  /// In en, this message translates to:
  /// **'How we use it'**
  String get how_we_use_it;

  /// No description provided for @show_current_position.
  ///
  /// In en, this message translates to:
  /// **'Show your current position in the app'**
  String get show_current_position;

  /// No description provided for @generate_trip_history.
  ///
  /// In en, this message translates to:
  /// **'Generate trip history (time series)'**
  String get generate_trip_history;

  /// No description provided for @enable_background_updates.
  ///
  /// In en, this message translates to:
  /// **'Enable optional background updates (if you opt in)'**
  String get enable_background_updates;

  /// No description provided for @your_choices.
  ///
  /// In en, this message translates to:
  /// **'Your choices'**
  String get your_choices;

  /// No description provided for @enable_location_tracking.
  ///
  /// In en, this message translates to:
  /// **'Enable location tracking'**
  String get enable_location_tracking;

  /// No description provided for @can_pause_later.
  ///
  /// In en, this message translates to:
  /// **'You can pause or disable later in Settings'**
  String get can_pause_later;

  /// No description provided for @allow_background_updates.
  ///
  /// In en, this message translates to:
  /// **'Allow background updates'**
  String get allow_background_updates;

  /// No description provided for @required_android_foreground.
  ///
  /// In en, this message translates to:
  /// **'Required for background service'**
  String get required_android_foreground;

  /// No description provided for @use_approximate_location.
  ///
  /// In en, this message translates to:
  /// **'Use approximate location'**
  String get use_approximate_location;

  /// No description provided for @lower_precision_privacy.
  ///
  /// In en, this message translates to:
  /// **'Lower precision to improve privacy and battery'**
  String get lower_precision_privacy;

  /// No description provided for @data_retention.
  ///
  /// In en, this message translates to:
  /// **'Data retention'**
  String get data_retention;

  /// No description provided for @trip_history_storage.
  ///
  /// In en, this message translates to:
  /// **'How long your trip history is stored'**
  String get trip_history_storage;

  /// No description provided for @days_7.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get days_7;

  /// No description provided for @days_14.
  ///
  /// In en, this message translates to:
  /// **'14 days'**
  String get days_14;

  /// No description provided for @days_30.
  ///
  /// In en, this message translates to:
  /// **'30 days'**
  String get days_30;

  /// No description provided for @days_90.
  ///
  /// In en, this message translates to:
  /// **'90 days'**
  String get days_90;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @legal.
  ///
  /// In en, this message translates to:
  /// **'Legal'**
  String get legal;

  /// No description provided for @privacy_policy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacy_policy;

  /// No description provided for @terms_of_service.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get terms_of_service;

  /// No description provided for @i_agree_to_above.
  ///
  /// In en, this message translates to:
  /// **'I have read and agree to the Privacy Policy.'**
  String get i_agree_to_above;

  /// No description provided for @can_change_settings.
  ///
  /// In en, this message translates to:
  /// **'You can change these settings at any time.'**
  String get can_change_settings;

  /// No description provided for @decline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get decline;

  /// No description provided for @accept_continue.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept_continue;

  /// No description provided for @could_not_open_link.
  ///
  /// In en, this message translates to:
  /// **'Could not open link'**
  String get could_not_open_link;

  /// No description provided for @location_consent_title.
  ///
  /// In en, this message translates to:
  /// **'Location Permission'**
  String get location_consent_title;

  /// No description provided for @location_sharing_disclaimer.
  ///
  /// In en, this message translates to:
  /// **'Location Sharing Notice'**
  String get location_sharing_disclaimer;

  /// No description provided for @location_sharing_disclaimer_text.
  ///
  /// In en, this message translates to:
  /// **'Important: All users can see the recent locations of other online users on the shared map. Your location will be visible to help coordinate firefighting efforts and improve community safety.'**
  String get location_sharing_disclaimer_text;

  /// No description provided for @location_sharing_disclaimer_acknowledge.
  ///
  /// In en, this message translates to:
  /// **'I understand that my location will be visible to other users'**
  String get location_sharing_disclaimer_acknowledge;

  /// No description provided for @location_sharing_disclaimer_privacy.
  ///
  /// In en, this message translates to:
  /// **'Your exact location is only shared while you\'re actively using the app. You can disable location sharing at any time in settings.'**
  String get location_sharing_disclaimer_privacy;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'ru': return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
