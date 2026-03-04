// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appName => 'lizaplayer';

  @override
  String get home => 'Главная';

  @override
  String get myWave => 'Моя волна';

  @override
  String get settings => 'Настройки';

  @override
  String get theme => 'Тема';

  @override
  String get light => 'Светлая';

  @override
  String get dark => 'Тёмная';

  @override
  String get system => 'Как в системе';

  @override
  String get language => 'Язык';

  @override
  String get mainColor => 'Основной цвет';

  @override
  String get clearCache => 'Очистить кэш';

  @override
  String get clearCacheSubtitle => 'Удалить все скачанные треки';

  @override
  String get logout => 'Выйти из аккаунта';

  @override
  String get logoutSubtitle => 'Удалить токен и выйти';

  @override
  String get searchTracks => 'Поиск треков...';

  @override
  String get find => 'Найти';

  @override
  String get personalRecommendations =>
      'Персональные рекомендации\nпо твоим вкусам';

  @override
  String get startMyWave => 'Запустить Мою волну';

  @override
  String get loading => 'Загрузка...';

  @override
  String get findSomething => 'Найди что-нибудь сверху';

  @override
  String get appearance => 'Внешний вид';

  @override
  String get languageSection => 'Язык';

  @override
  String get dataAndAccount => 'Данные и аккаунт';
}
