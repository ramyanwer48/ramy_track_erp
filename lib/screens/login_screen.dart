import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _rememberMe = true;

  final LocalAuthentication auth = LocalAuthentication();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
    _initGoogleSignIn(); // تهيئة جوجل للنسخة الحديثة

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  // دالة تهيئة جوجل
  Future<void> _initGoogleSignIn() async {
    try {
      await GoogleSignIn.instance.initialize();
    } catch (e) {
      debugPrint('Google Sign-In initialization error: $e');
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('saved_email');
    final savedPassword = prefs.getString('saved_password');

    if (savedEmail != null && savedPassword != null) {
      setState(() {
        _emailController.text = savedEmail;
        _passwordController.text = savedPassword;
        _rememberMe = true;
      });
    } else {
      setState(() {
        _rememberMe = false;
      });
    }
  }

  void _showCenteredSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      ),
    );
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showCenteredSnackBar('⚠️ برجاء إدخال البريد الإلكتروني وكلمة المرور أولاً', Colors.orange);
      return;
    }

    // تم إزالة رسالة "جاري تسجيل الدخول..." هنا بناءً على طلبك

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);

      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setString('saved_email', email);
        await prefs.setString('saved_password', password);
      } else {
        await prefs.remove('saved_email');
        await prefs.remove('saved_password');
      }

      _showCenteredSnackBar('✅ تم تسجيل الدخول بنجاح!', Colors.green);

    } on FirebaseAuthException catch (e) {
      String errorMessage = 'حدث خطأ أثناء تسجيل الدخول';
      if (e.code == 'user-not-found') {
        errorMessage = 'لا يوجد حساب مسجل بهذا البريد الإلكتروني';
      } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        errorMessage = 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'صيغة البريد الإلكتروني غير صحيحة';
      }
      _showCenteredSnackBar('❌ $errorMessage', Colors.redAccent);
    } catch (e) {
      _showCenteredSnackBar('❌ حدث خطأ غير متوقع، يرجى المحاولة لاحقاً', Colors.redAccent);
    }
  }

  // --- دالة تسجيل الدخول بـ Google المحدثة والصحيحة 100% ---
  Future<void> _handleGoogleSignIn() async {
    try {
      final googleUser = await GoogleSignIn.instance.authenticate();
      if (googleUser == null) return;

      final googleAuth = await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      _showCenteredSnackBar('✅ تم تسجيل الدخول بواسطة Google بنجاح!', Colors.green);

    } catch (e) {
      _showCenteredSnackBar('❌ فشل تسجيل الدخول باستخدام Google', Colors.redAccent);
    }
  }

  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController(text: _emailController.text.trim());

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF0B172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: const BorderSide(color: Color(0xFF1E2D4A)),
          ),
          title: const Text(
            'استعادة كلمة المرور',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'أدخل بريدك الإلكتروني وسنرسل لك رابطاً لتعيين كلمة مرور جديدة.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 15),
              SizedBox(
                height: 44,
                child: TextField(
                  controller: resetEmailController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'البريد الإلكتروني',
                    hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFF020B19),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF1E2D4A)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF00D2FF)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0072FF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final email = resetEmailController.text.trim();
                if (email.isEmpty) return;

                Navigator.pop(context);

                try {
                  await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                  _showCenteredSnackBar('✅ تم إرسال رابط استعادة كلمة المرور إلى بريدك بنجاح.', Colors.green);
                } catch (e) {
                  _showCenteredSnackBar('❌ حدث خطأ، تأكد من صحة البريد الإلكتروني.', Colors.redAccent);
                }
              },
              child: const Text('إرسال الرابط', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleFingerprint() async {
    try {
      final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await auth.isDeviceSupported();

      if (!canAuthenticate) {
        _showCenteredSnackBar('❌ جهازك لا يدعم تسجيل الدخول بالبصمة', Colors.redAccent);
        return;
      }

      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'قم بوضع إصبعك على المستشعر لتسجيل الدخول',
      );

      if (didAuthenticate) {
        _showCenteredSnackBar('✅ تم تسجيل الدخول بالبصمة بنجاح!', Colors.green);
      }
    } on PlatformException catch (e) {
      _showCenteredSnackBar('❌ كود الخطأ: ${e.code}', Colors.redAccent);
    } catch (e) {
      _showCenteredSnackBar('❌ خطأ: ${e.toString()}', Colors.redAccent);
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );

    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final topPadding = mediaQuery.padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFF020B19),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: SizedBox(
              height: screenHeight,
              child: Stack(
                children: [
                  Positioned(
                    top: -30,
                    left: 0,
                    right: 0,
                    height: screenHeight * 0.44,
                    child: Image.asset(
                      'assets/images/background.png',
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: const Color(0xFF020B19),
                          child: const Center(
                            child: Icon(Icons.image_not_supported_outlined, color: Colors.white24, size: 40),
                          ),
                        );
                      },
                    ),
                  ),
                  Positioned(
                    top: topPadding + screenHeight * 0.21,
                    left: 20,
                    right: 20,
                    child: Column(
                      children: [
                        RichText(
                          textAlign: TextAlign.center,
                          text: const TextSpan(
                            children: [
                              TextSpan(
                                text: 'Ramy Track ',
                                style: TextStyle(
                                  fontSize: 27,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                  shadows: [Shadow(blurRadius: 10, color: Colors.black54, offset: Offset(0, 2))],
                                ),
                              ),
                              TextSpan(
                                text: 'ERP',
                                style: TextStyle(
                                  fontSize: 27,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF00D2FF),
                                  letterSpacing: 0.5,
                                  shadows: [Shadow(blurRadius: 12, color: Color(0xFF00D2FF), offset: Offset(0, 0))],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'إدارة تتبع النقل والحسابات',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFB0C4DE),
                            letterSpacing: 0.3,
                            shadows: [Shadow(blurRadius: 6, color: Colors.black, offset: Offset(0, 1))],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Container(
                                height: 1.5,
                                margin: const EdgeInsets.only(left: 12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.transparent, const Color(0xFF00D2FF).withValues(alpha: 0.8)],
                                  ),
                                ),
                              ),
                            ),
                            const Text(
                              'مرحبًا بعودتك',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                                shadows: [
                                  Shadow(blurRadius: 10, color: Color(0xFF00D2FF), offset: Offset(0, 0)),
                                  Shadow(blurRadius: 8, color: Colors.black, offset: Offset(0, 2)),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Container(
                                height: 1.5,
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [const Color(0xFF00D2FF).withValues(alpha: 0.8), Colors.transparent],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      children: [
                        SizedBox(height: screenHeight * 0.35 + topPadding),
                        Expanded(
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: const [
                                        Icon(Icons.email_outlined, color: Color(0xFF00D2FF), size: 16),
                                        SizedBox(width: 6),
                                        Text('البريد الإلكتروني', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    SizedBox(
                                      height: 44,
                                      child: TextFormField(
                                        controller: _emailController,
                                        style: const TextStyle(color: Colors.white, fontSize: 13),
                                        keyboardType: TextInputType.emailAddress,
                                        decoration: InputDecoration(
                                          hintText: 'أدخل بريدك الإلكتروني',
                                          hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                                          filled: true,
                                          fillColor: const Color(0xFF0B172A).withValues(alpha: 0.85),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: const BorderSide(color: Color(0xFF1E2D4A)),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: const BorderSide(color: Color(0xFF00D2FF)),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: const [
                                        Icon(Icons.lock_outline, color: Color(0xFF00D2FF), size: 16),
                                        SizedBox(width: 6),
                                        Text('كلمة المرور', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    SizedBox(
                                      height: 44,
                                      child: TextFormField(
                                        controller: _passwordController,
                                        obscureText: !_isPasswordVisible,
                                        style: const TextStyle(color: Colors.white, fontSize: 13),
                                        decoration: InputDecoration(
                                          hintText: 'أدخل كلمة المرور',
                                          hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                                          filled: true,
                                          fillColor: const Color(0xFF0B172A).withValues(alpha: 0.85),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                          prefixIcon: IconButton(
                                            icon: Icon(
                                              _isPasswordVisible ? Icons.visibility : Icons.visibility_outlined,
                                              color: Colors.white38,
                                              size: 18,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _isPasswordVisible = !_isPasswordVisible;
                                              });
                                            },
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: const BorderSide(color: Color(0xFF1E2D4A)),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: const BorderSide(color: Color(0xFF00D2FF)),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: Checkbox(
                                            value: _rememberMe,
                                            activeColor: const Color(0xFF0072FF),
                                            checkColor: Colors.white,
                                            side: const BorderSide(color: Colors.white38),
                                            onChanged: (val) {
                                              setState(() {
                                                _rememberMe = val ?? false;
                                              });
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Text('تذكرني', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                      ],
                                    ),
                                    GestureDetector(
                                      onTap: _showForgotPasswordDialog,
                                      child: const Text(
                                        'نسيت كلمة المرور؟',
                                        style: TextStyle(color: Color(0xFF00D2FF), fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  width: double.infinity,
                                  height: 45,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF0072FF), Color(0xFF00D2FF)],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF00D2FF).withValues(alpha: 0.3),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: _handleLogin,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Text(
                                          'تسجيل الدخول',
                                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                        const SizedBox(width: 10),
                                        Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: BoxDecoration(
                                            border: Border.all(color: Colors.white70),
                                            borderRadius: BorderRadius.circular(5),
                                          ),
                                          child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 14),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Row(
                                  children: const [
                                    Expanded(child: Divider(color: Colors.white12)),
                                    Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 12.0),
                                      child: Text('أو', style: TextStyle(color: Colors.white38, fontSize: 11)),
                                    ),
                                    Expanded(child: Divider(color: Colors.white12)),
                                  ],
                                ),
                                GestureDetector(
                                  onTap: _handleFingerprint,
                                  child: Column(
                                    children: [
                                      AnimatedBuilder(
                                        animation: _pulseAnimation,
                                        builder: (context, child) {
                                          return Container(
                                            width: 46,
                                            height: 46,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(color: const Color(0xFF00D2FF), width: 1.5),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(0xFF00D2FF).withValues(alpha: 0.5),
                                                  blurRadius: 12 * _pulseAnimation.value,
                                                  spreadRadius: 3 * _pulseAnimation.value,
                                                ),
                                              ],
                                            ),
                                            child: const Icon(Icons.fingerprint, color: Color(0xFF00D2FF), size: 26),
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 5),
                                      const Text('الدخول بالبصمة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                      const Text('للدخول السريع والأمن', style: TextStyle(color: Colors.white38, fontSize: 10)),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: const [
                                    Expanded(child: Divider(color: Colors.white12)),
                                    Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 12.0),
                                      child: Text('أو', style: TextStyle(color: Colors.white38, fontSize: 11)),
                                    ),
                                    Expanded(child: Divider(color: Colors.white12)),
                                  ],
                                ),

                                // --- تم استرجاع تصميم جوجل الشيك ---
                                // --- تصميم جوجل الشيك بدون المستطيل الرمادي المزعج ---
                                InkWell(
                                  onTap: _handleGoogleSignIn,
                                  splashColor: Colors.transparent, // بيلغي لون الانفجار الرمادي
                                  highlightColor: Colors.transparent, // بيلغي لون التظليل الرمادي
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      CustomGoogleLogo(size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'متابعة باستخدام Google',
                                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                // -------------------------------------

                                Container(
                                  width: double.infinity,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFF0072FF)),
                                  ),
                                  child: TextButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const SignupScreen(),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.person_add_alt_1_outlined, color: Color(0xFF00D2FF), size: 18),
                                    label: const Text(
                                      'إنشاء حساب جديد',
                                      style: TextStyle(color: Color(0xFF00D2FF), fontSize: 13, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0B172A),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.white10),
                                      ),
                                      child: Row(
                                        children: const [
                                          Icon(Icons.language, color: Colors.white70, size: 14),
                                          SizedBox(width: 4),
                                          Text('العربية', style: TextStyle(color: Colors.white, fontSize: 11)),
                                          Icon(Icons.keyboard_arrow_down, color: Colors.white70, size: 14),
                                        ],
                                      ),
                                    ),
                                    const Text(
                                      'Version 1.0.0',
                                      style: TextStyle(color: Colors.white38, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- كلاسات رسم لوجو جوجل (مهمة عشان اللوجو يظهر) ---
class CustomGoogleLogo extends StatelessWidget {
  final double size;
  const CustomGoogleLogo({super.key, this.size = 24.0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: GoogleLogoPainter()),
    );
  }
}

class GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    final Paint blue = Paint()..color = const Color(0xFF4285F4);
    final Paint green = Paint()..color = const Color(0xFF34A853);
    final Paint yellow = Paint()..color = const Color(0xFFFBBC05);
    final Paint red = Paint()..color = const Color(0xFFEA4335);

    final Path bluePath = Path()
      ..moveTo(w * 0.95, h * 0.5)
      ..cubicTo(w * 0.95, h * 0.45, w * 0.94, h * 0.40, w * 0.93, h * 0.35)
      ..lineTo(w * 0.5, h * 0.35)
      ..lineTo(w * 0.5, h * 0.55)
      ..lineTo(w * 0.76, h * 0.55)
      ..cubicTo(w * 0.75, h * 0.62, w * 0.71, h * 0.68, w * 0.65, h * 0.72)
      ..lineTo(w * 0.65, h * 0.86)
      ..lineTo(w * 0.78, h * 0.86)
      ..cubicTo(w * 0.88, h * 0.77, w * 0.95, h * 0.65, w * 0.95, h * 0.5);
    canvas.drawPath(bluePath, blue);

    final Path greenPath = Path()
      ..moveTo(w * 0.65, h * 0.72)
      ..cubicTo(w * 0.61, h * 0.75, w * 0.56, h * 0.77, w * 0.5, h * 0.77)
      ..cubicTo(w * 0.38, h * 0.77, w * 0.28, h * 0.69, w * 0.24, h * 0.58)
      ..lineTo(w * 0.11, h * 0.58)
      ..lineTo(w * 0.11, h * 0.68)
      ..cubicTo(w * 0.18, h * 0.83, w * 0.33, h * 0.93, w * 0.5, h * 0.93)
      ..cubicTo(w * 0.62, h * 0.93, w * 0.71, h * 0.89, w * 0.78, h * 0.86)
      ..lineTo(w * 0.65, h * 0.72);
    canvas.drawPath(greenPath, green);

    final Path yellowPath = Path()
      ..moveTo(w * 0.24, h * 0.58)
      ..cubicTo(w * 0.23, h * 0.55, w * 0.22, h * 0.52, w * 0.22, h * 0.48)
      ..cubicTo(w * 0.22, h * 0.44, w * 0.23, h * 0.41, w * 0.24, h * 0.38)
      ..lineTo(w * 0.24, h * 0.28)
      ..lineTo(w * 0.11, h * 0.28)
      ..cubicTo(w * 0.07, h * 0.34, w * 0.05, h * 0.41, w * 0.05, h * 0.48)
      ..cubicTo(w * 0.05, h * 0.55, w * 0.07, h * 0.62, w * 0.11, h * 0.68)
      ..lineTo(w * 0.24, h * 0.58);
    canvas.drawPath(yellowPath, yellow);

    final Path redPath = Path()
      ..moveTo(w * 0.24, h * 0.38)
      ..cubicTo(w * 0.28, h * 0.27, w * 0.38, h * 0.19, w * 0.5, h * 0.19)
      ..cubicTo(w * 0.57, h * 0.19, w * 0.64, h * 0.22, w * 0.69, h * 0.26)
      ..lineTo(w * 0.80, h * 0.15)
      ..cubicTo(w * 0.72, h * 0.08, w * 0.62, h * 0.04, w * 0.5, h * 0.04)
      ..cubicTo(w * 0.33, h * 0.04, w * 0.18, h * 0.14, w * 0.11, h * 0.28)
      ..lineTo(w * 0.24, h * 0.38);
    canvas.drawPath(redPath, red);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}