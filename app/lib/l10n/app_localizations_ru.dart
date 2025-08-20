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
  String get edit_email_address => 'Изменить электронную почту';

  @override
  String get insert_new_email_address => 'Введите новую электронную почту ниже.';

  @override
  String get edit_email => 'Изменить электронную почту';

  @override
  String get back => 'Назад';

  @override
  String get verify_email_address => 'Подтвердите электронную почту';

  @override
  String verify_email_address_description(Object email) {
    return 'Мы отправили вам 6-значный код на $email. Пожалуйста, введите код ниже.';
  }

  @override
  String get submit => 'Отправить';

  @override
  String get resend_code => 'Отправить код повторно';

  @override
  String get change_email => 'Изменить электронную почту';

  @override
  String get passkey_verify_title => 'Войти с помощью PassKey';

  @override
  String get profile_page_description => 'Готовы борьба с пожарами вместе?';

  @override
  String get edit_profile => 'Изменить профиль';

  @override
  String get passkey_list => 'Список PassKey';

  @override
  String get sign_out => 'Выйти';

  @override
  String get full_name => 'Полное имя';

  @override
  String get email => 'Электронная почта';

  @override
  String get save_changes => 'Сохранить изменения';

  @override
  String get full_name_has_been_changed_successfully => 'Полное имя успешно изменено.';

  @override
  String greeting(String name) {
    return 'Привет $name';
  }
}
