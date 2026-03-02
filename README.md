<div align="center">
  <img src="https://i.imgur.com/removed.png" width="120" alt="lizaplayer">
  
  <h1>lizaplayer</h1>
  <p><strong>Красивый кастомный плеер для Yandex Music</strong></p>

  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/Linux-000000?style=for-the-badge&logo=linux&logoColor=white" alt="Linux">
  <img src="https://img.shields.io/badge/Yandex%20Music-FF0000?style=for-the-badge&logo=yandex&logoColor=white" alt="Yandex Music">

  <br><br>
  <img src="https://i.imgur.com/removed.png" width="800" alt="lizaplayer preview">
</div>

### Почему это имба?

- Полностью кастомный дизайн в тёмной эстетике
- Выбор акцентного цвета (аква, красный, серый, оранжевый, фиолетовый и т.д.)
- Красивые большие закругления везде
- Моя волна + поиск треков
- Кнопка "Найти" прямо внутри поля поиска
- Плавная анимация и внимание к мелочам
- Работает на Linux (и легко портируется)

### Скриншоты

Позже

### Как запустить

```bash
# Клонируем
git clone https://github.com/angemms/lizaplayer.git
cd lizaplayer

# Устанавливаем зависимости
flutter pub get

# Запускаем
flutter run -d linux --release
```
Как получить токен Yandex Music

Открой music.yandex.ru в браузере
Нажми F12 → вкладка Application → Local Storage → https://music.yandex.ru
Найди ключ access_token или oauth и скопируй его
Вставь в lizaplayer и нажми "Сохранить и войти"

Технологии

Flutter + Riverpod
just_audio
yandex_music API
shared_preferences
window_manager
