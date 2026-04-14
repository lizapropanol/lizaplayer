import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:lizaplayer/main.dart';
import 'package:lizaplayer/l10n/app_localizations.dart';
import 'package:lizaplayer/services/updater_service.dart';
import 'dart:ui';
import 'dart:io';

String _getSystemButtonStyle() {
  if (Platform.isWindows) return 'windows';
  if (Platform.isMacOS) return 'macos';
  if (Platform.isLinux) {
    final desktop = Platform.environment['XDG_CURRENT_DESKTOP']?.toLowerCase() ?? '';
    final session = Platform.environment['DESKTOP_SESSION']?.toLowerCase() ?? '';
    final knownDEs = ['gnome', 'kde', 'xfce', 'cinnamon', 'mate', 'lxde', 'lxqt', 'pantheon', 'deepin', 'unity'];
    final isDE = knownDEs.any((de) => desktop.contains(de) || session.contains(de));
    if (isDE) {
      return 'windows';
    } else {
      return 'none';
    }
  }
  return 'windows';
}

class CustomTitleBar extends ConsumerStatefulWidget {
  final bool isFullScreen;
  const CustomTitleBar({super.key, this.isFullScreen = false});

  @override
  ConsumerState<CustomTitleBar> createState() => _CustomTitleBarState();
}

class _CustomTitleBarState extends ConsumerState<CustomTitleBar> {
  bool _showUpdater = false;

  TextStyle s(TextStyle style) {
    final fontFamily = ref.watch(fontFamilyProvider);
    final fontWeightIndex = ref.watch(fontWeightProvider);
    final letterSpacing = ref.watch(letterSpacingProvider);
    final weights = [FontWeight.w100, FontWeight.w200, FontWeight.w300, FontWeight.w400, FontWeight.w500, FontWeight.w600, FontWeight.w700, FontWeight.w800, FontWeight.w900];
    final targetFontFamily = fontFamily ?? Theme.of(context).textTheme.bodyLarge?.fontFamily;
    return style.merge(TextStyle(
      fontFamily: targetFontFamily,
      fontWeight: weights[fontWeightIndex.clamp(0, 8)],
      letterSpacing: letterSpacing,
    ));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(updaterServiceProvider).checkForUpdates();
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() {
            _showUpdater = true;
          });
        }
      });
    });
  }

  Widget _buildUpdaterWidget(BuildContext context, bool isDark, Color accentColor, bool glassEnabled, bool isFrozen, AppLocalizations loc) {
    final updateVersion = ref.watch(updateAvailableProvider);
    final bool hasUpdate = updateVersion != null;

    final status = ref.watch(updateStatusProvider);
    final progress = ref.watch(updateProgressProvider);

    String statusText;
    if (status == 'Ready to restart') {
      statusText = loc.restartToUpdate;
    } else if (status == 'Downloading...') {
      statusText = loc.downloading;
    } else if (status == 'Extracting...') {
      statusText = loc.extracting;
    } else if (status == 'Installing...') {
      statusText = loc.installing;
    } else if (status == 'Error updating') {
      statusText = loc.errorUpdating;
    } else if (status == 'No compatible release found') {
      statusText = loc.noCompatibleRelease;
    } else {
      statusText = loc.updateAvailable(updateVersion ?? '');
    }

    return AnimatedSlide(
      offset: (_showUpdater && hasUpdate) ? Offset.zero : const Offset(0, -2.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: (_showUpdater && hasUpdate) ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 600),
        child: GestureDetector(
          onTap: () {
            if (status == null) {
              ref.read(updaterServiceProvider).downloadAndInstallUpdate();
            } else if (status == 'Ready to restart') {
              ref.read(updaterServiceProvider).restartApp();
            }
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 22,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: !glassEnabled ? Colors.black : (isFrozen ? Colors.transparent : (isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05))),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (!glassEnabled || isFrozen) ? Colors.transparent : accentColor.withOpacity(0.5),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    statusText,
                    style: s(TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: (!glassEnabled || isDark) ? Colors.white70 : Colors.black87,
                    )),
                  ),
                  if (progress != null) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 40,
                      height: 4,
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: (!glassEnabled || isDark) ? Colors.white12 : Colors.black12,
                        color: accentColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: s(TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      )),
                    ),
                  ]
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isFullScreen) return const SizedBox.shrink();
    
    final isEnabled = ref.watch(customTitleBarEnabledProvider);
    if (!isEnabled) return const SizedBox.shrink();

    final showTitle = true;
    final buttonStyle = _getSystemButtonStyle();
    final glassEnabled = ref.watch(glassEnabledProvider);
    final accentColor = ref.watch(accentColorProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFrozen = ref.watch(isFrozenProvider);
    final loc = AppLocalizations.of(context)!;

    final isNone = accentColor.value == 0;
    Color glassColor;
    if (isNone) {
      glassColor = isDark ? Colors.transparent : Colors.white.withOpacity(0.6);
    } else {
      final baseGlass = isDark ? Colors.transparent : Colors.white.withOpacity(0.5);
      glassColor = Color.alphaBlend(accentColor.withOpacity(isDark ? 0.12 : 0.18), baseGlass);
    }

    return Material(
      type: MaterialType.transparency,
      child: SizedBox(
        height: 30.0,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(end: (glassEnabled && !isFrozen) ? 15.0 : 0.0),
          duration: const Duration(milliseconds: 300),
          builder: (context, blurValue, child) {
            return ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blurValue, sigmaY: blurValue),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  color: !glassEnabled ? Colors.black : glassColor,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Row(
                          children: [
                            Expanded(
                              child: DragToMoveArea(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Row(
                                    children: [
                                      if (showTitle)
                                        Text(
                                          'lizaplayer',
                                          style: s(TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: (!glassEnabled || isDark) ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.7),
                                            letterSpacing: 0.5,
                                          )),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            _buildWindowButtons(context, buttonStyle, isDark, accentColor, !glassEnabled),
                          ],
                        ),
                      ),
                      Center(
                        child: IgnorePointer(
                          ignoring: false,
                          child: _buildUpdaterWidget(context, isDark, accentColor, glassEnabled, isFrozen, loc),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildWindowButtons(BuildContext context, String style, bool isDark, Color accentColor, bool forceDarkStyle) {
    if (style == 'none') {
      return const SizedBox.shrink();
    }
    if (style == 'macos') {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            _macButton(const Color(0xFFFF5F57), windowManager.close),
            const SizedBox(width: 8),
            _macButton(const Color(0xFFFFBD2E), windowManager.minimize),
            const SizedBox(width: 8),
            _macButton(const Color(0xFF28C840), windowManager.maximize),
          ],
        ),
      );
    }

    final iconColor = (isDark || forceDarkStyle) ? Colors.white70 : Colors.black87;

    return Row(
      children: [
        _windowButton(
          Icons.remove_rounded,
          iconColor,
          windowManager.minimize,
          hoverColor: Colors.black12,
        ),
        _windowButton(
          Icons.crop_square_rounded,
          iconColor,
          () async {
            if (await windowManager.isMaximized()) {
              windowManager.unmaximize();
            } else {
              windowManager.maximize();
            }
          },
          hoverColor: Colors.black12,
        ),
        _windowButton(
          Icons.close_rounded,
          iconColor,
          windowManager.close,
          hoverColor: Colors.red.withOpacity(0.8),
          hoverIconColor: Colors.white,
        ),
      ],
    );
  }

  Widget _macButton(Color color, VoidCallback onPressed) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 1,
                offset: const Offset(0, 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _windowButton(IconData icon, Color color, VoidCallback onPressed, {Color? hoverColor, Color? hoverIconColor}) {
    return WindowButton(
      icon: icon,
      color: color,
      onPressed: onPressed,
      hoverColor: hoverColor,
      hoverIconColor: hoverIconColor,
    );
  }
}

class WindowButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final Color? hoverColor;
  final Color? hoverIconColor;

  const WindowButton({
    super.key,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.hoverColor,
    this.hoverIconColor,
  });

  @override
  State<WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<WindowButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 46,
          height: double.infinity,
          color: _isHovered ? (widget.hoverColor ?? Colors.black12) : Colors.transparent,
          child: Icon(
            widget.icon,
            size: 16,
            color: _isHovered && widget.hoverIconColor != null ? widget.hoverIconColor : widget.color,
          ),
        ),
      ),
    );
  }
}
