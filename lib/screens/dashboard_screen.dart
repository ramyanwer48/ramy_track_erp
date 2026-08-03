import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'daily_entry_screen.dart';
import 'client_accounts_screen.dart';
import 'settings_screen.dart';
import 'settlements_screen.dart';
import 'sheikh_mohamed_screen.dart';
import 'driver_accounts_screen.dart';
import 'office_accounts_screen.dart';
import 'custom_bottom_nav.dart';

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
          title: const Row(
            children: [
              Icon(Icons.notifications, color: Color(0xFF00D2FF)),
              SizedBox(width: 8),
              Text('الإشعارات', style: TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'Cairo')),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.check_circle, color: Colors.green),
                title: Text('تم حفظ بيان اليوم بنجاح', style: TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'Cairo')),
                subtitle: Text('منذ 10 دقائق', style: TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'Cairo')),
              ),
              Divider(color: Colors.white24),
              ListTile(
                leading: Icon(Icons.info, color: Color(0xFF00D2FF)),
                title: Text('تحديث جديد لبيانات السائقين', style: TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'Cairo')),
                subtitle: Text('منذ ساعة', style: TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'Cairo')),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق', style: TextStyle(color: Color(0xFF00D2FF), fontFamily: 'Cairo')),
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
              Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none, color: Colors.white, size: 26),
                    onPressed: () => _showNotificationsDialog(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      child: const Text('3', style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
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
            ],
          ),
        ),

        bottomNavigationBar: const CustomBottomNav(currentIndex: 0),

        body: Container(
          width: double.infinity,
          padding: const EdgeInsets.only(top: 5),
          child: Column(
            children: [
              // 1. قسم مرحباً بك
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

              // 2. كارت الذكاء الاصطناعي
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
                      BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 5, offset: const Offset(0, 2))
                    ],
                  ),
                  child: InkWell(
                    onTap: () {},
                    borderRadius: BorderRadius.circular(15),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
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

              // 3. كارت حساب الشيخ محمد
              const Expanded(
                flex: 9,
                child: SheikhMohamedDashboardCard(),
              ),

              // 4. شبكة الأقسام
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
                            _buildGridCard(context, title: 'حسابات اللودر', icon: Icons.front_loader, color: Colors.amber.shade700, onTap: () {}),
                            _buildGridCard(context, title: 'لوحة التحكم', icon: Icons.pie_chart, color: Colors.red, onTap: () {}),
                            _buildGridCard(context, title: 'التقارير', icon: Icons.bar_chart, color: Colors.deepPurple, onTap: () {}),
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
    return amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
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
                          String clientName = (data['clientName'] ?? data['client_name'] ?? '').toString().trim();
                          String carType = (data['carType'] ?? data['vehicleType'] ?? data['type'] ?? '').toString().trim();

                          if ((clientName.contains('بخيت') || clientName.contains('عادل')) && (carType.contains('جرار') || carType.contains('جرارات'))) {
                            double cubage = double.tryParse(data['totalCubage']?.toString() ?? data['cubage']?.toString() ?? '0') ?? 0.0;
                            totalTractorMeters += cubage;
                          }
                        }
                      }

                      double totalPayments = 0.0;
                      if (paymentsSnapshot.hasData) {
                        for (var doc in paymentsSnapshot.data!.docs) {
                          var pData = doc.data() as Map<String, dynamic>;
                          totalPayments += double.tryParse(pData['amount']?.toString() ?? '0') ?? 0.0;
                        }
                      }

                      double netRemaining = (totalTractorMeters * meterPrice) - totalPayments;
                      bool isClear = netRemaining <= 0;

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.amber.shade600, width: 1.5),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))
                          ],
                        ),
                        child: InkWell(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SheikhMohamedScreen())),
                          borderRadius: BorderRadius.circular(15),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(color: Colors.amber.shade50, shape: BoxShape.circle),
                                  child: const Text('🚛', style: TextStyle(fontSize: 26)),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text('حساب الشيخ محمد', style: TextStyle(color: Color(0xFF0F2A52), fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                                      Text('نسبة الجرارات (الموقع الجديد)', style: TextStyle(color: Colors.grey, fontSize: 10, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('المتبقي', style: TextStyle(color: isClear ? Colors.green : Colors.red, fontSize: 10, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                                    Text('${_toArabicNumbers(_formatNumber(netRemaining))} ج', style: TextStyle(color: isClear ? Colors.green : Colors.red, fontSize: 16, fontWeight: FontWeight.w900, fontFamily: 'Cairo')),
                                  ],
                                ),
                                const SizedBox(width: 5),
                                const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 14),
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