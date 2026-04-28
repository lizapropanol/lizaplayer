import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SmoothScrollWrapper extends ConsumerStatefulWidget {
  final Widget Function(BuildContext context, ScrollController controller) builder;
  final ScrollController? controller;
  const SmoothScrollWrapper({super.key, required this.builder, this.controller});
  @override
  ConsumerState<SmoothScrollWrapper> createState() => _SmoothScrollWrapperState();
}

class _SmoothScrollWrapperState extends ConsumerState<SmoothScrollWrapper> with SingleTickerProviderStateMixin {
  late ScrollController _controller;
  double _targetPixels = 0;
  double _currentPixels = 0;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? ScrollController();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _animController.addListener(_updateScroll);
    _controller.addListener(_handleManualScroll);
  }

  void _handleManualScroll() {
    if (!_animController.isAnimating && _controller.hasClients) {
      _currentPixels = _controller.position.pixels;
      _targetPixels = _currentPixels;
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _controller.removeListener(_handleManualScroll);
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  void _handleScroll(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      if (!_controller.hasClients) return;
      
      if (!_animController.isAnimating) {
        _currentPixels = _controller.position.pixels;
        _targetPixels = _currentPixels;
        _animController.repeat();
      }
      
      final delta = event.scrollDelta.dy != 0 ? event.scrollDelta.dy : event.scrollDelta.dx;
      _targetPixels = (_targetPixels + delta).clamp(
        _controller.position.minScrollExtent, 
        _controller.position.maxScrollExtent
      );
    }
  }

  void _updateScroll() {
    if (!_controller.hasClients) return;

    final diff = _targetPixels - _currentPixels;
    if (diff.abs() < 0.5) {
      _currentPixels = _targetPixels;
      _controller.jumpTo(_targetPixels);
      _animController.stop();
      return;
    }

    _currentPixels += diff * 0.12;
    _controller.jumpTo(_currentPixels);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerSignal: _handleScroll,
      child: widget.builder(context, _controller),
    );
  }
}
