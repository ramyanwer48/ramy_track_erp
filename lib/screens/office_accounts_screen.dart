import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'custom_bottom_nav.dart';
import 'office_old_site_screen.dart';
import 'office_new_site_screen.dart'; // استدعاء شاشة الموقع الجديد

class OfficeAccountsScreen extends StatefulWidget {
  const OfficeAccountsScreen({super.key});

  @override
  State<OfficeAccountsScreen> createState() => _OfficeAccountsScreenState();
}

class _OfficeAccountsScreenState extends State<OfficeAccountsScreen> {
  DateTimeRange _selectedDateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );

  bool _isLoading = false;

  // متغيرات الموقع القديم
  double _oldRevenue = 0.0;
  double _oldZDriversDeduction = 0.0;
  double _oldLoaderDeduction = 0.0;
  double _oldSettlementsDeduction = 0.0;
  double get _oldTotalDeductions => _oldZDriversDeduction + _oldLoaderDeduction + _oldSettlementsDeduction;
  double get _oldNet => _oldRevenue - _oldTotalDeductions;

  // متغيرات الموقع الجديد
  double _newCompanyTrucksRev = 0.0;
  double _newOfficeTrucksRev = 0.0;
  double _newTractorsRev = 0.0;
  double _newSettlementsDeduction = 0.0;
  double get _newTotalRevenue => _newCompanyTrucksRev + _newOfficeTrucksRev + _newTractorsRev;
  double get _newNet => _newTotalRevenue - _newSettlementsDeduction;

  // الإجمالي الكلي
  double get _totalNet => _oldNet + _newNet;

  @override
  void initState() {
    super.initState();
    _calculateAccounts();
  }

  // دالة تحويل الأرقام الإنجليزية لعربية
  String _toArabicNumbers(String text) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    for (int i = 0; i < english.length; i++) {
      text = text.replaceAll(english[i], arabic[i]);
    }
    return text;
  }

  // دالة تنسيق الفلوس
  String _formatNumber(double num) {
    String numStr = num % 1 == 0 ? num.toInt().toString() : num.toStringAsFixed(1);
    return numStr.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }

  Future<void> _calculateAccounts() async {
    setState(() => _isLoading = true);

    try {
      _resetValues();

      DateTime start = DateTime(_selectedDateRange.start.year, _selectedDateRange.start.month, _selectedDateRange.start.day, 0, 0, 0);
      DateTime end = DateTime(_selectedDateRange.end.year, _selectedDateRange.end.month, _selectedDateRange.end.day, 23, 59, 59);

      var entriesSnap = await FirebaseFirestore.instance
          .collection('daily_entries')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      for (var doc in entriesSnap.docs) {
        var data = doc.data();
        String site = data['site'] ?? 'old';
        double totalCubage = double.tryParse(data['cubage']?.toString() ?? '0') ?? 0.0;
        bool isTractor = data['isTractor'] == true;
        String typeCode = data['typeCode']?.toString() ?? '';
        var globals = data['snapshotGlobals'] as Map<String, dynamic>? ?? {};

        if (site == 'old') {
          List<dynamic> trips = data['clientsTrips'] ?? [];
          for (var trip in trips) {
            double tripCubage = double.tryParse(trip['cubage']?.toString() ?? '0') ?? 0.0;
            double officePrice = double.tryParse(trip['officePriceSnapshot']?.toString() ?? '0') ?? 0.0;
            _oldRevenue += (tripCubage * officePrice);
          }
          if (typeCode == 'Z') {
            double zPrice = double.tryParse(globals['companyDriverPrice']?.toString() ?? '40') ?? 40.0;
            _oldZDriversDeduction += (totalCubage * zPrice);
          }
          double loaderPrice = double.tryParse(globals['loaderPrice']?.toString() ?? '15') ?? 15.0;
          _oldLoaderDeduction += (totalCubage * loaderPrice);

        } else if (site == 'new') {
          if (isTractor) {
            double tractorPrice = double.tryParse(globals['officeTractors']?.toString() ?? '53') ?? 53.0;
            _newTractorsRev += (totalCubage * tractorPrice);
          } else {
            if (typeCode == 'Z') {
              double compTruckPrice = double.tryParse(globals['officeTrucksCompany']?.toString() ?? '28') ?? 28.0;
              _newCompanyTrucksRev += (totalCubage * compTruckPrice);
            } else {
              double officeTruckPrice = double.tryParse(globals['officeTrucksOffice']?.toString() ?? '64') ?? 64.0;
              _newOfficeTrucksRev += (totalCubage * officeTruckPrice);
            }
          }
        }
      }

      var settlementsSnap = await FirebaseFirestore.instance
          .collection('settlements')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      for (var doc in settlementsSnap.docs) {
        var data = doc.data();
        String siteName = data['siteName']?.toString() ?? '';
        String type = data['type']?.toString() ?? '';
        double amount = double.tryParse(data['amount']?.toString() ?? '0') ?? 0.0;

        if (type == 'office_expense' || type == 'quality_discount' || type == 'loader_account' || type == 'offset_transfer' || type == 'covenant') {
          if (siteName == 'الموقع القديم') {
            _oldSettlementsDeduction += (type == 'offset_transfer' ? -amount : amount);
          } else if (siteName == 'الموقع الجديد') {
            _newSettlementsDeduction += (type == 'offset_transfer' ? -amount : amount);
          }
        }
      }

      if (mounted) setState(() => _isLoading = false);

    } catch (e) {
      debugPrint('Error calculating office accounts: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _resetValues() {
    _oldRevenue = 0.0;
    _oldZDriversDeduction = 0.0;
    _oldLoaderDeduction = 0.0;
    _oldSettlementsDeduction = 0.0;
    _newCompanyTrucksRev = 0.0;
    _newOfficeTrucksRev = 0.0;
    _newTractorsRev = 0.0;
    _newSettlementsDeduction = 0.0;
  }

  @override
  Widget build(BuildContext context) {
    String startStr = '${_selectedDateRange.start.year}/${_selectedDateRange.start.month.toString().padLeft(2, '0')}/${_selectedDateRange.start.day.toString().padLeft(2, '0')}';
    String endStr = '${_selectedDateRange.end.year}/${_selectedDateRange.end.month.toString().padLeft(2, '0')}/${_selectedDateRange.end.day.toString().padLeft(2, '0')}';
    String displayDate = _toArabicNumbers('من $startStr إلى $endStr');

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F9),
        appBar: AppBar(
          elevation: 0,
          centerTitle: true,
          toolbarHeight: 50,
          automaticallyImplyLeading: false,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF0F2A52), Color(0xFF1E4885)]),
            ),
          ),
          title: const Text('حسابات المكتب', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
        ),
        bottomNavigationBar: const CustomBottomNav(currentIndex: 5),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F2A52)))
            : RefreshIndicator(
          onRefresh: _calculateAccounts,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. فلتر التاريخ
                InkWell(
                  onTap: () async {
                    DateTimeRange? picked = await showDateRangePicker(
                      context: context,
                      initialDateRange: _selectedDateRange,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                      builder: (context, child) => Theme(
                        data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF0F2A52))),
                        child: Directionality(textDirection: TextDirection.rtl, child: child!),
                      ),
                    );
                    if (picked != null && mounted) {
                      setState(() => _selectedDateRange = picked);
                      _calculateAccounts();
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: const Color(0xFF0F2A52).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.filter_alt_rounded, color: Color(0xFF0F2A52), size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Text('فترة الحساب:', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                        const Spacer(),
                        Text(
                          displayDate,
                          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, color: Color(0xFF0F2A52), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 2. كارت الإجمالي الكلي
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF28A745), Color(0xFF198754)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        left: -30,
                        top: -20,
                        child: Icon(Icons.account_balance_wallet, size: 120, color: Colors.white.withOpacity(0.1)),
                      ),
                      Column(
                        children: [
                          const Text('إجمالي المستحق للمكتب', style: TextStyle(fontFamily: 'Cairo', color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            '${_toArabicNumbers(_formatNumber(_totalNet))} ج.م',
                            style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 15),
                          const Divider(color: Colors.white30, height: 1, thickness: 1),
                          const SizedBox(height: 15),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  children: [
                                    const Text('الموقع القديم', style: TextStyle(fontFamily: 'Cairo', color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_toArabicNumbers(_formatNumber(_oldNet))} ج',
                                      style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              Container(width: 1, height: 35, color: Colors.white30),
                              Expanded(
                                child: Column(
                                  children: [
                                    const Text('الموقع الجديد', style: TextStyle(fontFamily: 'Cairo', color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_toArabicNumbers(_formatNumber(_newNet))} ج',
                                      style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 3. كارت تفاصيل الموقع القديم
                _buildSiteCard(
                  title: 'الموقع القديم',
                  icon: Icons.domain,
                  color: const Color(0xFFD97706),
                  revenue: _oldRevenue,
                  deductions: _oldTotalDeductions,
                  netAmount: _oldNet,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => OfficeOldSiteScreen(dateRange: _selectedDateRange)));
                  },
                ),
                const SizedBox(height: 16),

                // 4. كارت تفاصيل الموقع الجديد (تم التوصيل والشغل تمام!)
                _buildSiteCard(
                  title: 'الموقع الجديد',
                  icon: Icons.add_business,
                  color: const Color(0xFF6F42C1),
                  revenue: _newTotalRevenue,
                  deductions: _newSettlementsDeduction,
                  netAmount: _newNet,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => OfficeNewSiteScreen(dateRange: _selectedDateRange)));
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSiteCard({
    required String title,
    required IconData icon,
    required Color color,
    required double revenue,
    required double deductions,
    required double netAmount,
    required VoidCallback onTap
  }) {
    bool isPositive = netAmount >= 0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0F2A52))),
                  const SizedBox(height: 2),
                  Text(
                    'إيرادات: ${_toArabicNumbers(_formatNumber(revenue))} | خصومات: ${_toArabicNumbers(_formatNumber(deductions))}',
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Text('الصافي: ', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey)),
                      Text(
                        '${_toArabicNumbers(_formatNumber(netAmount.abs()))} ج.م',
                        style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 15, color: isPositive ? Colors.green.shade700 : Colors.red.shade700),
                      ),
                      if (!isPositive)
                        const Text(' (مديونية)', style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: Colors.red)),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 18),
          ],
        ),
      ),
    );
  }
}