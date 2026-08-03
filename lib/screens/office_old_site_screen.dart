import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart' hide Border;

class OfficeOldSiteScreen extends StatefulWidget {
  final DateTimeRange dateRange;

  const OfficeOldSiteScreen({super.key, required this.dateRange});

  @override
  State<OfficeOldSiteScreen> createState() => _OfficeOldSiteScreenState();
}

class _OfficeOldSiteScreenState extends State<OfficeOldSiteScreen> {
  bool _isLoading = false;

  // الإيرادات وتفاصيل الشركات
  Map<String, double> _clientTotals = {};
  Map<String, double> _clientMeters = {};
  Map<String, double> _clientPrices = {};
  double _totalRevenue = 0.0;

  // الخصومات والتفاصيل
  double _zMeters = 0.0;
  double _zPrice = 40.0;
  double _zDeduction = 0.0;

  double _loaderMeters = 0.0;
  double _loaderPrice = 15.0;
  double _loaderDeduction = 0.0;

  List<Map<String, dynamic>> _qualityList = [];
  double _qualityTotal = 0.0;
  double _qualityMetersTotal = 0.0;
  double _qualityPrice = 0.0;

  List<Map<String, dynamic>> _expensesList = [];
  double _expensesTotal = 0.0;

  List<Map<String, dynamic>> _offsetList = [];
  double _offsetTotal = 0.0;

  // المجاميع النهائية
  double get _totalDeductions => _zDeduction + _loaderDeduction + _qualityTotal + _expensesTotal - _offsetTotal;
  double get _netAmount => _totalRevenue - _totalDeductions;

  @override
  void initState() {
    super.initState();
    _fetchOldSiteDetails();
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

  Future<void> _fetchOldSiteDetails() async {
    setState(() => _isLoading = true);

    try {
      _clientTotals.clear();
      _clientMeters.clear();
      _clientPrices.clear();
      _totalRevenue = 0.0;
      _zMeters = 0.0;
      _zDeduction = 0.0;
      _loaderMeters = 0.0;
      _loaderDeduction = 0.0;
      _qualityList.clear();
      _qualityTotal = 0.0;
      _qualityMetersTotal = 0.0;
      _expensesList.clear();
      _expensesTotal = 0.0;
      _offsetList.clear();
      _offsetTotal = 0.0;

      DateTime start = DateTime(widget.dateRange.start.year, widget.dateRange.start.month, widget.dateRange.start.day, 0, 0, 0);
      DateTime end = DateTime(widget.dateRange.end.year, widget.dateRange.end.month, widget.dateRange.end.day, 23, 59, 59);

      // 1. جلب إعدادات الأسعار بالاسم الدقيق من الإعدادات
      var settingsSnap = await FirebaseFirestore.instance.collection('settings').get();
      for (var doc in settingsSnap.docs) {
        var data = doc.data();

        if (doc.id == 'sheikh_settings' || doc.id == 'general' || data.containsKey('loaderPrice')) {
          _loaderPrice = double.tryParse(data['loaderPrice']?.toString() ?? '15') ?? _loaderPrice;
        }
        if (doc.id == 'prices_settings' || data.containsKey('companyDriverPrice')) {
          _zPrice = double.tryParse(data['companyDriverPrice']?.toString() ?? '40') ?? _zPrice;
        }

        // جلب سعر خصم الجودة بالاسم الدقيق
        if (data.containsKey('سعر م ٣ خصم الجودة')) {
          _qualityPrice = double.tryParse(data['سعر م ٣ خصم الجودة']?.toString() ?? '0') ?? _qualityPrice;
        } else if (data.containsKey('سعر م٣ خصم الجودة')) {
          _qualityPrice = double.tryParse(data['سعر م٣ خصم الجودة']?.toString() ?? '0') ?? _qualityPrice;
        }
      }

      // 2. جلب اليوميات
      var entriesSnap = await FirebaseFirestore.instance
          .collection('daily_entries')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      for (var doc in entriesSnap.docs) {
        var data = doc.data();
        if (data['site'] == 'old' || data['site'] == null) {
          double totalCubage = double.tryParse(data['cubage']?.toString() ?? '0') ?? 0.0;
          String typeCode = data['typeCode']?.toString() ?? '';
          var globals = data['snapshotGlobals'] as Map<String, dynamic>? ?? {};

          if (globals.containsKey('loaderPrice')) {
            _loaderPrice = double.tryParse(globals['loaderPrice'].toString()) ?? _loaderPrice;
          }
          if (globals.containsKey('companyDriverPrice')) {
            _zPrice = double.tryParse(globals['companyDriverPrice'].toString()) ?? _zPrice;
          }

          List<dynamic> trips = data['clientsTrips'] ?? [];
          for (var trip in trips) {
            String clientName = trip['clientName']?.toString() ?? 'غير معروف';
            double tripCubage = double.tryParse(trip['cubage']?.toString() ?? '0') ?? 0.0;
            double officePrice = double.tryParse(trip['officePriceSnapshot']?.toString() ?? '0') ?? 0.0;

            double tripValue = tripCubage * officePrice;
            _clientTotals[clientName] = (_clientTotals[clientName] ?? 0) + tripValue;
            _clientMeters[clientName] = (_clientMeters[clientName] ?? 0) + tripCubage;
            _clientPrices[clientName] = officePrice;
            _totalRevenue += tripValue;
          }

          if (typeCode == 'Z') {
            _zMeters += totalCubage;
            _zDeduction += (totalCubage * _zPrice);
          }

          _loaderMeters += totalCubage;
          _loaderDeduction += (totalCubage * _loaderPrice);
        }
      }

      // 3. جلب التسويات والخصومات
      var settlementsSnap = await FirebaseFirestore.instance
          .collection('settlements')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .where('siteName', isEqualTo: 'الموقع القديم')
          .get();

      for (var doc in settlementsSnap.docs) {
        var data = doc.data();
        String type = data['type']?.toString() ?? '';
        double amount = double.tryParse(data['amount']?.toString() ?? '0') ?? 0.0;
        double meters = double.tryParse(data['cubage']?.toString() ?? data['meters']?.toString() ?? '0') ?? 0.0;

        if (type == 'office_expense' || type == 'loader_account') {
          _expensesList.add(data);
          _expensesTotal += amount;
        } else if (type == 'quality_discount') {
          _qualityList.add(data);
          _qualityMetersTotal += meters;
          double calculatedQuality = meters > 0 ? (meters * _qualityPrice) : amount;
          _qualityTotal += calculatedQuality;
        } else if (type == 'offset_transfer') {
          _offsetList.add(data);
          _offsetTotal += amount;
        }
      }

      if (mounted) setState(() => _isLoading = false);

    } catch (e) {
      debugPrint('Error details: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _processOffsetTransfer() async {
    if (_netAmount >= 0) return;

    double transferAmount = _netAmount.abs();

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.sync_alt, color: Color(0xFF0F2A52)),
              SizedBox(width: 8),
              Text('ترحيل رصيد دائن', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Text(
            'لك رصيد دائن في الموقع القديم بقيمة ${_toArabicNumbers(_formatNumber(transferAmount))} ج.م\n\nهل تريد تصفية هذا الموقع وترحيل المبلغ كخصم من مديونيتك في "الموقع الجديد"؟',
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF28A745)),
              onPressed: () async {
                Navigator.pop(context);
                setState(() => _isLoading = true);

                try {
                  await FirebaseFirestore.instance.collection('settlements').add({
                    'type': 'offset_transfer',
                    'name': 'ترحيل رصيد دائن للموقع الجديد',
                    'amount': transferAmount,
                    'siteName': 'الموقع القديم',
                    'timestamp': FieldValue.serverTimestamp(),
                  });

                  await FirebaseFirestore.instance.collection('settlements').add({
                    'type': 'office_expense',
                    'name': 'رصيد دائن مرحل من الموقع القديم',
                    'amount': transferAmount,
                    'siteName': 'الموقع الجديد',
                    'timestamp': FieldValue.serverTimestamp(),
                  });

                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت المقاصة وترحيل الرصيد بنجاح!', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green));
                  _fetchOldSiteDetails();

                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء الترحيل: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red));
                  setState(() => _isLoading = false);
                }
              },
              child: const Text('تأكيد وترحيل', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // دوال التصدير
  Future<void> _exportToExcel() async {
    Navigator.pop(context);
    try {
      var excel = Excel.createExcel();
      String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
      excel.rename(defaultSheet, 'حسابات الموقع القديم');
      Sheet sheet = excel['حسابات الموقع القديم'];
      excel.setDefaultSheet('حسابات الموقع القديم');

      sheet.appendRow([TextCellValue('بند الحساب'), TextCellValue('التفاصيل'), TextCellValue('القيمة (ج.م)')]);
      sheet.appendRow([TextCellValue('إجمالي المستحقات'), TextCellValue('إيرادات الشركات'), TextCellValue(_totalRevenue.toStringAsFixed(0))]);
      sheet.appendRow([TextCellValue('خصم سيارات الشركة Z'), TextCellValue('أمتار: $_zMeters | سعر: $_zPrice'), TextCellValue(_zDeduction.toStringAsFixed(0))]);
      sheet.appendRow([TextCellValue('حساب اللودر'), TextCellValue('أمتار: $_loaderMeters | سعر: $_loaderPrice'), TextCellValue(_loaderDeduction.toStringAsFixed(0))]);
      sheet.appendRow([TextCellValue('إجمالي العهد والمصروفات'), TextCellValue(''), TextCellValue(_expensesTotal.toStringAsFixed(0))]);
      sheet.appendRow([TextCellValue('خصومات الجودة'), TextCellValue('أمتار: $_qualityMetersTotal | سعر: $_qualityPrice'), TextCellValue(_qualityTotal.toStringAsFixed(0))]);
      sheet.appendRow([TextCellValue('صافي المستحق للمكتب'), TextCellValue(''), TextCellValue(_netAmount.toStringAsFixed(0))]);

      var fileBytes = excel.save();
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/حسابات_الموقع_القديم.xlsx';

      File(path)..createSync(recursive: true)..writeAsBytesSync(fileBytes!);
      await Share.shareXFiles([XFile(path)], text: 'مرفق تقرير حسابات الموقع القديم');
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
      <h2>تقرير حسابات المكتب (الموقع القديم)</h2>
      <table>
        <tr><th>البند</th><th>التفاصيل</th><th>القيمة</th></tr>
        <tr><td>إجمالي المستحقات</td><td>إيرادات الشركات</td><td>$_totalRevenue ج.م</td></tr>
        <tr><td>خصم سيارات الشركة Z</td><td>أمتار: $_zMeters | سعر: $_zPrice</td><td>$_zDeduction ج.م</td></tr>
        <tr><td>حساب اللودر</td><td>أمتار: $_loaderMeters | سعر: $_loaderPrice</td><td>$_loaderDeduction ج.م</td></tr>
        <tr><td>إجمالي العهد والمصروفات</td><td>-</td><td>$_expensesTotal ج.م</td></tr>
        <tr><td>خصومات الجودة</td><td>أمتار: $_qualityMetersTotal | سعر: $_qualityPrice</td><td>$_qualityTotal ج.م</td></tr>
        <tr style='font-weight:bold; background-color:#f1f1f1;'><td colspan='2'>صافي المستحق للمكتب</td><td>$_netAmount ج.م</td></tr>
      </table></body></html>
      """;

      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/تقرير_الموقع_القديم.doc';
      final file = File(path);
      await file.writeAsString(htmlContent);

      await Share.shareXFiles([XFile(path)], text: 'مرفق تقرير Word لحسابات الموقع القديم');
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
          title: const Text('تفاصيل الموقع القديم', style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold)),
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
            // 1. الهيدر العلوي (الكارتين اللي فوق أكبر وأبرز، والكارت اللي تحت أصغر وملموم)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // الكارتين اللي فوق (تكبير المساحة والخطوط لتكون أكثر بروزاً)
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
                  // كارت صافي المستحق للمكتب (أكثر compactness ولمامة)
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

            // 2. الكروت التفصيلية
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
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
                        title: const Text('تفاصيل مستحقات المكتب (الشركات)', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold)),
                        subtitle: Text('الإجمالي: ${_toArabicNumbers(_formatNumber(_totalRevenue))} ج', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
                        childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        children: _clientTotals.isEmpty
                            ? [const Center(child: Text('لا توجد مستحقات', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)))]
                            : _clientTotals.entries.map((e) {
                          String clientName = e.key;
                          double totalVal = e.value;
                          double meters = _clientMeters[clientName] ?? 0.0;
                          double price = _clientPrices[clientName] ?? 0.0;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(clientName, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.black87))),
                                Text(
                                  '${_toArabicNumbers(_formatNumber(meters))} م³ | ${_toArabicNumbers(_formatNumber(price))} ج = ${_toArabicNumbers(_formatNumber(totalVal))} ج',
                                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  _buildCompactCard(
                    title: 'خصم سيارات الشركة (Z)',
                    icon: Icons.local_shipping,
                    color: Colors.orange,
                    amount: _zDeduction,
                    subDetail: 'أمتار: ${_toArabicNumbers(_formatNumber(_zMeters))} م³ | سعر: ${_toArabicNumbers(_formatNumber(_zPrice))} ج',
                  ),

                  _buildCompactCard(
                    title: 'حساب اللودر (للموقع كاملاً)',
                    icon: Icons.front_loader,
                    color: Colors.brown,
                    amount: _loaderDeduction,
                    subDetail: 'أمتار: ${_toArabicNumbers(_formatNumber(_loaderMeters))} م³ | سعر: ${_toArabicNumbers(_formatNumber(_loaderPrice))} ج',
                  ),

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

                  if (_offsetTotal > 0)
                    _buildCompactCard(
                      title: 'رصيد دائن مُرحّل للموقع الجديد',
                      icon: Icons.sync_alt,
                      color: Colors.blue,
                      amount: _offsetTotal,
                      subDetail: 'تم ترحيل هذا المبلغ كخصم من الموقع الجديد',
                    ),
                ],
              ),
            ),

            // زرار المقاصة
            if (!isPositive && _isLoading == false)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
                child: ElevatedButton.icon(
                  onPressed: _processOffsetTransfer,
                  icon: const Icon(Icons.sync_alt, color: Colors.white, size: 20),
                  label: const Text('ترحيل الرصيد كمديونية للموقع الجديد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F2A52),
                    minimumSize: const Size(double.infinity, 45),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
          ],
        ),
      ),
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