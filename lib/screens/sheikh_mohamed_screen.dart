import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart' hide Border, TextSpan;

class SheikhMohamedScreen extends StatefulWidget {
  const SheikhMohamedScreen({super.key});

  @override
  State<SheikhMohamedScreen> createState() => _SheikhMohamedScreenState();
}

class _SheikhMohamedScreenState extends State<SheikhMohamedScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  DateTime? _startDate;
  DateTime? _endDate;

  final Color bakheetTextColor = Colors.teal.shade800;
  final Color adelTextColor = Colors.deepOrange.shade800;
  final Color otherTextColor = Colors.grey.shade800;

  final Color bakheetBgColor = Colors.teal.shade50;
  final Color adelBgColor = Colors.deepOrange.shade50;
  final Color otherBgColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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

  String _formatFullDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _formatStrictRTLDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    String normalized = dateStr.replaceAll('/', '-');
    List<String> parts = normalized.split('-');
    if (parts.length == 3) {
      String y = parts[0], m = parts[1], d = parts[2];
      if (parts[0].length != 4) { d = parts[0]; m = parts[1]; y = parts[2]; }
      return '\u200F$d\u200F-\u200F$m\u200F-\u200F$y\u200F';
    }
    return dateStr;
  }

  DateTime? _parseDate(String dateStr) {
    if (dateStr.isEmpty) return null;
    String normalized = dateStr.replaceAll('/', '-');
    List<String> parts = normalized.split('-');
    if (parts.length == 3) {
      int? y, m, d;
      if (parts[0].length == 4) {
        y = int.tryParse(parts[0]);
        m = int.tryParse(parts[1]);
        d = int.tryParse(parts[2]);
      } else {
        d = int.tryParse(parts[0]);
        m = int.tryParse(parts[1]);
        y = int.tryParse(parts[2]);
      }
      if (y != null && m != null && d != null) {
        return DateTime(y, m, d);
      }
    }
    return DateTime.tryParse(dateStr);
  }

  Future<void> _pickDateRange() async {
    DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: 'اختر فترة الفلترة',
      cancelText: 'إلغاء',
      confirmText: 'تطبيق',
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF0F2A52), onPrimary: Colors.white),
          ),
          child: child!,
        ),
      ),
    );

    if (picked != null) {
      setState(() {
        _startDate = DateTime(picked.start.year, picked.start.month, picked.start.day);
        _endDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
      });
    }
  }

  void _clearFilter() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
  }

  void _navigateToAddPayment() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SheikhMohamedFormScreen(isEdit: false),
      ),
    );
  }

  void _navigateToEditPayment(String docId, Map<String, dynamic> paymentData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SheikhMohamedFormScreen(
          isEdit: true,
          docId: docId,
          initialAmount: paymentData['amount']?.toString() ?? '',
          initialMethod: paymentData['paymentMethod'] ?? 'كاش',
          initialDateStr: paymentData['dateString'] ?? _formatFullDate(DateTime.now()),
        ),
      ),
    );
  }

  void _showExportOptions(Map<String, dynamic> reportData) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (bottomContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('تصدير كشف حساب الشيخ محمد', style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF103667))),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.table_chart, color: Colors.green, size: 30),
                title: const Text('تصدير كملف Excel', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                onTap: () { Navigator.pop(bottomContext); _exportToExcel(reportData); },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.description, color: Colors.blue, size: 30),
                title: const Text('تصدير كملف Word', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                onTap: () { Navigator.pop(bottomContext); _exportToWord(reportData); },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportToExcel(Map<String, dynamic> data) async {
    final currentContext = context;
    try {
      var excel = Excel.createExcel();
      String sheetName = 'حساب_الشيخ_محمد';
      excel.rename(excel.getDefaultSheet() ?? 'Sheet1', sheetName);
      Sheet sheet = excel[sheetName];
      excel.setDefaultSheet(sheetName);

      sheet.appendRow([TextCellValue('\u200Fكشف حساب الشيخ محمد (الموقع الجديد)\u200F')]);
      sheet.appendRow([TextCellValue('\u200Fسعر المتر المعتمد للجرارات: ${_toArabicNumbers(data['meterPrice'].toString())} ج\u200F')]);
      sheet.appendRow([TextCellValue('')]);
      sheet.appendRow([TextCellValue('\u200Fإجمالي المستحقات:\u200F'), TextCellValue('\u200F${_toArabicNumbers(data['totalDues'].toString())} ج\u200F')]);
      sheet.appendRow([TextCellValue('\u200Fإجمالي المدفوعات:\u200F'), TextCellValue('\u200F${_toArabicNumbers(data['totalPayments'].toString())} ج\u200F')]);
      sheet.appendRow([TextCellValue('\u200Fصافي المتبقي:\u200F'), TextCellValue('\u200F${_toArabicNumbers(data['netRemaining'].toString())} ج\u200F')]);
      sheet.appendRow([TextCellValue('')]);

      sheet.appendRow([TextCellValue('\u200F--- تفاصيل أمتار الجرارات ---\u200F')]);
      sheet.appendRow([TextCellValue('\u200Fالتاريخ\u200F'), TextCellValue('\u200Fالعميل\u200F'), TextCellValue('\u200Fالسائق\u200F'), TextCellValue('\u200Fرقم الجرار\u200F'), TextCellValue('\u200Fالنقلات\u200F'), TextCellValue('\u200Fسعة السيارة\u200F'), TextCellValue('\u200Fالإجمالي\u200F')]);
      for (var t in data['trips']) {
        sheet.appendRow([
          TextCellValue('\u200F${_toArabicNumbers(_formatStrictRTLDate(t['dateString'].toString()))}\u200F'),
          TextCellValue('\u200F${t['clientName']}\u200F'),
          TextCellValue('\u200F${t['driverName']}\u200F'),
          TextCellValue('\u200F${_toArabicNumbers(t['vehicleNumber'])}\u200F'),
          TextCellValue('\u200F${_toArabicNumbers(t['tripsCount'].toString())}\u200F'),
          TextCellValue('\u200F${_toArabicNumbers(t['vCubage'].toString())} م³\u200F'),
          TextCellValue('\u200F${_toArabicNumbers(t['cubage'].toString())} م³\u200F'),
        ]);
      }
      sheet.appendRow([TextCellValue('')]);

      sheet.appendRow([TextCellValue('\u200F--- سجل الدفعات ---\u200F')]);
      sheet.appendRow([TextCellValue('\u200Fالتاريخ\u200F'), TextCellValue('\u200Fطريقة الدفع\u200F'), TextCellValue('\u200Fالمبلغ\u200F')]);
      for (var p in data['payments']) {
        sheet.appendRow([
          TextCellValue('\u200F${_toArabicNumbers(_formatStrictRTLDate(p['dateString'].toString()))}\u200F'),
          TextCellValue('\u200F${p['paymentMethod']}\u200F'),
          TextCellValue('\u200F${_toArabicNumbers(p['amount'].toString())} ج\u200F'),
        ]);
      }

      var fileBytes = excel.save();
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/كشف_حساب_الشيخ_محمد.xlsx';
      File(path)..createSync(recursive: true)..writeAsBytesSync(fileBytes!);

      if (!currentContext.mounted) return;
      await Share.shareXFiles([XFile(path)], text: 'مرفق حساب الشيخ محمد');
    } catch (e) {
      if (!currentContext.mounted) return;
      ScaffoldMessenger.of(currentContext).showSnackBar(SnackBar(content: Text('خطأ في الإكسيل: $e')));
    }
  }

  Future<void> _exportToWord(Map<String, dynamic> data) async {
    final currentContext = context;
    try {
      String tripsRows = data['trips'].map((t) => "<tr align=\"right\"><td align=\"right\">${_toArabicNumbers(_formatStrictRTLDate(t['dateString'].toString()))}</td><td align=\"right\">${t['clientName']}</td><td align=\"right\">${t['driverName']}</td><td align=\"right\">${_toArabicNumbers(t['vehicleNumber'])}</td><td align=\"right\">${_toArabicNumbers(t['tripsCount'].toString())}</td><td align=\"right\">${_toArabicNumbers(t['vCubage'].toString())} م³</td><td align=\"right\">${_toArabicNumbers(t['cubage'].toString())} م³</td></tr>").join('');
      String paysRows = data['payments'].map((p) => "<tr align=\"right\"><td align=\"right\">${_toArabicNumbers(_formatStrictRTLDate(p['dateString'].toString()))}</td><td align=\"right\">${p['paymentMethod']}</td><td align=\"right\">${_toArabicNumbers(p['amount'].toString())} ج</td></tr>").join('');

      String htmlContent = """
      <html dir="rtl" lang="ar">
      <head>
        <meta charset="utf-8">
        <style>
          body, div, p, h2, h3, table, th, td { direction: rtl; text-align: right !important; font-family: Tahoma, Arial, sans-serif; }
          h2, h3 { color: #103667; }
          table { width: 100%; border-collapse: collapse; margin-bottom: 20px; }
          th, td { border: 1px solid #ddd; padding: 8px; font-size: 13px; }
          th { background-color: #103667; color: white; font-weight: bold; }
          .summary { background-color: #f4f6f9; padding: 15px; border-radius: 8px; margin-bottom: 20px; font-weight: bold; border: 1px solid #103667; }
        </style>
      </head>
      <body dir="rtl">
      
      <h2 align="right" dir="rtl">كشف حساب الشيخ محمد (الموقع الجديد)</h2>
      
      <div class="summary" align="right" dir="rtl">
        <p align="right" dir="rtl">سعر المتر المعتمد للجرارات: ${_toArabicNumbers(data['meterPrice'].toString())} ج.م</p>
        <p align="right" dir="rtl">إجمالي المستحقات: ${_toArabicNumbers(data['totalDues'].toString())} ج.م | إجمالي الدفعات: ${_toArabicNumbers(data['totalPayments'].toString())} ج.م</p>
        <h3 align="right" dir="rtl" style="color: ${data['netRemaining'] >= 0 ? 'green' : 'red'};">صافي المتبقي: ${_toArabicNumbers(data['netRemaining'].toString())} ج.م</h3>
      </div>
      
      <h3 align="right" dir="rtl">تفاصيل أمتار الجرارات</h3>
      <table border="1" dir="rtl" align="right">
        <tr align="right">
          <th align="right">التاريخ</th>
          <th align="right">العميل</th>
          <th align="right">السائق</th>
          <th align="right">رقم الجرار</th>
          <th align="right">النقلات</th>
          <th align="right">سعة السيارة</th>
          <th align="right">الإجمالي</th>
        </tr>
        $tripsRows
      </table>

      <h3 align="right" dir="rtl">سجل الدفعات والتسويات</h3>
      <table border="1" dir="rtl" align="right">
        <tr align="right">
          <th align="right">التاريخ</th>
          <th align="right">طريقة الدفع</th>
          <th align="right">المبلغ</th>
        </tr>
        $paysRows
      </table>
      
      </body></html>
      """;

      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/كشف_حساب_الشيخ_محمد.doc';
      File(path).writeAsStringSync(htmlContent);

      if (!currentContext.mounted) return;
      await Share.shareXFiles([XFile(path)], text: 'مرفق حساب الشيخ محمد');
    } catch (e) {
      if (!currentContext.mounted) return;
      ScaffoldMessenger.of(currentContext).showSnackBar(SnackBar(content: Text('خطأ في الوورد: $e')));
    }
  }

  Widget _buildCenterDashCard({required String title, required String value, required Color color, Widget? bottomWidget}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(title, textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: color))
          ),
          const SizedBox(height: 6),
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.w900, color: color))),
          if (bottomWidget != null) ...[
            const SizedBox(height: 4),
            bottomWidget,
          ]
        ],
      ),
    );
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
                      double bakheetMeters = 0.0;
                      double adelMeters = 0.0;
                      double otherMeters = 0.0;

                      List<Map<String, dynamic>> tractorTrips = [];

                      if (tripsSnapshot.hasData) {
                        for (var doc in tripsSnapshot.data!.docs) {
                          var data = doc.data() as Map<String, dynamic>;

                          String site = data['site']?.toString() ?? 'old';
                          if (site != 'new' && site != 'الموقع الجديد') continue;

                          bool isTractor = data['isTractor'] ?? false;
                          if (!isTractor) continue;

                          String dateStr = data['dateString'] ?? '';

                          if (_startDate != null && _endDate != null) {
                            DateTime? d = _parseDate(dateStr);
                            if (d != null && (d.isBefore(_startDate!) || d.isAfter(_endDate!))) {
                              continue;
                            }
                          }

                          String vehicleNumber = data['vehicleNumber']?.toString() ?? 'بدون رقم';
                          double vCubage = double.tryParse(data['cubage']?.toString() ?? '0') ?? 0.0;

                          List<dynamic> cTrips = data['clientsTrips'] ?? [];
                          for (var c in cTrips) {
                            int tripsCount = int.tryParse((c['tripsCount'] ?? c['trips'] ?? '0').toString()) ?? 0;
                            if (tripsCount > 0) {
                              double cubage = double.tryParse((c['totalCubage'] ?? c['cubage'] ?? '0').toString()) ?? 0.0;
                              if (cubage == 0) {
                                cubage = tripsCount * vCubage;
                              }

                              totalTractorMeters += cubage;

                              String clientName = c['clientName'] ?? c['name'] ?? 'غير محدد';
                              if (clientName.contains('بخيت')) {
                                bakheetMeters += cubage;
                              } else if (clientName.contains('عادل')) {
                                adelMeters += cubage;
                              } else {
                                otherMeters += cubage;
                              }

                              tractorTrips.add({
                                'clientName': clientName,
                                'driverName': data['driverName'] ?? 'بدون سائق',
                                'vehicleNumber': vehicleNumber,
                                'tripsCount': tripsCount,
                                'vCubage': vCubage,
                                'dateString': dateStr,
                                'cubage': cubage,
                                'timestamp': data['createdAt'] ?? data['timestamp'],
                              });
                            }
                          }
                        }
                      }

                      tractorTrips.sort((a, b) {
                        if (a['timestamp'] != null && b['timestamp'] != null) {
                          return (b['timestamp'] as Timestamp).compareTo(a['timestamp'] as Timestamp);
                        }
                        return 0;
                      });

                      double totalDues = totalTractorMeters * meterPrice;

                      double totalPayments = 0.0;
                      List<QueryDocumentSnapshot> paymentsDocs = [];
                      List<Map<String, dynamic>> exportPayments = [];
                      if (paymentsSnapshot.hasData) {
                        for (var doc in paymentsSnapshot.data!.docs) {
                          var pData = doc.data() as Map<String, dynamic>;
                          String pDateStr = pData['dateString'] ?? '';

                          if (_startDate != null && _endDate != null) {
                            DateTime? d = _parseDate(pDateStr);
                            if (d != null && (d.isBefore(_startDate!) || d.isAfter(_endDate!))) {
                              continue;
                            }
                          }

                          totalPayments += double.tryParse(pData['amount']?.toString() ?? '0') ?? 0.0;
                          paymentsDocs.add(doc);
                          exportPayments.add(pData);
                        }
                      }

                      paymentsDocs.sort((a, b) => ((b.data() as Map)['timestamp']?.millisecondsSinceEpoch ?? 0).compareTo((a.data() as Map)['timestamp']?.millisecondsSinceEpoch ?? 0));
                      exportPayments.sort((a, b) => (b['timestamp']?.millisecondsSinceEpoch ?? 0).compareTo(a['timestamp']?.millisecondsSinceEpoch ?? 0));

                      double netRemaining = totalDues - totalPayments;
                      bool isSheikhOwed = netRemaining >= 0;

                      Color statusColor = isSheikhOwed ? const Color(0xFF388E3C) : const Color(0xFFD32F2F);
                      Color statusBgColor = isSheikhOwed ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE);

                      Map<String, dynamic> exportData = {
                        'meterPrice': meterPrice,
                        'totalDues': totalDues,
                        'totalPayments': totalPayments,
                        'netRemaining': netRemaining,
                        'trips': tractorTrips,
                        'payments': exportPayments,
                      };

                      return Directionality(
                        textDirection: TextDirection.rtl,
                        child: Scaffold(
                          backgroundColor: const Color(0xFFF4F6F9),
                          appBar: AppBar(
                            title: const Text('حساب الشيخ محمد', style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                            backgroundColor: const Color(0xFF0F2A52),
                            centerTitle: true,
                            elevation: 0,
                            leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
                            actions: [
                              IconButton(
                                icon: Icon(
                                  _startDate != null ? Icons.filter_alt : Icons.filter_alt_outlined,
                                  color: _startDate != null ? const Color(0xFF00D2FF) : Colors.white,
                                  size: 22,
                                ),
                                tooltip: 'فلتر بالتاريخ',
                                onPressed: _pickDateRange,
                              ),
                              IconButton(
                                icon: const Icon(Icons.ios_share, color: Colors.white, size: 22),
                                tooltip: 'تصدير الكشف',
                                onPressed: () => _showExportOptions(exportData),
                              ),
                            ],
                            bottom: TabBar(
                              controller: _tabController,
                              labelColor: const Color(0xFF00D2FF),
                              unselectedLabelColor: Colors.white70,
                              indicatorWeight: 3,
                              labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12),
                              tabs: const [
                                Tab(text: 'أمتار الجرارات', icon: Icon(Icons.local_shipping, size: 18)),
                                Tab(text: 'سجل الدفعات', icon: Icon(Icons.receipt_long, size: 18)),
                              ],
                            ),
                          ),
                          floatingActionButton: _tabController.index == 1 ? FloatingActionButton.extended(
                            onPressed: _navigateToAddPayment,
                            backgroundColor: const Color(0xFF0F2A52),
                            icon: const Icon(Icons.add, color: Colors.white),
                            label: const Text('صرف دفعة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
                          ) : null,
                          body: Column(
                            children: [
                              if (_startDate != null && _endDate != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  color: Colors.amber.shade100,
                                  child: Row(
                                    children: [
                                      const Icon(Icons.date_range, size: 16, color: Colors.brown),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'الفترة المفعلة: ${_toArabicNumbers(_formatStrictRTLDate(_formatFullDate(_startDate!)))} إلى ${_toArabicNumbers(_formatStrictRTLDate(_formatFullDate(_endDate!)))}',
                                          style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.brown),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close, size: 16, color: Colors.red),
                                        onPressed: _clearFilter,
                                        tooltip: 'إلغاء الفلتر',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                ),

                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                color: Colors.white,
                                child: _tabController.index == 0
                                    ? Column(
                                  children: [
                                    IntrinsicHeight(
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          Expanded(
                                            child: _buildCenterDashCard(
                                              title: 'المستحقات',
                                              value: '${_toArabicNumbers(_formatNumber(totalDues))} ج',
                                              color: const Color(0xFFFF8F00),
                                              bottomWidget: Text('\u200F(\u200Fالسعر: ${_toArabicNumbers(meterPrice.toString())} ج\u200F)\u200F', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6A1B9A))),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: _buildCenterDashCard(
                                              title: 'إجمالي الدفعات',
                                              value: '${_toArabicNumbers(_formatNumber(totalPayments))} ج',
                                              color: const Color(0xFF388E3C),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: _buildCenterDashCard(
                                              title: 'أمتار الجرارات\n\u200F(\u200Fالموقع الجديد\u200F)\u200F',
                                              value: '${_toArabicNumbers(_formatNumber(totalTractorMeters))} م³',
                                              color: const Color(0xFF4A78B9),
                                              bottomWidget: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Divider(height: 6, thickness: 0.5),
                                                  Text('بخيت: ${_toArabicNumbers(_formatNumber(bakheetMeters))} م³', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: bakheetTextColor)),
                                                  Text('عادل: ${_toArabicNumbers(_formatNumber(adelMeters))} م³', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: adelTextColor)),
                                                  if (otherMeters > 0)
                                                    Text('أخرى: ${_toArabicNumbers(_formatNumber(otherMeters))} م³', style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: otherTextColor)),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                      decoration: BoxDecoration(
                                        color: statusBgColor,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: statusColor, width: 1.0),
                                      ),
                                      child: Column(
                                        children: [
                                          Text('صافي المتبقي للشيخ محمد', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold, color: statusColor)),
                                          Text('${_toArabicNumbers(_formatNumber(netRemaining))} ج.م', style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w900, color: statusColor)),
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                                    : Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F5E9),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFF2E7D32), width: 2),
                                  ),
                                  child: Column(
                                    children: [
                                      const Text('إجمالي الدفعات المسجلة', style: TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
                                      const SizedBox(height: 8),
                                      Text('${_toArabicNumbers(_formatNumber(totalPayments))} ج.م', style: const TextStyle(fontFamily: 'Cairo', fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF1B5E20))),
                                    ],
                                  ),
                                ),
                              ),

                              Expanded(
                                child: TabBarView(
                                  controller: _tabController,
                                  children: [
                                    tractorTrips.isEmpty
                                        ? const Center(child: Text('لا توجد أمتار جرارات في الموقع الجديد', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)))
                                        : ListView.builder(
                                      padding: const EdgeInsets.all(8),
                                      itemCount: tractorTrips.length,
                                      itemBuilder: (context, index) {
                                        var trip = tractorTrips[index];
                                        String dateStr = trip['dateString'] ?? '';
                                        String cubage = trip['cubage']?.toString() ?? '0';
                                        String vCubageStr = trip['vCubage']?.toString() ?? '0';

                                        Color currentCardBgColor = otherBgColor;
                                        if (trip['clientName'].toString().contains('بخيت')) {
                                          currentCardBgColor = bakheetBgColor;
                                        } else if (trip['clientName'].toString().contains('عادل')) {
                                          currentCardBgColor = adelBgColor;
                                        }

                                        String detailsRow = '${_toArabicNumbers(_formatStrictRTLDate(dateStr))} | ${trip['clientName']} | ${trip['driverName']} | ${_toArabicNumbers(trip['vehicleNumber'])} | ${_toArabicNumbers(trip['tripsCount'].toString())} نقلة | ${_toArabicNumbers(_formatNumber(double.tryParse(vCubageStr) ?? 0))} م³';

                                        return Card(
                                          color: currentCardBgColor,
                                          elevation: 1,
                                          margin: const EdgeInsets.only(bottom: 6),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    detailsRow,
                                                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F2A52)),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  '${_toArabicNumbers(_formatNumber(double.tryParse(cubage) ?? 0))} م³',
                                                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF4A78B9)),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),

                                    paymentsDocs.isEmpty
                                        ? const Center(child: Text('لم يتم تسجيل أي دفعات للشيخ محمد', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)))
                                        : ListView.builder(
                                      padding: const EdgeInsets.all(8),
                                      itemCount: paymentsDocs.length,
                                      itemBuilder: (context, index) {
                                        var doc = paymentsDocs[index];
                                        var p = doc.data() as Map<String, dynamic>;
                                        String displayDate = p['dateString'] ?? (p['timestamp'] != null ? '${(p['timestamp'] as Timestamp).toDate().year}-${(p['timestamp'] as Timestamp).toDate().month.toString().padLeft(2, '0')}-${(p['timestamp'] as Timestamp).toDate().day.toString().padLeft(2, '0')}' : 'بدون تاريخ');

                                        String detailsRow = '${_toArabicNumbers(_formatStrictRTLDate(displayDate))} | ${p['paymentMethod'] ?? 'كاش'}';

                                        return Card(
                                          elevation: 1,
                                          margin: const EdgeInsets.only(bottom: 6),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          child: InkWell(
                                            onTap: () => _navigateToEditPayment(doc.id, p),
                                            borderRadius: BorderRadius.circular(8),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      detailsRow,
                                                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F2A52)),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    '${_toArabicNumbers(_formatNumber(double.tryParse(p['amount'].toString()) ?? 0))} ج',
                                                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF388E3C)),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
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

// ====================================================================
// شاشة مستقلة (Full-Screen Form) لتسجيل وتعديل الدفعات (بدون رسائل مزعجة)
// ====================================================================
class SheikhMohamedFormScreen extends StatefulWidget {
  final bool isEdit;
  final String? docId;
  final String? initialAmount;
  final String? initialMethod;
  final String? initialDateStr;

  const SheikhMohamedFormScreen({
    super.key,
    required this.isEdit,
    this.docId,
    this.initialAmount,
    this.initialMethod,
    this.initialDateStr,
  });

  @override
  State<SheikhMohamedFormScreen> createState() => _SheikhMohamedFormScreenState();
}

class _SheikhMohamedFormScreenState extends State<SheikhMohamedFormScreen> {
  late TextEditingController _amountController;
  late String _selectedMethod;
  late DateTime _selectedDate;
  final List<String> _paymentMethods = ['كاش', 'فودافون كاش', 'إنستاباي', 'تحويل بنكي', 'شيك بنكي'];

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: widget.initialAmount ?? '');
    _selectedMethod = widget.initialMethod ?? 'كاش';

    if (widget.initialDateStr != null && widget.initialDateStr!.isNotEmpty) {
      List<String> parts = widget.initialDateStr!.split('-');
      if (parts.length == 3) {
        _selectedDate = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
      } else {
        _selectedDate = DateTime.now();
      }
    } else {
      _selectedDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  String _toArabicNumbers(String text) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    for (int i = 0; i < english.length; i++) {
      text = text.replaceAll(english[i], arabic[i]);
    }
    return text;
  }

  String _formatFullDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _formatStrictRTLDate(String dateStr) {
    List<String> parts = dateStr.split('-');
    if (parts.length == 3) {
      return '\u200F${parts[2]}\u200F-\u200F${parts[1]}\u200F-\u200F${parts[0]}\u200F';
    }
    return dateStr;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F9),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F2A52),
          title: Text(
            widget.isEdit ? 'تعديل أو حذف الدفعة' : 'تسجيل دفعة جديدة للشيخ محمد',
            style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('قيمة الدفعة (ج.م)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Color(0xFF0F2A52), fontSize: 14)),
              const SizedBox(height: 8),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'أدخل المبلغ',
                  suffixText: 'ج.م',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              const Text('طريقة التحويل', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Color(0xFF0F2A52), fontSize: 14)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _paymentMethods.contains(_selectedMethod) ? _selectedMethod : 'كاش',
                    isExpanded: true,
                    items: _paymentMethods.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedMethod = val;
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('تاريخ الدفعة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Color(0xFF0F2A52), fontSize: 14)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                    builder: (context, child) => Theme(
                      data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF28A745))),
                      child: child!,
                    ),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                  }
                },
                icon: const Icon(Icons.calendar_month, color: Color(0xFF28A745)),
                label: Text('تاريخ الدفعة: ${_toArabicNumbers(_formatStrictRTLDate(_formatFullDate(_selectedDate)))}', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.black87)),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  side: const BorderSide(color: Colors.grey),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 40),
              if (!widget.isEdit)
                ElevatedButton(
                  onPressed: () async {
                    if (_amountController.text.isNotEmpty) {
                      double amount = double.tryParse(_amountController.text) ?? 0.0;
                      await FirebaseFirestore.instance.collection('settlements').add({
                        'type': 'sheikh_payment',
                        'name': 'الشيخ محمد',
                        'amount': amount,
                        'paymentMethod': _selectedMethod,
                        'dateString': _formatFullDate(_selectedDate),
                        'timestamp': FieldValue.serverTimestamp(),
                      });
                      if (!context.mounted) return;
                      Navigator.pop(context); // العودة الصامتة بدون رسائل مزعجة
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF28A745),
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('حفظ وتسديد الدفعة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          bool? confirm = await showDialog(
                            context: context,
                            builder: (confirmContext) => Directionality(
                              textDirection: TextDirection.rtl,
                              child: AlertDialog(
                                title: const Text('تأكيد الحذف', style: TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold)),
                                content: const Text('هل أنت متأكد من حذف هذه الدفعة نهائياً؟', style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(confirmContext, false), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(confirmContext, true),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                    child: const Text('حذف', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
                                  ),
                                ],
                              ),
                            ),
                          );

                          if (confirm == true && widget.docId != null) {
                            await FirebaseFirestore.instance.collection('settlements').doc(widget.docId).delete();
                            if (!context.mounted) return;
                            Navigator.pop(context); // العودة الصامتة
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 52),
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('حذف الدفعة', style: TextStyle(fontFamily: 'Cairo', color: Colors.red, fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (_amountController.text.isNotEmpty && widget.docId != null) {
                            double amount = double.tryParse(_amountController.text) ?? 0.0;
                            await FirebaseFirestore.instance.collection('settlements').doc(widget.docId).update({
                              'amount': amount,
                              'paymentMethod': _selectedMethod,
                              'updatedAt': FieldValue.serverTimestamp(),
                            });
                            if (!context.mounted) return;
                            Navigator.pop(context); // العودة الصامتة
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F2A52),
                          minimumSize: const Size(double.infinity, 52),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('حفظ التعديل', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15)),
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
}