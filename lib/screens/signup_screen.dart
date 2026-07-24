import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
      _showCenteredSnackBar('⚠️ برجاء ملء جميع الحقول المطلوبة', Colors.orange, seconds: 2);
      return;
    }

    if (password != confirmPassword) {
      _showCenteredSnackBar('❌ كلمة المرور غير متطابقة مع تأكيد كلمة المرور', Colors.redAccent, seconds: 2);
      return;
    }

    if (password.length < 6) {
      _showCenteredSnackBar('⚠️ كلمة المرور يجب ألا تقل عن 6 أحرف أو أرقام', Colors.orange, seconds: 2);
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

      // 1. إظهار رسالة النجاح لمدة ثانيتين
      _showCenteredSnackBar('✅ تم إنشاء الحساب بنجاح!', Colors.green, seconds: 2);

      // 2. الانتظار 2.5 ثانية (عشان الأنيميشن بتاع اختفاء الرسالة يلحق يخلص بالكامل على نفس الشاشة)
      await Future.delayed(const Duration(milliseconds: 2500));

      if (!mounted) return;

      // 3. مسح أي شريط رسايل من الذاكرة تماماً عشان ميفضلش معلق في الشاشة الجديدة
      ScaffoldMessenger.of(context).clearSnackBars();

      // 4. الرجوع لشاشة اللوجين بكل هدوء ونظافة
      Navigator.pop(context);

    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
      });

      String errorMessage = 'حدث خطأ أثناء إنشاء الحساب';
      if (e.code == 'weak-password') {
        errorMessage = 'كلمة المرور ضعيفة جداً';
      } else if (e.code == 'email-already-in-use') {
        errorMessage = 'البريد الإلكتروني مستخدم بالفعل لحساب آخر';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'صيغة البريد الإلكتروني غير صحيحة';
      }
      _showCenteredSnackBar('❌ $errorMessage', Colors.redAccent, seconds: 2);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showCenteredSnackBar('❌ حدث خطأ غير متوقع، يرجى المحاولة لاحقاً', Colors.redAccent, seconds: 2);
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
                    top: topPadding + screenHeight * 0.22,
                    left: 20,
                    right: 20,
                    child: Column(
                      children: [
                        const Text(
                          'حساب جديد',
                          textAlign: TextAlign.center,
                          style: TextStyle(
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
                        const Text(
                          'قم بانشاء حسابك للانضمام إلى Ramy Track ERP',
                          textAlign: TextAlign.center,
                          style: TextStyle(
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
                                        readOnly: _isLoading,
                                        style: const TextStyle(color: Colors.white, fontSize: 13),
                                        keyboardType: TextInputType.emailAddress,
                                        textInputAction: TextInputAction.next,
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
                                        readOnly: _isLoading,
                                        obscureText: !_isPasswordVisible,
                                        style: const TextStyle(color: Colors.white, fontSize: 13),
                                        textInputAction: TextInputAction.next,
                                        decoration: InputDecoration(
                                          hintText: 'أدخل كلمة المرور (6 أحرف على الأقل)',
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
                                      children: const [
                                        Icon(Icons.lock_reset, color: Color(0xFF00D2FF), size: 16),
                                        SizedBox(width: 6),
                                        Text('تأكيد كلمة المرور', style: TextStyle(color: Colors.white70, fontSize: 12)),
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
                                          hintText: 'أعد إدخال كلمة المرور',
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
                                    child: const Text(
                                      'تسجيل الحساب',
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                  ),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'لديك حساب بالفعل؟ ',
                                      style: TextStyle(color: Colors.white70, fontSize: 12),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        if (!_isLoading) Navigator.pop(context);
                                      },
                                      child: const Text(
                                        'تسجيل الدخول',
                                        style: TextStyle(
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