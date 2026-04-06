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
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
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

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @myWave.
  ///
  /// In en, this message translates to:
  /// **'My Vibe'**
  String get myWave;

  /// No description provided for @playlists.
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get playlists;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @searchTracks.
  ///
  /// In en, this message translates to:
  /// **'Search tracks...'**
  String get searchTracks;

  /// No description provided for @find.
  ///
  /// In en, this message translates to:
  /// **'Find'**
  String get find;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get loading;

  /// No description provided for @startMyWave.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get startMyWave;

  /// No description provided for @personalRecommendations.
  ///
  /// In en, this message translates to:
  /// **'Personal recommendations based on your taste'**
  String get personalRecommendations;

  /// No description provided for @myLikes.
  ///
  /// In en, this message translates to:
  /// **'My Likes'**
  String get myLikes;

  /// No description provided for @myPlaylists.
  ///
  /// In en, this message translates to:
  /// **'My Playlists'**
  String get myPlaylists;

  /// No description provided for @tracks.
  ///
  /// In en, this message translates to:
  /// **'tracks'**
  String get tracks;

  /// No description provided for @personalWave.
  ///
  /// In en, this message translates to:
  /// **'Personal Vibe'**
  String get personalWave;

  /// No description provided for @newWave.
  ///
  /// In en, this message translates to:
  /// **'New vibe'**
  String get newWave;

  /// No description provided for @noLikesYet.
  ///
  /// In en, this message translates to:
  /// **'No likes yet'**
  String get noLikesYet;

  /// No description provided for @likeToFill.
  ///
  /// In en, this message translates to:
  /// **'Like tracks to see them here'**
  String get likeToFill;

  /// No description provided for @syncComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Sync coming soon'**
  String get syncComingSoon;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @mainColor.
  ///
  /// In en, this message translates to:
  /// **'Main Color'**
  String get mainColor;

  /// No description provided for @cyan.
  ///
  /// In en, this message translates to:
  /// **'Cyan'**
  String get cyan;

  /// No description provided for @red.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get red;

  /// No description provided for @orange.
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get orange;

  /// No description provided for @purple.
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get purple;

  /// No description provided for @green.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get green;

  /// No description provided for @blue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get blue;

  /// No description provided for @pink.
  ///
  /// In en, this message translates to:
  /// **'Pink'**
  String get pink;

  /// No description provided for @indigo.
  ///
  /// In en, this message translates to:
  /// **'Indigo'**
  String get indigo;

  /// No description provided for @amber.
  ///
  /// In en, this message translates to:
  /// **'Amber'**
  String get amber;

  /// No description provided for @teal.
  ///
  /// In en, this message translates to:
  /// **'Teal'**
  String get teal;

  /// No description provided for @grey.
  ///
  /// In en, this message translates to:
  /// **'Grey'**
  String get grey;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @customBackground.
  ///
  /// In en, this message translates to:
  /// **'Custom Background'**
  String get customBackground;

  /// No description provided for @urlExample.
  ///
  /// In en, this message translates to:
  /// **'https://example.com/image.gif'**
  String get urlExample;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @glassInterface.
  ///
  /// In en, this message translates to:
  /// **'Glass Interface'**
  String get glassInterface;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// No description provided for @on.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get on;

  /// No description provided for @backgroundBlur.
  ///
  /// In en, this message translates to:
  /// **'Background Blur'**
  String get backgroundBlur;

  /// No description provided for @interfaceScale.
  ///
  /// In en, this message translates to:
  /// **'Interface Scale'**
  String get interfaceScale;

  /// No description provided for @freezeOptimization.
  ///
  /// In en, this message translates to:
  /// **'Freeze Optimization'**
  String get freezeOptimization;

  /// No description provided for @freezeOptimizationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pause all animations when window is not in focus'**
  String get freezeOptimizationSubtitle;

  /// No description provided for @recommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get recommended;

  /// No description provided for @experimental.
  ///
  /// In en, this message translates to:
  /// **'Experimental'**
  String get experimental;

  /// No description provided for @standard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get standard;

  /// No description provided for @languageSection.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageSection;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @russian.
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get russian;

  /// No description provided for @dataAndAccount.
  ///
  /// In en, this message translates to:
  /// **'Data and Account'**
  String get dataAndAccount;

  /// No description provided for @aboutSection.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutSection;

  /// No description provided for @clearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear Cache'**
  String get clearCache;

  /// No description provided for @clearCacheSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Clear downloaded covers and data'**
  String get clearCacheSubtitle;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get logout;

  /// No description provided for @logoutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Delete token and exit'**
  String get logoutSubtitle;

  /// No description provided for @queue.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get queue;

  /// No description provided for @queueEmpty.
  ///
  /// In en, this message translates to:
  /// **'Queue is empty'**
  String get queueEmpty;

  /// No description provided for @searchResultsFor.
  ///
  /// In en, this message translates to:
  /// **'Search results for \"{query}\"'**
  String searchResultsFor(String query);

  /// No description provided for @noResultsFound.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noResultsFound;

  /// No description provided for @untitledTrack.
  ///
  /// In en, this message translates to:
  /// **'Untitled Track'**
  String get untitledTrack;

  /// No description provided for @integrationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Integrations'**
  String get integrationsTitle;

  /// No description provided for @yandexTokenHint.
  ///
  /// In en, this message translates to:
  /// **'Yandex Music OAuth Token'**
  String get yandexTokenHint;

  /// No description provided for @soundcloudIdHint.
  ///
  /// In en, this message translates to:
  /// **'SoundCloud Client ID'**
  String get soundcloudIdHint;

  /// No description provided for @tokensSaved.
  ///
  /// In en, this message translates to:
  /// **'Tokens successfully saved.'**
  String get tokensSaved;

  /// No description provided for @aboutArtist.
  ///
  /// In en, this message translates to:
  /// **'About Artist'**
  String get aboutArtist;

  /// No description provided for @popularReleases.
  ///
  /// In en, this message translates to:
  /// **'Popular Releases'**
  String get popularReleases;

  /// No description provided for @popularTracks.
  ///
  /// In en, this message translates to:
  /// **'Popular Tracks'**
  String get popularTracks;

  /// No description provided for @untitledPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Untitled Playlist'**
  String get untitledPlaylist;

  /// No description provided for @yandexLikes.
  ///
  /// In en, this message translates to:
  /// **'Likes (Yandex)'**
  String get yandexLikes;

  /// No description provided for @playlistEmpty.
  ///
  /// In en, this message translates to:
  /// **'Playlist is empty'**
  String get playlistEmpty;

  /// No description provided for @syncYandex.
  ///
  /// In en, this message translates to:
  /// **'Sync with Yandex'**
  String get syncYandex;

  /// No description provided for @shuffleAll.
  ///
  /// In en, this message translates to:
  /// **'Shuffle All'**
  String get shuffleAll;

  /// No description provided for @localPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Local Playlists'**
  String get localPlaylists;

  /// No description provided for @createPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Create Playlist'**
  String get createPlaylist;

  /// No description provided for @playlistName.
  ///
  /// In en, this message translates to:
  /// **'Playlist Name'**
  String get playlistName;

  /// No description provided for @coverUrlHint.
  ///
  /// In en, this message translates to:
  /// **'Cover URL (Image/GIF)'**
  String get coverUrlHint;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @addToPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Add to Playlist'**
  String get addToPlaylist;

  /// No description provided for @selectFile.
  ///
  /// In en, this message translates to:
  /// **'Select File'**
  String get selectFile;

  /// No description provided for @trackAdded.
  ///
  /// In en, this message translates to:
  /// **'Track added'**
  String get trackAdded;

  /// No description provided for @editPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Edit Playlist'**
  String get editPlaylist;

  /// No description provided for @deletePlaylist.
  ///
  /// In en, this message translates to:
  /// **'Delete Playlist'**
  String get deletePlaylist;

  /// No description provided for @deletePlaylistConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete playlist \"{name}\"?'**
  String deletePlaylistConfirm(String name);

  /// No description provided for @playlistEdited.
  ///
  /// In en, this message translates to:
  /// **'Playlist edited'**
  String get playlistEdited;

  /// No description provided for @playlistDeleted.
  ///
  /// In en, this message translates to:
  /// **'Playlist deleted'**
  String get playlistDeleted;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @telemetrySection.
  ///
  /// In en, this message translates to:
  /// **'Telemetry'**
  String get telemetrySection;

  /// No description provided for @telemetry.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get telemetry;

  /// No description provided for @tracksPlayed.
  ///
  /// In en, this message translates to:
  /// **'Tracks played'**
  String get tracksPlayed;

  /// No description provided for @listeningTime.
  ///
  /// In en, this message translates to:
  /// **'Listening time'**
  String get listeningTime;

  /// No description provided for @hours.
  ///
  /// In en, this message translates to:
  /// **'hours'**
  String get hours;

  /// No description provided for @minutes.
  ///
  /// In en, this message translates to:
  /// **'minutes'**
  String get minutes;

  /// No description provided for @clearStatistics.
  ///
  /// In en, this message translates to:
  /// **'Clear statistics'**
  String get clearStatistics;

  /// No description provided for @statisticsCleared.
  ///
  /// In en, this message translates to:
  /// **'Statistics cleared'**
  String get statisticsCleared;

  /// No description provided for @daysInstalled.
  ///
  /// In en, this message translates to:
  /// **'Days installed'**
  String get daysInstalled;

  /// No description provided for @favoriteArtist.
  ///
  /// In en, this message translates to:
  /// **'Favorite artist'**
  String get favoriteArtist;

  /// No description provided for @favoriteTrack.
  ///
  /// In en, this message translates to:
  /// **'Favorite track'**
  String get favoriteTrack;

  /// No description provided for @favoritePlatform.
  ///
  /// In en, this message translates to:
  /// **'Favorite platform'**
  String get favoritePlatform;

  /// No description provided for @unknownArtist.
  ///
  /// In en, this message translates to:
  /// **'Unknown Artist'**
  String get unknownArtist;

  /// No description provided for @unknownTrack.
  ///
  /// In en, this message translates to:
  /// **'Unknown Track'**
  String get unknownTrack;

  /// No description provided for @yandexMusic.
  ///
  /// In en, this message translates to:
  /// **'Yandex Music'**
  String get yandexMusic;

  /// No description provided for @soundCloud.
  ///
  /// In en, this message translates to:
  /// **'SoundCloud'**
  String get soundCloud;

  /// No description provided for @customTrackCover.
  ///
  /// In en, this message translates to:
  /// **'Custom Track Cover'**
  String get customTrackCover;

  /// No description provided for @coverUrl.
  ///
  /// In en, this message translates to:
  /// **'Cover URL'**
  String get coverUrl;

  /// No description provided for @coverFile.
  ///
  /// In en, this message translates to:
  /// **'Cover File'**
  String get coverFile;

  /// No description provided for @supportedFormats.
  ///
  /// In en, this message translates to:
  /// **'Supported: GIF, PNG, JPG'**
  String get supportedFormats;

  /// No description provided for @noLyrics.
  ///
  /// In en, this message translates to:
  /// **'No lyrics available'**
  String get noLyrics;

  /// No description provided for @importPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Import Playlist'**
  String get importPlaylist;

  /// No description provided for @playlistLink.
  ///
  /// In en, this message translates to:
  /// **'Playlist Link'**
  String get playlistLink;

  /// No description provided for @artists.
  ///
  /// In en, this message translates to:
  /// **'Artists'**
  String get artists;

  /// No description provided for @albums.
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get albums;

  /// No description provided for @startWave.
  ///
  /// In en, this message translates to:
  /// **'Start Wave'**
  String get startWave;

  /// No description provided for @equalizer.
  ///
  /// In en, this message translates to:
  /// **'Equalizer'**
  String get equalizer;

  /// No description provided for @shortcutsTitle.
  ///
  /// In en, this message translates to:
  /// **'Keyboard Shortcuts'**
  String get shortcutsTitle;

  /// No description provided for @handbook.
  ///
  /// In en, this message translates to:
  /// **'Handbook'**
  String get handbook;

  /// No description provided for @shortcutSpace.
  ///
  /// In en, this message translates to:
  /// **'Pause / Play'**
  String get shortcutSpace;

  /// No description provided for @shortcutNextPrev.
  ///
  /// In en, this message translates to:
  /// **'Next / Previous track'**
  String get shortcutNextPrev;

  /// No description provided for @shortcutSeek.
  ///
  /// In en, this message translates to:
  /// **'Seek -10s / +10s'**
  String get shortcutSeek;

  /// No description provided for @shortcutTabs.
  ///
  /// In en, this message translates to:
  /// **'Switch tabs'**
  String get shortcutTabs;

  /// No description provided for @shortcutLists.
  ///
  /// In en, this message translates to:
  /// **'Navigate lists'**
  String get shortcutLists;

  /// No description provided for @shortcutEnter.
  ///
  /// In en, this message translates to:
  /// **'Select / Play'**
  String get shortcutEnter;

  /// No description provided for @shortcutLyrics.
  ///
  /// In en, this message translates to:
  /// **'Show lyrics'**
  String get shortcutLyrics;

  /// No description provided for @shortcutRepeat.
  ///
  /// In en, this message translates to:
  /// **'Toggle repeat'**
  String get shortcutRepeat;

  /// No description provided for @shortcutArtist.
  ///
  /// In en, this message translates to:
  /// **'Artist info'**
  String get shortcutArtist;

  /// No description provided for @shortcutLike.
  ///
  /// In en, this message translates to:
  /// **'Like / Dislike'**
  String get shortcutLike;

  /// No description provided for @shortcutPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Add to playlist'**
  String get shortcutPlaylist;

  /// No description provided for @shortcutSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get shortcutSearch;

  /// No description provided for @shortcutMute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get shortcutMute;

  /// No description provided for @shortcutFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Fullscreen'**
  String get shortcutFullscreen;

  /// No description provided for @shortcutVolume.
  ///
  /// In en, this message translates to:
  /// **'Volume -5% / +5%'**
  String get shortcutVolume;

  /// No description provided for @shortcutDigits.
  ///
  /// In en, this message translates to:
  /// **'Quick tab switch'**
  String get shortcutDigits;

  /// No description provided for @shortcutEscape.
  ///
  /// In en, this message translates to:
  /// **'Back / Close / Clear search'**
  String get shortcutEscape;

  /// No description provided for @gradientBorder.
  ///
  /// In en, this message translates to:
  /// **'Gradient Border'**
  String get gradientBorder;

  /// No description provided for @borderColor.
  ///
  /// In en, this message translates to:
  /// **'Border Color'**
  String get borderColor;

  /// No description provided for @gradientColor1.
  ///
  /// In en, this message translates to:
  /// **'Gradient Color 1'**
  String get gradientColor1;

  /// No description provided for @gradientColor2.
  ///
  /// In en, this message translates to:
  /// **'Gradient Color 2'**
  String get gradientColor2;

  /// No description provided for @defaultColor.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultColor;

  /// No description provided for @white.
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get white;

  /// No description provided for @black.
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get black;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
