import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart'; // تمت إضافة المكتبة لقراءة اللغة

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;

  String _currentLanguage = 'العربية'; // اللغة الافتراضية لحد ما نقرأ الذاكرة

  @override
  void initState() {
    super.initState();
    _loadLanguage(); // استدعاء اللغة المحفوظة بمجرد فتح الشاشة
  }

  // دالة قراءة اللغة من الذاكرة
  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLanguage = prefs.getString('app_language');
    if (savedLanguage != null) {
      setState(() {
        _currentLanguage = savedLanguage;
      });
    }
  }

  // قاموس الكلمات لترجمة شاشة التسجيل
  String _getText(String key) {
    final texts = {
      'العربية': {
        'err_empty_fields': '⚠️ برجاء ملء جميع الحقول المطلوبة',
        'err_pass_mismatch': '❌ كلمة المرور غير متطابقة مع تأكيد كلمة المرور',
        'err_pass_length': '⚠️ كلمة المرور يجب ألا تقل عن 6 أحرف أو أرقام',
        'signup_success': '✅ تم إنشاء الحساب بنجاح!',
        'err_weak_pass': 'كلمة المرور ضعيفة جداً',
        'err_email_in_use': 'البريد الإلكتروني مستخدم بالفعل لحساب آخر',
        'err_invalid_email': 'صيغة البريد الإلكتروني غير صحيحة',
        'err_unexpected': '❌ حدث خطأ غير متوقع، يرجى المحاولة لاحقاً',
        'title_signup': 'حساب جديد',
        'subtitle_signup': 'قم بانشاء حسابك للانضمام إلى Ramy Track ERP',
        'email': 'البريد الإلكتروني',
        'email_hint': 'أدخل بريدك الإلكتروني',
        'password': 'كلمة المرور',
        'password_hint': 'أدخل كلمة المرور (6 أحرف على الأقل)',
        'confirm_password': 'تأكيد كلمة المرور',
        'confirm_password_hint': 'أعد إدخال كلمة المرور',
        'signup_btn': 'تسجيل الحساب',
        'already_have_account': 'لديك حساب بالفعل؟ ',
        'login_link': 'تسجيل الدخول',
      },
      'English': {
        'err_empty_fields': '⚠️ Please fill in all required fields',
        'err_pass_mismatch': '❌ Passwords do not match',
        'err_pass_length': '⚠️ Password must be at least 6 characters',
        'signup_success': '✅ Account created successfully!',
        'err_weak_pass': 'Password is too weak',
        'err_email_in_use': 'Email is already in use by another account',
        'err_invalid_email': 'Invalid email format',
        'err_unexpected': '❌ An unexpected error occurred, try again later',
        'title_signup': 'New Account',
        'subtitle_signup': 'Create your account to join Ramy Track ERP',
        'email': 'Email Address',
        'email_hint': 'Enter your email',
        'password': 'Password',
        'password_hint': 'Enter password (min 6 chars)',
        'confirm_password': 'Confirm Password',
        'confirm_password_hint': 'Re-enter your password',
        'signup_btn': 'Sign Up',
        'already_have_account': 'Already have an account? ',
        'login_link': 'Login',
      }
    };
    return texts[_currentLanguage]![key] ?? key;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showCenteredSnackBar(String message, Color color, {int seconds = 2}) {
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
        duration: Duration(seconds: seconds),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      ),
    );
  }

  Future<void> _handleSignup() async {
    if (_isLoading) return;

    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      _showCenteredSnackBar(_getText('err_empty_fields'), Colors.orange, seconds: 2);
      return;
    }

    if (password != confirmPassword) {
      _showCenteredSnackBar(_getText('err_pass_mismatch'), Colors.redAccent, seconds: 2);
      return;
    }

    if (password.length < 6) {
      _showCenteredSnackBar(_getText('err_pass_length'), Colors.orange, seconds: 2);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      _showCenteredSnackBar(_getText('signup_success'), Colors.green, seconds: 2);

      await Future.delayed(const Duration(milliseconds: 2500));

      if (!mounted) return;

      ScaffoldMessenger.of(context).clearSnackBars();
      Navigator.pop(context);

    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
      });

      String errorMessage = _getText('err_unexpected');
      if (e.code == 'weak-password') {
        errorMessage = _getText('err_weak_pass');
      } else if (e.code == 'email-already-in-use') {
        errorMessage = _getText('err_email_in_use');
      } else if (e.code == 'invalid-email') {
        errorMessage = _getText('err_invalid_email');
      }
      _showCenteredSnackBar('❌ $errorMessage', Colors.redAccent, seconds: 2);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showCenteredSnackBar(_getText('err_unexpected'), Colors.redAccent, seconds: 2);
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
          // ضبط الاتجاه بناءً على اللغة المقروءة من الذاكرة
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
                    top: topPadding + screenHeight * 0.22,
                    left: 20,
                    right: 20,
                    child: Column(
                      children: [
                        Text(
                          _getText('title_signup'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                            shadows: [
                              Shadow(blurRadius: 10, color: Color(0xFF00D2FF), offset: Offset(0, 0)),
                              Shadow(blurRadius: 8, color: Colors.black, offset: Offset(0, 2)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _getText('subtitle_signup'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFB0C4DE),
                          ),
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
                                        readOnly: _isLoading,
                                        style: const TextStyle(color: Colors.white, fontSize: 13),
                                        keyboardType: TextInputType.emailAddress,
                                        textInputAction: TextInputAction.next,
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
                                        readOnly: _isLoading,
                                        obscureText: !_isPasswordVisible,
                                        style: const TextStyle(color: Colors.white, fontSize: 13),
                                        textInputAction: TextInputAction.next,
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
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.lock_reset, color: Color(0xFF00D2FF), size: 16),
                                        const SizedBox(width: 6),
                                        Text(_getText('confirm_password'), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    SizedBox(
                                      height: 44,
                                      child: TextFormField(
                                        controller: _confirmPasswordController,
                                        readOnly: _isLoading,
                                        obscureText: !_isConfirmPasswordVisible,
                                        style: const TextStyle(color: Colors.white, fontSize: 13),
                                        textInputAction: TextInputAction.done,
                                        onFieldSubmitted: (_) => _handleSignup(),
                                        decoration: InputDecoration(
                                          hintText: _getText('confirm_password_hint'),
                                          hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                                          filled: true,
                                          fillColor: const Color(0xFF0B172A).withValues(alpha: 0.85),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                          prefixIcon: IconButton(
                                            icon: Icon(
                                              _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_outlined,
                                              color: Colors.white38,
                                              size: 18,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
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
                                    onPressed: _isLoading ? () {} : _handleSignup,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    child: Text(
                                      _getText('signup_btn'),
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                  ),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _getText('already_have_account'),
                                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        if (!_isLoading) Navigator.pop(context);
                                      },
                                      child: Text(
                                        _getText('login_link'),
                                        style: const TextStyle(
                                          color: Color(0xFF00D2FF),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
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