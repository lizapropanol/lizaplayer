import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lizaplayer/main.dart';
import 'package:lizaplayer/screens/home_screen.dart';
import 'dart:async';
import 'dart:math';

class SettingsTerminal extends ConsumerStatefulWidget {
  final double scale;
  final bool isDark;
  final bool glassEnabled;

  const SettingsTerminal({
    super.key,
    required this.scale,
    required this.isDark,
    required this.glassEnabled,
  });

  @override
  ConsumerState<SettingsTerminal> createState() => _SettingsTerminalState();
}

class _SettingsTerminalState extends ConsumerState<SettingsTerminal> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _commandController = TextEditingController();
  final FocusNode _codeFocusNode = FocusNode();
  final FocusNode _commandFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final List<String> _terminalOutput = [];
  bool _initialized = false;
  Timer? _matrixTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _generateCurrentCss();
      _terminalOutput.add('System: Master UI Controller Initialized.');
      _terminalOutput.add('Type "help" for a full list of commands.');
      _initialized = true;
    }
  }

  void _generateCurrentCss() {
    final theme = ref.read(themeModeProvider) == ThemeMode.dark ? 'dark' : 'light';
    final accent = ref.read(accentColorProvider);
    final accentHex = accent.value == 0 ? 'none' : '#${accent.value.toRadixString(16).padLeft(8, '0').substring(2)}';
    
    _codeController.text = '''/* Master Stylesheet */
ui {
  theme: $theme;
  accent: $accentHex;
  glass: ${ref.read(glassEnabledProvider)};
  scale: ${ref.read(scaleProvider).toStringAsFixed(2)};
  mode: ${ref.read(uiModeProvider)};
}

effects {
  blur: ${ref.read(blurEnabledProvider)};
  cover: ${ref.read(coverEffectProvider)};
  slider: ${ref.read(playerSliderStyleProvider)};
  freeze: ${ref.read(freezeOptimizationProvider)};
  v2-anim: ${ref.read(v2FloatingEnabledProvider)};
}

border {
  gradient: ${ref.read(borderGradientEnabledProvider)};
  color: #${(ref.read(borderColorProvider) ?? Colors.white).value.toRadixString(16).padLeft(8, '0').substring(2)};
  speed: ${ref.read(borderAnimationSpeedProvider)};
  c1: #${ref.read(borderGradientColor1Provider).value.toRadixString(16).padLeft(8, '0').substring(2)};
  c2: #${ref.read(borderGradientColor2Provider).value.toRadixString(16).padLeft(8, '0').substring(2)};
}

filters {
  hue: ${ref.read(hueShiftProvider)};
  sat: ${ref.read(saturationProvider)};
  con: ${ref.read(contrastProvider)};
  bri: ${ref.read(brightnessProvider)};
  gray: ${ref.read(grayscaleProvider)};
  px: ${ref.read(pixelationProvider)};
  all: ${ref.read(applyFilterToAllProvider)};
}

fonts {
  family: "${ref.read(fontFamilyProvider) ?? "default"}";
  weight: ${ref.read(fontWeightProvider)};
  spacing: ${ref.read(letterSpacingProvider)};
}

title-bar {
  enabled: ${ref.read(customTitleBarEnabledProvider)};
  height: ${ref.read(titleBarHeightProvider)};
  color: #${(ref.read(titleBarColorProvider) ?? Colors.transparent).value.toRadixString(16).padLeft(8, '0').substring(2)};
  opacity: ${ref.read(titleBarOpacityProvider)};
  style: ${ref.read(titleBarButtonStyleProvider)};
  show-title: ${ref.read(titleBarShowTitleProvider)};
}

system {
  tray: ${ref.read(minimizeToTrayEnabledProvider)};
  discord: ${ref.read(discordRPCEnabledProvider)};
}''';
  }

  @override
  void dispose() {
    _matrixTimer?.cancel();
    _tabController.dispose();
    _codeController.dispose();
    _commandController.dispose();
    _codeFocusNode.dispose();
    _commandFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _stopProcess() {
    if (_matrixTimer?.isActive ?? false) {
      _matrixTimer?.cancel();
      setState(() {
        _terminalOutput.add('^C (Process terminated)');
      });
      _scrollToBottom();
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      final controller = _tabController.index == 0 ? _codeController : _commandController;
      final selection = controller.selection;
      final text = controller.text;
      final newText = text.replaceRange(
        max(0, selection.start),
        max(0, selection.end),
        data!.text!,
      );
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: max(0, selection.start) + data.text!.length),
      );
    }
  }

  void _startMatrix() {
    _matrixTimer?.cancel();
    _terminalOutput.add('> Initializing kernel dump...');
    _matrixTimer = Timer.periodic(const Duration(milliseconds: 20), (timer) {
      final r = Random();
      const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789@#\$%^&*()_+-=[]{}|;:,.<>?';
      final hex = r.nextInt(0xFFFFFFFF).toRadixString(16).padLeft(8, '0').toUpperCase();
      final content = List.generate(15, (_) => chars[r.nextInt(chars.length)]).join('');
      final line = '[0x$hex] SYS_REL_STATE_${r.nextInt(100)} :: DATA_STREAM >> $content';
      
      setState(() {
        _terminalOutput.add(line);
        if (_terminalOutput.length > 500) _terminalOutput.removeAt(0);
      });
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  Color _parseColor(String hex) {
    if (hex == 'transparent' || hex == 'none' || hex == '#000000' || hex == '000000') return Colors.transparent;
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  void _applyStyle(String key, String val) {
    try {
      switch (key) {
        case 'theme': ref.read(themeModeProvider.notifier).state = val == 'dark' ? ThemeMode.dark : ThemeMode.light; break;
        case 'accent': ref.read(accentColorProvider.notifier).state = _parseColor(val); break;
        case 'glass': ref.read(glassEnabledProvider.notifier).state = val == 'true'; break;
        case 'scale': ref.read(scaleProvider.notifier).state = double.parse(val); break;
        case 'mode': ref.read(uiModeProvider.notifier).state = val; break;
        case 'blur': ref.read(blurEnabledProvider.notifier).state = val == 'true'; break;
        case 'cover': ref.read(coverEffectProvider.notifier).state = val; break;
        case 'slider': ref.read(playerSliderStyleProvider.notifier).state = val; break;
        case 'freeze': ref.read(freezeOptimizationProvider.notifier).state = val == 'true'; break;
        case 'v2-anim': ref.read(v2FloatingEnabledProvider.notifier).state = val == 'true'; break;
        case 'gradient': ref.read(borderGradientEnabledProvider.notifier).state = val == 'true'; break;
        case 'border-color': ref.read(borderColorProvider.notifier).state = _parseColor(val); break;
        case 'speed': ref.read(borderAnimationSpeedProvider.notifier).state = double.parse(val); break;
        case 'c1': ref.read(borderGradientColor1Provider.notifier).state = _parseColor(val); break;
        case 'c2': ref.read(borderGradientColor2Provider.notifier).state = _parseColor(val); break;
        case 'hue': ref.read(hueShiftProvider.notifier).state = double.parse(val); break;
        case 'sat': ref.read(saturationProvider.notifier).state = double.parse(val); break;
        case 'con': ref.read(contrastProvider.notifier).state = double.parse(val); break;
        case 'bri': ref.read(brightnessProvider.notifier).state = double.parse(val); break;
        case 'gray': ref.read(grayscaleProvider.notifier).state = double.parse(val); break;
        case 'px': ref.read(pixelationProvider.notifier).state = double.parse(val); break;
        case 'all': ref.read(applyFilterToAllProvider.notifier).state = val == 'true'; break;
        case 'family': ref.read(fontFamilyProvider.notifier).state = val == 'default' ? null : val; break;
        case 'weight': ref.read(fontWeightProvider.notifier).state = int.parse(val); break;
        case 'spacing': ref.read(letterSpacingProvider.notifier).state = double.parse(val); break;
        case 'title-bar-enabled': ref.read(customTitleBarEnabledProvider.notifier).state = val == 'true'; break;
        case 'height': ref.read(titleBarHeightProvider.notifier).state = double.parse(val); break;
        case 'title-color': ref.read(titleBarColorProvider.notifier).state = _parseColor(val); break;
        case 'opacity': ref.read(titleBarOpacityProvider.notifier).state = double.parse(val); break;
        case 'title-style': ref.read(titleBarButtonStyleProvider.notifier).state = val; break;
        case 'show-title': ref.read(titleBarShowTitleProvider.notifier).state = val == 'true'; break;
        case 'tray': ref.read(minimizeToTrayEnabledProvider.notifier).state = val == 'true'; break;
        case 'discord': ref.read(discordRPCEnabledProvider.notifier).state = val == 'true'; break;
        case 'rebuild': ref.read(appKeyProvider.notifier).state = UniqueKey(); break;
        default: _terminalOutput.add('? Ignored: $key');
      }
    } catch (e) {
      _terminalOutput.add('! Error: $key=$val ($e)');
    }
  }

  void _runCss() {
    final code = _codeController.text;
    if (code.trim().isEmpty) return;
    setState(() => _terminalOutput.add('> Applying Stylesheet...'));
    try {
      String cleanCode = code.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
      final blockRegex = RegExp(r'([^{]+)\s*\{\s*([^}]+)\s*\}');
      final matches = blockRegex.allMatches(cleanCode);
      for (final match in matches) {
        final props = match.group(2)?.trim();
        if (props != null) {
          for (final prop in props.split(';')) {
            if (prop.trim().isEmpty) continue;
            final parts = prop.split(':');
            if (parts.length >= 2) _applyStyle(parts[0].trim(), parts.sublist(1).join(':').trim());
          }
        }
      }
      _terminalOutput.add('Success.');
    } catch (e) { _terminalOutput.add('Critical Error: $e'); }
    setState(() {});
    _scrollToBottom();
  }

  void _handleCommand(String input) {
    if (input.trim().isEmpty) return;
    setState(() => _terminalOutput.add('> $input'));
    final cmd = input.trim().toLowerCase();
    _commandController.clear();
    
    if (cmd == 'help') {
      _terminalOutput.add('--- MASTER COMMAND LIST ---');
      _terminalOutput.add('General: sync, clear, rebuild, matrix, stop');
      _terminalOutput.add('UI: theme (dark|light), accent (hex|none), glass (bool), scale (0.5-2.0), mode (v1|v2)');
      _terminalOutput.add('FX: blur (bool), cover (none|blood|slime), slider (wavy|dashed|dots|standard), freeze (bool), v2-anim (bool)');
      _terminalOutput.add('BORDER: gradient (bool), border-color (hex), speed (0.1-5.0), c1 (hex), c2 (hex)');
      _terminalOutput.add('FILTERS: hue, sat, con, bri, gray, px (0.0-2.0), all (bool)');
      _terminalOutput.add('FONTS: family (name|default), weight (1-9), spacing (num)');
      _terminalOutput.add('TITLE: title-bar-enabled (bool), height (20-100), title-color (hex), opacity (0.0-1.0), title-style (windows|macos), show-title (bool)');
      _terminalOutput.add('SYS: tray (bool), discord (bool)');
    } else if (cmd == 'sync') {
      _generateCurrentCss();
      _terminalOutput.add('Editor synced.');
    } else if (cmd == 'matrix') {
      _startMatrix();
    } else if (cmd == 'stop') {
      _matrixTimer?.cancel();
      _terminalOutput.add('Process terminated.');
    } else if (cmd == 'clear') {
      _terminalOutput.clear();
      _matrixTimer?.cancel();
    } else if (cmd.contains('=')) {
      final parts = cmd.split('=');
      _applyStyle(parts[0].trim(), parts[1].trim());
    } else { _terminalOutput.add('Unknown command.'); }
    setState(() {});
    _scrollToBottom();
    _commandFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final effectiveAccent = primary.value == 0 ? Colors.grey : primary;
    final monoStack = const ['DejaVu Sans Mono', 'Ubuntu Mono', 'Liberation Mono', 'monospace'];
    
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyC, control: true): _stopProcess,
        const SingleActivator(LogicalKeyboardKey.keyV, control: true, shift: true): _pasteFromClipboard,
      },
      child: Container(
        height: 600 * widget.scale,
        decoration: BoxDecoration(
          color: widget.isDark ? Colors.black : Colors.white,
          border: Border.all(color: widget.isDark ? Colors.white24 : Colors.black26, width: 1),
        ),
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              dividerColor: widget.isDark ? Colors.white12 : Colors.black12,
              indicatorColor: effectiveAccent,
              indicatorWeight: 1,
              labelColor: widget.isDark ? Colors.white : Colors.black,
              unselectedLabelColor: Colors.grey,
              labelStyle: TextStyle(fontFamily: 'DejaVu Sans Mono', fontSize: 13 * widget.scale, fontWeight: FontWeight.bold),
              tabs: const [Tab(text: 'STYLES'), Tab(text: 'SHELL')],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // CSS
                  Stack(
                    children: [
                      Container(
                        color: widget.isDark ? const Color(0xFF050505) : const Color(0xFFFAFAFA),
                        child: TextField(
                          controller: _codeController,
                          focusNode: _codeFocusNode,
                          maxLines: null,
                          expands: true,
                          cursorColor: widget.isDark ? Colors.white : Colors.black,
                          style: TextStyle(
                            fontFamily: 'DejaVu Sans Mono', 
                            fontFamilyFallback: monoStack,
                            color: effectiveAccent.value == 0 ? (widget.isDark ? Colors.white70 : Colors.black87) : effectiveAccent, 
                            fontSize: 15 * widget.scale,
                            letterSpacing: -0.5,
                          ),
                          decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.all(16)),
                        ),
                      ),
                      Positioned(
                        right: 16 * widget.scale,
                        bottom: 16 * widget.scale,
                        child: GestureDetector(
                          onTap: _runCss,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 20 * widget.scale, vertical: 10 * widget.scale),
                            decoration: BoxDecoration(
                              color: effectiveAccent.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12 * widget.scale),
                              border: Border.all(color: effectiveAccent.withOpacity(0.2)),
                            ),
                            child: Text(
                              'APPLY',
                              style: TextStyle(
                                color: effectiveAccent.withOpacity(0.6),
                                fontWeight: FontWeight.bold,
                                fontSize: 13 * widget.scale,
                                fontFamily: 'DejaVu Sans Mono',
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // SHELL
                  Column(
                    children: [
                      Expanded(
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            textSelectionTheme: TextSelectionThemeData(
                              selectionColor: effectiveAccent.withOpacity(0.4),
                            ),
                          ),
                          child: SelectionArea(
                            child: Container(
                              width: double.infinity,
                              color: widget.isDark ? Colors.black : Colors.white,
                              padding: const EdgeInsets.all(12),
                              child: ListView.builder(
                                controller: _scrollController,
                                itemCount: _terminalOutput.length,
                                itemBuilder: (context, index) => Text(
                                  _terminalOutput[index],
                                  style: TextStyle(
                                    fontFamily: 'DejaVu Sans Mono', 
                                    fontFamilyFallback: monoStack,
                                    color: widget.isDark ? Colors.greenAccent : Colors.green[800], 
                                    fontSize: 15 * widget.scale,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        height: 1,
                        color: widget.isDark ? Colors.white24 : Colors.black26,
                      ),
                      Container(
                        color: widget.isDark ? const Color(0xFF050505) : const Color(0xFFFAFAFA),
                        child: TextField(
                          controller: _commandController,
                          focusNode: _commandFocusNode,
                          cursorColor: widget.isDark ? Colors.white : Colors.black,
                          style: TextStyle(
                            fontFamily: 'DejaVu Sans Mono', 
                            fontFamilyFallback: monoStack,
                            color: widget.isDark ? Colors.white : Colors.black, 
                            fontSize: 15 * widget.scale,
                          ),
                          decoration: InputDecoration(
                            hintText: '>',
                            hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            border: InputBorder.none,
                          ),
                          onSubmitted: _handleCommand,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
