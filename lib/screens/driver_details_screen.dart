import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart' hide Border, TextSpan;

class DriverDetailsScreen extends StatefulWidget {
  final String driverName;
  final String vehicleNumber;

  const DriverDetailsScreen({super.key, required this.driverName, required this.vehicleNumber});

  @override
  State<DriverDetailsScreen> createState() => _DriverDetailsScreenState();
}

class _DriverDetailsScreenState extends State<DriverDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String _normalizeArabic(String text) {
    if (text.isEmpty) return '';
    return text
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();
  }

  String _toArabicNumbers(String text) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    for (int i = 0; i < english.length; i++) {
      text = text.replaceAll(english[i], arabic[i]);
    }
    return text;
  }

  String _formatCleanNumber(double num) {
    String numStr = num % 1 == 0 ? num.toInt().toString() : num.toStringAsFixed(1);
    return numStr.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }

  String _formatDate(String date) {
    if (date.isEmpty) return '';
    if (date.contains('/')) {
      List<String> parts = date.split('/');
      if (parts.length == 3) {
        if (parts[0].length == 4) {
          return '${parts[2]}-${parts[1]}-${parts[0]}';
        } else {
          return '${parts[0]}-${parts[1]}-${parts[2]}';
        }
      }
    }
    return date.replaceAll('/', '-');
  }

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

  // دالة موحدة لمعالجة واستخراج كافة بيانات السائق (النقلات، الدفعات، والمجاميع)
  Map<String, dynamic> _calculateDriverData(QuerySnapshot? settingsSnap, QuerySnapshot? tripsSnap, QuerySnapshot? paymentsSnap, String targetNorm) {
    double oldSiteRate = 40.0;
    double newSiteRate = 34.0;
    if (settingsSnap != null) {
      for (var doc in settingsSnap.docs) {
        var data = doc.data() as Map<String, dynamic>;
        if (doc.id == 'old_site_globals') oldSiteRate = double.tryParse(data['سعر سائقين الشركة']?.toString() ?? '40') ?? 40.0;
        if (doc.id == 'new_site_globals') newSiteRate = double.tryParse(data['سعر سائقين الشركة']?.toString() ?? '34') ?? 34.0;
      }
    }

    double totalDues = 0.0;
    double totalPayments = 0.0;
    double totalCubage = 0.0;
    double totalOldSiteCubage = 0.0;
    double totalNewSiteCubage = 0.0;

    List<Map<String, dynamic>> driverTrips = [];
    List<Map<String, dynamic>> driverPayments = [];

    if (tripsSnap != null) {
      for (var tripDoc in tripsSnap.docs) {
        var tData = tripDoc.data() as Map<String, dynamic>;
        if (_normalizeArabic(tData['driverName']?.toString() ?? '') == targetNorm) {
          String site = tData['site'] ?? 'old';
          double rate = site == 'new' ? newSiteRate : oldSiteRate;
          double vehicleCubage = double.tryParse(tData['cubage']?.toString() ?? '0') ?? 0.0;
          String dateStr = tData['dateString'] ?? '';

          List<dynamic> cTrips = tData['clientsTrips'] ?? [];
          for (var c in cTrips) {
            int tripsCount = (c['tripsCount'] ?? c['trips'] ?? 0) as int;
            if (tripsCount > 0) {
              double cubage = double.tryParse(c['totalCubage']?.toString() ?? c['cubage']?.toString() ?? '0') ?? 0.0;
              if (cubage == 0) cubage = tripsCount * vehicleCubage;

              double entryTotal = cubage * rate;
              totalDues += entryTotal;
              totalCubage += cubage;

              if (site == 'new') {
                totalNewSiteCubage += cubage;
              } else {
                totalOldSiteCubage += cubage;
              }

              String clientName = c['clientName'] ?? c['name'] ?? 'شركة غير محددة';

              driverTrips.add({
                'date': dateStr,
                'site': site,
                'clientName': clientName,
                'tripsCount': tripsCount,
                'vehicleCubage': vehicleCubage,
                'totalCubage': cubage,
                'rate': rate,
                'total': entryTotal,
              });
            }
          }
        }
      }
    }

    if (paymentsSnap != null) {
      for (var pDoc in paymentsSnap.docs) {
        var pData = pDoc.data() as Map<String, dynamic>;
        if (_normalizeArabic(pData['driverName']?.toString() ?? '') == targetNorm) {
          double amt = double.tryParse(pData['amount']?.toString() ?? '0') ?? 0.0;
          totalPayments += amt;
          driverPayments.add({
            'date': pData['date'] ?? 'غير محدد',
            'amount': amt,
            'note': pData['note'] ?? '',
          });
        }
      }
    }

    driverTrips.sort((a, b) => a['date'].toString().compareTo(b['date'].toString()));
    driverPayments.sort((a, b) => a['date'].toString().compareTo(b['date'].toString()));

    double netRemaining = totalDues - totalPayments;

    return {
      'oldSiteRate': oldSiteRate,
      'newSiteRate': newSiteRate,
      'totalDues': totalDues,
      'totalPayments': totalPayments,
      'totalCubage': totalCubage,
      'totalOldSiteCubage': totalOldSiteCubage,
      'totalNewSiteCubage': totalNewSiteCubage,
      'driverTrips': driverTrips,
      'driverPayments': driverPayments,
      'netRemaining': netRemaining,
    };
  }

  Future<void> _deleteDriver(double netRemaining) async {
    if (netRemaining != 0) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('تنبيه هام', style: TextStyle(color: Colors.red, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            content: const Text('عذراً، لا يمكن حذف السائق لوجود مديونية أو رصيد متبقي في حسابه.', style: TextStyle(fontFamily: 'Cairo')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('موافق', style: TextStyle(fontFamily: 'Cairo'))),
            ],
          ),
        ),
      );
      return;
    }

    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد الحذف', style: TextStyle(color: Colors.red, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          content: Text('هل أنت متأكد من حذف السائق (${widget.driverName})؟', style: const TextStyle(fontFamily: 'Cairo')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف', style: TextStyle(color: Colors.white, fontFamily: 'Cairo')),
            ),
          ],
        ),
      ),
    ) ?? false;

    if (confirm) {
      try {
        String docId = widget.vehicleNumber.replaceAll('/', '-').replaceAll(' ', '');
        await FirebaseFirestore.instance.collection('vehicles').doc(docId).delete();

        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف السائق بنجاح', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء الحذف: $e')));
      }
    }
  }

  // تصدير إكسيل تفصيلي ومضبوط من اليمين لليسار
  Future<void> _exportToExcel(Map<String, dynamic> data) async {
    Navigator.pop(context);
    try {
      List<Map<String, dynamic>> trips = data['driverTrips'];
      List<Map<String, dynamic>> payments = data['driverPayments'];
      double oldCubage = data['totalOldSiteCubage'];
      double oldRate = data['oldSiteRate'];
      double newCubage = data['totalNewSiteCubage'];
      double newRate = data['newSiteRate'];
      double totalDues = data['totalDues'];
      double totalPayments = data['totalPayments'];
      double netRemaining = data['netRemaining'];

      var excel = Excel.createExcel();
      String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
      excel.rename(defaultSheet, 'كشف حساب السائق');
      Sheet sheet = excel['كشف حساب السائق'];
      excel.setDefaultSheet('كشف حساب السائق');

      sheet.appendRow([TextCellValue('كشف حساب السائق: ${widget.driverName} (رقم المركبة: ${widget.vehicleNumber})')]);
      sheet.appendRow([TextCellValue('')]);

      // جدول النقلات
      sheet.appendRow([TextCellValue('--- سجل النقلات التفصيلي ---')]);
      sheet.appendRow([TextCellValue('التاريخ'), TextCellValue('الموقع'), TextCellValue('العميل'), TextCellValue('التفاصيل الكمية'), TextCellValue('السعر'), TextCellValue('الإجمالي')]);
      for (var t in trips) {
        sheet.appendRow([
          TextCellValue(t['date'].toString()),
          TextCellValue(t['site'] == 'new' ? 'الموقع الجديد' : 'الموقع القديم'),
          TextCellValue(t['clientName'].toString()),
          TextCellValue('نقلات: ${t['tripsCount']} | عربية: ${t['vehicleCubage']}م³ | الإجمالي: ${t['totalCubage']}م³'),
          TextCellValue('${t['rate']} ج'),
          TextCellValue('${t['total']} ج'),
        ]);
      }

      sheet.appendRow([TextCellValue('')]);
      // جدول الدفعات
      sheet.appendRow([TextCellValue('--- سجل الدفعات والسلف ---')]);
      sheet.appendRow([TextCellValue('التاريخ'), TextCellValue('الملاحظات'), TextCellValue('المبلغ')]);
      for (var p in payments) {
        sheet.appendRow([
          TextCellValue(p['date'].toString()),
          TextCellValue(p['note'].toString()),
          TextCellValue('${p['amount']} ج'),
        ]);
      }

      sheet.appendRow([TextCellValue('')]);
      // الملخص النهائي
      sheet.appendRow([TextCellValue('--- الملخص المحاسبي النهائي ---')]);
      sheet.appendRow([TextCellValue('البند المحاسبي'), TextCellValue('التفاصيل والكميات'), TextCellValue('الإجمالي')]);
      sheet.appendRow([TextCellValue('الموقع القديم'), TextCellValue('عدد الأمتار: ${oldCubage.toStringAsFixed(1)} م³ | السعر: ${oldRate.toStringAsFixed(0)} ج'), TextCellValue('${(oldCubage * oldRate).toStringAsFixed(0)} ج.م')]);
      sheet.appendRow([TextCellValue('الموقع الجديد'), TextCellValue('عدد الأمتار: ${newCubage.toStringAsFixed(1)} م³ | السعر: ${newRate.toStringAsFixed(0)} ج'), TextCellValue('${(newCubage * newRate).toStringAsFixed(0)} ج.م')]);
      sheet.appendRow([TextCellValue('إجمالي المستحقات'), TextCellValue(''), TextCellValue('${totalDues.toStringAsFixed(0)} ج.م')]);
      sheet.appendRow([TextCellValue('إجمالي الدفعات المسجلة'), TextCellValue(''), TextCellValue('${totalPayments.toStringAsFixed(0)} ج.م')]);
      sheet.appendRow([TextCellValue('صافي حساب السائق'), TextCellValue(''), TextCellValue('${netRemaining.toStringAsFixed(0)} ج.م')]);

      var fileBytes = excel.save();
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/كشف_حساب_${widget.driverName}.xlsx';

      File(path)..createSync(recursive: true)..writeAsBytesSync(fileBytes!);
      await Share.shareXFiles([XFile(path)], text: 'مرفق كشف حساب السائق الشامل: ${widget.driverName}');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء تصدير الإكسيل: $e')));
    }
  }

  // تصدير وورد تفصيلي ومضبوط تماماً من اليمين لليسار (RTL)
  Future<void> _exportToWord(Map<String, dynamic> data) async {
    Navigator.pop(context);
    try {
      List<Map<String, dynamic>> trips = data['driverTrips'];
      List<Map<String, dynamic>> payments = data['driverPayments'];
      double oldCubage = data['totalOldSiteCubage'];
      double oldRate = data['oldSiteRate'];
      double newCubage = data['totalNewSiteCubage'];
      double newRate = data['newSiteRate'];
      double totalDues = data['totalDues'];
      double totalPayments = data['totalPayments'];
      double netRemaining = data['netRemaining'];

      String tripsRows = '';
      for (var t in trips) {
        String siteName = t['site'] == 'new' ? 'الموقع الجديد' : 'الموقع القديم';
        tripsRows += "<tr><td>${t['date']}</td><td>$siteName</td><td>${t['clientName']}</td><td>نقلات: ${t['tripsCount']} | عربية: ${t['vehicleCubage']}م³ | الإجمالي: ${t['totalCubage']}م³</td><td>${t['rate']}ج</td><td>${t['total']}ج</td></tr>";
      }

      String paymentsRows = '';
      if (payments.isEmpty) {
        paymentsRows = "<tr><td colspan='3' style='text-align: center;'>لا توجد دفعات مسجلة</td></tr>";
      } else {
        for (var p in payments) {
          paymentsRows += "<tr><td>${p['date']}</td><td>${p['note']}</td><td>${p['amount']}ج</td></tr>";
        }
      }

      String htmlContent = """
      <html dir="rtl" lang="ar">
      <head>
        <meta charset="utf-8">
        <style>
          body { font-family: Tahoma; direction: rtl; text-align: right; }
          h2, h3 { direction: rtl; text-align: right; color: #0F2A52; }
          table { width: 100%; border-collapse: collapse; margin-bottom: 20px; direction: rtl; }
          th, td { border: 1px solid #ddd; padding: 6px; text-align: right; direction: rtl; font-size: 12px; }
          th { background-color: #0F2A52; color: white; text-align: right; direction: rtl; }
        </style>
      </head>
      <body dir="rtl">
      <h2>كشف حساب السائق: ${widget.driverName} (${widget.vehicleNumber})</h2>
      
      <h3>سجل النقلات التفصيلي</h3>
      <table dir="rtl">
        <tr><th>التاريخ</th><th>الموقع</th><th>العميل</th><th>التفاصيل</th><th>السعر</th><th>الإجمالي</th></tr>
        $tripsRows
      </table>

      <h3>سجل الدفعات والسلف</h3>
      <table dir="rtl">
        <tr><th>التاريخ</th><th>الملاحظات</th><th>المبلغ</th></tr>
        $paymentsRows
      </table>

      <h3>الملخص المحاسبي النهائي</h3>
      <table dir="rtl">
        <tr><th>البند المحاسبي</th><th>التفاصيل والكميات</th><th>الإجمالي</th></tr>
        <tr><td>الموقع القديم</td><td>عدد الأمتار: ${oldCubage.toStringAsFixed(1)} م³ | السعر: ${oldRate.toStringAsFixed(0)} ج</td><td>${(oldCubage * oldRate).toStringAsFixed(0)} ج.م</td></tr>
        <tr><td>الموقع الجديد</td><td>عدد الأمتار: ${newCubage.toStringAsFixed(1)} م³ | السعر: ${newRate.toStringAsFixed(0)} ج</td><td>${(newCubage * newRate).toStringAsFixed(0)} ج.م</td></tr>
        <tr><td colspan='2'>إجمالي المستحقات</td><td>${totalDues.toStringAsFixed(0)} ج.م</td></tr>
        <tr><td colspan='2'>إجمالي الدفعات المسجلة</td><td>${totalPayments.toStringAsFixed(0)} ج.م</td></tr>
        <tr style='font-weight:bold; background-color:#e8f5e9;'><td colspan='2'>صافي حساب السائق</td><td>${netRemaining.toStringAsFixed(0)} ج.م</td></tr>
      </table>
      
      </body></html>
      """;

      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/كشف_حساب_${widget.driverName}.doc';
      final file = File(path);
      await file.writeAsString(htmlContent);

      await Share.shareXFiles([XFile(path)], text: 'مرفق تقرير Word الشامل لكشف حساب السائق: ${widget.driverName}');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء تصدير Word: $e')));
    }
  }

  void _showExportBottomSheet(Map<String, dynamic> data) {
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
              const Text('تصدير كشف الحساب الشامل', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F2A52))),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.table_chart, color: Colors.green, size: 30),
                title: const Text('تصدير كملف Excel (تفصيلي)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                onTap: () => _exportToExcel(data),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.description, color: Colors.blue, size: 30),
                title: const Text('تصدير كملف Word (تفصيلي)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                onTap: () => _exportToWord(data),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String targetNorm = _normalizeArabic(widget.driverName);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F9),
        appBar: AppBar(
          title: Text('سائق: ${widget.driverName}', style: const TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
          backgroundColor: const Color(0xFF0F2A52),
          centerTitle: true,
          elevation: 0,
          leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
          actions: [
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('settings').snapshots(),
              builder: (context, settingsSnap) {
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('daily_entries').snapshots(),
                  builder: (context, tripsSnap) {
                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('driver_payments').snapshots(),
                      builder: (context, paymentsSnap) {

                        // استخدام الدالة الموحدة لجلب كافة البيانات وتجهيزها للتصدير
                        var driverData = _calculateDriverData(settingsSnap.data, tripsSnap.data, paymentsSnap.data, targetNorm);

                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.ios_share, color: Colors.white, size: 22),
                              tooltip: 'تصدير كشف الحساب',
                              onPressed: () => _showExportBottomSheet(driverData),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 24),
                              tooltip: 'حذف السائق',
                              onPressed: () => _deleteDriver(driverData['netRemaining']),
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF00D2FF),
            unselectedLabelColor: Colors.white70,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14),
            tabs: const [
              Tab(text: 'سجل النقلات', icon: Icon(Icons.local_shipping, size: 20)),
              Tab(text: 'سجل الدفعات', icon: Icon(Icons.payments, size: 20)),
            ],
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('settings').snapshots(),
            builder: (context, settingsSnap) {
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('daily_entries').snapshots(),
                builder: (context, tripsSnap) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('driver_payments').snapshots(),
                    builder: (context, paymentsSnap) {

                      var driverData = _calculateDriverData(settingsSnap.data, tripsSnap.data, paymentsSnap.data, targetNorm);

                      double oldSiteRate = driverData['oldSiteRate'];
                      double newSiteRate = driverData['newSiteRate'];
                      double totalDues = driverData['totalDues'];
                      double totalPayments = driverData['totalPayments'];
                      double totalCubage = driverData['totalCubage'];
                      double totalOldSiteCubage = driverData['totalOldSiteCubage'];
                      double totalNewSiteCubage = driverData['totalNewSiteCubage'];
                      List<Map<String, dynamic>> driverTrips = driverData['driverTrips'];
                      List<Map<String, dynamic>> driverPayments = driverData['driverPayments'];
                      double netRemaining = driverData['netRemaining'];

                      String netText = '${_toArabicNumbers(_formatCleanNumber(netRemaining))} ج.م';

                      return TabBarView(
                        controller: _tabController,
                        children: [
                          Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(10.0),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildDashboardCard(
                                            title: 'إجمالي الأمتار',
                                            value: '${_toArabicNumbers(_formatCleanNumber(totalCubage))} م³',
                                            textColor: Colors.blue.shade700,
                                            subTitleWidget: RichText(
                                              textAlign: TextAlign.center,
                                              text: TextSpan(
                                                style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold),
                                                children: [
                                                  TextSpan(
                                                    text: 'قديم: ${_toArabicNumbers(_formatCleanNumber(totalOldSiteCubage))} م³',
                                                    style: TextStyle(color: Colors.blue.shade700),
                                                  ),
                                                  const TextSpan(text: ' | ', style: TextStyle(color: Colors.grey)),
                                                  TextSpan(
                                                    text: 'جديد: ${_toArabicNumbers(_formatCleanNumber(totalNewSiteCubage))} م³',
                                                    style: TextStyle(color: Colors.green.shade700),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: _buildDashboardCard(
                                            title: 'إجمالي المستحقات',
                                            value: '${_toArabicNumbers(_formatCleanNumber(totalDues))} ج.م',
                                            textColor: Colors.amber.shade800,
                                            subTitleWidget: RichText(
                                              textAlign: TextAlign.center,
                                              text: TextSpan(
                                                style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold),
                                                children: [
                                                  TextSpan(
                                                    text: 'قديم: ${_toArabicNumbers(_formatCleanNumber(oldSiteRate))} ج',
                                                    style: TextStyle(color: Colors.blue.shade700),
                                                  ),
                                                  const TextSpan(text: ' | ', style: TextStyle(color: Colors.grey)),
                                                  TextSpan(
                                                    text: 'جديد: ${_toArabicNumbers(_formatCleanNumber(newSiteRate))} ج',
                                                    style: TextStyle(color: Colors.green.shade700),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: _buildDashboardCard(
                                            title: 'إجمالي الدفعات',
                                            value: '${_toArabicNumbers(_formatCleanNumber(totalPayments))} ج.م',
                                            textColor: Colors.green.shade700,
                                            subTitle: 'المسجل في الدفعات',
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    _buildCenteredGreenCard(
                                      title: 'صافي حساب السائق',
                                      value: netText,
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: driverTrips.isEmpty
                                    ? const Center(child: Text('لا توجد نقلات مسجلة.', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)))
                                    : ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  itemCount: driverTrips.length,
                                  itemBuilder: (context, index) {
                                    var trip = driverTrips[index];
                                    bool isNewSite = trip['site'] == 'new';
                                    String formattedDate = _formatDate(trip['date'].toString());

                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 6),
                                      elevation: 0.5,
                                      color: isNewSite ? const Color(0xFFE8F5E9) : const Color(0xFFE3F2FD),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                        side: BorderSide(color: isNewSite ? Colors.green.shade300 : Colors.blue.shade300, width: 1.0),
                                      ),
                                      child: ListTile(
                                        dense: true,
                                        visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                        leading: CircleAvatar(
                                          radius: 14,
                                          backgroundColor: isNewSite ? Colors.green.shade100 : Colors.blue.shade100,
                                          child: Icon(Icons.fire_truck, color: isNewSite ? Colors.green.shade700 : Colors.blue.shade700, size: 14),
                                        ),
                                        title: Text(
                                          '${_toArabicNumbers(formattedDate)} - ${isNewSite ? 'الموقع الجديد' : 'الموقع القديم'} - ${trip['clientName']}',
                                          style: TextStyle(
                                              fontFamily: 'Cairo',
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                              color: isNewSite ? Colors.green.shade900 : Colors.blue.shade900
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerRight,
                                          child: Text(
                                            'نقلات: ${_toArabicNumbers(_formatCleanNumber(trip['tripsCount'].toDouble()))} | عربية: ${_toArabicNumbers(_formatCleanNumber(trip['vehicleCubage']))} م³ | الإجمالي: ${_toArabicNumbers(_formatCleanNumber(trip['totalCubage']))} م³ | السعر: ${_toArabicNumbers(_formatCleanNumber(trip['rate']))} ج',
                                            style: TextStyle(fontFamily: 'Cairo', fontSize: 9, color: Colors.grey.shade800, fontWeight: FontWeight.bold),
                                            maxLines: 1,
                                          ),
                                        ),
                                        trailing: Text(
                                          '${_toArabicNumbers(_formatCleanNumber(trip['total']))} ج',
                                          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 12, color: isNewSite ? Colors.green.shade800 : Colors.blue.shade800),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(10.0),
                                child: _buildCenteredGreenCard(
                                  title: 'إجمالي الدفعات المسجلة',
                                  value: '${_toArabicNumbers(_formatCleanNumber(totalPayments))} ج.م',
                                ),
                              ),
                              Expanded(
                                child: driverPayments.isEmpty
                                    ? const Center(child: Text('لم يتم تسجيل أي دفعات أو سلف.', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)))
                                    : ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  itemCount: driverPayments.length,
                                  itemBuilder: (context, index) {
                                    var pay = driverPayments[index];
                                    String formattedDate = _formatDate(pay['date'].toString());
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 6),
                                      elevation: 0.5,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6), side: BorderSide(color: Colors.red.shade100, width: 1.0)),
                                      child: ListTile(
                                        dense: true,
                                        visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                        leading: const CircleAvatar(
                                          radius: 14,
                                          backgroundColor: Color(0xFFFFEBEE),
                                          child: Icon(Icons.money_off, color: Colors.redAccent, size: 14),
                                        ),
                                        title: Text('دفعة / سلفة (${_toArabicNumbers(formattedDate)})', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 11)),
                                        subtitle: Text(pay['note'], style: const TextStyle(fontFamily: 'Cairo', fontSize: 9), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        trailing: Text(
                                          '${_toArabicNumbers(_formatCleanNumber(pay['amount']))} ج',
                                          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 12, color: Colors.red),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            }
        ),
      ),
    );
  }

  Widget _buildDashboardCard({required String title, required String value, required Color textColor, bool isAlert = false, String? subTitle, Widget? subTitleWidget}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isAlert ? Colors.red.shade300 : Colors.grey.shade300),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Cairo', color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 15, color: textColor),
            ),
          ),
          if (subTitleWidget != null) ...[
            const SizedBox(height: 4),
            FittedBox(child: subTitleWidget),
          ] else if (subTitle != null) ...[
            const SizedBox(height: 4),
            FittedBox(
              child: Text(
                subTitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Cairo', color: Colors.grey.shade600, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildCenteredGreenCard({required String title, required String value}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.shade300, width: 1.2),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Cairo', color: Colors.green.shade800, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 20, color: Colors.green.shade900),
          ),
        ],
      ),
    );
  }
}