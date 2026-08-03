import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart' hide Border;

class OfficeNewSiteScreen extends StatefulWidget {
  final DateTimeRange dateRange;

  const OfficeNewSiteScreen({super.key, required this.dateRange});

  @override
  State<OfficeNewSiteScreen> createState() => _OfficeNewSiteScreenState();
}

class _OfficeNewSiteScreenState extends State<OfficeNewSiteScreen> {
  bool _isLoading = false;

  // إيرادات المستحقات للموقع الجديد
  double _companyCarsRevenue = 0.0;
  double _officeCarsRevenue = 0.0;
  double _tractorsRevenue = 0.0;
  double _totalRevenue = 0.0;

  // الأمتار والأسعار من الإعدادات لكل نوع
  double _companyCarsMeters = 0.0;
  double _officeCarsMeters = 0.0;
  double _tractorsMeters = 0.0;

  double _compTruckPrice = 28.0;
  double _officeTruckPrice = 64.0;
  double _tractorPrice = 53.0;

  // الخصومات الفعلية (عهد وجودة فقط)
  double _expensesTotal = 0.0;
  double _qualityTotal = 0.0;
  double _qualityMetersTotal = 0.0;
  double _qualityPrice = 0.0;

  // حساب اللودر (للعلم والبيان فقط - لا يُخصم)
  double _loaderMeters = 0.0;
  double _loaderPrice = 15.0;
  double _loaderTotal = 0.0;

  List<Map<String, dynamic>> _expensesList = [];
  List<Map<String, dynamic>> _qualityList = [];

  // إجمالي الخصومات (عهد + جودة فقط)
  double get _totalDeductions => _expensesTotal + _qualityTotal;
  double get _netAmount => _totalRevenue - _totalDeductions;

  @override
  void initState() {
    super.initState();
    _fetchNewSiteDetails();
  }

  String _toArabicNumbers(String text) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    for (int i = 0; i < english.length; i++) {
      text = text.replaceAll(english[i], arabic[i]);
    }
    return text;
  }

  String _formatNumber(double num) {
    String numStr = num % 1 == 0 ? num.toInt().toString() : num.toStringAsFixed(1);
    return numStr.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }

  Future<void> _fetchNewSiteDetails() async {
    setState(() => _isLoading = true);

    try {
      _companyCarsRevenue = 0.0;
      _officeCarsRevenue = 0.0;
      _tractorsRevenue = 0.0;
      _totalRevenue = 0.0;
      _companyCarsMeters = 0.0;
      _officeCarsMeters = 0.0;
      _tractorsMeters = 0.0;
      _expensesTotal = 0.0;
      _qualityTotal = 0.0;
      _qualityMetersTotal = 0.0;
      _loaderMeters = 0.0;
      _loaderTotal = 0.0;
      _expensesList.clear();
      _qualityList.clear();

      DateTime start = DateTime(widget.dateRange.start.year, widget.dateRange.start.month, widget.dateRange.start.day, 0, 0, 0);
      DateTime end = DateTime(widget.dateRange.end.year, widget.dateRange.end.month, widget.dateRange.end.day, 23, 59, 59);

      // 1. جلب الأسعار المخصصة للموقع الجديد من الإعدادات
      var settingsSnap = await FirebaseFirestore.instance.collection('settings').get();
      for (var doc in settingsSnap.docs) {
        var data = doc.data();
        if (doc.id == 'sheikh_settings' || doc.id == 'general' || data.containsKey('loaderPrice')) {
          _loaderPrice = double.tryParse(data['loaderPrice']?.toString() ?? '15') ?? _loaderPrice;
        }
        if (data.containsKey('officeTrucksCompany')) {
          _compTruckPrice = double.tryParse(data['officeTrucksCompany']?.toString() ?? '28') ?? _compTruckPrice;
        }
        if (data.containsKey('officeTrucksOffice')) {
          _officeTruckPrice = double.tryParse(data['officeTrucksOffice']?.toString() ?? '64') ?? _officeTruckPrice;
        }
        if (data.containsKey('officeTractors')) {
          _tractorPrice = double.tryParse(data['officeTractors']?.toString() ?? '53') ?? _tractorPrice;
        }
        if (data.containsKey('سعر م ٣ خصم الجودة')) {
          _qualityPrice = double.tryParse(data['سعر م ٣ خصم الجودة']?.toString() ?? '0') ?? _qualityPrice;
        } else if (data.containsKey('سعر م٣ خصم الجودة')) {
          _qualityPrice = double.tryParse(data['سعر م٣ خصم الجودة']?.toString() ?? '0') ?? _qualityPrice;
        }
      }

      // 2. جلب اليوميات الخاصة بالموقع الجديد
      var entriesSnap = await FirebaseFirestore.instance
          .collection('daily_entries')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      for (var doc in entriesSnap.docs) {
        var data = doc.data();
        if (data['site'] == 'new' || data['siteName'] == 'الموقع الجديد') {
          double totalCubage = double.tryParse(data['cubage']?.toString() ?? '0') ?? 0.0;
          bool isTractor = data['isTractor'] == true || '${data['carType'] ?? ''}'.toLowerCase().contains('جرار');
          String typeCode = data['typeCode']?.toString() ?? '';
          var globals = data['snapshotGlobals'] as Map<String, dynamic>? ?? {};

          if (globals.containsKey('officeTrucksCompany')) {
            _compTruckPrice = double.tryParse(globals['officeTrucksCompany'].toString()) ?? _compTruckPrice;
          }
          if (globals.containsKey('officeTrucksOffice')) {
            _officeTruckPrice = double.tryParse(globals['officeTrucksOffice'].toString()) ?? _officeTruckPrice;
          }
          if (globals.containsKey('officeTractors')) {
            _tractorPrice = double.tryParse(globals['officeTractors'].toString()) ?? _tractorPrice;
          }

          // حساب أمتار اللودر للموقع الإجمالي
          _loaderMeters += totalCubage;

          List<dynamic> trips = data['clientsTrips'] ?? [];
          for (var trip in trips) {
            double tripCubage = double.tryParse(trip['cubage']?.toString() ?? '0') ?? 0.0;
            // فحص نوع النقلة لتصنيفها بدقة
            bool tripIsTractor = trip['isTractor'] == true || '${trip['carType'] ?? ''}'.toLowerCase().contains('جرار') || isTractor;
            bool tripIsCompany = trip['isCompanyDriver'] == true || typeCode == 'Z' || '${trip['driverType'] ?? ''}'.toLowerCase().contains('شركة');

            if (tripIsTractor) {
              _tractorsMeters += tripCubage;
            } else if (tripIsCompany) {
              _companyCarsMeters += tripCubage;
            } else {
              _officeCarsMeters += tripCubage;
            }
          }
        }
      }

      // حساب الإيرادات النهائية لكل بند (الأمتار × السعر المسجل في الإعدادات)
      _companyCarsRevenue = _companyCarsMeters * _compTruckPrice;
      _officeCarsRevenue = _officeCarsMeters * _officeTruckPrice;
      _tractorsRevenue = _tractorsMeters * _tractorPrice;
      _totalRevenue = _companyCarsRevenue + _officeCarsRevenue + _tractorsRevenue;

      _loaderTotal = _loaderMeters * _loaderPrice;

      // 3. جلب التسويات والخصومات للموقع الجديد (عهد وجودة فقط)
      var settlementsSnap = await FirebaseFirestore.instance
          .collection('settlements')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .where('siteName', isEqualTo: 'الموقع الجديد')
          .get();

      for (var doc in settlementsSnap.docs) {
        var data = doc.data();
        String type = data['type']?.toString() ?? '';
        double amount = double.tryParse(data['amount']?.toString() ?? '0') ?? 0.0;
        double meters = double.tryParse(data['cubage']?.toString() ?? data['meters']?.toString() ?? '0') ?? 0.0;

        if (type == 'office_expense' || type == 'covenant') {
          _expensesList.add(data);
          _expensesTotal += amount;
        } else if (type == 'quality_discount') {
          _qualityList.add(data);
          _qualityMetersTotal += meters;
          double calculatedQuality = meters > 0 ? (meters * _qualityPrice) : amount;
          _qualityTotal += calculatedQuality;
        }
      }

      if (mounted) setState(() => _isLoading = false);

    } catch (e) {
      debugPrint('Error details: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // دوال التصدير
  Future<void> _exportToExcel() async {
    Navigator.pop(context);
    try {
      var excel = Excel.createExcel();
      String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
      excel.rename(defaultSheet, 'حسابات الموقع الجديد');
      Sheet sheet = excel['حسابات الموقع الجديد'];
      excel.setDefaultSheet('حسابات الموقع الجديد');

      sheet.appendRow([TextCellValue('بند الحساب'), TextCellValue('التفاصيل'), TextCellValue('القيمة (ج.م)')]);
      sheet.appendRow([TextCellValue('حساب السائقين (عربيات الشركة)'), TextCellValue('أمتار: $_companyCarsMeters | سعر: $_compTruckPrice'), TextCellValue(_companyCarsRevenue.toStringAsFixed(0))]);
      sheet.appendRow([TextCellValue('حساب السائقين (عربيات المكتب)'), TextCellValue('أمتار: $_officeCarsMeters | سعر: $_officeTruckPrice'), TextCellValue(_officeCarsRevenue.toStringAsFixed(0))]);
      sheet.appendRow([TextCellValue('حساب الجرارات'), TextCellValue('أمتار: $_tractorsMeters | سعر: $_tractorPrice'), TextCellValue(_tractorsRevenue.toStringAsFixed(0))]);
      sheet.appendRow([TextCellValue('إجمالي العهد والمصروفات'), TextCellValue(''), TextCellValue(_expensesTotal.toStringAsFixed(0))]);
      sheet.appendRow([TextCellValue('خصومات الجودة'), TextCellValue('أمتار: $_qualityMetersTotal | سعر: $_qualityPrice'), TextCellValue(_qualityTotal.toStringAsFixed(0))]);
      sheet.appendRow([TextCellValue('حساب اللودر (تتبع فقط - غير مخصوم)'), TextCellValue('أمتار: $_loaderMeters | سعر: $_loaderPrice'), TextCellValue(_loaderTotal.toStringAsFixed(0))]);
      sheet.appendRow([TextCellValue('صافي المستحق للمكتب'), TextCellValue(''), TextCellValue(_netAmount.toStringAsFixed(0))]);

      var fileBytes = excel.save();
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/حسابات_الموقع_الجديد.xlsx';

      File(path)..createSync(recursive: true)..writeAsBytesSync(fileBytes!);
      await Share.shareXFiles([XFile(path)], text: 'مرفق تقرير حسابات الموقع الجديد');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء تصدير الإكسيل: $e')));
    }
  }

  Future<void> _exportToWord() async {
    Navigator.pop(context);
    try {
      String htmlContent = """
      <html dir="rtl" lang="ar">
      <head><meta charset="utf-8"><style>body{font-family:Tahoma;} table{width:100%; border-collapse:collapse;} th,td{border:1px solid #ddd; padding:8px; text-align:center;} th{background-color:#0F2A52; color:white;}</style></head>
      <body>
      <h2>تقرير حسابات المكتب (الموقع الجديد)</h2>
      <table>
        <tr><th>البند</th><th>التفاصيل</th><th>القيمة</th></tr>
        <tr><td>حساب السائقين (عربيات الشركة)</td><td>أمتار: $_companyCarsMeters | سعر: $_compTruckPrice</td><td>$_companyCarsRevenue ج.م</td></tr>
        <tr><td>حساب السائقين (عربيات المكتب)</td><td>أمتار: $_officeCarsMeters | سعر: $_officeTruckPrice</td><td>$_officeCarsRevenue ج.م</td></tr>
        <tr><td>حساب الجرارات</td><td>أمتار: $_tractorsMeters | سعر: $_tractorPrice</td><td>$_tractorsRevenue ج.م</td></tr>
        <tr><td>إجمالي العهد والمصروفات</td><td>-</td><td>$_expensesTotal ج.م</td></tr>
        <tr><td>خصومات الجودة</td><td>أمتار: $_qualityMetersTotal | سعر: $_qualityPrice</td><td>$_qualityTotal ج.م</td></tr>
        <tr><td>حساب اللودر (تتبع فقط)</td><td>أمتار: $_loaderMeters | سعر: $_loaderPrice</td><td>$_loaderTotal ج.م</td></tr>
        <tr style='font-weight:bold; background-color:#f1f1f1;'><td colspan='2'>صافي المستحق للمكتب</td><td>$_netAmount ج.م</td></tr>
      </table></body></html>
      """;

      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/تقرير_الموقع_الجديد.doc';
      final file = File(path);
      await file.writeAsString(htmlContent);

      await Share.shareXFiles([XFile(path)], text: 'مرفق تقرير Word لحسابات الموقع الجديد');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء تصدير Word: $e')));
    }
  }

  void _showExportBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('تصدير كشف الحساب', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F2A52))),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.table_chart, color: Colors.green, size: 30),
                title: const Text('تصدير كملف Excel', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                onTap: _exportToExcel,
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.description, color: Colors.blue, size: 30),
                title: const Text('تصدير كملف Word', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                onTap: _exportToWord,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isPositive = _netAmount >= 0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F9),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: const Color(0xFF0F2A52),
          title: const Text('تفاصيل الموقع الجديد', style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold)),
          centerTitle: true,
          leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
          actions: [
            IconButton(
              icon: const Icon(Icons.ios_share, color: Colors.white, size: 22),
              onPressed: _showExportBottomSheet,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F2A52)))
            : Column(
          children: [
            // 1. الهيدر العلوي للموقع الجديد
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.green.shade200, width: 1.2),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('إجمالي المستحقات', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              Text('${_toArabicNumbers(_formatNumber(_totalRevenue))} ج', style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w900, color: Colors.green)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.shade200, width: 1.2),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('إجمالي الخصومات', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              Text('${_toArabicNumbers(_formatNumber(_totalDeductions))} ج', style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w900, color: Colors.red)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                    decoration: BoxDecoration(
                      color: isPositive ? Colors.green.shade700 : Colors.red.shade700,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [BoxShadow(color: (isPositive ? Colors.green : Colors.red).withOpacity(0.25), blurRadius: 6, offset: const Offset(0, 2))],
                    ),
                    child: Column(
                      children: [
                        const Text('صافي المستحق للمكتب', style: TextStyle(fontFamily: 'Cairo', color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(
                          '${_toArabicNumbers(_formatNumber(_netAmount.abs()))} ج.م',
                          style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                        ),
                        if (!isPositive)
                          const Text('(المكتب مدين لك بهذا المبلغ)', style: TextStyle(fontFamily: 'Cairo', color: Colors.white70, fontSize: 8.5, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 2. الكروت التفصيلية للموقع الجديد
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  // القائمة المنسدلة بالتسميات والمقاسات اللي طلبتها بالمللي
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        leading: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.business, color: Colors.green, size: 20),
                        ),
                        title: const Text('تفاصيل مستحقات الموقع الجديد', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold)),
                        subtitle: Text('الإجمالي: ${_toArabicNumbers(_formatNumber(_totalRevenue))} ج', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
                        childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        children: [
                          _buildRevenueRow('حساب السائقين (عربيات الشركة)', _companyCarsMeters, _compTruckPrice, _companyCarsRevenue),
                          const Divider(height: 10),
                          _buildRevenueRow('حساب السائقين (عربيات المكتب)', _officeCarsMeters, _officeTruckPrice, _officeCarsRevenue),
                          const Divider(height: 10),
                          _buildRevenueRow('حساب الجرارات', _tractorsMeters, _tractorPrice, _tractorsRevenue),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  _buildCompactCard(
                    title: 'إجمالي العهد والمصروفات',
                    icon: Icons.receipt_long,
                    color: Colors.red,
                    amount: _expensesTotal,
                    subDetail: _expensesList.isEmpty ? 'لا توجد عهد مسجلة' : 'عدد العهد: ${_toArabicNumbers(_expensesList.length.toString())}',
                  ),

                  _buildCompactCard(
                    title: 'إجمالي خصومات الجودة',
                    icon: Icons.verified,
                    color: Colors.purple,
                    amount: _qualityTotal,
                    subDetail: 'أمتار: ${_toArabicNumbers(_formatNumber(_qualityMetersTotal))} م³ | سعر: ${_toArabicNumbers(_formatNumber(_qualityPrice))} ج',
                  ),

                  // كارت اللودر الخاص (تتبع فقط - غير مخصوم)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.shade300, width: 1.2),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.front_loader, color: Colors.brown, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('حساب اللودر (تتبع فقط - غير مخصوم)', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.brown)),
                              Text('أمتار: ${_toArabicNumbers(_formatNumber(_loaderMeters))} م³ | سعر: ${_toArabicNumbers(_formatNumber(_loaderPrice))} ج', style: const TextStyle(fontFamily: 'Cairo', fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                        ),
                        Text('${_toArabicNumbers(_formatNumber(_loaderTotal))} ج', style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.brown, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueRow(String title, double meters, double price, double revenue) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(title, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.black87))),
        Text(
          '${_toArabicNumbers(_formatNumber(meters))} م³ | ${_toArabicNumbers(_formatNumber(price))} ج = ${_toArabicNumbers(_formatNumber(revenue))} ج',
          style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _buildCompactCard({required String title, required IconData icon, required Color color, required double amount, required String subDetail}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                Text(subDetail, style: const TextStyle(fontFamily: 'Cairo', fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
          Text('${_toArabicNumbers(_formatNumber(amount))} ج', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}