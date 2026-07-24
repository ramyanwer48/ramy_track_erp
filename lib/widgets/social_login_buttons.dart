import 'package:flutter/material.dart';

class SocialLoginButtons extends StatelessWidget {
  const SocialLoginButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [

        SizedBox(
          width: double.infinity,
          height: 62,
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: Image.asset(
              "assets/images/google.png",
              width: 28,
            ),
            label: const Text(
              "تسجيل الدخول باستخدام Google",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(
                color: Color(0xff2E4A85),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),

        const SizedBox(height: 18),

        SizedBox(
          width: double.infinity,
          height: 62,
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(
              Icons.email_outlined,
              color: Color(0xff2F80FF),
              size: 30,
            ),
            label: const Text(
              "تسجيل الدخول بالبريد الإلكتروني",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(
                color: Color(0xff2E4A85),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),

        const SizedBox(height: 30),

        Row(
          children: const [

            Expanded(
              child: Divider(
                color: Color(0xff1D4ED8),
              ),
            ),

            Padding(
              padding: EdgeInsets.symmetric(horizontal: 15),
              child: Text(
                "أو",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 24,
                ),
              ),
            ),

            Expanded(
              child: Divider(
                color: Color(0xff1D4ED8),
              ),
            ),
          ],
        ),
      ],
    );
  }
}