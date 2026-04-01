// =============================================================
//  Dot Loader Widget
//  Compact animated loader for inline use (buttons, etc.)
// =============================================================

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DotLoader extends StatefulWidget {
  final Color? color;
  final double size;

  const DotLoader({
    super.key,
    this.color,
    this.size = 6,
  });

  @override
  State<DotLoader> createState() => _DotLoaderState();
}

class _DotLoaderState extends State<DotLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dotColor = widget.color ?? AppTheme.primaryLight;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            // Each dot has a phase offset
            final phase = ((_controller.value * 3) - i).clamp(0.0, 1.0);
            final opacity = (phase < 0.5
                    ? phase * 2
                    : 2 - phase * 2)
                .clamp(0.3, 1.0);

            return Container(
              margin: EdgeInsets.only(right: i < 2 ? widget.size * 0.6 : 0),
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: dotColor.withOpacity(opacity),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}
