import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart' hide Border;

class ClientDetailsScreen extends StatefulWidget {
  final String clientName;
  final double openingBalance;

  const ClientDetailsScreen({
    super.key,
    required this.clientName,
    required this.openingBalance,
  });

  @override
  State<ClientDetailsScreen> createState() => _ClientDetailsScreenState();
}

class _ClientDetailsScreenState extends State<ClientDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _paymentMethods = ['كاش', 'فودافون كاش', 'إنستاباي', 'تحويل بنكي', 'شيك بنكي'];
  final List<String> _newSystemClients = ['بخيت', 'عادل'];
  double _currentNetRemaining = 0.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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

  String _formatCubage(double amount) {
    String result = amount == 0.0 ? '0' : (amount % 1 == 0 ? amount.toInt().toString() : amount.toStringAsFixed(1));
    return _toArabicNumbers(result);
  }

  DateTime? _parseRawDate(Map<String, dynamic> item) {
    try {
      if (item['timestamp'] != null && item['timestamp'] is Timestamp) {
        return (item['timestamp'] as Timestamp).toDate();
      }
      if (item['date'] != null && item['date'] is Timestamp) {
        return (item['date'] as Timestamp).toDate();
      }
      String rawDate = item['dateString'] ?? item['tripDate'] ?? '';
      if (rawDate.isNotEmpty) {
        var parts = rawDate.split(RegExp(r'[-/]'));
        if (parts.length == 3) {
          int p0 = int.tryParse(parts[0]) ?? 0;
          int p1 = int.tryParse(parts[1]) ?? 0;
          int p2 = int.tryParse(parts[2]) ?? 0;
          if (p0 > 1000) return DateTime(p0, p1, p2);
          if (p2 > 1000) return DateTime(p2, p1, p0);
        }
      }
    } catch (_) {}
    return null;
  }

  String _extractAndFormatDate(Map<String, dynamic> item) {
    try {
      String rawDate = item['dateString'] ?? item['date'] ?? item['tripDate'] ?? '';
      if (rawDate.isNotEmpty) {
        if (rawDate.contains('-')) {
          var parts = rawDate.split('-');
          if (parts.length == 3) {
            return '${_toArabicNumbers(parts[0])}/${_toArabicNumbers(int.parse(parts[1]).toString())}/${_toArabicNumbers(int.parse(parts[2]).toString())}';
          }
        } else if (rawDate.contains('/')) {
          var parts = rawDate.split('/');
          if (parts.length == 3) {
            if (parts[0].length == 4) {
              return '${_toArabicNumbers(parts[0])}/${_toArabicNumbers(int.parse(parts[1]).toString())}/${_toArabicNumbers(int.parse(parts[2]).toString())}';
            } else {
              return '${_toArabicNumbers(parts[2])}/${_toArabicNumbers(int.parse(parts[1]).toString())}/${_toArabicNumbers(int.parse(parts[0]).toString())}';
            }
          }
        }
        return _toArabicNumbers(rawDate);
      }
      if (item['timestamp'] != null && item['timestamp'] is Timestamp) {
        DateTime dt = (item['timestamp'] as Timestamp).toDate();
        return '${_toArabicNumbers(dt.year.toString())}/${_toArabicNumbers(dt.month.toString())}/${_toArabicNumbers(dt.day.toString())}';
      }
    } catch (_) {}
    return 'بدون تاريخ';
  }

  bool _isTripTractor(Map<String, dynamic> trip) {
    if (trip['isTractor'] == true) return true;
    String detailsStr = '${trip['vehicleNumber'] ?? ''} ${trip['carType'] ?? ''} ${trip['type'] ?? ''}'.toLowerCase();
    if (detailsStr.contains('جرار') || detailsStr.contains('tractor')) return true;
    return false;
  }

  String _formatNumber(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }

  void _showAddClientAccessDialog() {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(
            children: [
              Icon(Icons.person_add_alt_1, color: Color(0xFF4A78B9)),
              SizedBox(width: 8),
              Text('إعطاء صلاحية للعميل', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('أدخل إيميل العميل ليتمكن من الدخول للمشاهدة فقط.', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  hintText: 'example@company.com',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.email_outlined),
                  isDense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey))),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الإرسال بنجاح!', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green));
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF28A745)),
              child: const Text('إرسال دعوة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadArchiveFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'xlsx', 'xls', 'doc', 'docx', 'jpg', 'png'],
      );

      if (result != null && result.files.single.path != null) {
        String fileName = result.files.single.name;
        File file = File(result.files.single.path!);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('جاري رفع الملف... برجاء الانتظار', style: TextStyle(fontFamily: 'Cairo'))));

        Reference ref = FirebaseStorage.instance.ref().child('archives/${widget.clientName}/$fileName');
        UploadTask uploadTask = ref.putFile(file);
        TaskSnapshot snapshot = await uploadTask;
        String downloadUrl = await snapshot.ref.getDownloadURL();

        await FirebaseFirestore.instance.collection('client_archives').add({
          'clientName': widget.clientName,
          'fileName': fileName,
          'fileUrl': downloadUrl,
          'timestamp': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم رفع الملف بنجاح!', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: ${e.toString()}', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _deleteArchiveFile(String docId, String fileUrl) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد الحذف', style: TextStyle(fontFamily: 'Cairo', color: Colors.red, fontWeight: FontWeight.bold)),
          content: const Text('هل أنت متأكد من حذف هذا الملف من الأرشيف نهائياً؟', style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('client_archives').doc(docId).delete();
        if (fileUrl.isNotEmpty) {
          try {
            Reference ref = FirebaseStorage.instance.refFromURL(fileUrl);
            await ref.delete();
          } catch (_) {}
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف الملف بنجاح', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء الحذف: $e')));
        }
      }
    }
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يمكن فتح الرابط', style: TextStyle(fontFamily: 'Cairo'))));
    }
  }

  void _showExportOptions(List<Map<String, dynamic>> trips) {
    if (trips.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يوجد نقلات لتصديرها', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red));
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('اختر صيغة التصدير', style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold)),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.table_chart, color: Colors.green, size: 30),
                title: const Text('تصدير كملف Excel', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                onTap: () { Navigator.pop(ctx); _exportToExcel(trips); },
              ),
              ListTile(
                leading: const Icon(Icons.description, color: Colors.blue, size: 30),
                title: const Text('تصدير كملف Word', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                onTap: () { Navigator.pop(ctx); _exportToWord(trips); },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportToExcel(List<Map<String, dynamic>> trips) async {
    try {
      var excel = Excel.createExcel();
      String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
      excel.rename(defaultSheet, 'سجل النقلات');
      Sheet sheetObject = excel['سجل النقلات'];
      excel.setDefaultSheet('سجل النقلات');

      sheetObject.appendRow([
        TextCellValue('التاريخ'),
        TextCellValue('السائق'),
        TextCellValue('نوع المركبة'),
        TextCellValue('رقم المركبة'),
        TextCellValue('عدد النقلات'),
        TextCellValue('تكعيب العربية'),
        TextCellValue('إجمالي أمتار الرمل'),
      ]);

      double totalSandMetersSum = 0.0;

      for (var trip in trips) {
        String date = _extractAndFormatDate(trip);
        String driver = trip['driverName'] ?? trip['driver'] ?? 'غير محدد';
        bool isTractor = _isTripTractor(trip);
        String vehicleType = isTractor ? 'جرار' : 'عربية';
        String carNo = trip['vehicleNumber'] ?? trip['carNumber'] ?? '';

        int count = int.tryParse(trip['tripsCount']?.toString() ?? '1') ?? 1;
        double cubage = double.tryParse(trip['cubage']?.toString() ?? trip['totalCubage']?.toString() ?? '0') ?? 0.0;
        double totalTripSand = double.tryParse(trip['totalCubage']?.toString() ?? (count * cubage).toString()) ?? (count * cubage);

        totalSandMetersSum += totalTripSand;

        sheetObject.appendRow([
          TextCellValue(date),
          TextCellValue(driver),
          TextCellValue(vehicleType),
          TextCellValue(carNo),
          TextCellValue(count.toString()),
          TextCellValue(cubage.toStringAsFixed(1)),
          TextCellValue(totalTripSand.toStringAsFixed(1)),
        ]);
      }

      sheetObject.appendRow([
        TextCellValue('الإجمالي الكلي'),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue('${totalSandMetersSum.toStringAsFixed(1)} م³'),
      ]);

      var fileBytes = excel.save();
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/سجل_نقلات_${widget.clientName}.xlsx';

      File(path)..createSync(recursive: true)..writeAsBytesSync(fileBytes!);
      await Share.shareXFiles([XFile(path)], text: 'مرفق سجل النقلات للعميل: ${widget.clientName}');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء تصدير الإكسيل: $e')));
    }
  }

  Future<void> _exportToWord(List<Map<String, dynamic>> trips) async {
    try {
      String htmlContent = """
      <html dir="rtl" lang="ar">
      <head><meta charset="utf-8"><style>body{font-family:Tahoma;} table{width:100%; border-collapse:collapse;} th,td{border:1px solid #ddd; padding:8px; text-align:center;} th{background-color:#0F2A52; color:white;}</style></head>
      <body>
      <h2>سجل نقلات العميل: ${widget.clientName}</h2>
      <table>
        <tr><th>التاريخ</th><th>السائق</th><th>نوع المركبة</th><th>رقم المركبة</th><th>عدد النقلات</th><th>تكعيب العربية</th><th>إجمالي أمتار الرمل</th></tr>
      """;

      double totalSandMetersSum = 0.0;

      for (var trip in trips) {
        String date = _extractAndFormatDate(trip);
        String driver = trip['driverName'] ?? trip['driver'] ?? 'غير محدد';
        bool isTractor = _isTripTractor(trip);
        String vehicleType = isTractor ? 'جرار' : 'عربية';
        String carNo = trip['vehicleNumber'] ?? trip['carNumber'] ?? '';
        int count = int.tryParse(trip['tripsCount']?.toString() ?? '1') ?? 1;
        double cubage = double.tryParse(trip['cubage']?.toString() ?? trip['totalCubage']?.toString() ?? '0') ?? 0.0;
        double totalTripSand = double.tryParse(trip['totalCubage']?.toString() ?? (count * cubage).toString()) ?? (count * cubage);

        totalSandMetersSum += totalTripSand;

        htmlContent += "<tr><td>$date</td><td>$driver</td><td>$vehicleType</td><td>$carNo</td><td>$count</td><td>$cubage</td><td>$totalTripSand</td></tr>";
      }

      htmlContent += "<tr style='font-weight:bold; background-color:#f1f1f1;'><td colspan='6'>الإجمالي الكلي لأمتار الرمل</td><td>$totalSandMetersSum م³</td></tr>";
      htmlContent += "</table></body></html>";

      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/سجل_نقلات_${widget.clientName}.doc';
      final file = File(path);
      await file.writeAsString(htmlContent);

      await Share.shareXFiles([XFile(path)], text: 'مرفق تقرير Word لنقلات العميل: ${widget.clientName}');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء تصدير Word: $e')));
    }
  }

  Future<void> _deletePayment(String docId) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد الحذف', style: TextStyle(fontFamily: 'Cairo', color: Colors.red, fontWeight: FontWeight.bold)),
          content: const Text('هل أنت متأكد من حذف هذه الدفعة نهائياً؟', style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('settlements').doc(docId).delete();
    }
  }

  Future<void> _editPayment(String docId, Map<String, dynamic> currentData) async {
    TextEditingController amountCtrl = TextEditingController(text: currentData['amount'].toString());
    String selectedMethod = currentData['paymentMethod'] ?? 'كاش';

    await showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setStateDialog) => AlertDialog(
            title: const Text('تعديل الدفعة', style: TextStyle(fontFamily: 'Cairo')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _paymentMethods.contains(selectedMethod) ? selectedMethod : 'كاش',
                  decoration: const InputDecoration(labelText: 'طريقة الدفع', border: OutlineInputBorder()),
                  items: _paymentMethods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (val) => setStateDialog(() => selectedMethod = val!),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: () async {
                  double newAmount = double.tryParse(amountCtrl.text) ?? 0.0;
                  await FirebaseFirestore.instance.collection('settlements').doc(docId).update({'amount': newAmount, 'paymentMethod': selectedMethod});
                  if (mounted) Navigator.pop(ctx);
                },
                child: const Text('حفظ', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteClient() async {
    if (_currentNetRemaining > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('عفواً، لا يمكن حذف عميل عليه مديونية! برجاء تصفية الحساب أولاً.', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text('تأكيد الحذف النهائي', style: TextStyle(fontFamily: 'Cairo', color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: const Text('هل أنت متأكد من حذف هذا العميل نهائياً من قاعدة البيانات؟ لا يمكن التراجع عن هذا الإجراء.', style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف نهائي', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      try {
        var snapshot = await FirebaseFirestore.instance.collection('clients').where('name', isEqualTo: widget.clientName.trim()).get();
        for (var doc in snapshot.docs) {
          await doc.reference.delete();
        }
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حذف العميل بنجاح', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء الحذف: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String clientCleanName = widget.clientName.trim();
    String targetNorm = _normalizeArabic(clientCleanName);
    bool isNewSystem = _newSystemClients.any((c) => _normalizeArabic(c) == targetNorm);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F9),
        appBar: AppBar(
          title: Text('شركة: $clientCleanName', style: const TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF0F2A52),
          centerTitle: true,
          elevation: 0,
          leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),

          actions: [
            IconButton(
              icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
              tooltip: 'حذف العميل',
              onPressed: _deleteClient,
            ),
            if (_tabController.index != 2)
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('daily_entries').snapshots(),
                builder: (ctx, tripsSnap) {
                  List<Map<String, dynamic>> currentTrips = [];
                  if (tripsSnap.hasData) {
                    for (var doc in tripsSnap.data!.docs) {
                      var data = doc.data() as Map<String, dynamic>;
                      List<dynamic> namesList = data['clientNamesList'] ?? [];
                      bool matchesMain = namesList.any((n) => _normalizeArabic(n.toString()) == targetNorm);
                      List<dynamic> tripsList = data['clientsTrips'] ?? [];
                      for (var tripItem in tripsList) {
                        if (tripItem is Map) {
                          String tripClientName = tripItem['clientName']?.toString() ?? tripItem['client']?.toString() ?? '';
                          if (_normalizeArabic(tripClientName) == targetNorm || matchesMain) {
                            Map<String, dynamic> combinedTrip = Map<String, dynamic>.from(data);
                            combinedTrip.addAll(Map<String, dynamic>.from(tripItem));
                            currentTrips.add(combinedTrip);
                          }
                        }
                      }
                    }
                  }
                  return IconButton(
                      icon: const Icon(Icons.ios_share, color: Colors.white),
                      tooltip: 'تصدير',
                      onPressed: () => _showExportOptions(currentTrips)
                  );
                },
              ),
          ],

          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('client_archives').where('clientName', isEqualTo: clientCleanName).snapshots(),
              builder: (context, archiveSnap) {
                int archiveCount = archiveSnap.hasData ? archiveSnap.data!.docs.length : 0;
                String archiveLabel = archiveCount > 0 ? 'الأرشيف ($archiveCount)' : 'الأرشيف المرفق';

                return TabBar(
                  controller: _tabController,
                  labelColor: const Color(0xFF00D2FF),
                  unselectedLabelColor: Colors.white70,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12),
                  tabs: [
                    const Tab(text: 'سجل النقلات', icon: Icon(Icons.local_shipping, size: 18)),
                    const Tab(text: 'سجل الدفعات', icon: Icon(Icons.payments_outlined, size: 18)),
                    Tab(text: archiveLabel, icon: const Icon(Icons.folder_zip, size: 18)),
                  ],
                );
              },
            ),
          ),
        ),

        body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('settings').snapshots(),
            builder: (context, settingsSnapshot) {
              double clientSpecificPrice = 115.0;
              double truckPrice = 70.0;
              double tractorPrice = 100.0;

              if (settingsSnapshot.hasData) {
                for (var doc in settingsSnapshot.data!.docs) {
                  var data = doc.data() as Map<String, dynamic>;

                  if (doc.id == 'old_site_clients') {
                    for (var entry in data.entries) {
                      if (_normalizeArabic(entry.key) == targetNorm) {
                        clientSpecificPrice = double.tryParse(entry.value['سعر العميل']?.toString() ?? '115') ?? 115.0;
                      }
                    }
                  }

                  if (doc.id == 'new_site_clients') {
                    for (var entry in data.entries) {
                      if (_normalizeArabic(entry.key) == targetNorm) {
                        truckPrice = double.tryParse(entry.value['عربيات']?.toString() ?? '70') ?? 70.0;
                        tractorPrice = double.tryParse(entry.value['جرارات']?.toString() ?? '100') ?? 100.0;
                      }
                    }
                  }
                }
              }

              return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('daily_entries').snapshots(),
                  builder: (context, tripsSnapshot) {

                    return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('settlements').where('name', isEqualTo: clientCleanName).where('type', isEqualTo: 'client_payment').snapshots(),
                        builder: (context, paymentsSnapshot) {

                          double totalTruckMeters = 0.0;
                          double totalTractorMeters = 0.0;
                          double totalOldMeters = 0.0;
                          List<Map<String, dynamic>> clientTrips = [];

                          if (tripsSnapshot.hasData) {
                            for (var doc in tripsSnapshot.data!.docs) {
                              var data = doc.data() as Map<String, dynamic>;
                              List<dynamic> namesList = data['clientNamesList'] ?? [];
                              bool matchesMain = namesList.any((n) => _normalizeArabic(n.toString()) == targetNorm);

                              List<dynamic> tripsList = data['clientsTrips'] ?? [];
                              for (var tripItem in tripsList) {
                                if (tripItem is Map) {
                                  String tripClientName = tripItem['clientName']?.toString() ?? tripItem['client']?.toString() ?? '';
                                  if (_normalizeArabic(tripClientName) == targetNorm || matchesMain) {
                                    Map<String, dynamic> combinedTrip = Map<String, dynamic>.from(data);
                                    combinedTrip.addAll(Map<String, dynamic>.from(tripItem));
                                    clientTrips.add(combinedTrip);

                                    double cubage = double.tryParse(tripItem['totalCubage']?.toString() ?? tripItem['cubage']?.toString() ?? '0') ?? 0.0;
                                    bool isTractor = _isTripTractor(combinedTrip);

                                    if (isNewSystem) {
                                      if (isTractor) {
                                        totalTractorMeters += cubage;
                                      } else {
                                        totalTruckMeters += cubage;
                                      }
                                    } else {
                                      totalOldMeters += cubage;
                                    }
                                  }
                                }
                              }
                            }
                          }

                          // 🔥 الفرز الذكي (بالتاريخ التنازلي، ثم الجرارات أولاً) 🔥
                          clientTrips.sort((a, b) {
                            DateTime dateA = _parseRawDate(a) ?? DateTime(1970);
                            DateTime dateB = _parseRawDate(b) ?? DateTime(1970);
                            int dateComp = dateB.compareTo(dateA);
                            if (dateComp != 0) return dateComp;

                            bool isTractorA = _isTripTractor(a);
                            bool isTractorB = _isTripTractor(b);
                            if (isTractorA && !isTractorB) return -1;
                            if (!isTractorA && isTractorB) return 1;

                            return 0;
                          });

                          // تجهيز القائمة بالهيدر بتاع الأيام
                          List<dynamic> displayList = [];
                          String currentDateStr = '';
                          for (var trip in clientTrips) {
                            String dStr = _extractAndFormatDate(trip);
                            if (dStr != currentDateStr) {
                              displayList.add(dStr);
                              currentDateStr = dStr;
                            }
                            displayList.add(trip);
                          }

                          double newWorkValue = isNewSystem
                              ? (totalTruckMeters * truckPrice) + (totalTractorMeters * tractorPrice)
                              : (totalOldMeters * clientSpecificPrice);

                          double totalPayments = 0.0;
                          List<Map<String, dynamic>> paymentDetails = [];
                          if (paymentsSnapshot.hasData) {
                            for (var doc in paymentsSnapshot.data!.docs) {
                              var pData = doc.data() as Map<String, dynamic>;
                              pData['docId'] = doc.id;
                              paymentDetails.add(pData);
                              totalPayments += double.tryParse(pData['amount']?.toString() ?? '0') ?? 0.0;
                            }
                          }

                          double netRemaining = newWorkValue - totalPayments;
                          _currentNetRemaining = netRemaining;

                          return Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                                ),
                                child: Column(
                                  children: [
                                    IntrinsicHeight(
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          Expanded(
                                            child: _buildDashboardCard(
                                              'إجمالي المستحقات',
                                              newWorkValue,
                                              Colors.amber.shade900,
                                              Icons.account_balance_wallet,
                                              subtitle: isNewSystem ? '(عربيات: $truckPrice ج | جرارات: $tractorPrice ج)' : '(سعر الشركة: $clientSpecificPrice ج)',
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: _buildDashboardCard(
                                              'إجمالي الدفعات',
                                              totalPayments,
                                              Colors.green.shade700,
                                              Icons.payments,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    IntrinsicHeight(
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          Expanded(
                                            child: Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: Colors.red.shade50,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: Colors.red.shade700, width: 1.5),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red.shade700),
                                                      const SizedBox(width: 4),
                                                      Text('المديونية المتبقية', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 8),
                                                  FittedBox(
                                                    child: Text(
                                                      '${_toArabicNumbers(_formatNumber(netRemaining))} ج.م',
                                                      style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w900, color: Colors.red.shade700),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.shade50,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: Colors.blue.shade700, width: 1.5),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: isNewSystem ? [
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Row(children: [
                                                        Icon(Icons.airport_shuttle, size: 14, color: Colors.blue.shade700),
                                                        const SizedBox(width: 4),
                                                        Text('عربيات:', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
                                                      ]),
                                                      Text('${_formatCubage(totalTruckMeters)} م³', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w900, color: Colors.blue.shade900)),
                                                    ],
                                                  ),
                                                  const Divider(height: 12, thickness: 1),
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Row(children: [
                                                        Icon(Icons.local_shipping, size: 14, color: Colors.orange.shade800),
                                                        const SizedBox(width: 4),
                                                        Text('جرارات:', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
                                                      ]),
                                                      Text('${_formatCubage(totalTractorMeters)} م³', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w900, color: Colors.orange.shade900)),
                                                    ],
                                                  ),
                                                ] : [
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Row(children: [
                                                        Icon(Icons.layers, size: 14, color: Colors.blue.shade700),
                                                        const SizedBox(width: 4),
                                                        Text('إجمالي الأمتار:', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
                                                      ]),
                                                      Text('${_formatCubage(totalOldMeters)} م³', style: TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.w900, color: Colors.blue.shade900)),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              Expanded(
                                child: TabBarView(
                                  controller: _tabController,
                                  children: [
                                    // 1. سجل النقلات
                                    Column(
                                      children: [
                                        Container(
                                          color: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('إجمالي: ${_toArabicNumbers(clientTrips.length.toString())} نقلة', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          child: displayList.isEmpty
                                              ? _buildEmptyState(Icons.local_shipping_outlined, 'لم يتم تسجيل أي نقلات بعد')
                                              : ListView.builder(
                                            key: ValueKey(displayList.length),
                                            padding: const EdgeInsets.all(8),
                                            itemCount: displayList.length,
                                            itemBuilder: (context, index) {
                                              var item = displayList[index];

                                              // عرض فاصل اليومية المميز
                                              if (item is String) {
                                                return Container(
                                                    margin: const EdgeInsets.only(top: 12, bottom: 6),
                                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                                    decoration: BoxDecoration(
                                                        color: const Color(0xFF0F2A52),
                                                        borderRadius: BorderRadius.circular(6)
                                                    ),
                                                    child: Center(
                                                        child: Text(
                                                            'يومية: $item',
                                                            style: const TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)
                                                        )
                                                    )
                                                );
                                              }

                                              // عرض بيانات الكارت من غير التاريخ
                                              var trip = item as Map<String, dynamic>;
                                              String driver = trip['driverName'] ?? trip['driver'] ?? 'غير محدد';
                                              String carNo = trip['vehicleNumber'] ?? trip['carNumber'] ?? 'بدون رقم';
                                              String tripsCount = trip['tripsCount']?.toString() ?? trip['trips']?.toString() ?? '1';
                                              String cubage = trip['cubage']?.toString() ?? '0';
                                              String totalCubage = trip['totalCubage']?.toString() ?? cubage;

                                              bool isTractor = _isTripTractor(trip);
                                              String vehicleTypeLabel = isTractor ? 'جرار' : 'عربية';
                                              Color cardColor = isTractor ? Colors.orange.shade50 : Colors.blue.shade50;
                                              Color borderColor = isTractor ? Colors.orange.shade300 : Colors.blue.shade300;
                                              IconData vIcon = isTractor ? Icons.local_shipping : Icons.airport_shuttle;

                                              return Card(
                                                color: cardColor,
                                                margin: const EdgeInsets.only(bottom: 6),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6), side: BorderSide(color: borderColor, width: 1)),
                                                child: Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                  child: Row(
                                                    children: [
                                                      Icon(vIcon, color: borderColor.withValues(alpha: 0.8), size: 20),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: FittedBox(
                                                          fit: BoxFit.scaleDown,
                                                          alignment: Alignment.centerRight,
                                                          child: Text(
                                                            '$driver  |  $vehicleTypeLabel ${_toArabicNumbers(carNo)}  |  نقلات: ${_toArabicNumbers(tripsCount)}  |  تكعيب: ${_toArabicNumbers(cubage)}  |  الإجمالي: ${_toArabicNumbers(totalCubage)}م³',
                                                            style: const TextStyle(fontFamily: 'Cairo', fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF0F2A52)),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),

                                    // 2. سجل الدفعات
                                    Column(
                                      children: [
                                        Container(
                                          color: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('إجمالي الدفعات: ${_toArabicNumbers(_formatNumber(totalPayments))} ج.م', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                            child: paymentDetails.isEmpty
                                                ? _buildEmptyState(Icons.payments_outlined, 'لم يتم تسجيل أي دفعات بعد')
                                                : ListView.builder(
                                              padding: const EdgeInsets.all(10),
                                              itemCount: paymentDetails.length,
                                              itemBuilder: (context, index) {
                                                var p = paymentDetails[index];
                                                String paymentDate = _extractAndFormatDate(p);

                                                return Card(
                                                  margin: const EdgeInsets.only(bottom: 8),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.green.shade200)),
                                                  child: ListTile(
                                                    leading: const CircleAvatar(backgroundColor: Color(0xFF28A745), child: Icon(Icons.attach_money, color: Colors.white, size: 18)),
                                                    title: Text('المبلغ: ${_toArabicNumbers(p['amount'].toString())} ج.م', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
                                                    subtitle: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text('طريقة الدفع: ${p['paymentMethod'] ?? 'كاش'}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                                                        Text('التاريخ: $paymentDate', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                                                      ],
                                                    ),
                                                    trailing: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        IconButton(icon: Icon(Icons.edit, color: Colors.blue.shade700, size: 20), onPressed: () => _editPayment(p['docId'], p)),
                                                        IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => _deletePayment(p['docId'])),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              },
                                            )
                                        ),
                                      ],
                                    ),

                                    // 3. الأرشيف المرفق
                                    Column(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          width: double.infinity,
                                          color: Colors.white,
                                          child: ElevatedButton.icon(
                                            onPressed: _uploadArchiveFile,
                                            icon: const Icon(Icons.upload_file, color: Colors.white),
                                            label: const Text('رفع ملف للأرشيف', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
                                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F2A52)),
                                          ),
                                        ),
                                        Expanded(
                                          child: StreamBuilder<QuerySnapshot>(
                                              stream: FirebaseFirestore.instance.collection('client_archives').where('clientName', isEqualTo: clientCleanName).snapshots(),
                                              builder: (ctx, snapshot) {
                                                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                                                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _buildEmptyState(Icons.folder_off, 'لا يوجد ملفات في الأرشيف');

                                                return ListView.builder(
                                                    padding: const EdgeInsets.all(10),
                                                    itemCount: snapshot.data!.docs.length,
                                                    itemBuilder: (ctx, index) {
                                                      var doc = snapshot.data!.docs[index];
                                                      var docData = doc.data() as Map<String, dynamic>;
                                                      String docId = doc.id;
                                                      String fileUrl = docData['fileUrl'] ?? '';

                                                      return Card(
                                                        child: ListTile(
                                                          leading: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                                                          title: Text(docData['fileName'] ?? 'ملف بدون اسم', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                                                          trailing: Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              IconButton(
                                                                icon: const Icon(Icons.download, color: Colors.blue),
                                                                tooltip: 'تحميل',
                                                                onPressed: () => _launchURL(fileUrl),
                                                              ),
                                                              IconButton(
                                                                icon: const Icon(Icons.delete, color: Colors.red),
                                                                tooltip: 'حذف',
                                                                onPressed: () => _deleteArchiveFile(docId, fileUrl),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                );
                                              }
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }
                    );
                  }
              );
            }
        ),
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 60, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildDashboardCard(String title, double amount, Color color, IconData icon, {String? subtitle}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(title, style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            child: Text(
              '${_toArabicNumbers(_formatNumber(amount))} ج.م',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w900, color: color),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontFamily: 'Cairo', fontSize: 8.5, color: Colors.grey, fontWeight: FontWeight.bold)),
          ]
        ],
      ),
    );
  }
}