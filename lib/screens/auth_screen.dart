import 'package:flutter/material.dart';
import 'package:lizaplayer/services/token_storage.dart';
import 'package:lizaplayer/screens/home_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _tokenController = TextEditingController();

  Future<void> _saveToken() async {
    final token = _tokenController.text.trim();

    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Токен не может быть пустым')),
      );
      return;
    }

    print('Пытаюсь сохранить токен...');
    await TokenStorage.saveToken(token);

    // Проверяем, что сохранилось
    final saved = await TokenStorage.getToken();
    print('Сохранённый токен: ${saved != null ? "УСПЕШНО" : "НЕ УДАЛОСЬ"}');

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomeScreen(token: token)),
      );
    }
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Container(
          width: 460,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 40),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.music_note, size: 90, color: Colors.cyanAccent),
              const SizedBox(height: 24),
              const Text(
                'lizaplayer',
                style: TextStyle(fontSize: 42, fontWeight: FontWeight.w700, letterSpacing: 3),
              ),
              const SizedBox(height: 8),
              const Text(
                'Вставь свой токен',
                style: TextStyle(fontSize: 17, color: Colors.grey),
              ),
              const SizedBox(height: 40),

              TextField(
                controller: _tokenController,
                decoration: InputDecoration(
                  hintText: 'Токен',
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.grey.withOpacity(0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                ),
                onSubmitted: (_) => _saveToken(),
              ),

              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _saveToken,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                ),
                child: const Text('Сохранить и войти', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),

              const SizedBox(height: 40),

              const Text(
                'Как получить токен:\n'
                '1. Открой music.yandex.ru\n'
                '2. F12 → Application → Local Storage → https://music.yandex.ru\n'
                '3. Найди access_token и скопируй',
                style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.6),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
