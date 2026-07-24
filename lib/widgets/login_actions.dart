import 'package:flutter/material.dart';

class LoginActions extends StatelessWidget {
  final bool rememberMe;
  final ValueChanged<bool?> onRememberChanged;

  const LoginActions({
    super.key,
    required this.rememberMe,
    required this.onRememberChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [

        Row(
          children: [

            Checkbox(
              value: rememberMe,
              onChanged: onRememberChanged,
              activeColor: const Color(0xff1E88E5),
              side: const BorderSide(color: Colors.white54),
            ),

            const Text(
              "تذكرني",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),

            const Spacer(),

            TextButton(
              onPressed: () {},
              child: const Text(
                "نسيت كلمة المرور؟",
                style: TextStyle(
                  color: Color(0xff4EA3FF),
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          height: 58,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff1E88E5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () {},
            child: const Text(
              "تسجيل الدخول",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),

        const SizedBox(height: 18),

        SizedBox(
          width: double.infinity,
          height: 58,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(
                color: Color(0xff2F80FF),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () {},
            child: const Text(
              "إنشاء حساب جديد",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            Icon(
              Icons.language,
              color: Colors.white54,
              size: 18,
            ),

            SizedBox(width: 8),

            Text(
              "العربية",
              style: TextStyle(
                color: Colors.white54,
                fontSize: 15,
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        const Text(
          "Version 1.0.0",
          style: TextStyle(
            color: Colors.white38,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}