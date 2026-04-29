import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lizaplayer/main.dart';
import 'package:lizaplayer/widgets/smooth_scroll.dart';
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
  final double hoverScale;
  final double pressScale;
  final int duration;

  const _ConfigClickable({
    required this.child, 
    required this.onTap,
    this.hoverScale = 1.05,
    this.pressScale = 0.95,
    this.duration = 150,
  });

  @override
  State<_ConfigClickable> createState() => _ConfigClickableState();
}

class _ConfigClickableState extends State<_ConfigClickable> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final scale = _isPressed ? widget.pressScale : (_isHovered ? widget.hoverScale : 1.0);
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
          duration: Duration(milliseconds: widget.duration),
          curve: Curves.easeOutCubic,
          child: widget.child,
        ),
      ),
    );
  }
}

class _ConfigAnimation extends ConsumerStatefulWidget {
  final Widget child;
  final List<dynamic> effects;

  const _ConfigAnimation({required this.child, required this.effects});

  @override
  ConsumerState<_ConfigAnimation> createState() => _ConfigAnimationState();
}

class _ConfigAnimationState extends ConsumerState<_ConfigAnimation> with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<dynamic>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = [];
    _animations = [];
    _setupAnimations();
  }

  void _setupAnimations() {
    for (final effect in widget.effects) {
      final duration = (effect['duration'] as num?)?.toInt() ?? 1000;
      final delay = (effect['delay'] as num?)?.toInt() ?? 0;
      final loop = effect['loop'] == true;
      final reverse = effect['reverse'] == true;
      
      final controller = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: duration),
      );

      final curveName = effect['curve'] as String?;
      Curve curve = Curves.linear;
      switch (curveName) {
        case 'bounceOut': curve = Curves.bounceOut; break;
        case 'elasticOut': curve = Curves.elasticOut; break;
        case 'easeInOut': curve = Curves.easeInOut; break;
        case 'easeOutCubic': curve = Curves.easeOutCubic; break;
        case 'decelerate': curve = Curves.decelerate; break;
      }

      final type = effect['type'] as String?;
      Animation<dynamic> animation;

      if (type == 'slide') {
        final begin = effect['begin'] as Map?;
        final end = effect['end'] as Map?;
        animation = Tween<Offset>(
          begin: Offset((begin?['x'] as num?)?.toDouble() ?? 0.0, (begin?['y'] as num?)?.toDouble() ?? 0.0),
          end: Offset((end?['x'] as num?)?.toDouble() ?? 0.0, (end?['y'] as num?)?.toDouble() ?? 0.0),
        ).animate(CurvedAnimation(parent: controller, curve: curve));
      } else if (type == 'rotate') {
        animation = Tween<double>(
          begin: (effect['begin'] as num?)?.toDouble() ?? 0.0,
          end: (effect['end'] as num?)?.toDouble() ?? 6.28,
        ).animate(CurvedAnimation(parent: controller, curve: curve));
      } else if (type == 'scale') {
        animation = Tween<double>(
          begin: (effect['begin'] as num?)?.toDouble() ?? 1.0,
          end: (effect['end'] as num?)?.toDouble() ?? 1.2,
        ).animate(CurvedAnimation(parent: controller, curve: curve));
      } else {
        animation = Tween<double>(
          begin: (effect['begin'] as num?)?.toDouble() ?? 0.0,
          end: (effect['end'] as num?)?.toDouble() ?? 1.0,
        ).animate(CurvedAnimation(parent: controller, curve: curve));
      }

      _controllers.add(controller);
      _animations.add(animation);

      Future.delayed(Duration(milliseconds: delay), () {
        if (mounted) {
          if (loop) {
            controller.repeat(reverse: reverse);
          } else {
            controller.forward();
          }
        }
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFrozen = ref.watch(isFrozenProvider);

    for (int i = 0; i < widget.effects.length; i++) {
      final effect = widget.effects[i];
      final controller = _controllers[i];
      final loop = effect['loop'] == true;
      final reverse = effect['reverse'] == true;

      if (isFrozen) {
        controller.stop();
      } else {
        if (!controller.isAnimating) {
          if (loop) {
            controller.repeat(reverse: reverse);
          } else if (controller.value == 0) {
            controller.forward();
          }
        }
      }
    }

    Widget res = widget.child;
    for (int i = 0; i < widget.effects.length; i++) {
      final effect = widget.effects[i];
      final anim = _animations[i];
      final type = effect['type'] as String?;

      res = AnimatedBuilder(
        animation: anim,
        builder: (context, child) {
          if (type == 'slide') {
            return Transform.translate(offset: anim.value as Offset, child: child);
          } else if (type == 'rotate') {
            return Transform.rotate(angle: anim.value as double, child: child);
          } else if (type == 'scale') {
            return Transform.scale(scale: anim.value as double, child: child);
          } else {
            return Opacity(opacity: (anim.value as double).clamp(0.0, 1.0), child: child);
          }
        },
        child: res,
      );
    }
    return res;
  }
}

class ConfigEngine extends StatefulWidget {
  final Map<String, String> variables;
  final Map<String, VoidCallback> actions;
  final Map<String, Widget Function(Map<String, dynamic> data)> builders;

  static Map<String, Map<String, dynamic>> templates = {};
  static Map<String, Widget Function(Map<String, dynamic>)>? globalBuilders;
  static Map<String, VoidCallback>? globalActions;

  const ConfigEngine({super.key, required this.variables, required this.actions, required this.builders});

  static String substitute(String? text, Map<String, String> variables) {
    if (text == null) return '';
    String res = text;
    variables.forEach((key, value) {
      res = res.replaceAll('{$key}', value);
    });
    return res;
  }

  static dynamic evaluate(dynamic val, Map<String, String> variables) {
    if (val is! String) return val;
    String s = substitute(val, variables);
    if (s.contains('?')) {
      try {
        final parts = s.split('?');
        final cond = parts[0].trim();
        final vals = parts[1].split(':');
        if (cond == "true == true" || cond == "true" || cond.contains("true")) {
          return vals[0].trim();
        } else {
          return vals[1].trim();
        }
      } catch (_) {}
    }
    return s;
  }

  static Color? parseColor(dynamic hex, [Map<String, String>? variables]) {
    if (hex == null) return null;
    String processed = hex.toString();
    if (variables != null) {
      final evaluated = evaluate(processed, variables);
      processed = evaluated.toString();
    }

    try {
      String cleanHex = processed.replaceAll('#', '').replaceAll('0x', '').trim();
      if (cleanHex.length == 6) {
        cleanHex = 'FF$cleanHex';
      }
      return Color(int.parse(cleanHex, radix: 16));
    } catch (e) {
      return null;
    }
  }

  static Widget buildDynamic(Map<String, dynamic> data, Map<String, String> variables, Map<String, VoidCallback> actions, [Map<String, Widget Function(Map<String, dynamic>)>? extraBuilders]) {
    final allBuilders = {...(globalBuilders ?? {}), ...(extraBuilders ?? {})};
    return Material(
      type: MaterialType.transparency,
      child: _ConfigEngineState.buildStaticWidget(data, variables, actions, allBuilders),
    );
  }

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
    ConfigEngine.globalBuilders = widget.builders;
    ConfigEngine.globalActions = widget.actions;
    _loadAndWatchConfig();
  }

  @override
  void didUpdateWidget(ConfigEngine oldWidget) {
    super.didUpdateWidget(oldWidget);
    ConfigEngine.globalBuilders = widget.builders;
    ConfigEngine.globalActions = widget.actions;
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
      await file.writeAsString('{\n  "type": "Center",\n  "child": {\n    "type": "Text",\n    "text": "Hello Config!",\n    "color": "0xFFFFFFFF"\n  }\n}');
    }
    
    void load() async {
      try {
        final content = await file.readAsString();
        final cleanJson = content.split('\n').where((line) => !line.trimLeft().startsWith('//')).join('\n');
        final data = jsonDecode(cleanJson) as Map<String, dynamic>;
        
        if (data.containsKey('templates')) {
          ConfigEngine.templates = Map<String, Map<String, dynamic>>.from(data['templates']);
        }

        if (mounted) setState(() => _configContent = content);
      } catch (e) {
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

  static Widget buildStaticWidget(Map<String, dynamic>? data, Map<String, String> variables, Map<String, VoidCallback> actions, Map<String, Widget Function(Map<String, dynamic>)> builders) {
    EdgeInsets? getEdgeInsets(dynamic val) {
      if (val == null) return null;
      if (val is num) return EdgeInsets.all(val.toDouble());
      if (val is Map) {
        return EdgeInsets.only(
          left: (val['left'] as num?)?.toDouble() ?? 0.0,
          right: (val['right'] as num?)?.toDouble() ?? 0.0,
          top: (val['top'] as num?)?.toDouble() ?? 0.0,
          bottom: (val['bottom'] as num?)?.toDouble() ?? 0.0,
        );
      }
      return null;
    }

    if (data == null) return const SizedBox.shrink();
    final type = data['type'] as String?;
    if (type == null) return const SizedBox.shrink();

    Widget child = const SizedBox.shrink();
    if (data.containsKey('child')) {
      child = buildStaticWidget(data['child'] as Map<String, dynamic>, variables, actions, builders);
    }

    List<Widget> children = [];
    if (data.containsKey('children')) {
      children = (data['children'] as List).map((e) => buildStaticWidget(e as Map<String, dynamic>, variables, actions, builders)).toList();
    }

    Widget buildInner() {
      if (builders.containsKey(type)) {
        return builders[type]!(data);
      }
      switch (type) {
        case 'Container':
        case 'AnimatedContainer':
          BoxDecoration? decoration;
          if (data['color'] != null || data['borderRadius'] != null || data['glow'] != null || data['image'] != null || data['gradient'] != null || data['border'] != null || data['shape'] != null || data['shadows'] != null) {
            Gradient? gradient;
            if (data['gradient'] != null) {
              final gData = data['gradient'] as Map<String, dynamic>;
              final colors = (gData['colors'] as List?)?.map((c) => ConfigEngine.parseColor(c, variables) ?? Colors.transparent).toList() ?? [Colors.transparent, Colors.transparent];
              Alignment getAlignment(String? a) {
                switch (a) {
                  case 'topLeft': return Alignment.topLeft;
                  case 'topCenter': return Alignment.topCenter;
                  case 'topRight': return Alignment.topRight;
                  case 'centerLeft': return Alignment.centerLeft;
                  case 'center': return Alignment.center;
                  case 'centerRight': return Alignment.centerRight;
                  case 'bottomLeft': return Alignment.bottomLeft;
                  case 'bottomCenter': return Alignment.bottomCenter;
                  case 'bottomRight': return Alignment.bottomRight;
                  default: return Alignment.center;
                }
              }
              if (gData['type'] == 'Radial') {
                gradient = RadialGradient(colors: colors, center: getAlignment(gData['center']), radius: (gData['radius'] as num?)?.toDouble() ?? 0.5);
              } else if (gData['type'] == 'Sweep') {
                gradient = SweepGradient(colors: colors, center: getAlignment(gData['center']));
              } else {
                gradient = LinearGradient(colors: colors, begin: getAlignment(gData['begin']), end: getAlignment(gData['end']));
              }
            }
            BoxBorder? border;
            if (data['border'] != null) {
              final bData = data['border'] as Map<String, dynamic>;
              final widthVal = ConfigEngine.evaluate(bData['width'], variables);
              double width = 1.0;
              if (widthVal is num) width = widthVal.toDouble();
              else if (widthVal is String) width = double.tryParse(widthVal) ?? 1.0;

              border = Border.all(color: ConfigEngine.parseColor(bData['color'], variables) ?? Colors.black, width: width);
            }
            decoration = BoxDecoration(
              color: ConfigEngine.parseColor(data['color'], variables),
              shape: data['shape'] == 'circle' ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: data['shape'] == 'circle' ? null : (data['borderRadius'] != null ? BorderRadius.circular((data['borderRadius'] as num).toDouble()) : null),
              border: border,
              gradient: gradient,
              boxShadow: data['glow'] != null || data['shadows'] != null ? [
                if (data['glow'] != null) BoxShadow(
                  color: ConfigEngine.parseColor(data['glowColor'], variables) ?? Colors.white,
                  blurRadius: (data['glow'] as num).toDouble(),
                  spreadRadius: data['glowSpread'] != null ? (data['glowSpread'] as num).toDouble() : 0.0,
                ),
                if (data['shadows'] != null) ...((data['shadows'] as List).map((s) {
                  final sData = s as Map<String, dynamic>;
                  return BoxShadow(
                    color: ConfigEngine.parseColor(sData['color'], variables) ?? Colors.black,
                    blurRadius: (sData['blurRadius'] as num?)?.toDouble() ?? 0.0,
                    spreadRadius: (sData['spreadRadius'] as num?)?.toDouble() ?? 0.0,
                    offset: Offset((sData['offsetX'] as num?)?.toDouble() ?? 0.0, (sData['offsetY'] as num?)?.toDouble() ?? 0.0),
                  );
                }))
              ] : null,
              image: data['image'] != null ? DecorationImage(
                image: NetworkImage(ConfigEngine.substitute(data['image'] as String?, variables)),
                fit: data['imageFit'] == 'contain' ? BoxFit.contain : BoxFit.cover,
                colorFilter: data['imageColor'] != null ? ColorFilter.mode(ConfigEngine.parseColor(data['imageColor'], variables)!, BlendMode.srcATop) : null,
              ) : null,
            );
          }
          final w = data['width'] != null ? (data['width'] as num).toDouble() : null;
          final h = data['height'] != null ? (data['height'] as num).toDouble() : null;
          final m = getEdgeInsets(data['margin']);
          final p = getEdgeInsets(data['padding']);
          
          if (type == 'AnimatedContainer' || data['duration'] != null) {
            return AnimatedContainer(
              duration: Duration(milliseconds: data['duration'] != null ? (data['duration'] as num).toInt() : 300),
              curve: Curves.easeInOut,
              width: w, height: h, margin: m, padding: p, decoration: decoration, child: child,
            );
          }
          return Container(width: w, height: h, margin: m, padding: p, decoration: decoration, child: child);
          
        case 'Row':
        case 'Column':
          final mainAxis = data['mainAxisAlignment'] == 'center' ? MainAxisAlignment.center : data['mainAxisAlignment'] == 'spaceBetween' ? MainAxisAlignment.spaceBetween : data['mainAxisAlignment'] == 'spaceAround' ? MainAxisAlignment.spaceAround : data['mainAxisAlignment'] == 'spaceEvenly' ? MainAxisAlignment.spaceEvenly : data['mainAxisAlignment'] == 'end' ? MainAxisAlignment.end : MainAxisAlignment.start;
          final crossAxis = data['crossAxisAlignment'] == 'center' ? CrossAxisAlignment.center : data['crossAxisAlignment'] == 'stretch' ? CrossAxisAlignment.stretch : data['crossAxisAlignment'] == 'end' ? CrossAxisAlignment.end : CrossAxisAlignment.start;
          final mainAxisSize = data['mainAxisSize'] == 'min' ? MainAxisSize.min : MainAxisSize.max;
          if (type == 'Row') return Row(mainAxisAlignment: mainAxis, crossAxisAlignment: crossAxis, mainAxisSize: mainAxisSize, children: children);
          return Column(mainAxisAlignment: mainAxis, crossAxisAlignment: crossAxis, mainAxisSize: mainAxisSize, children: children);
          
        case 'Wrap':
          return Wrap(
            spacing: (data['spacing'] as num?)?.toDouble() ?? 0.0,
            runSpacing: (data['runSpacing'] as num?)?.toDouble() ?? 0.0,
            alignment: data['alignment'] == 'center' ? WrapAlignment.center : WrapAlignment.start,
            children: children,
          );
          
        case 'Stack':
          return Stack(
            alignment: data['alignment'] == 'center' ? Alignment.center : Alignment.topLeft,
            clipBehavior: data['clip'] == 'none' ? Clip.none : Clip.hardEdge,
            children: children
          );
          
        case 'Positioned':
        case 'AnimatedPositioned':
          final top = data['top'] != null ? (data['top'] as num).toDouble() : null;
          final bottom = data['bottom'] != null ? (data['bottom'] as num).toDouble() : null;
          final left = data['left'] != null ? (data['left'] as num).toDouble() : null;
          final right = data['right'] != null ? (data['right'] as num).toDouble() : null;
          final width = data['width'] != null ? (data['width'] as num).toDouble() : null;
          final height = data['height'] != null ? (data['height'] as num).toDouble() : null;
          if (type == 'AnimatedPositioned' || data['duration'] != null) {
            return AnimatedPositioned(
              duration: Duration(milliseconds: data['duration'] != null ? (data['duration'] as num).toInt() : 300),
              curve: Curves.easeInOut,
              top: top, bottom: bottom, left: left, right: right, width: width, height: height, child: child,
            );
          }
          return Positioned(top: top, bottom: bottom, left: left, right: right, width: width, height: height, child: child);
          
        case 'Center':
          return Center(child: child);
          
        case 'Align':
        case 'AnimatedAlign':
          Alignment getAlign(String? a) {
            switch (a) {
              case 'topLeft': return Alignment.topLeft;
              case 'topCenter': return Alignment.topCenter;
              case 'topRight': return Alignment.topRight;
              case 'centerLeft': return Alignment.centerLeft;
              case 'center': return Alignment.center;
              case 'centerRight': return Alignment.centerRight;
              case 'bottomLeft': return Alignment.bottomLeft;
              case 'bottomCenter': return Alignment.bottomCenter;
              case 'bottomRight': return Alignment.bottomRight;
              default: return Alignment.center;
            }
          }
          if (type == 'AnimatedAlign' || data['duration'] != null) {
            return AnimatedAlign(
              duration: Duration(milliseconds: data['duration'] != null ? (data['duration'] as num).toInt() : 300),
              curve: Curves.easeInOut,
              alignment: getAlign(data['alignment']), child: child,
            );
          }
          return Align(alignment: getAlign(data['alignment']), child: child);
          
        case 'Expanded':
          return Expanded(flex: (data['flex'] as num?)?.toInt() ?? 1, child: child);
          
        case 'Flexible':
          return Flexible(flex: (data['flex'] as num?)?.toInt() ?? 1, fit: data['fit'] == 'tight' ? FlexFit.tight : FlexFit.loose, child: child);
          
        case 'Padding':
          return Padding(padding: getEdgeInsets(data['padding']) ?? EdgeInsets.zero, child: child);
          
        case 'SizedBox':
          return SizedBox(width: data['width'] != null ? (data['width'] as num).toDouble() : null, height: data['height'] != null ? (data['height'] as num).toDouble() : null, child: child);
          
        case 'Opacity':
        case 'AnimatedOpacity':
          final op = (data['opacity'] as num?)?.toDouble() ?? 1.0;
          if (type == 'AnimatedOpacity' || data['duration'] != null) {
            return AnimatedOpacity(
              duration: Duration(milliseconds: data['duration'] != null ? (data['duration'] as num).toInt() : 300),
              curve: Curves.easeInOut,
              opacity: op, child: child,
            );
          }
          return Opacity(opacity: op, child: child);
          
        case 'Transform':
          Matrix4 mat = Matrix4.identity();
          if (data['translateX'] != null || data['translateY'] != null) {
            mat.translate((data['translateX'] as num?)?.toDouble() ?? 0.0, (data['translateY'] as num?)?.toDouble() ?? 0.0);
          }
          if (data['rotate'] != null) {
            mat.rotateZ((data['rotate'] as num).toDouble());
          }
          if (data['scale'] != null) {
            mat.scale((data['scale'] as num?)?.toDouble() ?? 1.0);
          } else if (data['scaleX'] != null || data['scaleY'] != null) {
            mat.scale((data['scaleX'] as num?)?.toDouble() ?? 1.0, (data['scaleY'] as num?)?.toDouble() ?? 1.0, 1.0);
          }
          return Transform(
            transform: mat,
            alignment: data['alignment'] == 'center' ? Alignment.center : Alignment.topLeft,
            child: child,
          );
          
        case 'ClipRRect':
          return ClipRRect(
            borderRadius: BorderRadius.circular((data['borderRadius'] as num?)?.toDouble() ?? 0.0),
            child: child,
          );
          
        case 'ClipOval':
          return ClipOval(child: child);
          
        case 'Text':
          final fontWeightStr = ConfigEngine.evaluate(data['fontWeight'], variables);
          FontWeight weight = FontWeight.normal;
          if (fontWeightStr == 'bold') weight = FontWeight.bold;
          else if (fontWeightStr != null && fontWeightStr is String && int.tryParse(fontWeightStr) != null) {
             weight = FontWeight.values[((int.parse(fontWeightStr) ~/ 100) - 1).clamp(0, 8)];
          }

          final textContent = ConfigEngine.evaluate(data['text'], variables);

          return Text(
            textContent.toString(),
            textAlign: data['textAlign'] == 'center' ? TextAlign.center : data['textAlign'] == 'right' ? TextAlign.right : TextAlign.left,
            maxLines: (data['maxLines'] as num?)?.toInt(),
            overflow: data['overflow'] == 'ellipsis' ? TextOverflow.ellipsis : null,
            style: TextStyle(
              color: ConfigEngine.parseColor(data['color'], variables) ?? Colors.white,
              fontSize: data['fontSize'] != null ? (data['fontSize'] as num).toDouble() : 14,
              fontWeight: weight,
              fontStyle: data['fontStyle'] == 'italic' ? FontStyle.italic : FontStyle.normal,
              fontFamily: data['fontFamily'],
              letterSpacing: (data['letterSpacing'] as num?)?.toDouble(),
              wordSpacing: (data['wordSpacing'] as num?)?.toDouble(),
              height: (data['lineHeight'] as num?)?.toDouble(),
              shadows: data['glow'] != null || data['shadows'] != null ? [
                if (data['glow'] != null) Shadow(
                  color: ConfigEngine.parseColor(data['glowColor'], variables) ?? Colors.white,
                  blurRadius: (data['glow'] as num).toDouble(),
                ),
                if (data['shadows'] != null) ...((data['shadows'] as List).map((s) {
                  final sData = s as Map<String, dynamic>;
                  return Shadow(
                    color: ConfigEngine.parseColor(sData['color'], variables) ?? Colors.black,
                    blurRadius: (sData['blurRadius'] as num?)?.toDouble() ?? 0.0,
                    offset: Offset((sData['offsetX'] as num?)?.toDouble() ?? 0.0, (sData['offsetY'] as num?)?.toDouble() ?? 0.0),
                  );
                }))
              ] : null,
            ),
          );
          
        case 'Image':
          final imgUrl = ConfigEngine.substitute(data['url'] as String?, variables);
          if (imgUrl.isEmpty) return const SizedBox.shrink();
          return Image.network(
            imgUrl,
            width: data['width'] != null ? (data['width'] as num).toDouble() : null,
            height: data['height'] != null ? (data['height'] as num).toDouble() : null,
            fit: data['fit'] == 'cover' ? BoxFit.cover : data['fit'] == 'fill' ? BoxFit.fill : BoxFit.contain,
            color: ConfigEngine.parseColor(data['color'], variables),
            colorBlendMode: data['blendMode'] == 'srcATop' ? BlendMode.srcATop : data['blendMode'] == 'modulate' ? BlendMode.modulate : data['blendMode'] == 'overlay' ? BlendMode.overlay : BlendMode.clear,
          );
          
        case 'Blur':
          return BackdropFilter(
            filter: ImageFilter.blur(sigmaX: (data['sigmaX'] as num?)?.toDouble() ?? 5.0, sigmaY: (data['sigmaY'] as num?)?.toDouble() ?? 5.0),
            child: child,
          );

        case 'ConfigAnimation':
          return _ConfigAnimation(
            effects: data['effects'] as List? ?? [],
            child: child,
          );
          
        case 'AppPlaylistInput':
          return const SizedBox.shrink(); 

        case 'AppScrollable':
          return SmoothScrollWrapper(
            builder: (context, controller) => SingleChildScrollView(
              controller: controller,
              physics: const BouncingScrollPhysics(),
              child: child,
            ),
          );
        default:
          return const SizedBox.shrink();
      }
    }

    final inner = buildInner();
    if (data['onTap'] != null && actions.containsKey(data['onTap'])) {
      return _ConfigClickable(
        onTap: actions[data['onTap']]!,
        hoverScale: (data['hoverScale'] as num?)?.toDouble() ?? 1.05,
        pressScale: (data['pressScale'] as num?)?.toDouble() ?? 0.95,
        duration: (data['animationDuration'] as num?)?.toInt() ?? 150,
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
      
      if (data.containsKey('templates')) {
        ConfigEngine.templates = Map<String, Map<String, dynamic>>.from(data['templates']);
      }

      return buildStaticWidget(data, widget.variables, widget.actions, widget.builders);
    } catch (e) {
      return Center(child: Text('Config Error: $e', style: const TextStyle(color: Colors.red)));
    }
  }
}
