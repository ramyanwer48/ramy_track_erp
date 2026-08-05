import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'signup_screen.dart';
import 'dashboard_screen.dart';

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
  String _currentLanguage = 'العربية';

  final LocalAuthentication auth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
    _checkInitialBiometricLogin();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  // --- ميزة البصمة التلقائية (مع انتظار اكتمال الرسم 100% لمنع الشاشة السوداء) ---
  Future<void> _checkInitialBiometricLogin() async {
    String? isBiometricEnabled = await _secureStorage.read(key: 'biometric_enabled');

    if (isBiometricEnabled == 'true') {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          _handleFingerprint(autoLogin: true);
        }
      });
    }
  }

  // --- دالة البصمة البنكية (تم التعديل لتتوافق مع إصدار المكتبة لديك) ---
  Future<void> _handleFingerprint({bool autoLogin = false}) async {
    try {
      String? isEnabled = await _secureStorage.read(key: 'biometric_enabled');
      if (isEnabled != 'true') {
        if (!autoLogin) _showCenteredSnackBar('⚠️ يرجى تسجيل الدخول بالبريد وكلمة المرور أولاً لتفعيل البصمة', Colors.orange);
        return;
      }

      final bool canCheck = await auth.canCheckBiometrics || await auth.isDeviceSupported();
      if (!canCheck) {
        if (!autoLogin) _showCenteredSnackBar(_getText('no_fingerprint'), Colors.redAccent);
        return;
      }

      final bool didAuthenticate = await auth.authenticate(
        localizedReason: _getText('fingerprint_prompt'),
      );

      // إجبار فلاتر على إعادة رسم الشاشة فوراً فور انتهاء/إغلاق نافذة البصمة
      if (mounted) {
        setState(() {});
      }

      if (didAuthenticate) {
        String? savedEmail = await _secureStorage.read(key: 'bio_email');
        String? savedPassword = await _secureStorage.read(key: 'bio_password');

        if (savedEmail != null && savedPassword != null) {
          if (!mounted) return;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => const Center(child: CircularProgressIndicator(color: Color(0xFF00D2FF))),
          );

          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: savedEmail,
            password: savedPassword,
          );

          if (!mounted) return;
          Navigator.pop(context); // إغلاق مؤشر التحميل
          ScaffoldMessenger.of(context).clearSnackBars();
          _goToDashboard();
        } else {
          if (!autoLogin) _showCenteredSnackBar('❌ بيانات البصمة غير صالحة، يرجى تسجيل الدخول يدوياً', Colors.redAccent);
        }
      }
    } on PlatformException catch (e) {
      if (mounted) setState(() {});
      if (!autoLogin) _showCenteredSnackBar('❌ ${e.code}', Colors.redAccent);
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        setState(() {});
      }
      if (!autoLogin) _showCenteredSnackBar('❌ حدث خطأ في الاتصال بالخادم', Colors.redAccent);
    }
  }

  // --- الدالة الذكية لسؤال المستخدم عن تفعيل البصمة لأول مرة ---
  Future<void> _checkAndPromptBiometricSetup(String email, String password) async {
    try {
      bool canCheck = await auth.canCheckBiometrics || await auth.isDeviceSupported();
      if (canCheck) {
        final prefs = await SharedPreferences.getInstance();
        bool alreadyPrompted = prefs.getBool('biometric_prompted') ?? false;
        String? isBiometricEnabled = await _secureStorage.read(key: 'biometric_enabled');

        if (!alreadyPrompted && isBiometricEnabled != 'true') {
          if (!mounted) return;

          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => Directionality(
              textDirection: _currentLanguage == 'العربية' ? TextDirection.rtl : TextDirection.ltr,
              child: AlertDialog(
                backgroundColor: const Color(0xFF0B172A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: const BorderSide(color: Color(0xFF1E2D4A)),
                ),
                title: Row(
                  children: [
                    const Icon(Icons.fingerprint, color: Color(0xFF00D2FF)),
                    const SizedBox(width: 8),
                    Text(
                      _getText('bio_prompt_title'),
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                content: Text(
                  _getText('bio_prompt_desc'),
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                actions: [
                  TextButton(
                    onPressed: () async {
                      await prefs.setBool('biometric_prompted', true);
                      await _secureStorage.write(key: 'biometric_enabled', value: 'false');
                      if (context.mounted) Navigator.pop(context);
                      _goToDashboard();
                    },
                    child: Text(_getText('bio_prompt_later'), style: const TextStyle(color: Colors.white54)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0072FF),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () async {
                      await prefs.setBool('biometric_prompted', true);
                      await _secureStorage.write(key: 'biometric_enabled', value: 'true');
                      await _secureStorage.write(key: 'bio_email', value: email);
                      await _secureStorage.write(key: 'bio_password', value: password);

                      if (context.mounted) Navigator.pop(context);
                      _goToDashboard();
                    },
                    child: Text(_getText('bio_prompt_enable'), style: const TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          );
          return;
        }
      }
    } catch (e) {
      debugPrint('Biometric prompt error: $e');
    }
    _goToDashboard();
  }

  void _goToDashboard() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const DashboardScreen()),
    );
  }

  String _getText(String key) {
    final texts = {
      'العربية': {
        'subtitle': 'إدارة تتبع النقل والحسابات',
        'welcome_back': 'مرحبًا بعودتك',
        'email': 'البريد الإلكتروني',
        'email_hint': 'أدخل بريدك الإلكتروني',
        'password': 'كلمة المرور',
        'password_hint': 'أدخل كلمة المرور',
        'remember_me': 'تذكرني',
        'forgot_password': 'نسيت كلمة المرور؟',
        'login_btn': 'تسجيل الدخول',
        'or': 'أو',
        'fingerprint': 'الدخول بالبصمة',
        'fingerprint_sub': 'للدخول السريع والأمن',
        'google_btn': 'متابعة باستخدام Google',
        'signup_btn': 'إنشاء حساب جديد',
        'enter_credentials': '⚠️ برجاء إدخال البريد الإلكتروني وكلمة المرور أولاً',
        'google_fail': '❌ فشل تسجيل الدخول باستخدام Google',
        'no_fingerprint': '❌ جهازك لا يدعم تسجيل الدخول بالبصمة',
        'fingerprint_prompt': 'قم بوضع إصبعك على المستشعر لتسجيل الدخول',
        'err_not_found': 'لا يوجد حساب مسجل بهذا البريد الإلكتروني',
        'err_wrong_pass': 'البريد الإلكتروني أو كلمة المرور غير صحيحة',
        'err_invalid_email': 'صيغة البريد الإلكتروني غير صحيحة',
        'err_unexpected': '❌ حدث خطأ غير متوقع، يرجى المحاولة لاحقاً',
        'forgot_title': 'استعادة كلمة المرور',
        'forgot_desc': 'أدخل بريدك الإلكتروني وسنرسل لك رابطاً لتعيين كلمة مرور جديدة.',
        'cancel': 'إلغاء',
        'send_link': 'إرسال الرابط',
        'reset_success': '✅ تم إرسال رابط استعادة كلمة المرور إلى بريدك بنجاح.',
        'reset_fail': '❌ حدث خطأ، تأكد من صحة البريد الإلكتروني.',
        'bio_prompt_title': 'تفعيل الدخول بالبصمة',
        'bio_prompt_desc': 'هل ترغب في تفعيل تسجيل الدخول بالبصمة لتسجيل الدخول السريع والآمن في المرات القادمة دون الحاجة لكتابة كلمة المرور؟',
        'bio_prompt_later': 'لاحقاً',
        'bio_prompt_enable': 'تفعيل الآن',
      },
      'English': {
        'subtitle': 'Transport & Accounts Management',
        'welcome_back': 'Welcome Back',
        'email': 'Email Address',
        'email_hint': 'Enter your email',
        'password': 'Password',
        'password_hint': 'Enter your password',
        'remember_me': 'Remember me',
        'forgot_password': 'Forgot password?',
        'login_btn': 'Login',
        'or': 'OR',
        'fingerprint': 'Fingerprint Login',
        'fingerprint_sub': 'For quick and secure access',
        'google_btn': 'Continue with Google',
        'signup_btn': 'Create New Account',
        'enter_credentials': '⚠️ Please enter email and password first',
        'google_fail': '❌ Failed to login with Google',
        'no_fingerprint': '❌ Your device does not support fingerprint',
        'fingerprint_prompt': 'Place your finger on the sensor to login',
        'err_not_found': 'No account found for this email',
        'err_wrong_pass': 'Incorrect email or password',
        'err_invalid_email': 'Invalid email format',
        'err_unexpected': '❌ An unexpected error occurred, try again later',
        'forgot_title': 'Reset Password',
        'forgot_desc': 'Enter your email and we will send a link to reset your password.',
        'cancel': 'Cancel',
        'send_link': 'Send Link',
        'reset_success': '✅ Password reset link sent successfully.',
        'reset_fail': '❌ Error occurred, check your email address.',
        'bio_prompt_title': 'Enable Fingerprint Login',
        'bio_prompt_desc': 'Would you like to enable fingerprint login for quick and secure access in the future without typing a password?',
        'bio_prompt_later': 'Later',
        'bio_prompt_enable': 'Enable Now',
      }
    };
    return texts[_currentLanguage]![key] ?? key;
  }

  void _toggleLanguage() async {
    setState(() {
      _currentLanguage = _currentLanguage == 'العربية' ? 'English' : 'العربية';
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', _currentLanguage);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLanguage = prefs.getString('app_language');
    if (savedLanguage != null) {
      setState(() {
        _currentLanguage = savedLanguage;
      });
    }

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
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
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
      _showCenteredSnackBar(_getText('enter_credentials'), Colors.orange);
      return;
    }

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

      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();

      await _checkAndPromptBiometricSetup(email, password);

    } on FirebaseAuthException catch (e) {
      String errorMessage = _getText('err_unexpected');
      if (e.code == 'user-not-found') {
        errorMessage = _getText('err_not_found');
      } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        errorMessage = _getText('err_wrong_pass');
      } else if (e.code == 'invalid-email') {
        errorMessage = _getText('err_invalid_email');
      }
      _showCenteredSnackBar('❌ $errorMessage', Colors.redAccent);
    } catch (e) {
      _showCenteredSnackBar(_getText('err_unexpected'), Colors.redAccent);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();

      if (await googleSignIn.isSignedIn()) {
        await googleSignIn.signOut();
      }

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();

      _goToDashboard();

    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      _showCenteredSnackBar('الخطأ: ${e.toString()}', Colors.redAccent);
    }
  }

  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController(text: _emailController.text.trim());

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: _currentLanguage == 'العربية' ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          backgroundColor: const Color(0xFF0B172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: const BorderSide(color: Color(0xFF1E2D4A)),
          ),
          title: Text(
            _getText('forgot_title'),
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _getText('forgot_desc'),
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 15),
              SizedBox(
                height: 44,
                child: TextField(
                  controller: resetEmailController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: _getText('email'),
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
              child: Text(_getText('cancel'), style: const TextStyle(color: Colors.white54)),
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
                  _showCenteredSnackBar(_getText('reset_success'), Colors.green);
                } catch (e) {
                  _showCenteredSnackBar(_getText('reset_fail'), Colors.redAccent);
                }
              },
              child: Text(_getText('send_link'), style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
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
          textDirection: _currentLanguage == 'العربية' ? TextDirection.rtl : TextDirection.ltr,
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
                    top: topPadding + 10,
                    left: 20,
                    child: InkWell(
                      onTap: _toggleLanguage,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0B172A).withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF1E2D4A)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.language, color: Color(0xFF00D2FF), size: 16),
                            const SizedBox(width: 6),
                            Text(
                              _currentLanguage == 'العربية' ? 'English' : 'العربية',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
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
                        Text(
                          _getText('subtitle'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
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
                            Text(
                              _getText('welcome_back'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
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
                                      children: [
                                        const Icon(Icons.email_outlined, color: Color(0xFF00D2FF), size: 16),
                                        const SizedBox(width: 6),
                                        Text(_getText('email'), style: const TextStyle(color: Colors.white70, fontSize: 12)),
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
                                          hintText: _getText('email_hint'),
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
                                      children: [
                                        const Icon(Icons.lock_outline, color: Color(0xFF00D2FF), size: 16),
                                        const SizedBox(width: 6),
                                        Text(_getText('password'), style: const TextStyle(color: Colors.white70, fontSize: 12)),
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
                                          hintText: _getText('password_hint'),
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
                                        Text(_getText('remember_me'), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                      ],
                                    ),
                                    GestureDetector(
                                      onTap: _showForgotPasswordDialog,
                                      child: Text(
                                        _getText('forgot_password'),
                                        style: const TextStyle(color: Color(0xFF00D2FF), fontSize: 12),
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
                                        Text(
                                          _getText('login_btn'),
                                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                        const SizedBox(width: 10),
                                        Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: BoxDecoration(
                                            border: Border.all(color: Colors.white70),
                                            borderRadius: BorderRadius.circular(5),
                                          ),
                                          child: Icon(
                                            _currentLanguage == 'العربية' ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded,
                                            color: Colors.white,
                                            size: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    const Expanded(child: Divider(color: Colors.white12)),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                      child: Text(_getText('or'), style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                    ),
                                    const Expanded(child: Divider(color: Colors.white12)),
                                  ],
                                ),
                                GestureDetector(
                                  onTap: () => _handleFingerprint(autoLogin: false),
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
                                      Text(_getText('fingerprint'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                      Text(_getText('fingerprint_sub'), style: const TextStyle(color: Colors.white38, fontSize: 10)),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    const Expanded(child: Divider(color: Colors.white12)),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                      child: Text(_getText('or'), style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                    ),
                                    const Expanded(child: Divider(color: Colors.white12)),
                                  ],
                                ),
                                InkWell(
                                  onTap: _handleGoogleSignIn,
                                  splashColor: Colors.transparent,
                                  highlightColor: Colors.transparent,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const CustomGoogleLogo(size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        _getText('google_btn'),
                                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
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
                                    label: Text(
                                      _getText('signup_btn'),
                                      style: const TextStyle(color: Color(0xFF00D2FF), fontSize: 13, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Text(
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