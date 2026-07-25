import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'daily_entry_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

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
              Text('الإشعارات', style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.check_circle, color: Colors.green),
                title: Text('تم حفظ بيان اليوم بنجاح', style: TextStyle(color: Colors.white, fontSize: 13)),
                subtitle: Text('منذ 10 دقائق', style: TextStyle(color: Colors.white70, fontSize: 10)),
              ),
              Divider(color: Colors.white24),
              ListTile(
                leading: Icon(Icons.info, color: Color(0xFF00D2FF)),
                title: Text('تحديث جديد لبيانات السائقين', style: TextStyle(color: Colors.white, fontSize: 13)),
                subtitle: Text('منذ ساعة', style: TextStyle(color: Colors.white70, fontSize: 10)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق', style: TextStyle(color: Color(0xFF00D2FF))),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
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
                  const Text('نظام إدارة النقل والحسابات', style: TextStyle(color: Colors.white70, fontSize: 9)),
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
                    children: const [
                      Icon(Icons.calendar_month, color: Colors.white, size: 12),
                      SizedBox(width: 4),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('16/07/2025', style: TextStyle(color: Colors.white, fontSize: 8)),
                          Text('الخميس', style: TextStyle(color: Colors.white70, fontSize: 7)),
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
              const UserAccountsDrawerHeader(
                decoration: BoxDecoration(color: Color(0xFF0A2540)),
                accountName: Text('مسؤول النظام', style: TextStyle(fontWeight: FontWeight.bold)),
                accountEmail: Text('admin@ramytrack.com'),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 40, color: Color(0xFF103667)),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.home, color: Colors.white),
                title: const Text('الرئيسية', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.edit_document, color: Colors.white),
                title: const Text('إدخال البيان اليومي', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const DailyEntryScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings, color: Colors.white),
                title: const Text('الإعدادات', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF103667),
            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1), width: 1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home, 'الرئيسية', 0, () => setState(() => _currentIndex = 0)),
              _buildNavItem(Icons.people_outline, 'العملاء', 1, () => setState(() => _currentIndex = 1)),
              _buildNavItem(Icons.domain, 'المكتب', 2, () => setState(() => _currentIndex = 2)),
              _buildNavItem(Icons.engineering, 'السائقين', 3, () => setState(() => _currentIndex = 3)),
              _buildNavItem(Icons.edit_document, 'إدخال البيان', 4, () {
                setState(() => _currentIndex = 4);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const DailyEntryScreen()));
              }),
              _buildNavItem(Icons.settings, 'الإعدادات', 5, () => setState(() => _currentIndex = 5)),
            ],
          ),
        ),
        body: Container(
          width: double.infinity,
          padding: const EdgeInsets.only(top: 5),
          child: Column(
            children: [
              // ==========================================
              // 1. قسم مرحباً بك (اللوجو المصغر والترانسبرنت في أقصى الشمال، والنصوص في اليمين)
              // ==========================================
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
                        // الترانسبرنت مصغر وفي أقصى الشمال
                        Positioned(
                          left: 5,
                          child: Opacity(
                            opacity: 0.15,
                            child: Image.asset(
                              'assets/images/logo.png',
                              width: 160,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => const SizedBox(),
                            ),
                          ),
                        ),
                        // اللوجو مصغر وفي أقصى الشمال
                        Positioned(
                          left: 20,
                          child: Image.asset(
                            'assets/images/logo.png',
                            width: 110,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => Image.asset('assets/images/Splash.png', width: 40),
                          ),
                        ),
                        // النصوص على اليمين واخذة راحتها بالكامل
                        Positioned(
                          right: 15,
                          left: 130, // مسافة أمان عشان ميتداخلش مع اللوجو الشمال
                          child: Row(
                            children: [
                              Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: Colors.blue.shade50,
                                    child: Icon(Icons.person, size: 24, color: Colors.blue.shade300),
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
                                    const Text(
                                      'مرحباً بك في النظام',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF103667)),
                                      maxLines: 1,
                                      overflow: TextOverflow.visible,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'اختر القسم المطلوب للمتابعة',
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                                      maxLines: 1,
                                      overflow: TextOverflow.visible,
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

              // ==========================================
              // 2. كارت الذكاء الاصطناعي
              // ==========================================
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
                                FittedBox(fit: BoxFit.scaleDown, child: Text('إدخال البيان بالذكاء الاصطناعي', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold))),
                                FittedBox(fit: BoxFit.scaleDown, child: Text('تصوير البيان اليدوي وتفريغه تلقائياً', style: TextStyle(color: Colors.white70, fontSize: 10))),
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

              // ==========================================
              // 3. شبكة الأقسام
              // ==========================================
              Expanded(
                flex: 52,
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
                            _buildGridCard(context, title: 'الخصومات والتسويات', icon: Icons.local_offer_outlined, color: Colors.orange, onTap: () {}),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Row(
                          children: [
                            _buildGridCard(context, title: 'حسابات العملاء', icon: Icons.people_outline, color: Colors.purple, onTap: () {}),
                            _buildGridCard(context, title: 'حسابات السائقين', icon: Icons.engineering, color: Colors.teal, onTap: () {}),
                            _buildGridCard(context, title: 'حسابات المكتب', icon: Icons.domain, color: Colors.blue.shade700, onTap: () {}),
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
                  child: Text(title, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, VoidCallback onTap) {
    bool isSelected = _currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
                icon,
                color: isSelected ? const Color(0xFF00D2FF) : Colors.white,
                size: 24
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? const Color(0xFF00D2FF) : Colors.white,
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}