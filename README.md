<h1 align="center">lizaplayer</h1>

[![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![License](https://img.shields.io/badge/license-GPL_v3-blue.svg?style=for-the-badge)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux-blue?style=for-the-badge)](https://github.com/lizapropanol/lizaplayer/releases)
[![Donate on DonationAlerts](https://img.shields.io/badge/Donate-DonationAlerts-orange?style=for-the-badge&logo=donate&logoColor=white)](https://www.donationalerts.com/r/lizapropanol)

**lizaplayer** is a modern, feature-rich, and highly customizable music player built with Flutter. It seamlessly integrates **Yandex Music** and **SoundCloud**, offering a premium listening experience with a focus on aesthetics and smooth performance.

---

## Key Features

- **Dual Integration**: Support for both Yandex Music and SoundCloud in one app.
- **My Vibe**: Enjoy personalized radio "My Vibe" from Yandex Music.
- **Synced Lyrics**: Real-time lyrics support (LRC) via [lrclib.net](https://lrclib.net).
- **Ultimate Customization**:
  - **Glassmorphism**: Beautiful frosted glass effects.
  - **Dynamic Themes**: Dark and Light modes with customizable accent colors.
  - **Personal Backgrounds**: Set custom GIFs or local images as your player background.
  - **Custom Covers**: Personalize track covers.
- **Enhanced Integration**:
  - **Discord RPC**: Show what you're listening to in your Discord profile.
  - **System Tray**: Minimize to tray for quick access.
  - **Single Instance**: Only one window of lizaplayer at a time.
  - **Deep Linking**: Handle authentication and links seamlessly.
- **Playlist Management**:
  - Create and edit local playlists.
  - Import playlists directly from Yandex Music or SoundCloud URLs.
  - Like tracks to sync them with your Yandex account.
- **Smooth UX**: Fluid animations, hover effects, and a responsive interface.
- **Cross-Platform**: Native performance on Windows and Linux with full media keys support.

---

## Screenshots

<p align="center">
  <img src="https://github.com/user-attachments/assets/d80f7370-2302-4033-a0fa-0759792e858a" width="85%" />
  <br />
  <em>The main player interface with a clean, modern design.</em>
</p>

<p align="center">
  <img src="https://github.com/user-attachments/assets/ac2c77c4-1518-4551-b06c-f5b393812fdc" width="42%" />
  <img src="https://github.com/user-attachments/assets/a15b774c-1d04-4e00-983c-2d26bb924208" width="42%" />
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

To enjoy the full experience, you'll need authorization tokens:

### Yandex Music Token
The easiest and safest way to get your token is by using the **yandex-music-token** browser extension:
1. Install the extension for [Chrome/Edge](https://chrome.google.com/webstore/detail/yandex-music-token/lcbjeookjibfhjjopieifgjnhlegmkib) or [Firefox](https://addons.mozilla.org/en-US/firefox/addon/yandex-music-token/).
2. Click the extension icon and log in to your Yandex account.
3. Copy the generated token and paste it into **lizaplayer**.

### SoundCloud Token
To get your SoundCloud OAuth token manually:
1. Log in to [soundcloud.com](https://soundcloud.com).
2. Press `F12` to open **Developer Tools**.
3. Go to the **Network** tab and filter by `api-v2`.
4. Refresh the page and click on any request (e.g., `me`).
5. In the **Headers** tab, find `Authorization`. Your token is the string after `OAuth` (e.g., `2-293451-123456...`).
6. Paste it into **lizaplayer**.

---

## Tech Stack

<p align="left">
  <img src="https://img.shields.io/badge/Riverpod-764ABC?style=flat-square&logo=redux&logoColor=white" alt="Riverpod" />
  <img src="https://img.shields.io/badge/Just%20Audio-0175C2?style=flat-square&logo=dart&logoColor=white" alt="Just Audio" />
  <img src="https://img.shields.io/badge/Media%20Kit-00599C?style=flat-square&logo=cplusplus&logoColor=white" alt="Media Kit" />
  <img src="https://img.shields.io/badge/Material%203-757575?style=flat-square&logo=materialdesign&logoColor=white" alt="Material 3" />
  <img src="https://img.shields.io/badge/Discord%20RPC-5865F2?style=flat-square&logo=discord&logoColor=white" alt="Discord RPC" />
</p>

- **State Management**: [Riverpod](https://riverpod.dev)
- **Audio Engine**: [just_audio](https://pub.dev/packages/just_audio) & [media_kit](https://pub.dev/packages/media_kit)
- **Networking**: [http](https://pub.dev/packages/http), [dio](https://pub.dev/packages/dio) & [yandex_music](https://pub.dev/packages/yandex_music)
- **UI Components**: [Font Awesome](https://fontawesome.com), [Flutter SVG](https://pub.dev/packages/flutter_svg), [Cached Network Image](https://pub.dev/packages/cached_network_image)
- **System Integration**: [window_manager](https://pub.dev/packages/window_manager), [tray_manager](https://pub.dev/packages/tray_manager), [dart_discord_presence](https://pub.dev/packages/dart_discord_presence)

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
  Developed with ❤️ by <a href="https://github.com/lizapropanol">lizapropanol</a> © 2026
</p>
