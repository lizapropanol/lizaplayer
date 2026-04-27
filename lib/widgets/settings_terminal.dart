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

class _SettingsTerminalState extends ConsumerState<SettingsTerminal> {
  final TextEditingController _terminalController = TextEditingController();
  final FocusNode _terminalFocusNode = FocusNode();
  final List<String> _terminalOutput = [
    'lizaplayer Settings Terminal',
    'Type a command to change UI (e.g. theme = dark, glass = false)'
  ];

  @override
  void dispose() {
    _terminalController.dispose();
    _terminalFocusNode.dispose();
    super.dispose();
  }

  void _handleTerminalCommand(String input) {
    if (input.trim().isEmpty) return;
    setState(() => _terminalOutput.add('> $input'));
    final cmd = input.trim().toLowerCase();
    _terminalController.clear();

    try {
      if (cmd == 'help') {
        _terminalOutput.add('Commands: theme=<dark/light>, glass=<true/false>, scale=<0.5-2.0>, uimode=<v1/v2>, accent=<hex>');
      } else if (cmd.startsWith('theme=')) {
        final val = cmd.split('=')[1].trim();
        ref.read(themeModeProvider.notifier).state = val == 'dark' ? ThemeMode.dark : ThemeMode.light;
        _terminalOutput.add('Theme set to $val');
      } else if (cmd.startsWith('glass=')) {
        final val = cmd.split('=')[1].trim() == 'true';
        ref.read(glassEnabledProvider.notifier).state = val;
        _terminalOutput.add('Glassmorphism set to $val');
      } else if (cmd.startsWith('scale=')) {
        final val = double.parse(cmd.split('=')[1].trim());
        ref.read(scaleProvider.notifier).state = val;
        _terminalOutput.add('Scale set to $val');
      } else if (cmd.startsWith('uimode=')) {
        final val = cmd.split('=')[1].trim();
        ref.read(uiModeProvider.notifier).state = val;
        _terminalOutput.add('UI Mode set to $val');
      } else if (cmd.startsWith('accent=')) {
        final val = cmd.split('=')[1].trim();
        final color = Color(int.parse(val.replaceAll('#', '0xFF')));
        ref.read(accentColorProvider.notifier).state = color;
        _terminalOutput.add('Accent color set to $val');
      } else if (cmd == 'clear') {
        _terminalOutput.clear();
      } else {
        _terminalOutput.add('Unknown command: $cmd');
      }
    } catch (e) {
      _terminalOutput.add('Error executing command: $e');
    }
    setState(() {});
    _terminalFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400 * widget.scale,
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.black87 : Colors.white70,
        borderRadius: BorderRadius.circular(12 * widget.scale),
        border: Border.all(color: Colors.white10),
      ),
      padding: EdgeInsets.all(16 * widget.scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _terminalOutput.length,
              itemBuilder: (context, index) {
                return Text(
                  _terminalOutput[index],
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: widget.isDark ? Colors.greenAccent : Colors.green[800],
                    fontSize: 14 * widget.scale,
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 8 * widget.scale),
          TextField(
            controller: _terminalController,
            focusNode: _terminalFocusNode,
            autofocus: true,
            style: TextStyle(
              fontFamily: 'monospace',
              color: widget.isDark ? Colors.white : Colors.black,
              fontSize: 14 * widget.scale,
            ),
            decoration: InputDecoration(
              hintText: 'Enter command...',
              hintStyle: const TextStyle(color: Colors.grey),
              filled: true,
              fillColor: widget.isDark ? Colors.black54 : Colors.grey[200],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8 * widget.scale),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 12 * widget.scale, vertical: 12 * widget.scale),
            ),
            onSubmitted: _handleTerminalCommand,
          ),
        ],
      ),
    );
  }
}
