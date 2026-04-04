// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get home => 'Главная';

  @override
  String get myWave => 'Моя Волна';

  @override
  String get playlists => 'Плейлисты';

  @override
  String get settings => 'Настройки';

  @override
  String get searchTracks => 'Поиск треков...';

  @override
  String get find => 'Найти';

  @override
  String get loading => 'Загрузка';

  @override
  String get startMyWave => 'Запустить';

  @override
  String get personalRecommendations =>
      'Персональные рекомендации по вашему вкусу';

  @override
  String get myLikes => 'Мне нравится';

  @override
  String get myPlaylists => 'Мои плейлисты';

  @override
  String get tracks => 'треков';

  @override
  String get personalWave => 'Персональная волна';

  @override
  String get newWave => 'Новая волна';

  @override
  String get noLikesYet => 'Пока нет лайков';

  @override
  String get likeToFill => 'Ставьте лайки трекам, чтобы они появились здесь';

  @override
  String get syncComingSoon => 'Синхронизация скоро';

  @override
  String get appearance => 'Внешний вид';

  @override
  String get theme => 'Тема';

  @override
  String get light => 'Светлая';

  @override
  String get dark => 'Темная';

  @override
  String get system => 'Системная';

  @override
  String get mainColor => 'Основной цвет';

  @override
  String get cyan => 'Голубой';

  @override
  String get red => 'Красный';

  @override
  String get orange => 'Оранжевый';

  @override
  String get purple => 'Фиолетовый';

  @override
  String get green => 'Зеленый';

  @override
  String get blue => 'Синий';

  @override
  String get pink => 'Розовый';

  @override
  String get indigo => 'Индиго';

  @override
  String get amber => 'Янтарный';

  @override
  String get teal => 'Бирюзовый';

  @override
  String get grey => 'Серый';

  @override
  String get none => 'Нет';

  @override
  String get customBackground => 'Пользовательский фон';

  @override
  String get urlExample => 'https://example.com/image.gif';

  @override
  String get save => 'Сохранить';

  @override
  String get clear => 'Очистить';

  @override
  String get glassInterface => 'Стеклянный интерфейс';

  @override
  String get off => 'Выкл';

  @override
  String get on => 'Вкл';

  @override
  String get backgroundBlur => 'Размытие фона';

  @override
  String get interfaceScale => 'Масштаб интерфейса';

  @override
  String get freezeOptimization => 'Оптимизация в фоне';

  @override
  String get freezeOptimizationSubtitle =>
      'Останавливать все эффекты, когда окно не в фокусе';

  @override
  String get recommended => 'Рекомендуется';

  @override
  String get languageSection => 'Язык';

  @override
  String get language => 'Язык приложения';

  @override
  String get english => 'Английский';

  @override
  String get russian => 'Русский';

  @override
  String get dataAndAccount => 'Данные и аккаунт';

  @override
  String get clearCache => 'Очистить кэш';

  @override
  String get clearCacheSubtitle => 'Удалить загруженные обложки и данные';

  @override
  String get logout => 'Выйти';

  @override
  String get logoutSubtitle => 'Удалить токены и выйти';

  @override
  String get queue => 'Очередь';

  @override
  String get queueEmpty => 'Очередь пуста';

  @override
  String searchResultsFor(String query) {
    return 'Результаты по запросу \"$query\"';
  }

  @override
  String get noResultsFound => 'Ничего не найдено';

  @override
  String get untitledTrack => 'Неизвестный трек';

  @override
  String get integrationsTitle => 'Интеграции';

  @override
  String get yandexTokenHint => 'OAuth Токен Яндекс Музыки';

  @override
  String get soundcloudIdHint => 'Client ID SoundCloud';

  @override
  String get tokensSaved => 'Токены успешно сохранены.';

  @override
  String get aboutArtist => 'Об артисте';

  @override
  String get popularReleases => 'Популярные релизы';

  @override
  String get popularTracks => 'Популярные треки';

  @override
  String get untitledPlaylist => 'Без названия';

  @override
  String get yandexLikes => 'Мне нравится (Яндекс)';

  @override
  String get playlistEmpty => 'Плейлист пуст';

  @override
  String get syncYandex => 'Синхронизировать Яндекс';

  @override
  String get shuffleAll => 'Перемешать всё';

  @override
  String get localPlaylists => 'Локальные плейлисты';

  @override
  String get createPlaylist => 'Создать плейлист';

  @override
  String get playlistName => 'Название плейлиста';

  @override
  String get coverUrlHint => 'Ссылка на обложку (URL/GIF)';

  @override
  String get cancel => 'Отмена';

  @override
  String get create => 'Создать';

  @override
  String get addToPlaylist => 'Добавить в плейлист';

  @override
  String get selectFile => 'Выбрать файл';

  @override
  String get trackAdded => 'Трек добавлен';

  @override
  String get editPlaylist => 'Редактировать плейлист';

  @override
  String get deletePlaylist => 'Удалить плейлист';

  @override
  String deletePlaylistConfirm(String name) {
    return 'Удалить плейлист \"$name\"?';
  }

  @override
  String get playlistEdited => 'Плейлист отредактирован';

  @override
  String get playlistDeleted => 'Плейлист удалён';

  @override
  String get delete => 'Удалить';

  @override
  String get telemetrySection => 'Телеметрия';

  @override
  String get telemetry => 'Статистика';

  @override
  String get tracksPlayed => 'Слушали треков';

  @override
  String get listeningTime => 'Время прослушивания';

  @override
  String get hours => 'часов';

  @override
  String get minutes => 'минут';

  @override
  String get clearStatistics => 'Очистить статистику';

  @override
  String get statisticsCleared => 'Статистика очищена';

  @override
  String get daysInstalled => 'Дней в приложении';

  @override
  String get favoriteArtist => 'Любимый исполнитель';

  @override
  String get favoriteTrack => 'Любимый трек';

  @override
  String get favoritePlatform => 'Любимая площадка';

  @override
  String get unknownArtist => 'Неизвестный исполнитель';

  @override
  String get unknownTrack => 'Неизвестный трек';

  @override
  String get yandexMusic => 'Яндекс Музыка';

  @override
  String get soundCloud => 'SoundCloud';

  @override
  String get customTrackCover => 'Пользовательская обложка треков';

  @override
  String get coverUrl => 'Ссылка на обложку';

  @override
  String get coverFile => 'Файл обложки';

  @override
  String get supportedFormats => 'Форматы: GIF, PNG, JPG';

  @override
  String get noLyrics => 'Текст отсутствует';

  @override
  String get importPlaylist => 'Импорт плейлиста';

  @override
  String get playlistLink => 'Ссылка на плейлист';

  @override
  String get artists => 'Артисты';

  @override
  String get albums => 'Альбомы';

  @override
  String get startWave => 'Включить волну';

  @override
  String get equalizer => 'Эквалайзер';

  @override
  String get shortcutsTitle => 'Горячие клавиши';

  @override
  String get handbook => 'Справочник';

  @override
  String get shortcutSpace => 'Пауза / Воспроизведение';

  @override
  String get shortcutNextPrev => 'Следующий / Предыдущий трек';

  @override
  String get shortcutSeek => 'Перемотка -10с / +10с';

  @override
  String get shortcutTabs => 'Переключение вкладок';

  @override
  String get shortcutLists => 'Навигация по спискам';

  @override
  String get shortcutEnter => 'Выбор / Воспроизведение';

  @override
  String get shortcutLyrics => 'Текст песни';

  @override
  String get shortcutRepeat => 'Режим повтора';

  @override
  String get shortcutArtist => 'Карточка артиста';

  @override
  String get shortcutLike => 'Лайк / Дизлайк';

  @override
  String get shortcutPlaylist => 'Добавить в плейлист';

  @override
  String get shortcutSearch => 'Поиск';

  @override
  String get shortcutMute => 'Выключить звук';

  @override
  String get shortcutFullscreen => 'Полноэкранный режим';

  @override
  String get shortcutVolume => 'Громкость -5% / +5%';

  @override
  String get shortcutDigits => 'Быстрый переход по вкладкам';

  @override
  String get shortcutEscape => 'Назад / Закрыть / Очистить поиск';
}
