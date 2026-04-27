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
      _codeController.text = '''/* LizaPlayer UI Stylesheet */
ui {
  theme: dark;
  accent-color: #00e5ff;
  glass: true;
  scale: 1.0;
  ui-mode: v2;
  slider-style: wavy;
}''';
      _terminalOutput.add('System: Developer Environment Ready.');
      _initialized = true;
    }
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
    if (hex == 'transparent') return Colors.transparent;
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  void _applyStyle(String key, String val) {
    try {
      switch (key) {
        case 'theme':
          ref.read(themeModeProvider.notifier).state = val == 'dark' ? ThemeMode.dark : ThemeMode.light;
          break;
        case 'accent-color':
        case 'color':
          ref.read(accentColorProvider.notifier).state = _parseColor(val);
          break;
        case 'glass':
          ref.read(glassEnabledProvider.notifier).state = val == 'true';
          break;
        case 'scale':
          ref.read(scaleProvider.notifier).state = double.parse(val);
          break;
        case 'ui-mode':
          ref.read(uiModeProvider.notifier).state = val;
          break;
        case 'cover-effect':
          ref.read(coverEffectProvider.notifier).state = val;
          break;
        case 'slider-style':
          ref.read(playerSliderStyleProvider.notifier).state = val;
          break;
        case 'hue':
          ref.read(hueShiftProvider.notifier).state = double.parse(val);
          break;
        case 'image-blur':
          ref.read(blurEnabledProvider.notifier).state = val == 'true';
          break;
        default:
          _terminalOutput.add('Warning: Unknown property "$key"');
      }
    } catch (e) {
      _terminalOutput.add('Error: $key -> $e');
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
        final propertiesStr = match.group(2)?.trim();
        if (propertiesStr != null) {
          final properties = propertiesStr.split(';');
          for (final prop in properties) {
            if (prop.trim().isEmpty) continue;
            final parts = prop.split(':');
            if (parts.length >= 2) {
              _applyStyle(parts[0].trim(), parts.sublist(1).join(':').trim());
            }
          }
        }
      }
      _terminalOutput.add('Success: Styles applied.');
    } catch (e) {
      _terminalOutput.add('Error: $e');
    }
    setState(() {});
  }

  void _handleCommand(String input) {
    if (input.trim().isEmpty) return;
    setState(() => _terminalOutput.add('> $input'));
    final cmd = input.trim().toLowerCase();
    _commandController.clear();
    
    try {
      if (cmd == 'help') {
        _terminalOutput.add('Available: theme, glass, scale, uimode, accent, clear');
      } else if (cmd.startsWith('theme=')) {
        ref.read(themeModeProvider.notifier).state = cmd.contains('dark') ? ThemeMode.dark : ThemeMode.light;
      } else if (cmd == 'clear') {
        _terminalOutput.clear();
      } else if (cmd.contains('=')) {
        final parts = cmd.split('=');
        _applyStyle(parts[0].trim(), parts[1].trim());
      } else {
        _terminalOutput.add('Unknown command. Use property=value or "help".');
      }
    } catch (e) {
      _terminalOutput.add('Error: $e');
    }
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
            indicatorColor: effectiveAccent,
            labelColor: widget.isDark ? Colors.white : Colors.black,
            unselectedLabelColor: Colors.grey,
            tabs: const [Tab(text: 'Styles (CSS)'), Tab(text: 'Console (CMD)')],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // CSS Editor Tab
                Padding(
                  padding: EdgeInsets.all(16 * widget.scale),
                  child: Column(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: widget.isDark ? const Color(0xFF1E1E1E) : Colors.grey[200],
                            borderRadius: BorderRadius.circular(8 * widget.scale),
                          ),
                          child: TextField(
                            controller: _codeController,
                            focusNode: _codeFocusNode,
                            maxLines: null,
                            expands: true,
                            cursorColor: widget.isDark ? Colors.white : Colors.black,
                            style: TextStyle(fontFamily: 'monospace', color: widget.isDark ? Colors.cyanAccent[100] : Colors.blue[800], fontSize: 13 * widget.scale),
                            decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.all(12)),
                          ),
                        ),
                      ),
                      SizedBox(height: 12 * widget.scale),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _runCss,
                          style: ElevatedButton.styleFrom(backgroundColor: effectiveAccent, foregroundColor: widget.isDark ? Colors.black : Colors.white),
                          child: const Text('Apply Stylesheet'),
                        ),
                      ),
                    ],
                  ),
                ),
                // Console Tab
                Padding(
                  padding: EdgeInsets.all(16 * widget.scale),
                  child: Column(
                    children: [
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: widget.isDark ? Colors.black : Colors.white,
                            borderRadius: BorderRadius.circular(8 * widget.scale),
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
                          hintText: 'Enter command...',
                          filled: true,
                          fillColor: widget.isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8 * widget.scale), borderSide: BorderSide.none),
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
