import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:media_kit/media_kit.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:lizaplayer/l10n/app_localizations.dart';
import 'package:lizaplayer/screens/auth_screen.dart';
import 'package:lizaplayer/screens/home_screen.dart';
import 'package:lizaplayer/services/token_storage.dart';
import 'package:lizaplayer/services/player_service.dart';
import 'package:lizaplayer/services/mpris_service.dart';
import 'dart:io';
import 'dart:ui';

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);
final accentColorProvider = StateProvider<Color>((ref) => Colors.transparent);
final localeProvider = StateProvider<Locale>((ref) => const Locale('en'));
final glassEnabledProvider = StateProvider<bool>((ref) => true);
final freezeOptimizationProvider = StateProvider<bool>((ref) => false);
final isFrozenProvider = StateProvider<bool>((ref) => false);
final borderColorProvider = StateProvider<Color?>((ref) => null);
final borderGradientEnabledProvider = StateProvider<bool>((ref) => false);
final borderAnimationSpeedProvider = StateProvider<double>((ref) => 1.0);
final borderGradientColor1Provider = StateProvider<Color>((ref) => Colors.cyanAccent);
final borderGradientColor2Provider = StateProvider<Color>((ref) => Colors.purpleAccent);
final playerSliderStyleProvider = StateProvider<String>((ref) => 'standard');

final customTitleBarEnabledProvider = StateProvider<bool>((ref) => true);
final titleBarHeightProvider = StateProvider<double>((ref) => 40.0);
final titleBarColorProvider = StateProvider<Color?>((ref) => null);
final titleBarOpacityProvider = StateProvider<double>((ref) => 1.0);
final titleBarShowTitleProvider = StateProvider<bool>((ref) => true);
final titleBarButtonStyleProvider = StateProvider<String>((ref) => 'windows');
final syncYandexLikesProvider = StateProvider<bool>((ref) => false);

LizaplayerMprisService? mprisService;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  JustAudioMediaKit.title = '';

  final playerService = PlayerService();
  mprisService = LizaplayerMprisService(playerService);
  await mprisService!.init();

  final savedTheme = await TokenStorage.getThemeMode();
  final savedColorValue = await TokenStorage.getAccentColor();
  final savedLang = await TokenStorage.getLanguage();
  final savedGlassEnabled = await TokenStorage.getGlassEnabled() ?? false;
  final savedFreezeOptimization = await TokenStorage.getFreezeOptimization();
  
  final savedBorderColor = await TokenStorage.getBorderColor();
  final savedGradientEnabled = await TokenStorage.getBorderGradientEnabled();
  final savedBorderSpeed = await TokenStorage.getBorderAnimationSpeed();
  final savedGradientColor1 = await TokenStorage.getBorderGradientColor1();
  final savedGradientColor2 = await TokenStorage.getBorderGradientColor2();
  final savedPlayerSliderStyle = await TokenStorage.getPlayerSliderStyle();

  final savedTitleBarEnabled = await TokenStorage.getCustomTitleBarEnabled();
  final savedTitleBarHeight = await TokenStorage.getTitleBarHeight();
  final savedTitleBarColor = await TokenStorage.getTitleBarColor();
  final savedTitleBarOpacity = await TokenStorage.getTitleBarOpacity();
  final savedTitleBarShowTitle = await TokenStorage.getTitleBarShowTitle();
  final savedTitleBarButtonStyle = await TokenStorage.getTitleBarButtonStyle();
  final savedSyncYandexLikes = await TokenStorage.getSyncYandexLikes();

  final initialLocale = savedLang == 'ru' ? const Locale('ru') : const Locale('en');

  await windowManager.ensureInitialized();

  final windowOptions = WindowOptions(
    size: const Size(1280, 867),
    center: true,
    backgroundColor: Colors.transparent,
    titleBarStyle: savedTitleBarEnabled ? TitleBarStyle.hidden : TitleBarStyle.normal,
    skipTaskbar: false,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setMinimumSize(const Size(828, 867));
    await windowManager.setResizable(true);
    await windowManager.setHasShadow(true);
    await windowManager.show();
    await windowManager.focus();
    await windowManager.setTitle('lizaplayer');
  });

  runApp(ProviderScope(
    overrides: [
      themeModeProvider.overrideWith((ref) => savedTheme),
      accentColorProvider.overrideWith((ref) => Color(savedColorValue)),
      localeProvider.overrideWith((ref) => initialLocale),
      glassEnabledProvider.overrideWith((ref) => savedGlassEnabled),
      freezeOptimizationProvider.overrideWith((ref) => savedFreezeOptimization),
      if (savedBorderColor != null && savedBorderColor != 0) borderColorProvider.overrideWith((ref) => Color(savedBorderColor)),
      borderGradientEnabledProvider.overrideWith((ref) => savedGradientEnabled),
      borderAnimationSpeedProvider.overrideWith((ref) => savedBorderSpeed),
      if (savedGradientColor1 != null) borderGradientColor1Provider.overrideWith((ref) => Color(savedGradientColor1)),
      if (savedGradientColor2 != null) borderGradientColor2Provider.overrideWith((ref) => Color(savedGradientColor2)),
      playerSliderStyleProvider.overrideWith((ref) => savedPlayerSliderStyle),
      customTitleBarEnabledProvider.overrideWith((ref) => savedTitleBarEnabled),
      titleBarHeightProvider.overrideWith((ref) => savedTitleBarHeight),
      if (savedTitleBarColor != null) titleBarColorProvider.overrideWith((ref) => Color(savedTitleBarColor)),
      titleBarOpacityProvider.overrideWith((ref) => savedTitleBarOpacity),
      titleBarShowTitleProvider.overrideWith((ref) => savedTitleBarShowTitle),
      titleBarButtonStyleProvider.overrideWith((ref) => savedTitleBarButtonStyle),
      syncYandexLikesProvider.overrideWith((ref) => savedSyncYandexLikes),
    ],
    child: const MyApp(),
  ));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final accentColor = ref.watch(accentColorProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp(
      title: 'lizaplayer',
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('ru')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData.light(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.light(primary: accentColor),
      ),
      darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.dark(primary: accentColor),
      ),
      themeMode: themeMode,
      home: const InitialScreen(),
    );
  }
}

class InitialScreen extends ConsumerWidget {
  const InitialScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadInitialData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/logo.png',
                    width: 120,
                    height: 120,
                    filterQuality: FilterQuality.high,
                  ),
                  const SizedBox(height: 32),
                  const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ],
              ),
            ),
          );
        }
        final data = snapshot.data ?? {};
        final yandexToken = data['yandex'];
        final scClientId = data['soundcloud'];
        final isFirstRun = data['isFirstRun'] ?? true;

        if (isFirstRun) {
             return const AuthScreen();
        }

        return HomeScreen(
           yandexToken: yandexToken,
           soundcloudClientId: scClientId,
        );
      },
    );
  }

  Future<Map<String, dynamic>> _loadInitialData() async {
    final yToken = await TokenStorage.getYandexToken();
    final scId = await TokenStorage.getSoundcloudClientId();
    final isFirstRun = await TokenStorage.isFirstRun();
    return {
      'yandex': yToken,
      'soundcloud': scId,
      'isFirstRun': isFirstRun,
    };
  }
}
