import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lizaplayer/utils/font_styler.dart';
import 'dart:ui';

class GlassToastWidget extends ConsumerStatefulWidget {
  final String message;
  final bool isError;
  final bool isLoading;
  final double scale;
  final bool isDark;
  final bool glassEnabled;
  final VoidCallback onDismiss;

  const GlassToastWidget({
    super.key,
    required this.message,
    required this.isError,
    this.isLoading = false,
    required this.scale,
    required this.isDark,
    required this.glassEnabled,
    required this.onDismiss,
  });

  @override
  ConsumerState<GlassToastWidget> createState() => _GlassToastWidgetState();
}

class _GlassToastWidgetState extends ConsumerState<GlassToastWidget> with SingleTickerProviderStateMixin, FontStyler {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(1.2, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutQuart,
    ));

    _controller.forward();
    
    if (!widget.isLoading) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          _controller.reverse().then((_) => widget.onDismiss());
        }
      });
    }
  }

  @override
  void didUpdateWidget(GlassToastWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLoading && !widget.isLoading) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          _controller.reverse().then((_) => widget.onDismiss());
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;
    return Positioned(
      top: 40 * scale,
      right: 24 * scale,
      child: SlideTransition(
        position: _offsetAnimation,
        child: Material(
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16 * scale),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: (widget.isDark ? Colors.black : Colors.white).withOpacity(widget.glassEnabled ? 0.2 : 0.9),
                  borderRadius: BorderRadius.circular(16 * scale),
                  border: Border.all(
                    color: widget.isError ? Colors.redAccent.withOpacity(0.5) : (widget.isDark ? Colors.white12 : Colors.black12),
                    width: 1.5 * scale,
                  ),
                ),
                padding: EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 12 * scale),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.isLoading)
                      SizedBox(
                        width: 18 * scale,
                        height: 18 * scale,
                        child: CircularProgressIndicator(
                          strokeWidth: 2 * scale,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.primary.opacity == 0 
                              ? (widget.isDark ? Colors.white70 : Colors.black87) 
                              : Theme.of(context).colorScheme.primary
                          ),
                        ),
                      )
                    else
                      Icon(
                        widget.isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                        color: widget.isError 
                          ? Colors.redAccent 
                          : (Theme.of(context).colorScheme.primary.opacity == 0 
                              ? (widget.isDark ? Colors.white70 : Colors.black87) 
                              : Theme.of(context).colorScheme.primary),
                        size: 20 * scale,
                      ),
                    SizedBox(width: 12 * scale),
                    Text(
                      widget.message,
                      style: s(TextStyle(
                        fontSize: 14 * scale,
                        fontWeight: FontWeight.w500,
                        color: widget.isDark ? Colors.white : Colors.black87,
                      )),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
