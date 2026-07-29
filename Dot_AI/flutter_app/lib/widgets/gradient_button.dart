// =============================================================
//  Gradient Button Widget
//  Reusable full-width button with gradient background
// =============================================================

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GradientButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed; // null = disabled state

  const GradientButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null;

    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 58,
        decoration: BoxDecoration(
          gradient: isDisabled ? null : AppTheme.neonGradient,
          color: isDisabled ? AppTheme.surfaceLight : null,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isDisabled
              ? null
              : [
                  BoxShadow(
                    color: AppTheme.accentNeon.withValues(alpha: 0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                color: isDisabled ? AppTheme.textSecondary : Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
            ],
            Text(
              label,
              style: TextStyle(
                color: isDisabled ? AppTheme.textSecondary : Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
