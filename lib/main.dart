import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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

final fontFamilyProvider = StateProvider<String?>((ref) => null);
final customFontPathProvider = StateProvider<String?>((ref) => null);
final fontWeightProvider = StateProvider<int>((ref) => 4);
final letterSpacingProvider = StateProvider<double>((ref) => 0.0);

final customTitleBarEnabledProvider = StateProvider<bool>((ref) => true);
final titleBarHeightProvider = StateProvider<double>((ref) => 40.0);
final titleBarColorProvider = StateProvider<Color?>((ref) => null);
final titleBarOpacityProvider = StateProvider<double>((ref) => 1.0);
final titleBarShowTitleProvider = StateProvider<bool>((ref) => true);
final titleBarButtonStyleProvider = StateProvider<String>((ref) => 'windows');
final syncYandexLikesProvider = StateProvider<bool>((ref) => false);

LizaplayerMprisService? mprisService;
final appKeyProvider = StateProvider<Key>((ref) => UniqueKey());

Future<void> loadCustomFont(String path) async {
  try {
    final file = File(path);
    if (await file.exists()) {
      final fontData = await file.readAsBytes();
      final fontLoader = FontLoader('CustomFont');
      fontLoader.addFont(Future.value(fontData.buffer.asByteData()));
      await fontLoader.load();
    }
  } catch (e) {}
}

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

  final savedFontFamily = await TokenStorage.getFontFamily();
  final savedCustomFontPath = await TokenStorage.getCustomFontPath();
  final savedFontWeight = await TokenStorage.getFontWeight();
  final savedLetterSpacing = await TokenStorage.getLetterSpacing();

  if (savedCustomFontPath != null) {
    await loadCustomFont(savedCustomFontPath);
  }

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
      fontFamilyProvider.overrideWith((ref) => savedFontFamily),
      customFontPathProvider.overrideWith((ref) => savedCustomFontPath),
      fontWeightProvider.overrideWith((ref) => savedFontWeight),
      letterSpacingProvider.overrideWith((ref) => savedLetterSpacing),
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
    final fontFamily = ref.watch(fontFamilyProvider);
    final fontWeightIndex = ref.watch(fontWeightProvider);
    final letterSpacing = ref.watch(letterSpacingProvider);

    final weights = [
      FontWeight.w100,
      FontWeight.w200,
      FontWeight.w300,
      FontWeight.w400,
      FontWeight.w500,
      FontWeight.w600,
      FontWeight.w700,
      FontWeight.w800,
      FontWeight.w900,
    ];
    final fontWeight = weights[fontWeightIndex.clamp(0, 8)];

    final customStyle = TextStyle(
      fontFamily: fontFamily,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
    );

    TextTheme createTextTheme(TextTheme base) {
      return base.copyWith(
        displayLarge: (base.displayLarge ?? const TextStyle()).merge(customStyle),
        displayMedium: (base.displayMedium ?? const TextStyle()).merge(customStyle),
        displaySmall: (base.displaySmall ?? const TextStyle()).merge(customStyle),
        headlineLarge: (base.headlineLarge ?? const TextStyle()).merge(customStyle),
        headlineMedium: (base.headlineMedium ?? const TextStyle()).merge(customStyle),
        headlineSmall: (base.headlineSmall ?? const TextStyle()).merge(customStyle),
        titleLarge: (base.titleLarge ?? const TextStyle()).merge(customStyle),
        titleMedium: (base.titleMedium ?? const TextStyle()).merge(customStyle),
        titleSmall: (base.titleSmall ?? const TextStyle()).merge(customStyle),
        bodyLarge: (base.bodyLarge ?? const TextStyle()).merge(customStyle),
        bodyMedium: (base.bodyMedium ?? const TextStyle()).merge(customStyle),
        bodySmall: (base.bodySmall ?? const TextStyle()).merge(customStyle),
        labelLarge: (base.labelLarge ?? const TextStyle()).merge(customStyle),
        labelMedium: (base.labelMedium ?? const TextStyle()).merge(customStyle),
        labelSmall: (base.labelSmall ?? const TextStyle()).merge(customStyle),
      );
    }

    final typography = Typography.material2021(platform: defaultTargetPlatform);

    ThemeData buildTheme(Brightness brightness) {
      final isDark = brightness == Brightness.dark;
      final tTheme = createTextTheme(isDark ? typography.white : typography.black);
      return ThemeData(
        useMaterial3: true,
        brightness: brightness,
        colorScheme: isDark ? ColorScheme.dark(primary: accentColor) : ColorScheme.light(primary: accentColor),
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamily != null ? [fontFamily] : null,
        textTheme: tTheme,
        primaryTextTheme: tTheme,
        typography: typography,
        tabBarTheme: TabBarThemeData(
          labelStyle: const TextStyle().merge(customStyle),
          unselectedLabelStyle: const TextStyle().merge(customStyle),
        ),
      );
    }

    return MaterialApp(
      key: ref.watch(appKeyProvider),
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
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: themeMode,
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return DefaultTextStyle.merge(
          style: customStyle.copyWith(color: isDark ? Colors.white : Colors.black),
          child: child!,
        );
      },
      home: const InitialScreen(),
    );
  }
}

class InitialScreen extends ConsumerStatefulWidget {
  const InitialScreen({super.key});

  @override
  ConsumerState<InitialScreen> createState() => _InitialScreenState();
}

class _InitialScreenState extends ConsumerState<InitialScreen> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadInitialData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: RotatingLogo(size: 140),
            ),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(body: Center(child: Text('Error: ${snapshot.error}')));
        }
        
        final data = snapshot.data!;
        if (data['isFirstRun']) return const AuthScreen();
        return HomeScreen(
          yandexToken: data['yandex'],
          soundcloudClientId: data['soundcloud'],
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

class RotatingLogo extends StatefulWidget {
  final double size;
  const RotatingLogo({super.key, this.size = 120});

  @override
  State<RotatingLogo> createState() => _RotatingLogoState();
}

class _RotatingLogoState extends State<RotatingLogo> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 15))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Image.asset(
        'assets/logo.png',
        width: widget.size,
        height: widget.size,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}
