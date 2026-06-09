import 'package:flutter/material.dart';

import '../../shared/theme.dart';

class SplashScreen extends StatefulWidget {
  final Widget nextScreen;

  const SplashScreen({super.key, required this.nextScreen});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );

    // Entry fade in: ~850ms
    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 850),
      // Hold visible: ~1800ms
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 1800),
      // Exit fade out: ~850ms
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 850),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    // Scale animation for a smooth "breathing" / zoom effect
    _scaleAnimation = TweenSequence<double>([
      // Zoom in slowly during entry
      TweenSequenceItem(tween: Tween(begin: 0.8, end: 1.0), weight: 850),
      // Hold steady
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 1800),
      // Zoom out slightly during exit
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.2), weight: 850),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _navigateToNext();
      }
    });

    // Start animation
    _controller.forward();
  }

  void _navigateToNext() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            widget.nextScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: child,
              ),
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.accent.withOpacity(0.5),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accent.withOpacity(0.2),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/logo-no-border.png',
                  width: 90,
                  height: 90,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 32),
              // App Name
              const Text(
                'MOBILE GAMEPAD',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4,
                  color: AppTheme.textPri,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'LOW-LATENCY EDITION',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 8,
                  color: AppTheme.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
