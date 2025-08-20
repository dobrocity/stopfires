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
  /// **'Edit profile'**
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
