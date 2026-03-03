import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  static const String _tokenKey = 'yandex_access_token';

  static Future<void> saveToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      print('Токен успешно сохранён!');
      print('Токен: ${token.substring(0, 20)}...');
    } catch (e) {
      print('ОШИБКА при сохранении токена: $e');
    }
  }

  static Future<String?> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      print('Токен из хранилища: ${token?.isEmpty == true ? "ПУСТО" : "есть"}');
      return token;
    } catch (e) {
      print('ОШИБКА при чтении токена: $e');
      return null;
    }
  }

  static Future<void> deleteToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      print('Токен удалён');
    } catch (e) {
      print('ОШИБКА при удалении токена: $e');
    }
  }
}
