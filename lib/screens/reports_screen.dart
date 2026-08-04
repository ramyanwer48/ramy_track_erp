import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart' hide Border, TextSpan;

class ReportData {
  final String title;
  final String subtitle;
  final String fileName;
  final List<String> headers;
  final List<List<String>> rows;
  final List<String> footers;

  ReportData({
    required this.title,
    required this.subtitle,
    required this.fileName,
    required this.headers,
    required this.rows,
    required this.footers,
  });
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
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

  String _formatDateRTL(String date) {
    if (date.isEmpty) return '';
    String normalized = date.replaceAll('-', '/');
    List<String> parts = normalized.split('/');
    if (parts.length == 3) {
      String y = parts[0], m = parts[1], d = parts[2];
      if (parts[0].length != 4) { d = parts[0]; m = parts[1]; y = parts[2]; }
      return '\u200F$d/$m/$y\u200F';
    }
    return date;
  }

  Future<String?> _showSelectionDialog(List<String> items, String title) async {
    String? selected;
    if (!mounted) return null;
    await showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(title, style: const TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: items.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(items[index], style: const TextStyle(fontFamily: 'Cairo', fontSize: 13)),
                  onTap: () {
                    selected = items[index];
                    Navigator.pop(ctx);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
          ],
        ),
      ),
    );
    return selected;
  }

  Future<void> _generateDetailedReport(int reportType) async {
    try {
      var tripsSnap = await FirebaseFirestore.instance.collection('daily_entries').get();
      var clientPaysSnap = await FirebaseFirestore.instance.collection('client_payments').get();
      var driverPaysSnap = await FirebaseFirestore.instance.collection('driver_payments').get();
      var settlementsSnap = await FirebaseFirestore.instance.collection('settlements').get();
      var settingsSnap = await FirebaseFirestore.instance.collection('settings').get();

      double tractorRate = 22.0, loaderRate = 15.0, oldDriverRate = 40.0, newDriverRate = 34.0;
      for (var doc in settingsSnap.docs) {
        var data = doc.data();
        if (doc.id == 'sheikh_settings' && data.containsKey('tractorRate')) {
          tractorRate = double.tryParse(data['tractorRate'].toString()) ?? 22.0;
        }
        if (data.containsKey('loaderRate')) {
          loaderRate = double.tryParse(data['loaderRate'].toString()) ?? 15.0;
        }
        if (doc.id == 'old_site_globals' && data.containsKey('سعر سائقين الشركة')) {
          oldDriverRate = double.tryParse(data['سعر سائقين الشركة'].toString()) ?? 40.0;
        }
        if (doc.id == 'new_site_globals' && data.containsKey('سعر سائقين الشركة')) {
          newDriverRate = double.tryParse(data['سعر سائقين الشركة'].toString()) ?? 34.0;
        }
      }

      ReportData? report;

      if (reportType == 1) {
        Set<String> clientsSet = {};
        for (var doc in tripsSnap.docs) {
          List<dynamic> cTrips = doc.data()['clientsTrips'] ?? [];
          for (var c in cTrips) {
            String name = c['clientName'] ?? c['name'] ?? '';
            if (name.isNotEmpty) clientsSet.add(name);
          }
        }

        String? chosenClient = await _showSelectionDialog(clientsSet.toList(), 'اختر العميل المطلوب');
        if (chosenClient == null) return;

        List<List<String>> rows = [];
        double totalDues = 0, totalPays = 0;

        for (var doc in tripsSnap.docs) {
          var data = doc.data();
          String dateStr = data['dateString'] ?? '';
          String site = data['site'] == 'new' ? 'الموقع الجديد' : 'الموقع القديم';
          double vCubage = double.tryParse(data['cubage']?.toString() ?? '0') ?? 0.0;

          List<dynamic> cTrips = data['clientsTrips'] ?? [];
          for (var c in cTrips) {
            String name = c['clientName'] ?? c['name'] ?? '';
            if (name == chosenClient) {
              int tCount = (c['tripsCount'] ?? c['trips'] ?? 0) as int;
              double cubage = double.tryParse(c['totalCubage']?.toString() ?? '0') ?? 0.0;
              if (cubage == 0) cubage = tCount * vCubage;
              double price = double.tryParse(c['price']?.toString() ?? '0') ?? 0.0;
              double dues = cubage * price;
              totalDues += dues;

              rows.add([_formatDateRTL(dateStr), site, 'نقلات: $tCount | الأمتار: $cubage', '$price ج', '${_formatCleanNumber(dues)} ج']);
            }
          }
        }

        for (var doc in clientPaysSnap.docs) {
          var data = doc.data();
          if (data['clientName'] == chosenClient) {
            double amt = double.tryParse(data['amount']?.toString() ?? '0') ?? 0.0;
            totalPays += amt;
            rows.add([_formatDateRTL(data['date'] ?? ''), 'دفعة نقدية/تحويل', 'سند قبض نقدي', '-', '- ${_formatCleanNumber(amt)} ج']);
          }
        }

        double netRemaining = totalDues - totalPays;

        report = ReportData(
          title: 'كشف حساب عميل مفصل: $chosenClient',
          subtitle: 'تقرير تفصيلي لحركة المسحوبات والمدفوعات',
          fileName: 'كشف_حساب_عميل_$chosenClient',
          headers: ['التاريخ', 'الموقع/النوع', 'التفاصيل', 'السعر', 'القيمة / المدفوع'],
          rows: rows,
          footers: ['الصافي المتبقي على العميل', '', '', '', '${_formatCleanNumber(netRemaining)} ج.م'],
        );
      }
      else if (reportType == 2) {
        Set<String> driversSet = {};
        for (var doc in tripsSnap.docs) {
          String dName = doc.data()['driverName'] ?? '';
          if (dName.isNotEmpty) driversSet.add(dName);
        }

        String? chosenDriver = await _showSelectionDialog(driversSet.toList(), 'اختر السائق المطلوب');
        if (chosenDriver == null) return;

        List<List<String>> rows = [];
        double totalDues = 0, totalPays = 0;

        for (var doc in tripsSnap.docs) {
          var data = doc.data();
          if (data['driverName'] == chosenDriver) {
            String dateStr = data['dateString'] ?? '';
            String site = data['site'] ?? 'old';
            double dRate = site == 'new' ? newDriverRate : oldDriverRate;

            List<dynamic> cTrips = data['clientsTrips'] ?? [];
            for (var c in cTrips) {
              int tCount = (c['tripsCount'] ?? c['trips'] ?? 0) as int;
              double cubage = double.tryParse(c['totalCubage']?.toString() ?? '0') ?? 0.0;
              if (cubage == 0) cubage = tCount * double.tryParse(data['cubage']?.toString() ?? '0')!;
              double dues = cubage * dRate;
              totalDues += dues;

              rows.add([_formatDateRTL(dateStr), site == 'new' ? 'الموقع الجديد' : 'الموقع القديم', '$cubage م³', '$dRate ج', '${_formatCleanNumber(dues)} ج']);
            }
          }
        }

        for (var doc in driverPaysSnap.docs) {
          var data = doc.data();
          if (data['driverName'] == chosenDriver) {
            double amt = double.tryParse(data['amount']?.toString() ?? '0') ?? 0.0;
            totalPays += amt;
            rows.add([_formatDateRTL(data['date'] ?? ''), 'سلفة / دفعة', 'صرف نقدية للسائق', '-', '- ${_formatCleanNumber(amt)} ج']);
          }
        }

        double netRemaining = totalDues - totalPays;

        report = ReportData(
          title: 'كشف حساب سائق مفصل: $chosenDriver',
          subtitle: 'تقرير الأمتار والمستحقات والسلف',
          fileName: 'كشف_حساب_سائق_$chosenDriver',
          headers: ['التاريخ', 'الموقع', 'الكمية', 'فئة المتر', 'المستحق / المسحوب'],
          rows: rows,
          footers: ['الصافي المتبقي للسائق', '', '', '', '${_formatCleanNumber(netRemaining)} ج.م'],
        );
      }
      else if (reportType == 3) {
        List<List<String>> rows = [];
        double totalTractorMeters = 0;
        double totalPayments = 0;

        for (var doc in tripsSnap.docs) {
          var data = doc.data();
          String clientName = (data['clientName'] ?? data['client_name'] ?? '').toString().trim();
          String carType = (data['carType'] ?? data['vehicleType'] ?? '').toString().trim();

          if ((clientName.contains('بخيت') || clientName.contains('عادل')) && carType.contains('جرار')) {
            String dateStr = data['dateString'] ?? '';
            double cubage = double.tryParse(data['totalCubage']?.toString() ?? data['cubage']?.toString() ?? '0') ?? 0.0;
            totalTractorMeters += cubage;
            double dues = cubage * tractorRate;

            rows.add([_formatDateRTL(dateStr), clientName, carType, '$cubage م³', '$tractorRate ج', '${_formatCleanNumber(dues)} ج']);
          }
        }

        for (var doc in settlementsSnap.docs) {
          var data = doc.data();
          if (data['type'] == 'sheikh_payment') {
            double amt = double.tryParse(data['amount']?.toString() ?? '0') ?? 0.0;
            totalPayments += amt;
            rows.add([_formatDateRTL(data['date'] ?? ''), 'دفعة مالية', 'تسوية / دفعة للشيخ', '-', '-', '- ${_formatCleanNumber(amt)} ج']);
          }
        }

        double netRemaining = (totalTractorMeters * tractorRate) - totalPayments;

        report = ReportData(
          title: 'تقرير حساب الشيخ محمد (نسبة الجرارات)',
          subtitle: 'حساب جرارات الموقع الجديد والتسويات',
          fileName: 'تقرير_حساب_الشيخ_محمد',
          headers: ['التاريخ', 'جهة العمل', 'نوع الآلية', 'الأمتار', 'السعر', 'الإجمالي / المدفوع'],
          rows: rows,
          footers: ['إجمالي الأمتار والمتبقي', '${_formatCleanNumber(totalTractorMeters)} م³', '', '', '', '${_formatCleanNumber(netRemaining)} ج.م'],
        );
      }
      else if (reportType == 4) {
        List<List<String>> rows = [];
        double totalCubage = 0;

        for (var doc in tripsSnap.docs) {
          var data = doc.data();
          String site = data['site'] == 'new' ? 'الموقع الجديد' : 'الموقع القديم';
          String dateStr = data['dateString'] ?? '';
          double vCubage = double.tryParse(data['cubage']?.toString() ?? '0') ?? 0.0;

          List<dynamic> cTrips = data['clientsTrips'] ?? [];
          for (var c in cTrips) {
            String material = c['material']?.toString() ?? data['material']?.toString() ?? '';
            if (material.isEmpty || material.contains('رمل')) {
              int tCount = (c['tripsCount'] ?? c['trips'] ?? 0) as int;
              double cubage = double.tryParse(c['totalCubage']?.toString() ?? '0') ?? 0.0;
              if (cubage == 0) cubage = tCount * vCubage;
              totalCubage += cubage;
              double dues = cubage * loaderRate;

              rows.add([_formatDateRTL(dateStr), site, c['clientName'] ?? 'جهة غير محددة', '$cubage م³', '$loaderRate ج', '${_formatCleanNumber(dues)} ج']);
            }
          }
        }

        double totalLoaderDues = totalCubage * loaderRate;

        report = ReportData(
          title: 'تقرير حركات ومستحقات اللودر (الرمل)',
          subtitle: 'حساب تعبئة اللودر الشامل للموقعين',
          fileName: 'تقرير_حسابات_اللودر',
          headers: ['التاريخ', 'الموقع', 'العميل', 'الأمتار', 'سعر المتر', 'إجمالي المستحق'],
          rows: rows,
          footers: ['الإجمالي العام', '', '', '${_formatCleanNumber(totalCubage)} م³', '', '${_formatCleanNumber(totalLoaderDues)} ج.م'],
        );
      }
      else if (reportType == 5) {
        List<List<String>> rows = [];
        double totalOfficeCubage = 0;
        double totalOfficeRevenues = 0;

        for (var doc in tripsSnap.docs) {
          var data = doc.data();
          String carType = (data['carType'] ?? data['vehicleType'] ?? '').toString();
          if (carType.contains('مكتب')) {
            String dateStr = data['dateString'] ?? '';
            String site = data['site'] == 'new' ? 'الموقع الجديد' : 'الموقع القديم';
            double vCubage = double.tryParse(data['cubage']?.toString() ?? '0') ?? 0.0;

            List<dynamic> cTrips = data['clientsTrips'] ?? [];
            for (var c in cTrips) {
              int tCount = (c['tripsCount'] ?? c['trips'] ?? 0) as int;
              double cubage = double.tryParse(c['totalCubage']?.toString() ?? '0') ?? 0.0;
              if (cubage == 0) cubage = tCount * vCubage;
              double price = double.tryParse(c['price']?.toString() ?? '0') ?? 0.0;
              double revenue = cubage * price;

              totalOfficeCubage += cubage;
              totalOfficeRevenues += revenue;

              rows.add([_formatDateRTL(dateStr), site, c['clientName'] ?? 'بدون عميل', '$cubage م³', '$price ج', '${_formatCleanNumber(revenue)} ج']);
            }
          }
        }

        report = ReportData(
          title: 'تقرير حساب المكتب (إيرادات سيارات المكتب)',
          subtitle: 'حصر شامل للنقلات والأمتار التابعة لسيارات المكتب مباشرة',
          fileName: 'تقرير_حساب_المكتب',
          headers: ['التاريخ', 'الموقع', 'العميل', 'الأمتار المنقولة', 'سعر النقل', 'إجمالي الإيراد'],
          rows: rows,
          footers: ['الإجمالي العام', '', '', '${_formatCleanNumber(totalOfficeCubage)} م³', '', '${_formatCleanNumber(totalOfficeRevenues)} ج.م'],
        );
      }

      if (report != null && mounted) {
        _showExportOptions(report);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في إعداد التقرير: $e')));
      }
    }
  }

  void _showExportOptions(ReportData report) {
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
              Text(report.title, style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF103667))),
              const SizedBox(height: 5),
              Text(report.subtitle, style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.table_chart, color: Colors.green, size: 30),
                title: const Text('تصدير كملف Excel', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                onTap: () { Navigator.pop(context); _exportExcel(report); },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.description, color: Colors.blue, size: 30),
                title: const Text('تصدير كملف Word', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                onTap: () { Navigator.pop(context); _exportWord(report); },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportExcel(ReportData data) async {
    try {
      var excel = Excel.createExcel();
      String sheetName = 'تقرير';
      excel.rename(excel.getDefaultSheet() ?? 'Sheet1', sheetName);
      Sheet sheet = excel[sheetName];
      excel.setDefaultSheet(sheetName);

      sheet.appendRow([TextCellValue(data.title)]);
      sheet.appendRow([TextCellValue(data.subtitle)]);
      sheet.appendRow([TextCellValue('')]);
      sheet.appendRow(data.headers.map((e) => TextCellValue(e)).toList());
      for (var row in data.rows) {
        sheet.appendRow(row.map((e) => TextCellValue(_toArabicNumbers(e))).toList());
      }
      sheet.appendRow([TextCellValue('')]);
      sheet.appendRow(data.footers.map((e) => TextCellValue(_toArabicNumbers(e))).toList());

      var fileBytes = excel.save();
      final directory = await getTemporaryDirectory();
      String cleanFileName = data.fileName.replaceAll(RegExp(r'[^\w\s\u0600-\u06FF]'), '_').replaceAll(' ', '_');
      final path = '${directory.path}/$cleanFileName.xlsx';

      File(path)..createSync(recursive: true)..writeAsBytesSync(fileBytes!);
      if (mounted) {
        await Share.shareXFiles([XFile(path)], text: 'مرفق ${data.title}');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في الإكسيل: $e')));
    }
  }

  Future<void> _exportWord(ReportData data) async {
    try {
      String ths = data.headers.map((h) => '<th>$h</th>').join('');
      String trs = data.rows.map((row) => '<tr>${row.map((cell) => '<td>${_toArabicNumbers(cell)}</td>').join('')}</tr>').join('');
      String tfoot = '<tr>${data.footers.map((f) => '<td style="font-weight:bold; background-color:#e8f5e9;">${_toArabicNumbers(f)}</td>').join('')}</tr>';

      String htmlContent = """
      <html dir="rtl" lang="ar">
      <head>
        <meta charset="utf-8">
        <style>
          body { font-family: Tahoma; direction: rtl; text-align: right; }
          h2 { color: #103667; }
          p { color: #666; font-size: 13px; }
          table { width: 100%; border-collapse: collapse; margin-top: 15px; }
          th, td { border: 1px solid #ddd; padding: 8px; text-align: right; font-size: 12px; }
          th { background-color: #103667; color: white; }
        </style>
      </head>
      <body>
      <h2>${data.title}</h2>
      <p>${data.subtitle}</p>
      <table>
        <thead><tr>$ths</tr></thead>
        <tbody>$trs</tbody>
        <tfoot>$tfoot</tfoot>
      </table>
      </body></html>
      """;

      final directory = await getTemporaryDirectory();
      String cleanFileName = data.fileName.replaceAll(RegExp(r'[^\w\s\u0600-\u06FF]'), '_').replaceAll(' ', '_');
      final path = '${directory.path}/$cleanFileName.doc';
      File(path).writeAsStringSync(htmlContent);

      if (mounted) {
        await Share.shareXFiles([XFile(path)], text: 'مرفق ${data.title}');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في الوورد: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F9),
        appBar: AppBar(
          title: const Text('التقارير المفصلة المخصصة', style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
          backgroundColor: const Color(0xFF103667),
          centerTitle: true,
          elevation: 0,
          leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
        ),
        body: ListView(
          padding: const EdgeInsets.all(12.0),
          children: [
            const Text('اختر نوع التقرير المفصل المطلوب:', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF103667))),
            const SizedBox(height: 16),

            _buildReportCard(
              title: 'كشف حساب عميل مفصل',
              subtitle: 'اختر عميل لاستخراج كافة نقلاته ومدفوعاته ورصيده',
              icon: Icons.person_search,
              color: Colors.purple.shade700,
              onTap: () => _generateDetailedReport(1),
            ),

            _buildReportCard(
              title: 'كشف حساب سائق مفصل',
              subtitle: 'اختر سائق لمراجعة أمتاره ومستحقاته وسلفه',
              icon: Icons.engineering,
              color: Colors.teal.shade700,
              onTap: () => _generateDetailedReport(2),
            ),

            _buildReportCard(
              title: 'تقرير حساب المكتب',
              subtitle: 'حصر شامل لنقلات وإيرادات سيارات المكتب مباشرة',
              icon: Icons.domain,
              color: Colors.blue.shade800,
              onTap: () => _generateDetailedReport(5),
            ),

            _buildReportCard(
              title: 'تقرير حساب الشيخ محمد (جرارات)',
              subtitle: 'مراجعة أمتار الجرارات والتسويات المدفوعة',
              icon: Icons.local_shipping,
              color: Colors.amber.shade800,
              onTap: () => _generateDetailedReport(3),
            ),

            _buildReportCard(
              title: 'تقرير حساب اللودر الشامل',
              subtitle: 'تفاصيل تعبئة الرمل للموقعين',
              icon: Icons.front_loader,
              color: Colors.indigo.shade700,
              onTap: () => _generateDetailedReport(4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard({required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold, color: color)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.grey.shade700)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}