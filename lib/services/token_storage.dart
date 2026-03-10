import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  static const String _yandexTokenKey = 'yandex_access_token';
  static const String _soundcloudClientIdKey = 'soundcloud_client_id';
  static const String _languageKey = 'app_language';
  static const String _themeKey = 'app_theme_mode';
  static const String _accentColorKey = 'app_accent_color';
  static const String _likedTracksKey = 'liked_track_ids';
  static const String _glassEnabledKey = 'glass_enabled';
  static const String _customGifUrlKey = 'custom_gif_url';
  static const String _blurEnabledKey = 'blur_enabled';
  static const String _textScaleKey = 'text_scale';
  static const String _volumeKey = 'app_volume';

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
      return prefs.getString(_soundcloudClientIdKey);
    } catch (e) {
      return null;
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
    return prefs.getInt(_accentColorKey) ?? Colors.cyanAccent.value;
  }

  static Future<void> saveGlassEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_glassEnabledKey, value);
  }

  static Future<bool> getGlassEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_glassEnabledKey) ?? false;
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
}

