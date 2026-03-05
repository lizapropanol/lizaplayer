### О плеере

- opensource
- Полностью кастомный дизайн в тёмном/светлом стиле
- Выбор акцентного цвета (аква, красный, серый, оранжевый, фиолетовый и т.д.)
- Приятный интерфейс
- Моя волна
- Поиск треков
- Плавные анимации и внимание к мелочам
- Работает на Linux и Windows

### Скриншоты

![w1](https://github.com/user-attachments/assets/bf8f3b63-be6a-4c1c-8f98-368bcc25e128)
![w2](https://github.com/user-attachments/assets/7e398ba5-68ca-4298-a3e2-c5c52e1850a4)
![w3](https://github.com/user-attachments/assets/577530ed-df63-49b7-bcfd-ac64eddcb2d2)
![w4](https://github.com/user-attachments/assets/aefb337f-f95f-4595-9650-5fbcff3bb12c)

### Как запустить

- Скачиваем последний релиз
- Разархивируем
- Запускаем исполняемый файл

### Как запустить (альтернатива)

```bash
# Клонируем
git clone https://github.com/lizapropanol/lizaplayer.git
cd lizaplayer

# Устанавливаем зависимости
flutter pub get

# Запускаем
flutter run -d linux --release
```

### Как получить токен Yandex Music

Открой music.yandex.ru в браузере
Нажми F12 → вкладка Application → Local Storage → https://music.yandex.ru
Найди ключ access_token или oauth и скопируй его
Вставь в lizaplayer и нажми "Сохранить и войти"

### Технологии

Flutter + Riverpod
just_audio
yandex_music API
shared_preferences
window_manager
