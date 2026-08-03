import 'package:flutter/material.dart';
import 'custom_bottom_nav.dart';

class OfficeAccountsScreen extends StatefulWidget {
  const OfficeAccountsScreen({super.key});

  @override
  State<OfficeAccountsScreen> createState() => _OfficeAccountsScreenState();
}

class _OfficeAccountsScreenState extends State<OfficeAccountsScreen> {
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F9),
        appBar: AppBar(
          elevation: 0,
          centerTitle: true,
          toolbarHeight: 45,
          automaticallyImplyLeading: false, // عشان دي شاشة رئيسية في البار السفلي مفيش سهم رجوع
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F2A52), Color(0xFF1E4885)],
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
              ),
            ),
          ),
          title: const Text(
            'حسابات المكتب',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Cairo'),
          ),
        ),
        bottomNavigationBar: const CustomBottomNav(currentIndex: 5), // إندكس 5 بتاع المكتب
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.business_rounded, size: 80, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text(
                  'شاشة حسابات المكتب جاهزة للعمل 🚀',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}