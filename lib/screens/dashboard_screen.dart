import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart'; // تم إضافة مكتبة جوجل
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // تم إضافة مكتبة الخزنة المشفرة
import 'package:shared_preferences/shared_preferences.dart'; // تم إضافة مكتبة الذاكرة
import 'login_screen.dart'; // استدعاء شاشة تسجيل الدخول
import 'daily_entry_screen.dart';
import 'client_accounts_screen.dart';
import 'settings_screen.dart';
import 'settlements_screen.dart';
import 'sheikh_mohamed_screen.dart';
import 'driver_accounts_screen.dart';
import 'office_accounts_screen.dart';
import 'loader_accounts_screen.dart';
import 'custom_bottom_nav.dart';
import 'control_panel_screen.dart';
import 'reports_screen.dart';
import 'ai_daily_entry_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DateTime _selectedDate = DateTime.now();

  String _getArabicDay(int weekday) {
    switch (weekday) {
      case 1: return 'الإثنين';
      case 2: return 'الثلاثاء';
      case 3: return 'الأربعاء';
      case 4: return 'الخميس';
      case 5: return 'الجمعة';
      case 6: return 'السبت';
      case 7: return 'الأحد';
      default: return '';
    }
  }

  void _showNotificationsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF103667),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Row(
            children: [
              const Icon(Icons.notifications_active, color: Color(0xFF00D2FF)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('الإشعارات', style: TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              ),
              IconButton(
                icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
                tooltip: 'مسح جميع الإشعارات',
                onPressed: () async {
                  var snap = await FirebaseFirestore.instance.collection('notifications').get();
                  for (var doc in snap.docs) {
                    await doc.reference.delete();
                  }
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 400),
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('notifications').orderBy('timestamp', descending: true).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFF00D2FF)));
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text('لا توجد إشعارات جديدة حالياً.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontFamily: 'Cairo')),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: snapshot.data!.docs.length,
                    separatorBuilder: (context, index) => const Divider(color: Colors.white24, height: 1),
                    itemBuilder: (context, index) {
                      var doc = snapshot.data!.docs[index];
                      var data = doc.data() as Map<String, dynamic>;

                      String title = data['title'] ?? 'إشعار جديد';
                      String body = data['body'] ?? '';

                      String timeText = 'الآن';
                      if (data['timestamp'] != null) {
                        DateTime dt = (data['timestamp'] as Timestamp).toDate();
                        timeText = '${dt.hour}:${dt.minute.toString().padLeft(2, '0')} | ${dt.day}/${dt.month}/${dt.year}';
                      }

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), shape: BoxShape.circle),
                          child: const Icon(Icons.campaign, color: Color(0xFF00D2FF), size: 18),
                        ),
                        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 2),
                            Text(body, style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'Cairo')),
                            const SizedBox(height: 4),
                            Text(timeText, style: const TextStyle(color: Colors.white38, fontSize: 9, fontFamily: 'Cairo')),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                          onPressed: () => doc.reference.delete(),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق', style: TextStyle(color: Color(0xFF00D2FF), fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF00D2FF),
              onPrimary: Color(0xFF103667),
              surface: Color(0xFF103667),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // --- دالة تسجيل الخروج الاحترافية (Sign Out) ---
  Future<void> _handleSignOut(BuildContext context) async {
    try {
      // إظهار مؤشر تحميل شيك أثناء الخروج
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator(color: Color(0xFF00D2FF))),
      );

      // 1. تسجيل الخروج من فايربيز
      await FirebaseAuth.instance.signOut();

      // 2. تسجيل الخروج من جوجل
      final GoogleSignIn googleSignIn = GoogleSignIn();
      if (await googleSignIn.isSignedIn()) {
        await googleSignIn.signOut();
      }

      // 3. مسح بيانات البصمة من الخزنة المشفرة لزيادة الأمان
      const secureStorage = FlutterSecureStorage();
      await secureStorage.write(key: 'biometric_enabled', value: 'false');
      await secureStorage.delete(key: 'bio_email');
      await secureStorage.delete(key: 'bio_password');

      // 4. مسح ذاكرة سؤال البصمة عشان يسأله تاني لو دخل بحساب جديد
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('biometric_prompted');

      if (!context.mounted) return;
      Navigator.pop(context); // إغلاق مؤشر التحميل

      // 5. الرجوع لشاشة تسجيل الدخول ومسح كل الشاشات السابقة من الذاكرة
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
      );
    } catch (e) {
      if (context.mounted) Navigator.pop(context); // إغلاق مؤشر التحميل
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء تسجيل الخروج: $e', style: const TextStyle(fontFamily: 'Cairo')),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF103667),
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      title: Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6.0),
          child: Row(
            children: [
              Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu, color: Colors.white, size: 26),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text('Ramy Track ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('ERP', style: TextStyle(color: Color(0xFF00D2FF), fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                  ),
                  const Text('نظام إدارة النقل والحسابات', style: TextStyle(color: Colors.white70, fontSize: 9, fontFamily: 'Cairo')),
                ],
              ),
              const SizedBox(width: 6),
              Transform(
                alignment: Alignment.center,
                transform: Matrix4.rotationY(math.pi),
                child: const Icon(Icons.local_shipping, color: Color(0xFF00D2FF), size: 26),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _selectDate(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white54),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month, color: Colors.white, size: 12),
                      const SizedBox(width: 4),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}',
                              style: const TextStyle(color: Colors.white, fontSize: 8)
                          ),
                          Text(
                              _getArabicDay(_selectedDate.weekday),
                              style: const TextStyle(color: Colors.white70, fontSize: 7, fontFamily: 'Cairo')
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('notifications').snapshots(),
                builder: (context, snapshot) {
                  int notifCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_none, color: Colors.white, size: 26),
                        onPressed: () => _showNotificationsDialog(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      if (notifCount > 0)
                        Positioned(
                          top: 2,
                          right: 2,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                            child: Text(
                              notifCount > 9 ? '+9' : notifCount.toString(),
                              style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF103667),
        appBar: _buildAppBar(context),
        drawer: Drawer(
          backgroundColor: const Color(0xFF103667),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              UserAccountsDrawerHeader(
                decoration: const BoxDecoration(color: Color(0xFF0A2540)),
                accountName: Text(currentUser?.displayName ?? 'مسؤول النظام', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                accountEmail: Text(currentUser?.email ?? 'admin@ramytrack.com'),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Colors.white,
                  backgroundImage: currentUser?.photoURL != null ? NetworkImage(currentUser!.photoURL!) : null,
                  child: currentUser?.photoURL == null ? const Icon(Icons.person, size: 40, color: Color(0xFF103667)) : null,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.home, color: Colors.white),
                title: const Text('الرئيسية', style: TextStyle(color: Colors.white, fontFamily: 'Cairo')),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.edit_document, color: Colors.white),
                title: const Text('إدخال البيان اليومي', style: TextStyle(color: Colors.white, fontFamily: 'Cairo')),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const DailyEntryScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.people_outline, color: Colors.white),
                title: const Text('حسابات العملاء', style: TextStyle(color: Colors.white, fontFamily: 'Cairo')),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ClientAccountsScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings, color: Colors.white),
                title: const Text('الإعدادات', style: TextStyle(color: Colors.white, fontFamily: 'Cairo')),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
                },
              ),
              // --- فاصل وزرار تسجيل الخروج ---
              const Divider(color: Colors.white24),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text('تسجيل الخروج', style: TextStyle(color: Colors.redAccent, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context); // قفل القائمة الجانبية أولاً
                  _handleSignOut(context);
                },
              ),
            ],
          ),
        ),

        bottomNavigationBar: const CustomBottomNav(currentIndex: 0),

        body: Container(
          width: double.infinity,
          padding: const EdgeInsets.only(top: 5),
          child: Column(
            children: [
              Expanded(
                flex: 14,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          left: -10,
                          child: Opacity(
                            opacity: 0.12,
                            child: Image.asset(
                              'assets/images/logo.png',
                              width: 170,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => const SizedBox(),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 10,
                          child: Image.asset(
                            'assets/images/logo.png',
                            width: 125,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => Image.asset('assets/images/Splash.png', width: 40),
                          ),
                        ),
                        Positioned(
                          right: 15,
                          left: 140,
                          child: Row(
                            children: [
                              Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: Colors.blue.shade50,
                                    backgroundImage: currentUser?.photoURL != null ? NetworkImage(currentUser!.photoURL!) : null,
                                    child: currentUser?.photoURL == null
                                        ? Icon(Icons.person, size: 24, color: Colors.blue.shade300)
                                        : null,
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                    child: const CircleAvatar(radius: 5, backgroundColor: Colors.green),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerRight,
                                      child: const Text(
                                        'مرحباً بك في النظام',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF103667), fontFamily: 'Cairo'),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'اختر القسم المطلوب للمتابعة',
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontFamily: 'Cairo'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
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

              // --- زرار إدخال البيان بالذكاء الاصطناعي (مفعل بالانتقال الصاروخي الفوري) ---
              Expanded(
                flex: 9,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00D2FF), Color(0xFF0066FF)],
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                    ),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 5, offset: const Offset(0, 2))
                    ],
                  ),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (context, animation, secondaryAnimation) => const AiDailyEntryScreen(),
                          transitionsBuilder: (context, animation, secondaryAnimation, child) {
                            return child; // انتقال فوري وصاروخي بدون أي تأخير
                          },
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(15),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                            child: const Icon(Icons.document_scanner, color: Colors.white, size: 26),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                FittedBox(fit: BoxFit.scaleDown, child: Text('إدخال البيان بالذكاء الاصطناعي', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Cairo'))),
                                FittedBox(fit: BoxFit.scaleDown, child: Text('تصوير البيان اليدوي وتفريغه تلقائياً', style: TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'Cairo'))),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              Expanded(
                flex: 9,
                child: const SheikhMohamedDashboardCard(),
              ),

              Expanded(
                flex: 48,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
                  child: Column(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            _buildGridCard(context, title: 'إدخال البيان اليومي', icon: Icons.edit_document, color: Colors.green, onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const DailyEntryScreen()));
                            }),
                            _buildGridCard(context, title: 'البيانات اليومية', icon: Icons.calendar_today, color: Colors.blue, onTap: () {}),
                            _buildGridCard(context, title: 'الخصومات والتسويات', icon: Icons.local_offer_outlined, color: Colors.orange, onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const SettlementsScreen()));
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Row(
                          children: [
                            _buildGridCard(context, title: 'حسابات العملاء', icon: Icons.people_outline, color: Colors.purple, onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const ClientAccountsScreen()));
                            }),
                            _buildGridCard(context, title: 'حسابات السائقين', icon: Icons.engineering, color: Colors.teal, onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const DriverAccountsScreen()));
                            }),
                            _buildGridCard(context, title: 'حسابات المكتب', icon: Icons.domain, color: Colors.blue.shade700, onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const OfficeAccountsScreen()));
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Row(
                          children: [
                            _buildGridCard(context, title: 'حسابات اللودر', icon: Icons.front_loader, color: Colors.amber.shade700, onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const LoaderAccountsScreen()));
                            }),
                            _buildGridCard(context, title: 'لوحة التحكم', icon: Icons.pie_chart, color: Colors.red, onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const ControlPanelScreen()));
                            }),
                            _buildGridCard(context, title: 'التقارير', icon: Icons.bar_chart, color: Colors.deepPurple, onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const ReportsScreen()));
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Row(
                          children: [
                            _buildGridCard(context, title: 'توزيع الأرباح', icon: Icons.pie_chart_outline, color: Colors.green, onTap: () {}),
                            _buildGridCard(context, title: 'المطابقة', icon: Icons.fact_check_outlined, color: Colors.blue, onTap: () {}),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 5),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridCard(BuildContext context, {required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 36, color: color),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text(title, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==============================================================
// كارت حساب الشيخ محمد المستقل
// ==============================================================
class SheikhMohamedDashboardCard extends StatelessWidget {
  const SheikhMohamedDashboardCard({super.key});

  String _toArabicNumbers(String text) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    for (int i = 0; i < english.length; i++) {
      text = text.replaceAll(english[i], arabic[i]);
    }
    return text;
  }

  String _formatNumber(double amount) {
    String numStr = amount % 1 == 0 ? amount.toInt().toString() : amount.toStringAsFixed(1);
    return numStr.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('settings').doc('sheikh_settings').snapshots(),
        builder: (context, settingsSnapshot) {
          double meterPrice = 22.0;
          if (settingsSnapshot.hasData && settingsSnapshot.data!.exists) {
            var data = settingsSnapshot.data!.data() as Map<String, dynamic>?;
            if (data != null && data.containsKey('tractorRate')) {
              meterPrice = double.tryParse(data['tractorRate'].toString()) ?? 22.0;
            }
          }

          return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('daily_entries').snapshots(),
              builder: (context, tripsSnapshot) {
                return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('settlements').where('type', isEqualTo: 'sheikh_payment').snapshots(),
                    builder: (context, paymentsSnapshot) {

                      double totalTractorMeters = 0.0;
                      if (tripsSnapshot.hasData) {
                        for (var doc in tripsSnapshot.data!.docs) {
                          var data = doc.data() as Map<String, dynamic>;

                          String site = data['site']?.toString() ?? 'old';
                          if (site != 'new' && site != 'الموقع الجديد') continue;

                          bool isTractor = data['isTractor'] ?? false;
                          if (!isTractor) continue;

                          List<dynamic> cTrips = data['clientsTrips'] ?? [];
                          for (var c in cTrips) {
                            int tripsCount = int.tryParse((c['tripsCount'] ?? c['trips'] ?? '0').toString()) ?? 0;
                            if (tripsCount > 0) {
                              double cubage = double.tryParse((c['totalCubage'] ?? c['cubage'] ?? '0').toString()) ?? 0.0;
                              if (cubage == 0) {
                                double vCubage = double.tryParse(data['cubage']?.toString() ?? '0') ?? 0.0;
                                cubage = tripsCount * vCubage;
                              }
                              totalTractorMeters += cubage;
                            }
                          }
                        }
                      }

                      double totalDues = totalTractorMeters * meterPrice;

                      double totalPayments = 0.0;
                      if (paymentsSnapshot.hasData) {
                        for (var doc in paymentsSnapshot.data!.docs) {
                          var pData = doc.data() as Map<String, dynamic>;
                          totalPayments += double.tryParse(pData['amount']?.toString() ?? '0') ?? 0.0;
                        }
                      }

                      double netRemaining = totalDues - totalPayments;
                      bool isSheikhOwed = netRemaining >= 0;
                      Color statusColor = isSheikhOwed ? Colors.green.shade700 : Colors.red.shade700;

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.amber.shade600, width: 1.5),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))
                          ],
                        ),
                        child: InkWell(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SheikhMohamedScreen())),
                          borderRadius: BorderRadius.circular(15),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(color: Colors.amber.shade50, shape: BoxShape.circle),
                                  child: const Text('🚛', style: TextStyle(fontSize: 20)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 6,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          'حساب الشيخ محمد',
                                          style: TextStyle(color: Color(0xFF0F2A52), fontSize: 14.5, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text('أمتار الجرارات (الموقع الجديد)', style: TextStyle(color: Colors.grey.shade600, fontSize: 8.5, fontFamily: 'Cairo', fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 5,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('صافي المتبقي', style: TextStyle(color: statusColor, fontSize: 8.5, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 1),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          '${_toArabicNumbers(_formatNumber(netRemaining))} ج',
                                          style: TextStyle(color: statusColor, fontSize: 13.5, fontWeight: FontWeight.w900, fontFamily: 'Cairo'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 12),
                              ],
                            ),
                          ),
                        ),
                      );
                    }
                );
              }
          );
        }
    );
  }
}