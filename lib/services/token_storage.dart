import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  static const String _yandexTokenKey = 'yandex_access_token';
  static const String _soundcloudClientIdKey = 'soundcloud_client_id';
  static const String _languageKey = 'app_language';
  static const String _themeKey = 'app_theme_mode';
  static const String _accentColorKey = 'app_accent_color';
  static const String _wasTransparentColorKey = 'was_transparent_color';

  static Future<void> saveWasTransparentColor(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_wasTransparentColorKey, value);
  }

  static Future<bool> getWasTransparentColor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_wasTransparentColorKey) ?? false;
  }
  static const String _likedTracksKey = 'liked_track_ids';
  static const String _glassEnabledKey = 'glass_enabled';
  static const String _customGifUrlKey = 'custom_gif_url';
  static const String _customBackgroundPathKey = 'custom_background_path';
  static const String _customTrackCoverUrlKey = 'custom_track_cover_url';
  static const String _customTrackCoverPathKey = 'custom_track_cover_path';
  static const String _blurEnabledKey = 'blur_enabled';
  static const String _textScaleKey = 'text_scale';
  static const String _volumeKey = 'app_volume';
  static const String _tracksPlayedKey = 'telemetry_tracks_played';
  static const String _totalListeningTimeKey = 'telemetry_total_listening_time';
  static const String _lastResetDateKey = 'telemetry_last_reset_date';
  static const String _firstInstallDateKey = 'telemetry_first_install_date';
  static const String _artistPlayCountsKey = 'telemetry_artist_play_counts';
  static const String _trackPlayCountsKey = 'telemetry_track_play_counts';
  static const String _platformCountsKey = 'telemetry_platform_counts';
  static const String _isFirstRunKey = 'is_first_run';
  static const String _freezeOptimizationKey = 'freeze_optimization';
  static const String _lastTrackKey = 'last_played_track';
  static const String _lastPositionKey = 'last_played_position';
  static const String _lastPlaylistKey = 'last_played_playlist';
  static const String _lastIndexKey = 'last_played_index';
  static const String _borderColorKey = 'border_color';
  static const String _borderGradientEnabledKey = 'border_gradient_enabled';
  static const String _borderGradientColor1Key = 'border_gradient_color1';
  static const String _borderGradientColor2Key = 'border_gradient_color2';
  static const String _borderAnimationSpeedKey = 'border_animation_speed';
  static const String _playerSliderStyleKey = 'player_slider_style';
  static const String _customTitleBarEnabledKey = 'custom_title_bar_enabled';

  static Future<void> savePlayerSliderStyle(String style) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_playerSliderStyleKey, style);
  }

  static Future<String> getPlayerSliderStyle() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_playerSliderStyleKey) ?? 'standard';
  }
  static const String _titleBarHeightKey = 'title_bar_height';
  static const String _titleBarColorKey = 'title_bar_color';
  static const String _titleBarOpacityKey = 'title_bar_opacity';
  static const String _titleBarShowTitleKey = 'title_bar_show_title';
  static const String _titleBarButtonStyleKey = 'title_bar_button_style';

  static Future<void> saveCustomTitleBarEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_customTitleBarEnabledKey, enabled);
  }

  static Future<bool> getCustomTitleBarEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_customTitleBarEnabledKey) ?? true;
  }

  static Future<void> saveTitleBarHeight(double height) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_titleBarHeightKey, height);
  }

  static Future<double> getTitleBarHeight() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_titleBarHeightKey) ?? 40.0;
  }

  static Future<void> saveTitleBarColor(int? colorValue) async {
    final prefs = await SharedPreferences.getInstance();
    if (colorValue == null) {
      await prefs.remove(_titleBarColorKey);
    } else {
      await prefs.setInt(_titleBarColorKey, colorValue);
    }
  }

  static Future<int?> getTitleBarColor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_titleBarColorKey);
  }

  static Future<void> saveTitleBarOpacity(double opacity) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_titleBarOpacityKey, opacity);
  }

  static Future<double> getTitleBarOpacity() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_titleBarOpacityKey) ?? 1.0;
  }

  static Future<void> saveTitleBarShowTitle(bool show) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_titleBarShowTitleKey, show);
  }

  static Future<bool> getTitleBarShowTitle() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_titleBarShowTitleKey) ?? true;
  }

  static Future<void> saveTitleBarButtonStyle(String style) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_titleBarButtonStyleKey, style);
  }

  static Future<String> getTitleBarButtonStyle() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_titleBarButtonStyleKey) ?? 'windows';
  }

  static Future<void> saveBorderColor(int colorValue) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_borderColorKey, colorValue);
  }

  static Future<int?> getBorderColor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_borderColorKey);
  }

  static Future<void> saveBorderGradientEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_borderGradientEnabledKey, enabled);
  }

  static Future<bool> getBorderGradientEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_borderGradientEnabledKey) ?? false;
  }

  static Future<void> saveBorderGradientColor1(int colorValue) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_borderGradientColor1Key, colorValue);
  }

  static Future<int?> getBorderGradientColor1() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_borderGradientColor1Key);
  }

  static Future<void> saveBorderGradientColor2(int colorValue) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_borderGradientColor2Key, colorValue);
  }

  static Future<int?> getBorderGradientColor2() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_borderGradientColor2Key);
  }

  static Future<void> saveBorderAnimationSpeed(double speed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_borderAnimationSpeedKey, speed);
  }

  static Future<double> getBorderAnimationSpeed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_borderAnimationSpeedKey) ?? 1.0;
  }

  static Future<void> saveLastPlaylist(List<String> tracksJson, int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_lastPlaylistKey, tracksJson);
    await prefs.setInt(_lastIndexKey, index);
  }

  static Future<List<String>> getLastPlaylist() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_lastPlaylistKey) ?? [];
  }

  static Future<int> getLastIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_lastIndexKey) ?? -1;
  }

  static Future<void> saveLastTrack(String json) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastTrackKey, json);
  }

  static Future<String?> getLastTrack() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastTrackKey);
  }

  static Future<void> saveLastPosition(int ms) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastPositionKey, ms);
  }

  static Future<int> getLastPosition() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_lastPositionKey) ?? 0;
  }

  static Future<void> saveYandexToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_yandexTokenKey, token);
    } catch (e) {}
  }

  static Future<String?> getYandexToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_yandexTokenKey);
    } catch (e) {
      return null;
    }
  }

  static Future<void> deleteYandexToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_yandexTokenKey);
    } catch (e) {}
  }

  static Future<void> saveSoundcloudClientId(String clientId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_soundcloudClientIdKey, clientId);
    } catch (e) {}
  }

  static Future<String?> getSoundcloudClientId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_soundcloudClientIdKey) ?? 'khI8ciOiYPX6UVGInQY5zA0zvTkfzuuC';
    } catch (e) {
      return 'khI8ciOiYPX6UVGInQY5zA0zvTkfzuuC';
    }
  }

  static Future<void> deleteSoundcloudClientId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_soundcloudClientIdKey);
    } catch (e) {}
  }

  static Future<void> deleteAllTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_yandexTokenKey);
      await prefs.remove(_soundcloudClientIdKey);
    } catch (e) {}
  }

  static Future<void> saveLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, languageCode);
  }

  static Future<String?> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_languageKey);
  }

  static Future<void> saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode.toString());
  }

  static Future<ThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_themeKey);
    if (value == ThemeMode.light.toString()) return ThemeMode.light;
    if (value == ThemeMode.dark.toString()) return ThemeMode.dark;
    return ThemeMode.dark;
  }

  static Future<void> saveAccentColor(int colorValue) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_accentColorKey, colorValue);
  }

  static Future<int> getAccentColor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_accentColorKey) ?? Colors.transparent.value;
  }

  static Future<void> saveGlassEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_glassEnabledKey, value);
  }

  static Future<bool> getGlassEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_glassEnabledKey) ?? true;
  }

  static Future<void> saveFreezeOptimization(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_freezeOptimizationKey, value);
  }

  static Future<bool> getFreezeOptimization() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_freezeOptimizationKey) ?? false;
  }

  static Future<void> saveFirstRunCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isFirstRunKey, false);
  }

  static Future<bool> isFirstRun() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isFirstRunKey) ?? true;
  }

  static Future<void> saveLikedTrackIds(List<String> ids) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_likedTracksKey, ids);
    } catch (e) {}
  }

  static Future<List<String>> getLikedTrackIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_likedTracksKey) ?? [];
    } catch (e) {
      return [];
    }
  }

  static Future<void> clearLikedTracks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_likedTracksKey);
    } catch (e) {}
  }

  static Future<void> saveCustomGifUrl(String? url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (url == null || url.trim().isEmpty) {
        await prefs.remove(_customGifUrlKey);
      } else {
        await prefs.setString(_customGifUrlKey, url.trim());
      }
    } catch (e) {}
  }

  static Future<String?> getCustomGifUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_customGifUrlKey);
    } catch (e) {
      return null;
    }
  }

  static Future<void> saveCustomBackgroundPath(String? path) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (path == null || path.trim().isEmpty) {
        await prefs.remove(_customBackgroundPathKey);
      } else {
        await prefs.setString(_customBackgroundPathKey, path.trim());
      }
    } catch (e) {}
  }

  static Future<String?> getCustomBackgroundPath() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_customBackgroundPathKey);
    } catch (e) {
      return null;
    }
  }

  static Future<void> saveBlurEnabled(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_blurEnabledKey, value);
    } catch (e) {}
  }

  static Future<bool> getBlurEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_blurEnabledKey) ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<void> saveScale(double scale) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_textScaleKey, scale);
    } catch (e) {}
  }

  static Future<double?> getScale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getDouble(_textScaleKey);
    } catch (e) {
      return null;
    }
  }

  static Future<void> saveVolume(double volume) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_volumeKey, volume);
    } catch (e) {}
  }

  static Future<double?> getVolume() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getDouble(_volumeKey);
    } catch (e) {
      return null;
    }
  }

  static Future<void> initFirstInstallDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!prefs.containsKey(_firstInstallDateKey)) {
        await prefs.setString(_firstInstallDateKey, DateTime.now().toIso8601String());
      }
    } catch (e) {}
  }

  static Future<int> getDaysInstalled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final installDateStr = prefs.getString(_firstInstallDateKey);
      if (installDateStr != null) {
        final installDate = DateTime.parse(installDateStr);
        return DateTime.now().difference(installDate).inDays;
      }
    } catch (e) {}
    return 0;
  }

  static Future<void> saveTelemetryData(int tracksPlayed, int totalSeconds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_tracksPlayedKey, tracksPlayed);
      await prefs.setInt(_totalListeningTimeKey, totalSeconds);
    } catch (e) {}
  }

  static Future<Map<String, dynamic>> getTelemetryData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final artistCounts = Map.fromEntries(
        (prefs.getStringList(_artistPlayCountsKey) ?? []).map((e) {
          final parts = e.split('|');
          return MapEntry(parts[0], int.parse(parts[1]));
        })
      );
      final trackCounts = Map.fromEntries(
        (prefs.getStringList(_trackPlayCountsKey) ?? []).map((e) {
          final parts = e.split('|');
          return MapEntry(parts[0], int.parse(parts[1]));
        })
      );
      final platformCounts = Map.fromEntries(
        (prefs.getStringList(_platformCountsKey) ?? []).map((e) {
          final parts = e.split('|');
          return MapEntry(parts[0], int.parse(parts[1]));
        })
      );

      String? favoriteArtist;
      int maxArtistPlays = 0;
      artistCounts.forEach((artist, count) {
        if (count > maxArtistPlays) {
          maxArtistPlays = count;
          favoriteArtist = artist;
        }
      });

      String? favoriteTrack;
      int maxTrackPlays = 0;
      trackCounts.forEach((track, count) {
        if (count > maxTrackPlays) {
          maxTrackPlays = count;
          favoriteTrack = track;
        }
      });

      String? favoritePlatform;
      int maxPlatformPlays = 0;
      platformCounts.forEach((platform, count) {
        if (count > maxPlatformPlays) {
          maxPlatformPlays = count;
          favoritePlatform = platform;
        }
      });

      return {
        'tracksPlayed': prefs.getInt(_tracksPlayedKey) ?? 0,
        'totalListeningTime': prefs.getInt(_totalListeningTimeKey) ?? 0,
        'lastResetDate': prefs.getString(_lastResetDateKey),
        'daysInstalled': await getDaysInstalled(),
        'favoriteArtist': favoriteArtist,
        'favoriteTrack': favoriteTrack,
        'favoritePlatform': favoritePlatform,
      };
    } catch (e) {
      return {
        'tracksPlayed': 0,
        'totalListeningTime': 0,
        'lastResetDate': null,
        'daysInstalled': 0,
        'favoriteArtist': null,
        'favoriteTrack': null,
        'favoritePlatform': null,
      };
    }
  }

  static Future<void> incrementTracksPlayed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getInt(_tracksPlayedKey) ?? 0;
      await prefs.setInt(_tracksPlayedKey, current + 1);
    } catch (e) {}
  }

  static Future<void> addListeningTime(int seconds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getInt(_totalListeningTimeKey) ?? 0;
      await prefs.setInt(_totalListeningTimeKey, current + seconds);
    } catch (e) {}
  }

  static Future<void> recordTrackPlay(String artist, String trackTitle, String platform) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final artistCounts = prefs.getStringList(_artistPlayCountsKey) ?? [];
      final artistMap = <String, int>{};
      for (var e in artistCounts) {
        final parts = e.split('|');
        if (parts.length == 2) artistMap[parts[0]] = int.parse(parts[1]);
      }
      artistMap[artist] = (artistMap[artist] ?? 0) + 1;
      await prefs.setStringList(_artistPlayCountsKey, 
        artistMap.entries.map((e) => '${e.key}|${e.value}').toList());

      final trackCounts = prefs.getStringList(_trackPlayCountsKey) ?? [];
      final trackMap = <String, int>{};
      for (var e in trackCounts) {
        final parts = e.split('|');
        if (parts.length == 2) trackMap[parts[0]] = int.parse(parts[1]);
      }
      trackMap[trackTitle] = (trackMap[trackTitle] ?? 0) + 1;
      await prefs.setStringList(_trackPlayCountsKey, 
        trackMap.entries.map((e) => '${e.key}|${e.value}').toList());

      final platformCounts = prefs.getStringList(_platformCountsKey) ?? [];
      final platformMap = <String, int>{};
      for (var e in platformCounts) {
        final parts = e.split('|');
        if (parts.length == 2) platformMap[parts[0]] = int.parse(parts[1]);
      }
      platformMap[platform] = (platformMap[platform] ?? 0) + 1;
      await prefs.setStringList(_platformCountsKey, 
        platformMap.entries.map((e) => '${e.key}|${e.value}').toList());
    } catch (e) {}
  }

  static Future<void> clearTelemetry() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tracksPlayedKey);
      await prefs.remove(_totalListeningTimeKey);
      await prefs.remove(_artistPlayCountsKey);
      await prefs.remove(_trackPlayCountsKey);
      await prefs.remove(_platformCountsKey);
      await prefs.setString(_lastResetDateKey, DateTime.now().toIso8601String());
    } catch (e) {}
  }

  static Future<void> saveCustomTrackCoverUrl(String? url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (url == null || url.trim().isEmpty) {
        await prefs.remove(_customTrackCoverUrlKey);
      } else {
        await prefs.setString(_customTrackCoverUrlKey, url.trim());
      }
    } catch (e) {}
  }

  static Future<String?> getCustomTrackCoverUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_customTrackCoverUrlKey);
    } catch (e) {
      return null;
    }
  }

  static Future<void> saveCustomTrackCoverPath(String? path) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (path == null || path.trim().isEmpty) {
        await prefs.remove(_customTrackCoverPathKey);
      } else {
        await prefs.setString(_customTrackCoverPathKey, path.trim());
      }
    } catch (e) {}
  }

  static Future<String?> getCustomTrackCoverPath() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_customTrackCoverPathKey);
    } catch (e) {
      return null;
    }
  }

  static const String _syncYandexLikesKey = 'sync_yandex_likes';

  static Future<void> saveSyncYandexLikes(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_syncYandexLikesKey, enabled);
  }

  static Future<bool> getSyncYandexLikes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_syncYandexLikesKey) ?? false;
  }

}
