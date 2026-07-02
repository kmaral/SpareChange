import 'package:flutter/material.dart';

class AnimatedSplashScreen extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const AnimatedSplashScreen({
    super.key,
    required this.child,
    this.duration = const Duration(seconds: 2),
  });

  @override
  State<AnimatedSplashScreen> createState() => _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends State<AnimatedSplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _noteController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _slideAnimation;
  bool _showContent = false;

  @override
  void initState() {
    super.initState();

    // Fade controller for the entire splash screen
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    // Animation controller for the note
    _noteController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Scale animation for the note (pulsing effect)
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.8,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.95,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.95,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 35,
      ),
    ]).animate(_noteController);

    // Slide animation for the note (up and down)
    _slideAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 20,
          end: -10,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: -10,
          end: 0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
    ]).animate(_noteController);

    // Start the note animation
    _noteController.forward().then((_) {
      // After animation completes, fade out and show content
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _fadeController.forward().then((_) {
            if (mounted) {
              setState(() => _showContent = true);
            }
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showContent) {
      return widget.child;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF121212) : Colors.white;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        color: backgroundColor,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated currency icon
              AnimatedBuilder(
                animation: _noteController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _slideAnimation.value),
                    child: Transform.scale(
                      scale: _scaleAnimation.value,
                      child: _CurrencyIcon(color: primaryColor, size: 120),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
              // App title
              Text(
                'Spare Change',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Track Your Currency',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 48),
              // Loading indicator
              SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Custom currency icon widget with animated note
class _CurrencyIcon extends StatelessWidget {
  final Color color;
  final double size;

  const _CurrencyIcon({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.22),
      ),
      child: Stack(
        children: [
          // White border frame
          Center(
            child: Container(
              width: size * 0.7,
              height: size * 0.45,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(size * 0.08),
              ),
            ),
          ),
          // Teal inner background
          Center(
            child: Container(
              width: size * 0.65,
              height: size * 0.4,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(size * 0.06),
              ),
            ),
          ),
          // Decorative circles on left
          Positioned(
            left: size * 0.22,
            top: size * 0.35,
            child: Container(
              width: size * 0.08,
              height: size * 0.08,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Decorative circles on right
          Positioned(
            right: size * 0.22,
            top: size * 0.35,
            child: Container(
              width: size * 0.08,
              height: size * 0.08,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Rupee symbol in center
          Center(
            child: Container(
              width: size * 0.25,
              height: size * 0.25,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: CustomPaint(
                  size: Size(size * 0.15, size * 0.15),
                  painter: _RupeeSymbolPainter(color: color),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter for rupee symbol
class _RupeeSymbolPainter extends CustomPainter {
  final Color color;

  _RupeeSymbolPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Top horizontal line
    canvas.drawLine(
      Offset(size.width * 0.1, size.height * 0.15),
      Offset(size.width * 0.9, size.height * 0.15),
      paint,
    );

    // Middle horizontal line
    canvas.drawLine(
      Offset(size.width * 0.1, size.height * 0.35),
      Offset(size.width * 0.9, size.height * 0.35),
      paint,
    );

    // Curved stroke (simplified rupee symbol)
    final path = Path();
    path.moveTo(size.width * 0.5, size.height * 0.35);
    path.quadraticBezierTo(
      size.width * 0.7,
      size.height * 0.4,
      size.width * 0.7,
      size.height * 0.6,
    );
    path.quadraticBezierTo(
      size.width * 0.7,
      size.height * 0.85,
      size.width * 0.4,
      size.height * 0.9,
    );

    canvas.drawPath(path, paint);

    // Diagonal line
    canvas.drawLine(
      Offset(size.width * 0.45, size.height * 0.35),
      Offset(size.width * 0.25, size.height * 0.9),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
