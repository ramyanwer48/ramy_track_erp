import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _beamController;
  late Animation<double> _beamAnimation;

  // ==========================================
  // 🎯 التعديل الدقيق: النور يمين سنة، وتحت حاجة بسيطة جداً
  // ==========================================
  // الكشاف الأيسر (الأمامي)
  final double leftLightTop = 0.360; // نزل تحت شعرة (كان 0.355)
  final double leftLightLeft = 0.29; // رحل يمين سنة (كان 0.27)

  // الكشاف الأيمن (الخلفي/الداخلي)
  final double rightLightTop = 0.350; // نزل تحت شعرة (كان 0.345)
  final double rightLightLeft = 0.39; // رحل يمين سنة (كان 0.37)

  // درجة ميلان النور
  final double beamAngle = -0.15;
  // ==========================================

  @override
  void initState() {
    super.initState();

    _beamController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _beamAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _beamController, curve: Curves.easeOut),
    );

    _beamController.forward();

    // الانتقال لشاشة الدخول بعد 4 ثواني
    Future.delayed(const Duration(seconds: 2), () {
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
    _beamController.dispose();
    super.dispose();
  }

  Widget _buildLightBeam() {
    return AnimatedBuilder(
      animation: _beamAnimation,
      builder: (context, child) {
        return Transform.rotate(
          angle: beamAngle,
          alignment: Alignment.centerRight,
          child: Transform.scale(
            scaleX: _beamAnimation.value,
            alignment: Alignment.centerRight,
            child: Opacity(
              opacity: _beamAnimation.value,
              child: Container(
                width: 90,
                height: 5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: [
                      Colors.white.withOpacity(0.9),
                      const Color(0xFF00D2FF).withOpacity(0.6),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.3, 1.0],
                  ),
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00D2FF).withOpacity(0.5),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
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
            // 1. الصورة
            Image.asset(
              'assets/images/Splash.png',
              fit: BoxFit.cover,
              width: size.width,
              height: size.height,
            ),

            // 2. الكشافات بعد الضبط الدقيق
            Positioned(
              top: size.height * leftLightTop,
              right: size.width - (size.width * leftLightLeft),
              child: _buildLightBeam(),
            ),
            Positioned(
              top: size.height * rightLightTop,
              right: size.width - (size.width * rightLightLeft),
              child: _buildLightBeam(),
            ),

            // 3. الخط المضيء تحت الكلمة
            Positioned(
              top: size.height * 0.54,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedBuilder(
                  animation: _beamAnimation,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _beamAnimation.value,
                      child: Container(
                        height: 2.5,
                        width: 250,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              const Color(0xFF00D2FF).withOpacity(0.8),
                              Colors.white,
                              const Color(0xFF00D2FF).withOpacity(0.8),
                              Colors.transparent
                            ],
                            stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0xFF00D2FF),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // 4. اللودينج
            Positioned(
              bottom: size.height * 0.24,
              left: 0,
              right: 0,
              child: const Center(
                child: SizedBox(
                  width: 45,
                  height: 45,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00D2FF)),
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