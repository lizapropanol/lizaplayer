import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lizaplayer/main.dart';
import 'package:lizaplayer/screens/home_screen.dart';

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
  final List<String> _terminalOutput = [];
  bool _initialized = false;

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
      _terminalOutput.add('System: Full UI Control Active.');
      _initialized = true;
    }
  }

  void _generateCurrentCss() {
    final theme = ref.read(themeModeProvider) == ThemeMode.dark ? 'dark' : 'light';
    final accent = ref.read(accentColorProvider);
    final accentHex = '#${accent.value.toRadixString(16).padLeft(8, '0').substring(2)}';
    
    _codeController.text = '''/* LizaPlayer Master Stylesheet */
ui {
  theme: $theme;
  accent-color: $accentHex;
  glass: ${ref.read(glassEnabledProvider)};
  scale: ${ref.read(scaleProvider).toStringAsFixed(2)};
  ui-mode: ${ref.read(uiModeProvider)};
}

effects {
  blur: ${ref.read(blurEnabledProvider)};
  cover-effect: ${ref.read(coverEffectProvider)};
  slider-style: ${ref.read(playerSliderStyleProvider)};
  optimization: ${ref.read(freezeOptimizationProvider)};
}

border {
  gradient: ${ref.read(borderGradientEnabledProvider)};
  color: #${(ref.read(borderColorProvider) ?? Colors.white).value.toRadixString(16).padLeft(8, '0').substring(2)};
  speed: ${ref.read(borderAnimationSpeedProvider)};
  color1: #${ref.read(borderGradientColor1Provider).value.toRadixString(16).padLeft(8, '0').substring(2)};
  color2: #${ref.read(borderGradientColor2Provider).value.toRadixString(16).padLeft(8, '0').substring(2)};
}

filters {
  hue: ${ref.read(hueShiftProvider)};
  saturation: ${ref.read(saturationProvider)};
  contrast: ${ref.read(contrastProvider)};
  brightness: ${ref.read(brightnessProvider)};
  grayscale: ${ref.read(grayscaleProvider)};
  pixelation: ${ref.read(pixelationProvider)};
}

title-bar {
  enabled: ${ref.read(customTitleBarEnabledProvider)};
  height: ${ref.read(titleBarHeightProvider)};
  opacity: ${ref.read(titleBarOpacityProvider)};
}''';
  }

  @override
  void dispose() {
    _tabController.dispose();
    _codeController.dispose();
    _commandController.dispose();
    _codeFocusNode.dispose();
    _commandFocusNode.dispose();
    super.dispose();
  }

  Color _parseColor(String hex) {
    if (hex == 'transparent' || hex == 'none') return Colors.transparent;
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  void _applyStyle(String key, String val) {
    try {
      switch (key) {
        case 'theme': ref.read(themeModeProvider.notifier).state = val == 'dark' ? ThemeMode.dark : ThemeMode.light; break;
        case 'accent-color': ref.read(accentColorProvider.notifier).state = _parseColor(val); break;
        case 'glass': ref.read(glassEnabledProvider.notifier).state = val == 'true'; break;
        case 'scale': ref.read(scaleProvider.notifier).state = double.parse(val); break;
        case 'ui-mode': ref.read(uiModeProvider.notifier).state = val; break;
        case 'blur': ref.read(blurEnabledProvider.notifier).state = val == 'true'; break;
        case 'cover-effect': ref.read(coverEffectProvider.notifier).state = val; break;
        case 'slider-style': ref.read(playerSliderStyleProvider.notifier).state = val; break;
        case 'optimization': ref.read(freezeOptimizationProvider.notifier).state = val == 'true'; break;
        case 'gradient': ref.read(borderGradientEnabledProvider.notifier).state = val == 'true'; break;
        case 'border-color': ref.read(borderColorProvider.notifier).state = _parseColor(val); break;
        case 'speed': ref.read(borderAnimationSpeedProvider.notifier).state = double.parse(val); break;
        case 'color1': ref.read(borderGradientColor1Provider.notifier).state = _parseColor(val); break;
        case 'color2': ref.read(borderGradientColor2Provider.notifier).state = _parseColor(val); break;
        case 'hue': ref.read(hueShiftProvider.notifier).state = double.parse(val); break;
        case 'saturation': ref.read(saturationProvider.notifier).state = double.parse(val); break;
        case 'contrast': ref.read(contrastProvider.notifier).state = double.parse(val); break;
        case 'brightness': ref.read(brightnessProvider.notifier).state = double.parse(val); break;
        case 'grayscale': ref.read(grayscaleProvider.notifier).state = double.parse(val); break;
        case 'pixelation': ref.read(pixelationProvider.notifier).state = double.parse(val); break;
        case 'title-bar-enabled': ref.read(customTitleBarEnabledProvider.notifier).state = val == 'true'; break;
        case 'height': ref.read(titleBarHeightProvider.notifier).state = double.parse(val); break;
        case 'opacity': ref.read(titleBarOpacityProvider.notifier).state = double.parse(val); break;
        default: _terminalOutput.add('? Property "$key" ignored');
      }
    } catch (e) {
      _terminalOutput.add('! Error: $key -> $e');
    }
  }

  void _runCss() {
    final code = _codeController.text;
    if (code.trim().isEmpty) return;
    setState(() => _terminalOutput.add('> Updating UI parameters...'));
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
      _terminalOutput.add('Done: Configuration applied.');
    } catch (e) { _terminalOutput.add('Critical Error: $e'); }
    setState(() {});
  }

  void _handleCommand(String input) {
    if (input.trim().isEmpty) return;
    setState(() => _terminalOutput.add('> $input'));
    final cmd = input.trim().toLowerCase();
    _commandController.clear();
    if (cmd == 'help') {
      _terminalOutput.add('Commands: sync, clear, <property>=<value>');
    } else if (cmd == 'sync') {
      _generateCurrentCss();
      _terminalOutput.add('Synced with system state.');
    } else if (cmd == 'clear') {
      _terminalOutput.clear();
    } else if (cmd.contains('=')) {
      final parts = cmd.split('=');
      _applyStyle(parts[0].trim(), parts[1].trim());
    } else { _terminalOutput.add('Unknown command.'); }
    setState(() {});
    _commandFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final effectiveAccent = primary.value == 0 ? Colors.grey : primary;
    
    return Container(
      height: 550 * widget.scale,
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.black87 : Colors.white70,
        borderRadius: BorderRadius.circular(16 * widget.scale),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            dividerColor: Colors.transparent,
            indicatorColor: effectiveAccent.withOpacity(0.5),
            indicatorWeight: 2,
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
                    Padding(
                      padding: EdgeInsets.all(12 * widget.scale),
                      child: Container(
                        decoration: BoxDecoration(
                          color: widget.isDark ? const Color(0xFF141414) : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12 * widget.scale),
                        ),
                        child: TextField(
                          controller: _codeController,
                          focusNode: _codeFocusNode,
                          maxLines: null,
                          expands: true,
                          cursorColor: widget.isDark ? Colors.white : Colors.black,
                          style: TextStyle(fontFamily: 'monospace', color: widget.isDark ? Colors.cyanAccent[100] : Colors.blue[800], fontSize: 13 * widget.scale),
                          decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.all(16)),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 28 * widget.scale,
                      bottom: 28 * widget.scale,
                      child: GestureDetector(
                        onTap: _runCss,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 16 * widget.scale, vertical: 8 * widget.scale),
                          decoration: BoxDecoration(
                            color: effectiveAccent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12 * widget.scale),
                            border: Border.all(color: effectiveAccent.withOpacity(0.3)),
                          ),
                          child: Text(
                            'APPLY',
                            style: TextStyle(
                              color: effectiveAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 12 * widget.scale,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: EdgeInsets.all(16 * widget.scale),
                  child: Column(
                    children: [
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: widget.isDark ? Colors.black : Colors.white,
                            borderRadius: BorderRadius.circular(12 * widget.scale),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: ListView.builder(
                            itemCount: _terminalOutput.length,
                            itemBuilder: (context, index) => Text(
                              _terminalOutput[index],
                              style: TextStyle(fontFamily: 'monospace', color: widget.isDark ? Colors.greenAccent : Colors.green[800], fontSize: 12 * widget.scale),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 12 * widget.scale),
                      TextField(
                        controller: _commandController,
                        focusNode: _commandFocusNode,
                        cursorColor: widget.isDark ? Colors.white : Colors.black,
                        style: TextStyle(fontFamily: 'monospace', color: widget.isDark ? Colors.white : Colors.black, fontSize: 13 * widget.scale),
                        decoration: InputDecoration(
                          hintText: 'Command...',
                          filled: true,
                          fillColor: widget.isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12 * widget.scale), borderSide: BorderSide.none),
                        ),
                        onSubmitted: _handleCommand,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
