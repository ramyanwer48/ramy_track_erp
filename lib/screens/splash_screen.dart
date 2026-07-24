import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    // إفكت إضاءة الخط المتحرك
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.1, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // الانتقال لشاشة الدخول بعد 4 ثواني
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF020B19),
      body: SizedBox(
        width: size.width,
        height: size.height,
        child: Stack(
          children: [
            // 1. صورتك الأصلية مفرودة بالكامل على الشاشة (بدون أي نصوص من عندي نهائياً)
            Image.asset(
              'assets/images/Splash.png',
              fit: BoxFit.cover, // بيفرد صورتك تملى الشاشة
              width: size.width,
              height: size.height,
            ),

            // 2. الخط المضيء المتحرك (فوق الصورة)
            Positioned(
              // الرقم ده (0.54) بيحدد مكان الخط. لو محتاج ترفعه أو تنزله، غيره لـ 0.52 أو 0.56 مثلاً
              top: size.height * 0.54,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedBuilder(
                  animation: _glowAnimation,
                  builder: (context, child) {
                    return Container(
                      height: 2.5,
                      width: 250,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            const Color(0xFF00D2FF).withValues(alpha: _glowAnimation.value),
                            Colors.white.withValues(alpha: _glowAnimation.value),
                            const Color(0xFF00D2FF).withValues(alpha: _glowAnimation.value),
                            Colors.transparent
                          ],
                          stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00D2FF).withValues(alpha: _glowAnimation.value * 0.6),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

            // 3. دائرة التحميل المتحركة (فوق الصورة)
            Positioned(
              // الرقم ده (0.24) بيحدد مكان الدائرة من تحت. لو مش متسنترة غيره براحتك
              bottom: size.height * 0.24,
              left: 0,
              right: 0,
              child: Center(
                child: SizedBox(
                  width: 45,
                  height: 45,
                  child: CircularProgressIndicator(
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00D2FF)),
                    strokeWidth: 3.0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}