import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lizaplayer/main.dart';
import 'package:lizaplayer/screens/home_screen.dart';
import 'package:lizaplayer/services/token_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
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
  List<String> _commandHistory = [];
  int _historyIndex = -1;
  
  double _termOpacity = 0.9;
  Color? _termTextColor;
  
  bool _initialized = false;
  Timer? _matrixTimer;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final history = await TokenStorage.getTerminalHistory();
    final opacity = await TokenStorage.getTerminalOpacity();
    final colorVal = await TokenStorage.getTerminalTextColor();
    
    if (mounted) {
      setState(() {
        _commandHistory = history;
        _termOpacity = opacity;
        if (colorVal != null) _termTextColor = Color(colorVal);
      });
    }
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
    
    _codeController.text = '''ui {
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

system {
  title-bar: ${ref.read(customTitleBarEnabledProvider)};
  tray: ${ref.read(minimizeToTrayEnabledProvider)};
  discord: ${ref.read(discordRPCEnabledProvider)};
  sync-likes: ${ref.read(syncYandexLikesProvider)};
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
        _isBusy = false;
        _terminalOutput.add('^C (Process terminated)');
      });
      _scrollToBottom();
    }
  }

  Future<void> _pasteFromClipboard() async {
    if (_isBusy && _tabController.index == 1) return;
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

  void _historyUp() {
    if (_commandHistory.isEmpty || _isBusy) return;
    setState(() {
      _historyIndex++;
      if (_historyIndex >= _commandHistory.length) _historyIndex = _commandHistory.length - 1;
      _commandController.text = _commandHistory[_historyIndex];
      _commandController.selection = TextSelection.fromPosition(TextPosition(offset: _commandController.text.length));
    });
  }

  void _historyDown() {
    if (_isBusy) return;
    setState(() {
      _historyIndex--;
      if (_historyIndex < -1) {
        _historyIndex = -1;
        _commandController.clear();
      } else if (_historyIndex == -1) {
        _commandController.clear();
      } else {
        _commandController.text = _commandHistory[_historyIndex];
        _commandController.selection = TextSelection.fromPosition(TextPosition(offset: _commandController.text.length));
      }
    });
  }

  void _startMatrix() {
    _matrixTimer?.cancel();
    _terminalOutput.add('> Initializing kernel dump...');
    setState(() => _isBusy = true);
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

  Future<void> _exportPrefs() async {
    setState(() => _isBusy = true);
    _terminalOutput.add('> Locating shared preferences...');
    try {
      final appDir = await getApplicationSupportDirectory();
      final prefsFile = File('${appDir.path}/shared_preferences.json');
      
      if (await prefsFile.exists()) {
        String home = Platform.isLinux 
            ? Platform.environment['HOME'] ?? '/home' 
            : Platform.environment['USERPROFILE'] ?? 'C:';
        
        final destPath = '$home/lizaplayer_prefs_backup.json';
        await prefsFile.copy(destPath);
        _terminalOutput.add('Success: File copied to $destPath');
      } else {
        _terminalOutput.add('Error: JSON file not found in ${appDir.path}');
      }
    } catch (e) {
      _terminalOutput.add('Export failed: $e');
    }
    setState(() => _isBusy = false);
    _scrollToBottom();
  }

  void _apply(String block, String key, String val) {
    try {
      final fullKey = block.isEmpty ? key : '$block-$key';
      switch (fullKey) {
        case 'ui-theme':
        case 'theme': ref.read(themeModeProvider.notifier).state = val == 'dark' ? ThemeMode.dark : ThemeMode.light; break;
        case 'ui-accent':
        case 'accent': ref.read(accentColorProvider.notifier).state = _parseColor(val); break;
        case 'ui-glass':
        case 'glass': ref.read(glassEnabledProvider.notifier).state = val == 'true'; break;
        case 'ui-scale':
        case 'scale': ref.read(scaleProvider.notifier).state = double.parse(val); break;
        case 'ui-mode':
        case 'mode': ref.read(uiModeProvider.notifier).state = val; break;
        case 'effects-blur':
        case 'blur': ref.read(blurEnabledProvider.notifier).state = val == 'true'; break;
        case 'effects-cover':
        case 'cover': ref.read(coverEffectProvider.notifier).state = val; break;
        case 'effects-slider':
        case 'slider': ref.read(playerSliderStyleProvider.notifier).state = val; break;
        case 'effects-freeze':
        case 'freeze': ref.read(freezeOptimizationProvider.notifier).state = val == 'true'; break;
        case 'effects-v2-anim':
        case 'v2-anim': ref.read(v2FloatingEnabledProvider.notifier).state = val == 'true'; break;
        case 'border-gradient':
        case 'gradient': ref.read(borderGradientEnabledProvider.notifier).state = val == 'true'; break;
        case 'border-color': ref.read(borderColorProvider.notifier).state = _parseColor(val); break;
        case 'border-speed':
        case 'speed': ref.read(borderAnimationSpeedProvider.notifier).state = double.parse(val); break;
        case 'border-c1':
        case 'c1': ref.read(borderGradientColor1Provider.notifier).state = _parseColor(val); break;
        case 'border-c2':
        case 'c2': ref.read(borderGradientColor2Provider.notifier).state = _parseColor(val); break;
        case 'filters-hue':
        case 'hue': ref.read(hueShiftProvider.notifier).state = double.parse(val); break;
        case 'filters-sat':
        case 'sat': ref.read(saturationProvider.notifier).state = double.parse(val); break;
        case 'filters-con':
        case 'con': ref.read(contrastProvider.notifier).state = double.parse(val); break;
        case 'filters-bri':
        case 'bri': ref.read(brightnessProvider.notifier).state = double.parse(val); break;
        case 'filters-gray':
        case 'gray': ref.read(grayscaleProvider.notifier).state = double.parse(val); break;
        case 'filters-px':
        case 'px': ref.read(pixelationProvider.notifier).state = double.parse(val); break;
        case 'filters-all':
        case 'all': ref.read(applyFilterToAllProvider.notifier).state = val == 'true'; break;
        case 'fonts-family':
        case 'family': ref.read(fontFamilyProvider.notifier).state = val == 'default' ? null : val.replaceAll('"', ''); break;
        case 'fonts-weight':
        case 'weight': ref.read(fontWeightProvider.notifier).state = int.parse(val); break;
        case 'fonts-spacing':
        case 'spacing': ref.read(letterSpacingProvider.notifier).state = double.parse(val); break;
        case 'system-title-bar':
        case 'title-bar': ref.read(customTitleBarEnabledProvider.notifier).state = val == 'true'; break;
        case 'system-tray':
        case 'tray': ref.read(minimizeToTrayEnabledProvider.notifier).state = val == 'true'; break;
        case 'system-discord':
        case 'discord': ref.read(discordRPCEnabledProvider.notifier).state = val == 'true'; break;
        case 'system-sync-likes':
        case 'sync-likes': ref.read(syncYandexLikesProvider.notifier).state = val == 'true'; break;
        case 'rebuild': ref.read(appKeyProvider.notifier).state = UniqueKey(); break;
        case 'term-opacity': 
          if (val == 'default') {
            const o = 0.9;
            setState(() => _termOpacity = o);
            TokenStorage.saveTerminalOpacity(o);
          } else {
            final o = double.parse(val).clamp(0.1, 1.0);
            setState(() => _termOpacity = o);
            TokenStorage.saveTerminalOpacity(o);
          }
          break;
        case 'term-color':
          if (val == 'default') {
            setState(() => _termTextColor = null);
            TokenStorage.resetTerminalTextColor();
          } else {
            final c = _parseColor(val);
            setState(() => _termTextColor = c);
            TokenStorage.saveTerminalTextColor(c.value);
          }
          break;
        default: _terminalOutput.add('? Ignored: $fullKey');
      }
    } catch (e) {
      _terminalOutput.add('! Error: $block-$key=$val ($e)');
    }
  }

  void _runCss() {
    if (_isBusy) return;
    final code = _codeController.text;
    if (code.trim().isEmpty) return;
    setState(() => _terminalOutput.add('> Applying Stylesheet...'));
    try {
      String cleanCode = code.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
      final blockRegex = RegExp(r'([a-zA-Z0-9-]+)\s*\{\s*([^}]+)\s*\}');
      final matches = blockRegex.allMatches(cleanCode);
      for (final match in matches) {
        final blockName = match.group(1)?.trim().toLowerCase() ?? '';
        final propsStr = match.group(2)?.trim();
        if (propsStr != null) {
          for (final prop in propsStr.split(';')) {
            if (prop.trim().isEmpty) continue;
            final parts = prop.split(':');
            if (parts.length >= 2) _apply(blockName, parts[0].trim().toLowerCase(), parts.sublist(1).join(':').trim());
          }
        }
      }
      _terminalOutput.add('Success.');
    } catch (e) { _terminalOutput.add('Critical Error: $e'); }
    setState(() {});
    _scrollToBottom();
  }

  void _handleCommand(String input) {
    final raw = input.trim();
    if (raw.isEmpty) return;
    final cmd = raw.toLowerCase();
    if (_isBusy && cmd != 'stop') {
      _commandController.clear();
      return;
    }
    setState(() {
      _terminalOutput.add('> $raw');
      if (_commandHistory.isEmpty || _commandHistory.first != raw) {
        _commandHistory.insert(0, raw);
        TokenStorage.saveTerminalHistory(_commandHistory);
      }
      _historyIndex = -1;
    });
    _commandController.clear();
    if (cmd == 'help') {
      _terminalOutput.add('--- MASTER COMMAND LIST ---');
      _terminalOutput.add('General: sync, clear, rebuild, matrix, stop, export-prefs');
      _terminalOutput.add('Terminal: term-opacity, term-color');
      _terminalOutput.add('UI: theme, accent, glass, scale, mode');
      _terminalOutput.add('FX: blur, cover, slider, freeze, v2-anim');
      _terminalOutput.add('BORDER: gradient, color, speed, c1, c2');
      _terminalOutput.add('FILTERS: hue, sat, con, bri, gray, px, all');
      _terminalOutput.add('FONTS: family, weight, spacing');
      _terminalOutput.add('SYS: title-bar, tray, discord, sync-likes');
    } else if (cmd == 'sync') {
      _generateCurrentCss();
      _terminalOutput.add('Editor synced.');
    } else if (cmd == 'matrix') {
      _startMatrix();
    } else if (cmd == 'export-prefs') {
      _exportPrefs();
    } else if (cmd == 'stop') {
      _stopProcess();
    } else if (cmd == 'clear') {
      _terminalOutput.clear();
      _stopProcess();
    } else if (cmd.contains('=')) {
      final parts = raw.split('=');
      final keyParts = parts[0].trim().split('-');
      if (keyParts.length > 1) {
        _apply(keyParts[0], keyParts.sublist(1).join('-'), parts[1].trim());
      } else {
        _apply('', parts[0].trim().toLowerCase(), parts[1].trim());
      }
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
    final shellTextColor = _termTextColor ?? (widget.isDark ? Colors.greenAccent : Colors.green[800]);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyC, control: true): _stopProcess,
        const SingleActivator(LogicalKeyboardKey.keyV, control: true, shift: true): _pasteFromClipboard,
      },
      child: Container(
        height: 600 * widget.scale,
        decoration: BoxDecoration(
          color: (widget.isDark ? Colors.black : Colors.white).withOpacity(_termOpacity),
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
              tabs: const [Tab(text: 'Styles (CSS)'), Tab(text: 'Console (SH)')],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  Stack(
                    children: [
                      Container(
                        color: Colors.transparent,
                        child: TextField(
                          controller: _codeController,
                          focusNode: _codeFocusNode,
                          maxLines: null,
                          expands: true,
                          enabled: !_isBusy,
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
                              color: Colors.transparent,
                              padding: const EdgeInsets.all(12),
                              child: ListView.builder(
                                controller: _scrollController,
                                itemCount: _terminalOutput.length,
                                itemBuilder: (context, index) => Text(
                                  _terminalOutput[index],
                                  style: TextStyle(
                                    fontFamily: 'DejaVu Sans Mono', 
                                    fontFamilyFallback: monoStack,
                                    color: shellTextColor, 
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
                        color: _isBusy 
                            ? (widget.isDark ? Colors.red.withOpacity(0.05) : Colors.red.withOpacity(0.02))
                            : Colors.transparent,
                        child: CallbackShortcuts(
                          bindings: {
                            const SingleActivator(LogicalKeyboardKey.arrowUp): _historyUp,
                            const SingleActivator(LogicalKeyboardKey.arrowDown): _historyDown,
                          },
                          child: TextField(
                            controller: _commandController,
                            focusNode: _commandFocusNode,
                            cursorColor: widget.isDark ? Colors.white : Colors.black,
                            style: TextStyle(
                              fontFamily: 'DejaVu Sans Mono', 
                              fontFamilyFallback: monoStack,
                              color: _isBusy ? Colors.redAccent.withOpacity(0.5) : (widget.isDark ? Colors.white : Colors.black), 
                              fontSize: 15 * widget.scale,
                            ),
                            decoration: InputDecoration(
                              hintText: _isBusy ? '[Busy] Ctrl+C to interrupt' : '>',
                              hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              border: InputBorder.none,
                            ),
                            onSubmitted: _handleCommand,
                          ),
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
