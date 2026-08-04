import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart' hide Border, TextSpan;

class LoaderAccountsScreen extends StatefulWidget {
  const LoaderAccountsScreen({super.key});

  @override
  State<LoaderAccountsScreen> createState() => _LoaderAccountsScreenState();
}

class _LoaderAccountsScreenState extends State<LoaderAccountsScreen> {
  // متغيرات الفلتر
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedSite = 'all'; // 'all', 'old', 'new'

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

  // دالة لضبط التاريخ بشكل إجباري (اليوم يميناً ثم الشهر ثم السنة يساراً)
  String _formatDate(String date) {
    if (date.isEmpty) return '';
    String normalizedDate = date.replaceAll('/', '-');
    List<String> parts = normalizedDate.split('-');
    if (parts.length == 3) {
      String year, month, day;
      if (parts[0].length == 4) { // YYYY-MM-DD
        year = parts[0];
        month = parts[1];
        day = parts[2];
      } else { // DD-MM-YYYY
        day = parts[0];
        month = parts[1];
        year = parts[2];
      }
      // علامة \u200F تجبر النص على الترتيب من اليمين لليسار بدقة تامة
      return '\u200F$day\u200F-\u200F$month\u200F-\u200F$year\u200F';
    }
    return normalizedDate;
  }

  String _formatDateTimeRTL(DateTime dt) {
    return '\u200F${dt.day}\u200F-\u200F${dt.month}\u200F-\u200F${dt.year}\u200F';
  }

  // دالة موحدة لمعالجة واستخراج كافة بيانات اللودر مع تطبيق الفلاتر
  Map<String, dynamic> _calculateLoaderData(QuerySnapshot? tripsSnap, double currentLoaderRate) {
    double oldSiteSandCubage = 0.0;
    double newSiteSandCubage = 0.0;
    List<Map<String, dynamic>> loaderTrips = [];

    if (tripsSnap != null) {
      for (var tripDoc in tripsSnap.docs) {
        var tData = tripDoc.data() as Map<String, dynamic>;
        String site = tData['site'] ?? 'old';
        String dateStr = tData['dateString'] ?? '';
        double vehicleCubage = double.tryParse(tData['cubage']?.toString() ?? '0') ?? 0.0;

        // --- تطبيق فلاتر التاريخ والموقع ---
        if (_selectedSite != 'all' && site != _selectedSite) {
          continue;
        }

        if (dateStr.isNotEmpty) {
          DateTime? tripDate = DateTime.tryParse(dateStr.replaceAll('/', '-'));
          if (tripDate != null) {
            DateTime cleanTrip = DateTime(tripDate.year, tripDate.month, tripDate.day);
            if (_startDate != null) {
              DateTime cleanStart = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
              if (cleanTrip.isBefore(cleanStart)) continue;
            }
            if (_endDate != null) {
              DateTime cleanEnd = DateTime(_endDate!.year, _endDate!.month, _endDate!.day);
              if (cleanTrip.isAfter(cleanEnd)) continue;
            }
          }
        }

        List<dynamic> cTrips = tData['clientsTrips'] ?? [];
        for (var c in cTrips) {
          int tripsCount = (c['tripsCount'] ?? c['trips'] ?? 0) as int;

          if (tripsCount > 0) {
            double cubage = double.tryParse(c['totalCubage']?.toString() ?? c['cubage']?.toString() ?? '0') ?? 0.0;
            if (cubage == 0) cubage = tripsCount * vehicleCubage;

            if (site == 'new') {
              newSiteSandCubage += cubage;
            } else {
              oldSiteSandCubage += cubage;
            }

            String clientName = c['clientName'] ?? c['name'] ?? 'جهة غير محددة';
            double entryTotal = cubage * currentLoaderRate;

            loaderTrips.add({
              'date': dateStr,
              'site': site,
              'clientName': clientName,
              'material': 'رمل',
              'tripsCount': tripsCount,
              'vehicleCubage': vehicleCubage,
              'totalCubage': cubage,
              'rate': currentLoaderRate,
              'total': entryTotal,
            });
          }
        }
      }
    }

    // ترتيب السجل تصاعدياً
    loaderTrips.sort((a, b) => a['date'].toString().compareTo(b['date'].toString()));

    double oldSiteDues = oldSiteSandCubage * currentLoaderRate;
    double newSiteDues = newSiteSandCubage * currentLoaderRate;
    double totalLoaderDues = oldSiteDues + newSiteDues;

    return {
      'oldSiteSandCubage': oldSiteSandCubage,
      'newSiteSandCubage': newSiteSandCubage,
      'oldSiteDues': oldSiteDues,
      'newSiteDues': newSiteDues,
      'totalLoaderDues': totalLoaderDues,
      'loaderTrips': loaderTrips,
      'loaderRate': currentLoaderRate,
    };
  }

  // استخراج سعر اللودر
  double _getLoaderRate(QuerySnapshot? settingsSnap) {
    double rate = 15.0;
    if (settingsSnap != null) {
      for (var doc in settingsSnap.docs) {
        var data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('سعر اللودر')) {
          rate = double.tryParse(data['سعر اللودر'].toString()) ?? rate;
        } else if (data.containsKey('loaderRate')) {
          rate = double.tryParse(data['loaderRate'].toString()) ?? rate;
        } else if (doc.id == 'general_settings' && data.containsKey('loaderRate')) {
          rate = double.tryParse(data['loaderRate'].toString()) ?? rate;
        }
      }
    }
    return rate;
  }

  // نافذة الفلتر المنبثقة بنتيجة واحدة لاختيار فترة التاريخ
  Future<void> _showFilterBottomSheet() async {
    DateTime? tempStart = _startDate;
    DateTime? tempEnd = _endDate;
    String tempSite = _selectedSite;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('تصفية حركات اللودر', style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F2A52))),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.pop(ctx),
                        )
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 5),
                    const Text('حسب الموقع:', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildFilterChip('الكل', 'all', tempSite, (val) => setModalState(() => tempSite = val)),
                        const SizedBox(width: 8),
                        _buildFilterChip('الموقع القديم', 'old', tempSite, (val) => setModalState(() => tempSite = val)),
                        const SizedBox(width: 8),
                        _buildFilterChip('الموقع الجديد', 'new', tempSite, (val) => setModalState(() => tempSite = val)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('حسب الفترة الزمنية:', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: (tempStart != null || tempEnd != null) ? const Color(0xFF0F2A52) : Colors.grey.shade400),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: Icon(Icons.date_range, size: 20, color: (tempStart != null || tempEnd != null) ? const Color(0xFF0F2A52) : Colors.grey.shade600),
                        label: Text(
                          (tempStart == null || tempEnd == null)
                              ? 'تحديد فترة التاريخ (من - إلى)'
                              : 'من: ${_toArabicNumbers(_formatDateTimeRTL(tempStart!))}  إلى: ${_toArabicNumbers(_formatDateTimeRTL(tempEnd!))}',
                          style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold, color: (tempStart != null || tempEnd != null) ? const Color(0xFF0F2A52) : Colors.grey.shade600),
                        ),
                        onPressed: () async {
                          DateTimeRange? pickedRange = await showDateRangePicker(
                            context: ctx,
                            initialDateRange: (tempStart != null && tempEnd != null)
                                ? DateTimeRange(start: tempStart!, end: tempEnd!)
                                : null,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                            builder: (context, child) {
                              return Theme(
                                data: ThemeData.light().copyWith(
                                  colorScheme: const ColorScheme.light(
                                    primary: Color(0xFF0F2A52),
                                    onPrimary: Colors.white,
                                    surface: Colors.white,
                                    onSurface: Colors.black,
                                  ),
                                ),
                                child: Directionality(
                                  textDirection: TextDirection.rtl,
                                  child: child!,
                                ),
                              );
                            },
                          );

                          if (pickedRange != null) {
                            setModalState(() {
                              tempStart = pickedRange.start;
                              tempEnd = pickedRange.end;
                            });
                          }
                        },
                      ),
                    ),

                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F2A52),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () {
                              setState(() {
                                _startDate = tempStart;
                                _endDate = tempEnd;
                                _selectedSite = tempSite;
                              });
                              Navigator.pop(ctx);
                            },
                            child: const Text('تطبيق الفلتر', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: const BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () {
                              setState(() {
                                _startDate = null;
                                _endDate = null;
                                _selectedSite = 'all';
                              });
                              Navigator.pop(ctx);
                            },
                            child: const Text('مسح الفلتر', style: TextStyle(fontFamily: 'Cairo', color: Colors.red, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterChip(String label, String value, String groupValue, Function(String) onSelect) {
    bool isSelected = value == groupValue;
    return InkWell(
      onTap: () => onSelect(value),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F2A52) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? const Color(0xFF0F2A52) : Colors.grey.shade300),
        ),
        child: Text(label, style: TextStyle(fontFamily: 'Cairo', color: isSelected ? Colors.white : Colors.black87, fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  // تصدير إكسيل
  Future<void> _exportToExcel(Map<String, dynamic> data) async {
    Navigator.pop(context);
    try {
      List<Map<String, dynamic>> trips = data['loaderTrips'];
      double oldCubage = data['oldSiteSandCubage'];
      double newCubage = data['newSiteSandCubage'];
      double oldDues = data['oldSiteDues'];
      double newDues = data['newSiteDues'];
      double totalDues = data['totalLoaderDues'];
      double rate = data['loaderRate'];

      var excel = Excel.createExcel();
      String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
      excel.rename(defaultSheet, 'حسابات اللودر');
      Sheet sheet = excel['حسابات اللودر'];
      excel.setDefaultSheet('حسابات اللودر');

      sheet.appendRow([TextCellValue('كشف حساب اللودر')]);
      sheet.appendRow([TextCellValue('سعر التعبئة المعتمد: ${rate.toStringAsFixed(1)} ج للمتر')]);

      if (_startDate != null || _endDate != null || _selectedSite != 'all') {
        String filterDetails = 'تمت التصفية حسب: ';
        if (_selectedSite == 'old') filterDetails += '[الموقع القديم] ';
        if (_selectedSite == 'new') filterDetails += '[الموقع الجديد] ';
        if (_startDate != null && _endDate != null) filterDetails += 'من (${_formatDateTimeRTL(_startDate!).replaceAll('\u200F', '')}) إلى (${_formatDateTimeRTL(_endDate!).replaceAll('\u200F', '')})';
        sheet.appendRow([TextCellValue(filterDetails)]);
      }

      sheet.appendRow([TextCellValue('')]);

      sheet.appendRow([TextCellValue('--- سجل حركات اللودر التفصيلي ---')]);
      sheet.appendRow([TextCellValue('التاريخ'), TextCellValue('الموقع'), TextCellValue('الجهة/العميل'), TextCellValue('المادة'), TextCellValue('التفاصيل الكمية'), TextCellValue('السعر'), TextCellValue('الإجمالي')]);
      for (var t in trips) {
        // إزالة علامة RTL قبل الإدراج في الإكسيل لتجنب أي مشاكل في خلايا إكسيل
        String formattedDate = _toArabicNumbers(_formatDate(t['date'].toString())).replaceAll('\u200F', '');
        sheet.appendRow([
          TextCellValue(formattedDate),
          TextCellValue(t['site'] == 'new' ? 'الموقع الجديد' : 'الموقع القديم'),
          TextCellValue(t['clientName'].toString()),
          TextCellValue(t['material'].toString()),
          TextCellValue('نقلات: ${t['tripsCount']} | الإجمالي: ${t['totalCubage']}م³'),
          TextCellValue('${t['rate']} ج'),
          TextCellValue('${t['total']} ج'),
        ]);
      }

      sheet.appendRow([TextCellValue('')]);
      sheet.appendRow([TextCellValue('--- الملخص المحاسبي النهائي ---')]);
      sheet.appendRow([TextCellValue('البند المحاسبي'), TextCellValue('التفاصيل والكميات'), TextCellValue('إجمالي المستحق')]);
      sheet.appendRow([TextCellValue('الموقع القديم'), TextCellValue('إجمالي الأمتار: ${oldCubage.toStringAsFixed(1)} م³ | السعر: ${rate.toStringAsFixed(1)} ج'), TextCellValue('${oldDues.toStringAsFixed(0)} ج.م')]);
      sheet.appendRow([TextCellValue('الموقع الجديد'), TextCellValue('إجمالي الأمتار: ${newCubage.toStringAsFixed(1)} م³ | السعر: ${rate.toStringAsFixed(1)} ج'), TextCellValue('${newDues.toStringAsFixed(0)} ج.م')]);
      sheet.appendRow([TextCellValue('إجمالي المستحق للودر'), TextCellValue(''), TextCellValue('${totalDues.toStringAsFixed(0)} ج.م')]);

      var fileBytes = excel.save();
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/كشف_حساب_اللودر.xlsx';

      File(path)..createSync(recursive: true)..writeAsBytesSync(fileBytes!);
      await Share.shareXFiles([XFile(path)], text: 'مرفق كشف حساب اللودر الشامل');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء تصدير الإكسيل: $e')));
    }
  }

  // تصدير وورد
  Future<void> _exportToWord(Map<String, dynamic> data) async {
    Navigator.pop(context);
    try {
      List<Map<String, dynamic>> trips = data['loaderTrips'];
      double oldCubage = data['oldSiteSandCubage'];
      double newCubage = data['newSiteSandCubage'];
      double oldDues = data['oldSiteDues'];
      double newDues = data['newSiteDues'];
      double totalDues = data['totalLoaderDues'];
      double rate = data['loaderRate'];

      String tripsRows = '';
      for (var t in trips) {
        String siteName = t['site'] == 'new' ? 'الموقع الجديد' : 'الموقع القديم';
        String formattedDate = _toArabicNumbers(_formatDate(t['date'].toString())); // يحتفظ بعلامات الـ RTL ليظهر صحيح في الوورد
        tripsRows += "<tr><td>$formattedDate</td><td>$siteName</td><td>${t['clientName']}</td><td>${t['material']}</td><td>نقلات: ${t['tripsCount']} | الإجمالي: ${t['totalCubage']}م³</td><td>${t['rate']}ج</td><td>${t['total']}ج</td></tr>";
      }

      String filterText = '';
      if (_startDate != null || _endDate != null || _selectedSite != 'all') {
        filterText = '<p style="color: #666; font-size: 14px;">تمت التصفية حسب: ';
        if (_selectedSite == 'old') filterText += '<b>[الموقع القديم]</b> ';
        if (_selectedSite == 'new') filterText += '<b>[الموقع الجديد]</b> ';
        if (_startDate != null && _endDate != null) filterText += 'من <b>(${_formatDateTimeRTL(_startDate!)})</b> إلى <b>(${_formatDateTimeRTL(_endDate!)})</b>';
        filterText += '</p>';
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
      <h2>كشف حساب اللودر الشامل</h2>
      <p>سعر التعبئة المعتمد: <b>${rate.toStringAsFixed(1)} ج</b> للمتر</p>
      $filterText
      
      <h3>سجل حركات اللودر التفصيلي</h3>
      <table dir="rtl">
        <tr><th>التاريخ</th><th>الموقع</th><th>الجهة/العميل</th><th>المادة</th><th>التفاصيل الكمية</th><th>السعر</th><th>الإجمالي</th></tr>
        $tripsRows
      </table>

      <h3>الملخص المحاسبي النهائي</h3>
      <table dir="rtl">
        <tr><th>البند المحاسبي</th><th>التفاصيل والكميات</th><th>إجمالي المستحق</th></tr>
        <tr><td>الموقع القديم</td><td>إجمالي الأمتار: ${oldCubage.toStringAsFixed(1)} م³ | السعر: ${rate.toStringAsFixed(1)} ج</td><td>${oldDues.toStringAsFixed(0)} ج.م</td></tr>
        <tr><td>الموقع الجديد</td><td>إجمالي الأمتار: ${newCubage.toStringAsFixed(1)} م³ | السعر: ${rate.toStringAsFixed(1)} ج</td><td>${newDues.toStringAsFixed(0)} ج.م</td></tr>
        <tr style='font-weight:bold; background-color:#e8f5e9;'><td colspan='2'>إجمالي المستحق للودر في الموقعين</td><td>${totalDues.toStringAsFixed(0)} ج.م</td></tr>
      </table>
      
      </body></html>
      """;

      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/كشف_حساب_اللودر.doc';
      final file = File(path);
      await file.writeAsString(htmlContent);

      await Share.shareXFiles([XFile(path)], text: 'مرفق تقرير Word الشامل لكشف حساب اللودر');
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
              const Text('تصدير كشف حساب اللودر', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F2A52))),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.table_chart, color: Colors.green, size: 30),
                title: const Text('تصدير كملف Excel', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                onTap: () => _exportToExcel(data),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.description, color: Colors.blue, size: 30),
                title: const Text('تصدير كملف Word', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F9),
        appBar: AppBar(
          title: const Text('حسابات اللودر', style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
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

                    double loaderRate = _getLoaderRate(settingsSnap.data);
                    var loaderData = _calculateLoaderData(tripsSnap.data, loaderRate);

                    return IconButton(
                      icon: const Icon(Icons.ios_share, color: Colors.white, size: 22),
                      tooltip: 'تصدير حسابات اللودر',
                      onPressed: () => _showExportBottomSheet(loaderData),
                    );
                  },
                );
              },
            ),
          ],
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('settings').snapshots(),
          builder: (context, settingsSnap) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('daily_entries').snapshots(),
              builder: (context, tripsSnap) {
                if (!tripsSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                double loaderRate = _getLoaderRate(settingsSnap.data);
                var loaderData = _calculateLoaderData(tripsSnap.data, loaderRate);

                double oldCubage = loaderData['oldSiteSandCubage'];
                double newCubage = loaderData['newSiteSandCubage'];
                double oldDues = loaderData['oldSiteDues'];
                double newDues = loaderData['newSiteDues'];
                double totalDues = loaderData['totalLoaderDues'];
                List<Map<String, dynamic>> loaderTrips = loaderData['loaderTrips'];

                String totalDuesText = '${_toArabicNumbers(_formatCleanNumber(totalDues))} ج.م';
                String currentRateText = _toArabicNumbers(_formatCleanNumber(loaderRate));

                bool isFilterActive = _startDate != null || _endDate != null || _selectedSite != 'all';

                return Column(
                  children: [
                    // 1. الكروت العلوية والسفلية (الداشبورد) بالألوان المميزة
                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildDashboardCard(
                                  title: 'مستحقات الموقع القديم',
                                  value: '${_toArabicNumbers(_formatCleanNumber(oldDues))} ج.م',
                                  textColor: Colors.blue.shade800,
                                  subTitleWidget: RichText(
                                    textAlign: TextAlign.center,
                                    text: TextSpan(
                                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 11),
                                      children: [
                                        TextSpan(text: 'الأمتار: ', style: TextStyle(color: Colors.grey.shade600)),
                                        TextSpan(text: '${_toArabicNumbers(_formatCleanNumber(oldCubage))} م³\n', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.w900)),
                                        TextSpan(text: 'السعر: ', style: TextStyle(color: Colors.grey.shade600)),
                                        TextSpan(text: '$currentRateText ج', style: TextStyle(color: Colors.deepOrange.shade600, fontWeight: FontWeight.w900)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildDashboardCard(
                                  title: 'مستحقات الموقع الجديد',
                                  value: '${_toArabicNumbers(_formatCleanNumber(newDues))} ج.م',
                                  textColor: Colors.green.shade800,
                                  subTitleWidget: RichText(
                                    textAlign: TextAlign.center,
                                    text: TextSpan(
                                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 11),
                                      children: [
                                        TextSpan(text: 'الأمتار: ', style: TextStyle(color: Colors.grey.shade600)),
                                        TextSpan(text: '${_toArabicNumbers(_formatCleanNumber(newCubage))} م³\n', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w900)),
                                        TextSpan(text: 'السعر: ', style: TextStyle(color: Colors.grey.shade600)),
                                        TextSpan(text: '$currentRateText ج', style: TextStyle(color: Colors.deepOrange.shade600, fontWeight: FontWeight.w900)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _buildCenteredGreenCard(
                            title: 'إجمالي المستحق للودر في الموقعين',
                            value: totalDuesText,
                          ),
                        ],
                      ),
                    ),

                    // 2. فاصل عنوان السجل وزرار الفلتر
                    Padding(
                      padding: const EdgeInsets.only(left: 10.0, right: 14.0, bottom: 4.0),
                      child: Row(
                        children: [
                          const Icon(Icons.list_alt, color: Color(0xFF0F2A52), size: 18),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text('سجل حركات اللودر بالكامل', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey.shade800)),
                          ),
                          InkWell(
                            onTap: _showFilterBottomSheet,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isFilterActive ? Colors.green.shade50 : Colors.white,
                                border: Border.all(color: isFilterActive ? Colors.green.shade400 : Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.filter_alt, size: 16, color: isFilterActive ? Colors.green.shade700 : Colors.grey.shade700),
                                  const SizedBox(width: 4),
                                  Text('تصفية', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: isFilterActive ? Colors.green.shade800 : Colors.grey.shade800)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 3. السجل التفصيلي
                    Expanded(
                      child: loaderTrips.isEmpty
                          ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.folder_open, size: 40, color: Colors.grey.shade400),
                            const SizedBox(height: 8),
                            Text('لا توجد حركات لودر مسجلة في هذه الفترة.', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey.shade600)),
                          ],
                        ),
                      )
                          : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        itemCount: loaderTrips.length,
                        itemBuilder: (context, index) {
                          var trip = loaderTrips[index];
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
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              leading: CircleAvatar(
                                radius: 16,
                                backgroundColor: isNewSite ? Colors.green.shade100 : Colors.blue.shade100,
                                child: Icon(Icons.front_loader, color: isNewSite ? Colors.green.shade700 : Colors.blue.shade700, size: 16),
                              ),
                              // هنا التاريخ هيكون (اليوم يميناً ثم شرطة ثم الشهر ثم شرطة ثم السنة يساراً)
                              title: Text(
                                '${_toArabicNumbers(formattedDate)} - ${isNewSite ? 'الموقع الجديد' : 'الموقع القديم'} - ${trip['clientName']}',
                                style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: isNewSite ? Colors.green.shade900 : Colors.blue.shade900
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  'نقلات: ${_toArabicNumbers(_formatCleanNumber(trip['tripsCount'].toDouble()))} | الإجمالي: ${_toArabicNumbers(_formatCleanNumber(trip['totalCubage']))} م³ | السعر: ${_toArabicNumbers(_formatCleanNumber(trip['rate']))} ج',
                                  style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: Colors.grey.shade800, fontWeight: FontWeight.bold),
                                ),
                              ),
                              trailing: Text(
                                '${_toArabicNumbers(_formatCleanNumber(trip['total']))} ج',
                                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 13, color: isNewSite ? Colors.green.shade800 : Colors.blue.shade800),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildDashboardCard({required String title, required String value, required Color textColor, Widget? subTitleWidget}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Cairo', color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          FittedBox(
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 18, color: textColor),
            ),
          ),
          if (subTitleWidget != null) ...[
            const SizedBox(height: 6),
            FittedBox(child: subTitleWidget),
          ]
        ],
      ),
    );
  }

  Widget _buildCenteredGreenCard({required String title, required String value}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
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
            style: TextStyle(fontFamily: 'Cairo', color: Colors.green.shade800, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 22, color: Colors.green.shade900),
          ),
        ],
      ),
    );
  }
}