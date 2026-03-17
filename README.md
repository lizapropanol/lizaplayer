<width="32" height="32" /> lizaplayer

[![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![License](https://img.shields.io/badge/license-MIT-green.svg?style=for-the-badge)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux-blue?style=for-the-badge)](https://github.com/lizapropanol/lizaplayer/releases)

**lizaplayer** is a modern, feature-rich, and highly customizable music player built with Flutter. It seamlessly integrates **Yandex Music** and **SoundCloud**, offering a premium listening experience with a focus on aesthetics and smooth performance.

---

## Key Features

- **Dual Integration**: Support for both Yandex Music and SoundCloud in one app.
- **My Wave**: Enjoy personalized radio "My Wave" from Yandex Music.
- **Synced Lyrics**: Real-time lyrics support (LRC) via [lrclib.net](https://lrclib.net).
- **Ultimate Customization**:
  - **Glassmorphism**: Beautiful frosted glass effects.
  - **Dynamic Themes**: Dark and Light modes with customizable accent colors.
  - **Personal Backgrounds**: Set custom GIFs or local images as your player background.
  - **Custom Covers**: Personalize track covers.
- **Playlist Management**:
  - Create and edit local playlists.
  - Import playlists directly from Yandex Music or SoundCloud URLs.
  - Like tracks to sync them with your Yandex account.
- **Smooth UX**: Fluid animations, hover effects, and a responsive interface.
- **Cross-Platform**: Native performance on Windows and Linux.

---

## Screenshots

<p align="center">
  <img src="https://github.com/user-attachments/assets/bf8f3b63-be6a-4c1c-8f98-368bcc25e128" width="85%" />
  <br />
  <em>The main player interface with a clean, modern design.</em>
</p>

<p align="center">
  <img src="https://github.com/user-attachments/assets/605de2bb-2308-4533-9275-4faeff2d1859" width="42%" />
  <img src="https://github.com/user-attachments/assets/5d078405-3d66-40cc-9e85-6a7f69943661" width="42%" />
  <br />
  <em>Dark and Light themes with customizable accent colors.</em>
</p>

---

## Installation & Setup

### For Users
1. Go to the [**Releases**](https://github.com/lizapropanol/lizaplayer/releases) page.
2. Download the archive for your OS (Windows or Linux).
3. Unpack and run the executable.

### For Developers
```bash
# Clone the repository
git clone https://github.com/lizapropanol/lizaplayer.git
cd lizaplayer

# Install dependencies
flutter pub get

# Run the app
flutter run -d windows # or linux
```

---

## Getting Started

To enjoy the full experience, you'll need a Yandex Music token:
1. Open [music.yandex.ru](https://music.yandex.ru) in your browser.
2. Press `F12` → **Application** tab → **Local Storage** → `https://music.yandex.ru`.
3. Find the `access_token` key and copy its value.
4. Paste it into **lizaplayer** and click **"Save and Login"**.

---

## Tech Stack

<p align="left">
  <img src="https://img.shields.io/badge/Riverpod-764ABC?style=flat-square&logo=redux&logoColor=white" alt="Riverpod" />
  <img src="https://img.shields.io/badge/Just%20Audio-0175C2?style=flat-square&logo=dart&logoColor=white" alt="Just Audio" />
  <img src="https://img.shields.io/badge/Material%203-757575?style=flat-square&logo=materialdesign&logoColor=white" alt="Material 3" />
  <img src="https://img.shields.io/badge/Intl-FFB000?style=flat-square&logo=google&logoColor=white" alt="Intl" />
</p>

- **State Management**: [Riverpod](https://riverpod.dev)
- **Audio Engine**: [just_audio](https://pub.dev/packages/just_audio) & [media_kit](https://pub.dev/packages/media_kit)
- **Networking**: [http](https://pub.dev/packages/http) & [yandex_music](https://pub.dev/packages/yandex_music)
- **UI Components**: [Font Awesome](https://fontawesome.com), [Cached Network Image](https://pub.dev/packages/cached_network_image)

---

## Star History

<p align="center">
<a href="https://star-history.com/#lizapropanol/lizaplayer&Date">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/image?repos=lizapropanol/lizaplayer&type=date&theme=dark" />
    <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/image?repos=lizapropanol/lizaplayer&type=date" />
    <img alt="Star History Chart" src="https://api.star-history.com/image?repos=lizapropanol/lizaplayer&type=date" />
  </picture>
</a>
</p>

---

<p align="center">
  Developed with ❤️ by <a href="https://github.com/lizapropanol">lizapropanol</a>
</p>

## 

[![Donate on DonationAlerts](https://img.shields.io/badge/Donate-DonationAlerts-orange?style=for-the-badge&logo=donate&logoColor=white)](https://www.donationalerts.com/r/lizapropanol)
