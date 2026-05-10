import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class InteractiveCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double borderRadius;
  final Color? backgroundColor;
  final EdgeInsetsGeometry padding;
  final double elevation;

  const InteractiveCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius = 16,
    this.backgroundColor,
    this.padding = const EdgeInsets.all(16),
    this.elevation = 2,
  });

  @override
  State<InteractiveCard> createState() => _InteractiveCardState();
}

class _InteractiveCardState extends State<InteractiveCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _elevationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _elevationAnimation = Tween<double>(
      begin: widget.elevation,
      end: 0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    HapticFeedback.lightImpact();
    _controller.forward();
  }

  void _onTapUp(TapUpDetails _) {
    _controller.reverse();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  void _onLongPressStart(LongPressStartDetails _) {
    HapticFeedback.mediumImpact();
    _controller.forward();
  }

  void _onLongPressEnd(LongPressEndDetails _) {
    _controller.reverse();
    widget.onLongPress?.call();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              color: widget.backgroundColor ?? Colors.white,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: _elevationAnimation.value * 4,
                  offset: Offset(0, _elevationAnimation.value),
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTapDown: widget.onTap != null ? _onTapDown : null,
        onTapUp: widget.onTap != null ? _onTapUp : null,
        onTapCancel: widget.onTap != null ? _onTapCancel : null,
        onTap: widget.onTap,
        onLongPressStart: widget.onLongPress != null ? _onLongPressStart : null,
        onLongPressEnd: widget.onLongPress != null ? _onLongPressEnd : null,
        child: Padding(
          padding: widget.padding,
          child: widget.child,
        ),
      ),
    );
  }
}
