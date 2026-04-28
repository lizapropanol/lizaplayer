import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

String getConfigPath() {
  if (Platform.isWindows) {
    return p.join(Platform.environment['APPDATA']!, 'lizaplayer', 'style.conf');
  } else {
    return p.join(Platform.environment['HOME']!, '.config', 'lizaplayer', 'style.conf');
  }
}

class _ConfigClickable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _ConfigClickable({required this.child, required this.onTap});

  @override
  State<_ConfigClickable> createState() => _ConfigClickableState();
}

class _ConfigClickableState extends State<_ConfigClickable> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final scale = _isPressed ? 0.95 : (_isHovered ? 1.05 : 1.0);
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() { _isHovered = false; _isPressed = false; }),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          child: widget.child,
        ),
      ),
    );
  }
}

class ConfigEngine extends StatefulWidget {
  final Map<String, String> variables;
  final Map<String, VoidCallback> actions;

  const ConfigEngine({super.key, required this.variables, required this.actions});

  @override
  State<ConfigEngine> createState() => _ConfigEngineState();
}

class _ConfigEngineState extends State<ConfigEngine> {
  String _configContent = '';
  DateTime _lastModified = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _watchTimer;

  @override
  void initState() {
    super.initState();
    _loadAndWatchConfig();
  }

  @override
  void dispose() {
    _watchTimer?.cancel();
    super.dispose();
  }

  void _loadAndWatchConfig() async {
    final path = getConfigPath();
    final file = File(path);
    if (!await file.exists()) {
      await file.parent.create(recursive: true);
      await file.writeAsString('// Write your UI config here (JSON format)\n{\n  "type": "Center",\n  "child": {\n    "type": "Text",\n    "text": "Hello Config!",\n    "color": "0xFFFFFFFF"\n  }\n}');
    }
    
    void load() async {
      try {
        final content = await file.readAsString();
        print("ConfigEngine: Loaded config from ${file.path}");
        if (mounted) setState(() => _configContent = content);
      } catch (e) {
        print("ConfigEngine: Error loading config: $e");
        if (mounted) setState(() => _configContent = '');
      }
    }
    
    load();
    _watchTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      try {
        final stat = file.statSync();
        if (stat.type != FileSystemEntityType.notFound && stat.modified != _lastModified) {
          _lastModified = stat.modified;
          load();
        }
      } catch (e) {}
    });
  }

  Widget _buildWidget(Map<String, dynamic>? data) {
    if (data == null) return const SizedBox.shrink();
    final type = data['type'] as String?;
    if (type == null) return const SizedBox.shrink();

    String substitute(String? text) {
      if (text == null) return '';
      String res = text;
      widget.variables.forEach((key, value) {
        res = res.replaceAll('{$key}', value);
      });
      return res;
    }

    Widget child = const SizedBox.shrink();
    if (data.containsKey('child')) {
      child = _buildWidget(data['child'] as Map<String, dynamic>);
    }

    List<Widget> children = [];
    if (data.containsKey('children')) {
      children = (data['children'] as List).map((e) => _buildWidget(e as Map<String, dynamic>)).toList();
    }

    Color? parseColor(String? hex) {
      if (hex == null) return null;
      String cleanHex = hex.replaceAll('#', '').replaceAll('0x', '');
      if (cleanHex.length == 6) {
        cleanHex = 'FF$cleanHex';
      }
      return Color(int.parse(cleanHex, radix: 16));
    }

    Widget buildInner() {
      switch (type) {
        case 'Container':
          BoxDecoration? decoration;
          if (data['color'] != null || data['borderRadius'] != null || data['glow'] != null || data['image'] != null) {
            decoration = BoxDecoration(
              color: parseColor(data['color']),
              borderRadius: data['borderRadius'] != null ? BorderRadius.circular((data['borderRadius'] as num).toDouble()) : null,
              boxShadow: data['glow'] != null ? [
                BoxShadow(
                  color: parseColor(data['glowColor']) ?? Colors.white,
                  blurRadius: (data['glow'] as num).toDouble(),
                  spreadRadius: data['glowSpread'] != null ? (data['glowSpread'] as num).toDouble() : 0.0,
                )
              ] : null,
              image: data['image'] != null ? DecorationImage(
                image: NetworkImage(substitute(data['image'] as String?)),
                fit: BoxFit.cover,
              ) : null,
            );
          }
          return Container(
            width: data['width'] != null ? (data['width'] as num).toDouble() : null,
            height: data['height'] != null ? (data['height'] as num).toDouble() : null,
            margin: data['margin'] != null ? EdgeInsets.all((data['margin'] as num).toDouble()) : null,
            padding: data['padding'] != null ? EdgeInsets.all((data['padding'] as num).toDouble()) : null,
            decoration: decoration,
            child: child,
          );
        case 'Row':
          return Row(
            mainAxisAlignment: data['mainAxisAlignment'] == 'center' ? MainAxisAlignment.center : data['mainAxisAlignment'] == 'spaceBetween' ? MainAxisAlignment.spaceBetween : MainAxisAlignment.start,
            crossAxisAlignment: data['crossAxisAlignment'] == 'center' ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            children: children,
          );
        case 'Column':
          return Column(
            mainAxisAlignment: data['mainAxisAlignment'] == 'center' ? MainAxisAlignment.center : data['mainAxisAlignment'] == 'spaceBetween' ? MainAxisAlignment.spaceBetween : MainAxisAlignment.start,
            crossAxisAlignment: data['crossAxisAlignment'] == 'center' ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            children: children,
          );
        case 'Stack':
          return Stack(children: children);
        case 'Positioned':
          return Positioned(
            top: data['top'] != null ? (data['top'] as num).toDouble() : null,
            bottom: data['bottom'] != null ? (data['bottom'] as num).toDouble() : null,
            left: data['left'] != null ? (data['left'] as num).toDouble() : null,
            right: data['right'] != null ? (data['right'] as num).toDouble() : null,
            child: child,
          );
        case 'Center':
          return Center(child: child);
        case 'Text':
          return Text(
            substitute(data['text'] as String?),
            style: TextStyle(
              color: parseColor(data['color']) ?? Colors.white,
              fontSize: data['fontSize'] != null ? (data['fontSize'] as num).toDouble() : 14,
              fontWeight: data['fontWeight'] == 'bold' ? FontWeight.bold : FontWeight.normal,
              shadows: data['glow'] != null ? [
                Shadow(
                  color: parseColor(data['glowColor']) ?? Colors.white,
                  blurRadius: (data['glow'] as num).toDouble(),
                )
              ] : null,
            ),
          );
        case 'Image':
          return Image.network(
            substitute(data['url'] as String?),
            width: data['width'] != null ? (data['width'] as num).toDouble() : null,
            height: data['height'] != null ? (data['height'] as num).toDouble() : null,
            fit: data['fit'] == 'cover' ? BoxFit.cover : BoxFit.contain,
          );
        case 'Blur':
          return BackdropFilter(
            filter: ImageFilter.blur(sigmaX: (data['sigmaX'] as num?)?.toDouble() ?? 5.0, sigmaY: (data['sigmaY'] as num?)?.toDouble() ?? 5.0),
            child: child,
          );
        default:
          return const SizedBox.shrink();
      }
    }

    final inner = buildInner();
    if (data['onTap'] != null && widget.actions.containsKey(data['onTap'])) {
      return _ConfigClickable(
        onTap: widget.actions[data['onTap']]!,
        child: inner,
      );
    }
    return inner;
  }

  @override
  Widget build(BuildContext context) {
    if (_configContent.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    
    try {
      final cleanJson = _configContent.split('\n').where((line) => !line.trimLeft().startsWith('//')).join('\n');
      final data = jsonDecode(cleanJson) as Map<String, dynamic>;
      return Material(
        color: Colors.transparent,
        child: _buildWidget(data),
      );
    } catch (e) {
      return Center(child: Text('Config Error: $e', style: const TextStyle(color: Colors.red)));
    }
  }
}
