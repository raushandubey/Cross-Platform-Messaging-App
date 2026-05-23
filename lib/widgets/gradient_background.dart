import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/colors.dart';

class GradientBackground extends StatelessWidget {
  final Widget child;

  const GradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // 1. Solid Darkest Base
          Container(color: AppColors.background),

          // 2. Violet Glow - Top Left
          Positioned(
            top: -size.height * 0.2,
            left: -size.width * 0.15,
            width: size.width * 0.6,
            height: size.height * 0.6,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accentIndigo.withValues(alpha: 0.18),
                    AppColors.accentIndigo.withValues(alpha: 0.04),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // 3. Deep Blue Glow - Bottom Right
          Positioned(
            bottom: -size.height * 0.25,
            right: -size.width * 0.15,
            width: size.width * 0.7,
            height: size.height * 0.7,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accentBlue.withValues(alpha: 0.12),
                    AppColors.accentBlue.withValues(alpha: 0.02),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // 4. Ambient Backdrop Blur overlay to blend gradients smoothly
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80.0, sigmaY: 80.0),
              child: Container(color: Colors.transparent),
            ),
          ),

          // 5. Foregrounds children
          SafeArea(
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
