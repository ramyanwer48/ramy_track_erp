import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;

// 🧠 فلتر سحري لتوحيد الأرقام
String _normalizeNumberForMatch(String input) {
  const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  String result = input;
  for (int i = 0; i < arabic.length; i++) {
    result = result.replaceAll(arabic[i], english[i]);
  }
  return result.replaceAll(RegExp(r'[^0-9]'), '');
}

// 🧠 توحيد الحروف
String _normalizeText(String text) {
  return text.trim()
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('آ', 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll(' ', '');
}

int _levenshteinDistance(String s, String t) {
  if (s == t) return 0;
  if (s.isEmpty) return t.length;
  if (t.isEmpty) return s.length;

  List<int> v0 = List<int>.generate(t.length + 1, (i) => i);
  List<int> v1 = List<int>.filled(t.length + 1, 0);

  for (int i = 0; i < s.length; i++) {
    v1[0] = i + 1;
    for (int j = 0; j < t.length; j++) {
      int cost = (s[i] == t[j]) ? 0 : 1;
      v1[j + 1] = [v1[j] + 1, v0[j + 1] + 1, v0[j] + cost].reduce(min);
    }
    for (int j = 0; j < v0.length; j++) {
      v0[j] = v1[j];
    }
  }
  return v1[t.length];
}

class DestinationRecord {
  TextEditingController clientCtrl = TextEditingController();
  TextEditingController tripsCtrl = TextEditingController();

  DestinationRecord({String client = '', String trips = '1'}) {
    clientCtrl.text = client;
    tripsCtrl.text = trips;
  }
  void dispose() {
    clientCtrl.dispose();
    tripsCtrl.dispose();
  }
}

class DriverEntryRecord {
  TextEditingController driverCtrl = TextEditingController();
  TextEditingController carNumberCtrl = TextEditingController();
  TextEditingController cubageCtrl = TextEditingController();
  List<DestinationRecord> destinations = [];
  String site = 'new';

  DriverEntryRecord({
    String driver = '',
    String carNumber = '',
    String cubage = '0',
    String siteVal = 'new',
    List<DestinationRecord> destList = const [],
  }) {
    driverCtrl.text = driver;
    carNumberCtrl.text = carNumber;
    cubageCtrl.text = cubage;
    site = siteVal;
    destinations = List.from(destList);
  }
  void dispose() {
    driverCtrl.dispose();
    carNumberCtrl.dispose();
    cubageCtrl.dispose();
    for (var d in destinations) {
      d.dispose();
    }
  }
}

class AiDailyEntryScreen extends StatefulWidget {
  const AiDailyEntryScreen({super.key});

  @override
  State<AiDailyEntryScreen> createState() => _AiDailyEntryScreenState();
}

class _AiDailyEntryScreenState extends State<AiDailyEntryScreen> {
  File? _selectedImage;
  bool _isAnalyzing = false;
  bool _isDataExtracted = false;

  // 1️⃣ تاريخ البيان المخصص (يأخذ تاريخ اليوم افتراضياً)
  DateTime _selectedDate = DateTime.now();

  List<DriverEntryRecord> _driverRecords = [];

  List<String> _existingClientsFromDb = [];
  List<Map<String, dynamic>> _vehiclesFromDb = [];
  List<String> _allCarNumbers = [];

  // 5️⃣ متغيرات حفظ الأسعار الافتراضية
  double _defaultClientPrice = 0.0;
  double _defaultOfficePrice = 0.0;

  final ImagePicker _picker = ImagePicker();
  final String geminiApiKey = ''; // ⚠️ ضع مفتاح جوجل هنا ⚠️

  @override
  void initState() {
    super.initState();
    _fetchDatabaseData(showMessages: false);
  }

  Future<void> _fetchDatabaseData({bool showMessages = true}) async {
    try {
      if (showMessages && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('جاري الاتصال بالفايربيز...', style: TextStyle(fontFamily: 'Cairo')), duration: Duration(seconds: 1)),
        );
      }

      var clientsSnap = await FirebaseFirestore.instance.collection('clients').get();
      var vehiclesSnap = await FirebaseFirestore.instance.collection('vehicles').get();

      var settingsSnap = await FirebaseFirestore.instance.collection('settings').doc('prices').get();
      if(settingsSnap.exists) {
        _defaultClientPrice = (settingsSnap.data()?['defaultClientPrice'] ?? 100.0).toDouble();
        _defaultOfficePrice = (settingsSnap.data()?['defaultOfficePrice'] ?? 10.0).toDouble();
      }

      setState(() {
        _existingClientsFromDb = clientsSnap.docs.map((doc) => doc['name'].toString()).toList();

        _vehiclesFromDb = vehiclesSnap.docs.map((doc) {
          var data = doc.data();
          return {
            'name': data['name']?.toString() ?? '',
            'number': data['number']?.toString() ?? '',
            'cubage': data['cubage']?.toString() ?? '0',
          };
        }).toList();

        _allCarNumbers = _vehiclesFromDb.map((e) => e['number'].toString()).toList();
      });

      if (showMessages && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ تم الربط بنجاح: تم جلب ${_vehiclesFromDb.length} معدة وسائق!', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            backgroundColor: Colors.blueAccent,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error fetching db data: $e');
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF00D2FF),
              onPrimary: Color(0xFF103667),
              surface: Color(0xFF0A2540),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF0A2540),
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

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1800,
        maxHeight: 1800,
      );
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _isDataExtracted = false;
          _driverRecords.clear();
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _analyzeImageWithAI() async {
    if (_selectedImage == null) return;

    // تم إزالة القفلة التي كانت تمنع التحليل، سيتم المحاولة لجلب البيانات وإكمال التحليل حتى لو لم توجد معدات
    if (_vehiclesFromDb.isEmpty) {
      await _fetchDatabaseData(showMessages: true);
    }

    setState(() {
      _isAnalyzing = true;
    });

    try {
      final imageBytes = await _selectedImage!.readAsBytes();
      String base64Image = base64Encode(imageBytes);

      final prompt = '''
      أنت محاسب محترف لنظام ERP محاجر في مصر. حلل هذه الصورة لجدول يومية نقل بخط اليد.
      فك الاختصارات (مثل: خ = خلاطة، ش = شارع).
      لكل سائق، استخرج:
      - اسم السائق بوضوح.
      - رقم العربية أو الجرار (استخرج كل الأرقام المكتوبة قدر الإمكان).
      - اسم العميل وعدد النقلات لكل جهة.
      أرجع النتيجة بصيغة JSON Array فقط وبدون أي نصوص إضافية بهذا الشكل تماماً:
      [
        {
          "driverName": "اسم السائق",
          "carNumber": "رقم العربية",
          "destinations": [
            {"clientName": "اسم العميل", "tripsCount": 2}
          ]
        }
      ]
      ''';

      final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent?key=$geminiApiKey');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {"text": prompt},
                {
                  "inlineData": {
                    "mimeType": "image/jpeg",
                    "data": base64Image
                  }
                }
              ]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String responseText = data['candidates'][0]['content']['parts'][0]['text'];

        responseText = responseText.replaceAll('```json', '').replaceAll('```', '').trim();
        List<dynamic> parsedData = jsonDecode(responseText);

        setState(() {
          _driverRecords = parsedData.map((driverData) {
            String aiDriverName = driverData['driverName']?.toString().trim() ?? '';
            String aiCarNumberRaw = driverData['carNumber']?.toString().trim() ?? '';

            String matchedCarNumber = '';
            String matchedCubage = '0';

            String normalizedAiName = _normalizeText(aiDriverName);
            for (var dbVehicle in _vehiclesFromDb) {
              String normalizedDbName = _normalizeText(dbVehicle['name'].toString());
              if (normalizedDbName.isNotEmpty && normalizedAiName.isNotEmpty &&
                  (normalizedDbName.contains(normalizedAiName) || aiDriverName.contains(normalizedDbName))) {
                matchedCarNumber = dbVehicle['number'];
                matchedCubage = dbVehicle['cubage'];
                break;
              }
            }

            if (matchedCarNumber.isEmpty && aiCarNumberRaw.isNotEmpty) {
              String cleanAiNum = _normalizeNumberForMatch(aiCarNumberRaw);
              for (var dbVehicle in _vehiclesFromDb) {
                String cleanDbNum = _normalizeNumberForMatch(dbVehicle['number'].toString());
                if (cleanAiNum.isNotEmpty && cleanDbNum.isNotEmpty && cleanDbNum.length >= 2) {
                  if (cleanAiNum.contains(cleanDbNum) || cleanDbNum.contains(cleanAiNum)) {
                    matchedCarNumber = dbVehicle['number'];
                    matchedCubage = dbVehicle['cubage'];
                    break;
                  }
                }
              }
            }

            if (matchedCarNumber.isEmpty) matchedCarNumber = aiCarNumberRaw;

            var dests = (driverData['destinations'] as List? ?? []).map((d) {
              return DestinationRecord(
                client: d['clientName']?.toString() ?? '',
                trips: d['tripsCount']?.toString() ?? '1',
              );
            }).toList();

            return DriverEntryRecord(
              driver: aiDriverName,
              carNumber: matchedCarNumber,
              cubage: matchedCubage,
              siteVal: 'new',
              destList: dests,
            );
          }).toList();

          _isAnalyzing = false;
          _isDataExtracted = true;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ تم التحليل بنجاح!', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['error']['message'] ?? 'تأكد من صحة مفتاح الـ API للذكاء الاصطناعي.';
        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint('AI Error: $e');
      setState(() {
        _isAnalyzing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('❌ فشل التحليل: $e', style: const TextStyle(fontFamily: 'Cairo')),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 6)
          ),
        );
      }
    }
  }

  void _showVehicleSelectionSheet(BuildContext context, DriverEntryRecord driverRec) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            var filteredVehicles = _vehiclesFromDb.where((v) {
              return v['number'].toString().contains(searchQuery) ||
                  v['name'].toString().contains(searchQuery);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Color(0xFF0A2540),
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              ),
              padding: const EdgeInsets.only(top: 10, left: 16, right: 16),
              child: Column(
                children: [
                  Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(10))),
                  const SizedBox(height: 20),
                  const Text('ابحث واختر المعدة', style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  TextField(
                    onChanged: (val) => setModalState(() => searchQuery = val),
                    style: const TextStyle(color: Colors.white, fontFamily: 'Cairo'),
                    decoration: InputDecoration(
                      hintText: 'ابحث بالاسم أو برقم العربية...',
                      hintStyle: const TextStyle(color: Colors.white54, fontFamily: 'Cairo'),
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF00D2FF)),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredVehicles.length,
                      itemBuilder: (context, index) {
                        var vehicle = filteredVehicles[index];
                        return Card(
                          color: Colors.white.withValues(alpha: 0.05),
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          child: ListTile(
                            title: Text(vehicle['name'].toString(), style: const TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15)),
                            subtitle: Text('رقم: ${vehicle['number']}  |  تكعيب: ${vehicle['cubage']}', style: const TextStyle(color: Colors.white70, fontFamily: 'Cairo')),
                            onTap: () {
                              setState(() {
                                driverRec.carNumberCtrl.text = vehicle['number'].toString();
                                driverRec.cubageCtrl.text = vehicle['cubage'].toString();
                                driverRec.driverCtrl.text = vehicle['name'].toString();
                              });
                              Navigator.pop(context);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submitAiEntry() async {
    if (_driverRecords.isEmpty) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator(color: Color(0xFF00D2FF))),
      );

      // 3️⃣ حفظ الصورة كدليل
      String uploadedImageUrl = '';
      if (_selectedImage != null) {
        try {
          String fileName = 'daily_entry_${DateTime.now().millisecondsSinceEpoch}.jpg';
          Reference storageRef = FirebaseStorage.instance.ref().child('daily_entries_images/$fileName');
          await storageRef.putFile(_selectedImage!);
          uploadedImageUrl = await storageRef.getDownloadURL();
        } catch (imgError) {
          debugPrint('لم يتم رفع الصورة: $imgError');
        }
      }

      WriteBatch batch = FirebaseFirestore.instance.batch();
      CollectionReference entriesRef = FirebaseFirestore.instance.collection('daily_entries');
      CollectionReference clientsRef = FirebaseFirestore.instance.collection('clients');
      CollectionReference clientAccountsRef = FirebaseFirestore.instance.collection('client_accounts');
      CollectionReference vehiclesRef = FirebaseFirestore.instance.collection('vehicles');

      String formattedDate = '${_selectedDate.year}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.day.toString().padLeft(2, '0')}';

      for (var driverRec in _driverRecords) {
        if (driverRec.driverCtrl.text.trim().isEmpty) continue;

        String engCubage = driverRec.cubageCtrl.text.replaceAll('٠', '0').replaceAll('١', '1').replaceAll('٢', '2').replaceAll('٣', '3').replaceAll('٤', '4').replaceAll('٥', '5').replaceAll('٦', '6').replaceAll('٧', '7').replaceAll('٨', '8').replaceAll('٩', '9');
        double totalCubage = double.tryParse(engCubage) ?? 0.0;

        // التسجيل التلقائي للمعدات الجديدة
        if (!_allCarNumbers.contains(driverRec.carNumberCtrl.text) && driverRec.carNumberCtrl.text.isNotEmpty) {
          DocumentReference newVehicleDoc = vehiclesRef.doc();
          batch.set(newVehicleDoc, {
            'name': driverRec.driverCtrl.text.trim(),
            'number': driverRec.carNumberCtrl.text.trim(),
            'cubage': totalCubage,
            'typeCode': 'M',
            'createdAt': FieldValue.serverTimestamp(),
          });
          _allCarNumbers.add(driverRec.carNumberCtrl.text);
        }

        List<Map<String, dynamic>> clientsTripsList = [];
        int totalTripsCount = 0;

        for (var dest in driverRec.destinations) {
          String engTrips = dest.tripsCtrl.text.replaceAll('٠', '0').replaceAll('١', '1').replaceAll('٢', '2');
          int trips = int.tryParse(engTrips) ?? 1;
          String clientName = dest.clientCtrl.text.trim();
          totalTripsCount += trips;

          if (clientName.isNotEmpty) {
            // التسجيل التلقائي للعملاء الجدد
            if (!_existingClientsFromDb.contains(clientName)) {
              DocumentReference newClientDoc = clientsRef.doc();
              batch.set(newClientDoc, {
                'name': clientName,
                'createdAt': FieldValue.serverTimestamp(),
              });

              DocumentReference newAccountDoc = clientAccountsRef.doc();
              batch.set(newAccountDoc, {
                'clientName': clientName,
                'balance': 0,
                'createdAt': FieldValue.serverTimestamp(),
              });
              _existingClientsFromDb.add(clientName);
            }
          }

          clientsTripsList.add({
            'clientName': clientName,
            'tripsCount': trips,
            'totalCubage': 0.0,
            'clientPriceSnapshot': _defaultClientPrice,
            'officePriceSnapshot': _defaultOfficePrice,
          });
        }

        double singleCubage = totalTripsCount > 0 ? totalCubage / totalTripsCount : totalCubage;

        DocumentReference entryDocRef = entriesRef.doc();
        batch.set(entryDocRef, {
          'site': driverRec.site,
          'driverName': driverRec.driverCtrl.text.trim(),
          'carNumber': driverRec.carNumberCtrl.text.trim(),
          'dateString': formattedDate,
          'timestamp': FieldValue.serverTimestamp(),
          'clientsTrips': clientsTripsList,
          'cubage': singleCubage,
          'totalCubage': totalCubage,
          'auditImageUrl': uploadedImageUrl,
          'isAiGenerated': true,
        });
      }

      await batch.commit();

      if (!mounted) return;
      Navigator.pop(context);
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم ترحيل اليومية والمعدات والعملاء بنجاح!', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          backgroundColor: Color(0xFF28A745),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء الحفظ: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red));
    }
  }

  @override
  void dispose() {
    for (var r in _driverRecords) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF103667),
        appBar: AppBar(
          backgroundColor: const Color(0xFF103667),
          elevation: 0,
          centerTitle: true,
          title: const Text(
            'إدخال البيان بالذكاء الاصطناعي',
            style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.sync, color: Color(0xFF00D2FF)),
              tooltip: 'تحديث بيانات الفايربيز',
              onPressed: () => _fetchDatabaseData(showMessages: true),
            ),
          ],
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 650),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.calendar_today, color: Color(0xFF00D2FF)),
                      title: const Text('تاريخ البيان:', style: TextStyle(color: Colors.white70, fontFamily: 'Cairo', fontSize: 14)),
                      subtitle: Text('${_selectedDate.year}/${_selectedDate.month}/${_selectedDate.day}', style: const TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
                      trailing: const Icon(Icons.edit, color: Colors.white54, size: 20),
                      onTap: () => _selectDate(context),
                    ),
                  ),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF00D2FF).withValues(alpha: 0.4), width: 1.8),
                    ),
                    child: _selectedImage == null
                        ? Column(
                      children: [
                        const Icon(Icons.document_scanner_rounded, color: Color(0xFF00D2FF), size: 52),
                        const SizedBox(height: 14),
                        const Text('مسح البيان والمطابقة الذكية', style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(child: ElevatedButton.icon(onPressed: () => _pickImage(ImageSource.camera), icon: const Icon(Icons.camera_alt), label: const Text('الكاميرا', style: TextStyle(fontFamily: 'Cairo')))),
                            const SizedBox(width: 12),
                            Expanded(child: ElevatedButton.icon(onPressed: () => _pickImage(ImageSource.gallery), icon: const Icon(Icons.photo_library), label: const Text('الاستوديو', style: TextStyle(fontFamily: 'Cairo')))),
                          ],
                        ),
                      ],
                    )
                        : Stack(
                      alignment: Alignment.topRight,
                      children: [
                        ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.file(_selectedImage!, width: double.infinity, height: 220, fit: BoxFit.cover)),
                        CircleAvatar(backgroundColor: Colors.red, radius: 18, child: IconButton(icon: const Icon(Icons.delete, color: Colors.white, size: 18), onPressed: () => setState(() => _selectedImage = null))),
                      ],
                    ),
                  ),

                  if (_selectedImage != null && !_isDataExtracted) ...[
                    const SizedBox(height: 15),
                    ElevatedButton.icon(
                      onPressed: _isAnalyzing ? null : _analyzeImageWithAI,
                      icon: _isAnalyzing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.psychology, color: Color(0xFF103667)),
                      label: Text(_isAnalyzing ? 'جاري القراءة والمطابقة...' : 'تحليل البيان بالذكاء الاصطناعي 🧠', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF103667))),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00D2FF), minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ],

                  if (_isDataExtracted) ...[
                    const Divider(color: Colors.white24, height: 30),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _driverRecords.length,
                      itemBuilder: (context, index) {
                        final driverRec = _driverRecords[index];

                        bool isCubageHigh = (double.tryParse(driverRec.cubageCtrl.text) ?? 0) > 80;
                        bool isNewVehicle = !_allCarNumbers.contains(driverRec.carNumberCtrl.text) && driverRec.carNumberCtrl.text.isNotEmpty;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: const Color(0xFF00D2FF).withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  ChoiceChip(label: const Text('القديم', style: TextStyle(fontSize: 11, fontFamily: 'Cairo')), selected: driverRec.site == 'old', selectedColor: const Color(0xFF00D2FF), backgroundColor: Colors.black26, labelStyle: TextStyle(color: driverRec.site == 'old' ? const Color(0xFF103667) : Colors.white), onSelected: (val) => setState(() => driverRec.site = 'old'), visualDensity: VisualDensity.compact),
                                  const SizedBox(width: 6),
                                  ChoiceChip(label: const Text('الجديد', style: TextStyle(fontSize: 11, fontFamily: 'Cairo')), selected: driverRec.site == 'new', selectedColor: const Color(0xFF00D2FF), backgroundColor: Colors.black26, labelStyle: TextStyle(color: driverRec.site == 'new' ? const Color(0xFF103667) : Colors.white), onSelected: (val) => setState(() => driverRec.site = 'new'), visualDensity: VisualDensity.compact),
                                  const Spacer(),
                                  IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => setState(() => _driverRecords.removeAt(index))),
                                ],
                              ),
                              const Divider(color: Colors.white24),

                              Row(
                                children: [
                                  CircleAvatar(backgroundColor: const Color(0xFF00D2FF), radius: 14, child: Text('${index + 1}', style: const TextStyle(color: Color(0xFF103667), fontSize: 12, fontWeight: FontWeight.bold))),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: driverRec.driverCtrl,
                                      style: const TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14),
                                      decoration: const InputDecoration(labelText: 'اسم السائق', labelStyle: TextStyle(color: Colors.white54, fontSize: 11), isDense: true, border: InputBorder.none),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        TextField(
                                          controller: driverRec.carNumberCtrl,
                                          style: const TextStyle(color: Color(0xFF00D2FF), fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                                          decoration: InputDecoration(
                                            labelText: 'رقم العربية',
                                            labelStyle: const TextStyle(color: Colors.white54, fontSize: 11),
                                            filled: true,
                                            fillColor: Colors.black12,
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                            isDense: true,
                                            suffixIcon: IconButton(icon: const Icon(Icons.search, color: Color(0xFF00D2FF)), onPressed: () => _showVehicleSelectionSheet(context, driverRec)),
                                          ),
                                          onChanged: (v) => setState((){}),
                                        ),
                                        if (isNewVehicle)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: Text('🆕 سيتم إدراج معدة جديدة', style: TextStyle(color: Colors.orangeAccent.shade200, fontSize: 10, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                                          )
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 1,
                                    child: TextField(
                                      controller: driverRec.cubageCtrl,
                                      keyboardType: TextInputType.number,
                                      style: TextStyle(color: isCubageHigh ? Colors.redAccent : Colors.greenAccent, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                                      decoration: InputDecoration(
                                        labelText: 'التكعيب (م³)',
                                        labelStyle: const TextStyle(color: Colors.white54, fontSize: 11),
                                        filled: true,
                                        fillColor: isCubageHigh ? Colors.red.withValues(alpha: 0.1) : Colors.black12,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: isCubageHigh ? const BorderSide(color: Colors.redAccent) : BorderSide.none),
                                        isDense: true,
                                      ),
                                      onChanged: (v) => setState((){}),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              const Text('العملاء والنقلات:', style: TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),

                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: driverRec.destinations.length,
                                itemBuilder: (context, destIndex) {
                                  final dest = driverRec.destinations[destIndex];
                                  bool isNewClient = !_existingClientsFromDb.contains(dest.clientCtrl.text) && dest.clientCtrl.text.isNotEmpty;
                                  bool isTripsHigh = (int.tryParse(dest.tripsCtrl.text) ?? 0) > 10;

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Autocomplete<String>(
                                                optionsBuilder: (TextEditingValue v) => v.text.isEmpty ? _existingClientsFromDb : _existingClientsFromDb.where((opt) => opt.contains(v.text)),
                                                onSelected: (String sel) { dest.clientCtrl.text = sel; setState((){}); },
                                                fieldViewBuilder: (ctx, ctrl, node, onSub) {
                                                  if (ctrl.text.isEmpty && dest.clientCtrl.text.isNotEmpty) ctrl.text = dest.clientCtrl.text;
                                                  ctrl.addListener(() { dest.clientCtrl.text = ctrl.text; setState((){}); });
                                                  return TextField(controller: ctrl, focusNode: node, style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'Cairo'), decoration: InputDecoration(hintText: 'اسم العميل', filled: true, fillColor: Colors.white.withValues(alpha: 0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none), isDense: true));
                                                },
                                              ),
                                              if (isNewClient)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 2),
                                                  child: Text('🆕 سيتم إدراج عميل وفتح حساب له', style: TextStyle(color: Colors.orangeAccent.shade200, fontSize: 9, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                                                )
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          flex: 1,
                                          child: TextField(
                                            controller: dest.tripsCtrl,
                                            keyboardType: TextInputType.number,
                                            style: TextStyle(color: isTripsHigh ? Colors.redAccent : Colors.white, fontSize: 12, fontFamily: 'Cairo'),
                                            decoration: InputDecoration(
                                              hintText: 'نقلات',
                                              filled: true,
                                              fillColor: isTripsHigh ? Colors.red.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.05),
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: isTripsHigh ? const BorderSide(color: Colors.redAccent) : BorderSide.none),
                                              isDense: true,
                                            ),
                                            onChanged: (v) => setState((){}),
                                          ),
                                        ),
                                        IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 18), onPressed: () => setState(() => driverRec.destinations.removeAt(destIndex))),
                                      ],
                                    ),
                                  );
                                },
                              ),

                              TextButton.icon(
                                onPressed: () => setState(() => driverRec.destinations.add(DestinationRecord(client: '', trips: '1'))),
                                icon: const Icon(Icons.add, size: 16, color: Color(0xFF00D2FF)),
                                label: const Text('إضافة عميل لهذا السائق', style: TextStyle(color: Color(0xFF00D2FF), fontSize: 11, fontFamily: 'Cairo')),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: _submitAiEntry,
                      icon: const Icon(Icons.cloud_upload, color: Colors.white),
                      label: Text('اعتماد وترحيل بيانات ${_driverRecords.length} معدة', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF28A745), minimumSize: const Size(double.infinity, 52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                    const SizedBox(height: 20),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}