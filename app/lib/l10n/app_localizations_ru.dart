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
  String get profile_page_description => 'Готовы к борьбе с пожарами вместе?';

  @override
  String get edit_profile => 'Профиль';

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
  String get check_your_passkeys => 'Проверьте ваши PassKey';

  @override
  String get passkey_has_been_deleted_successfully => 'PassKey успешно удален.';

  @override
  String get passkey_has_been_created_successfully => 'PassKey успешно создан.';

  @override
  String get add_passkey => 'Добавить PassKey';

  @override
  String get set_up_your_passkey => 'Настройте ваш PassKey';

  @override
  String get set_up_your_passkey_description => 'Быстрый и безопасный вход с помощью Touch ID или Face ID вместо паролей.';

  @override
  String get create_passkey => 'Создать PassKey';

  @override
  String get maybe_later => 'Может позже';

  @override
  String get delete => 'Удалить';

  @override
  String get shared_map => 'Общая карта';

  @override
  String fire_clusters_title(Object fires, Object clusters) {
    return 'Кластеры пожаров - $fires пожаров, $clusters кластеров';
  }

  @override
  String greeting(String name) {
    return 'Привет $name';
  }

  @override
  String help_improve_app_location(String appName) {
    return 'Помогите улучшить $appName, поделившись своим местоположением. Мы собираем только то, что нам нужно, и вы можете приостановить в любое время.';
  }

  @override
  String get what_we_collect => 'Что мы собираем';

  @override
  String get gps_coordinates => 'GPS координаты (широта и долгота)';

  @override
  String get timestamp_and_accuracy => 'Временная метка и точность';

  @override
  String get speed_and_heading => 'Скорость и направление (если доступно)';

  @override
  String get hashed_region => 'Хешированный регион (geohash) для ближайших функций';

  @override
  String get how_we_use_it => 'Как мы используем';

  @override
  String get show_current_position => 'Показать ваше текущее положение в приложении';

  @override
  String get generate_trip_history => 'Создать историю поездок (временной ряд)';

  @override
  String get enable_background_updates => 'Включить опциональные фоновые обновления (если вы согласны)';

  @override
  String get your_choices => 'Ваш выбор';

  @override
  String get enable_location_tracking => 'Включить отслеживание местоположения';

  @override
  String get can_pause_later => 'Вы можете приостановить или отключить позже в Настройках';

  @override
  String get allow_background_updates => 'Разрешить фоновые обновления';

  @override
  String get required_android_foreground => 'Требуется для работы приложения в фоновом режиме';

  @override
  String get use_approximate_location => 'Использовать приблизительное местоположение';

  @override
  String get lower_precision_privacy => 'Меньшая точность для улучшения конфиденциальности и батареи';

  @override
  String get data_retention => 'Хранение данных';

  @override
  String get trip_history_storage => 'Как долго хранится история ваших поездок';

  @override
  String get days_7 => '7 дней';

  @override
  String get days_14 => '14 дней';

  @override
  String get days_30 => '30 дней';

  @override
  String get days_90 => '90 дней';

  @override
  String get privacy => 'Конфиденциальность';

  @override
  String get settings => 'Настройки';

  @override
  String get privacy_policy => 'Политика конфиденциальности';

  @override
  String get terms_of_service => 'Условия использования';

  @override
  String get i_agree_to_above => 'Я прочитал и согласен с политикой конфиденциальности.';

  @override
  String get can_change_settings => 'Вы можете изменить эти настройки в любое время.';

  @override
  String get decline => 'Отклонить';

  @override
  String get accept_continue => 'Принять';

  @override
  String get could_not_open_link => 'Не удалось открыть ссылку';

  @override
  String get location_consent_title => 'Согласие';

  @override
  String get location_sharing_disclaimer => 'Уведомление о совместном использовании местоположения';

  @override
  String get location_sharing_disclaimer_text => 'Важно: Все пользователи могут видеть недавние местоположения других пользователей онлайн на общей карте. Ваше местоположение будет видимым для координации усилий по тушению пожаров и улучшения безопасности сообщества.';

  @override
  String get location_sharing_disclaimer_acknowledge => 'Я понимаю, что мое местоположение будет видимым для других пользователей';

  @override
  String get location_sharing_disclaimer_privacy => 'Ваше точное местоположение передается только во время активного использования приложения. Вы можете отключить передачу местоположения в любое время в настройках.';
}
