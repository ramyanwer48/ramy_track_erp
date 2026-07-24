import 'package:flutter/material.dart';

class LoginHeader extends StatelessWidget {
  const LoginHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),

        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),

        const SizedBox(height: 20),

        Image.asset(
          "assets/images/icon.png",
          width: 145,
        ),

        const SizedBox(height: 15),

        const Text(
          "Welcome Back",
          style: TextStyle(
            fontSize: 34,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 10),

        Row(
          children: [
            const Expanded(
              child: Divider(
                color: Color(0xff1E5EFF),
                thickness: 1,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Text(
                "تسجيل الدخول",
                style: TextStyle(
                  color: Colors.blue.shade400,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Expanded(
              child: Divider(
                color: Color(0xff1E5EFF),
                thickness: 1,
              ),
            ),
          ],
        ),
      ],
    );
  }
}