import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:lizaplayer/main.dart';
import 'package:lizaplayer/l10n/app_localizations.dart';
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

class CustomTitleBar extends ConsumerWidget {
  final bool isFullScreen;
  const CustomTitleBar({super.key, this.isFullScreen = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isFullScreen) return const SizedBox.shrink();
    
    final isEnabled = ref.watch(customTitleBarEnabledProvider);
    if (!isEnabled) return const SizedBox.shrink();

    final showTitle = true;
    final buttonStyle = _getSystemButtonStyle();
    final glassEnabled = ref.watch(glassEnabledProvider);
    final accentColor = ref.watch(accentColorProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      type: MaterialType.transparency,
      child: SizedBox(
        height: 30.0,
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: glassEnabled ? 15 : 0, sigmaY: glassEnabled ? 15 : 0),
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
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: (isDark ? Colors.white : Colors.black).withOpacity(0.7),
                                letterSpacing: 0.5,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                _buildWindowButtons(context, buttonStyle, isDark, accentColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWindowButtons(BuildContext context, String style, bool isDark, Color accentColor) {
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

    final iconColor = isDark ? Colors.white70 : Colors.black87;

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
