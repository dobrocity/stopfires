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
  String get app_name => 'stopfires.org';

  @override
  String get signup_init_title => 'Победим пожары вместе';

  @override
  String get email_address => 'Электронная почта';

  @override
  String get signup_init_button => 'Зарегистрироваться';

  @override
  String get sign_up_already_registered => 'У меня уже есть аккаунт';

  @override
  String get welcome_back => 'Привет снова';

  @override
  String get login_init_title => 'Продолжим борьбу с пожарами вместе.';

  @override
  String get login_init_button => 'Войти';

  @override
  String get create_new_account => 'Создать новый аккаунт';

  @override
  String greeting(String name) {
    return 'Привет $name';
  }
}
