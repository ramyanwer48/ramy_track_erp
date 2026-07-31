import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'client_details_screen.dart';

class DailyEntryScreen extends StatefulWidget {
  const DailyEntryScreen({super.key});

  @override
  State<DailyEntryScreen> createState() => _DailyEntryScreenState();
}

class _DailyEntryScreenState extends State<DailyEntryScreen> {
  // 1. المتغيرات الأساسية
  String _selectedSite = 'old';
  DateTime _selectedDate = DateTime.now();
  final bool _isArabic = true;
  String? _currentDocId;

  // تحكم في فتح الكيبورد وحماية البيانات
  bool _vehicleSearchActive = false;
  bool _isReadOnly = false;
  int _vehicleKeyCounter = 0;

  final List<Map<String, dynamic>> _clientTrips = [];

  // ==========================================
  // قاعدة بيانات المركبات
  // ==========================================
  final List<Map<String, dynamic>> _vehiclesDB = [
    {'number': '6734', 'name': 'سيد ثروت', 'typeCode': 'Z', 'cubage': 19.0},
    {'number': '5361', 'name': 'محمود ثروت', 'typeCode': 'Z', 'cubage': 19.0},
    {'number': '7391', 'name': 'سيد حمدي', 'typeCode': 'Z', 'cubage': 20.0},
    {'number': '9728', 'name': 'مصطفى ثروت', 'typeCode': 'Z', 'cubage': 20.0},
    {'number': '7718', 'name': 'سيد فرداني', 'typeCode': 'Z', 'cubage': 14.0},
    {'number': '2461', 'name': 'صبحي السيد', 'typeCode': 'Z', 'cubage': 19.0},
    {'number': '4129', 'name': 'علي', 'typeCode': 'Z', 'cubage': 20.0},
    {'number': '2365', 'name': 'محمود جميل', 'typeCode': 'Z', 'cubage': 19.0},
    {'number': '6534', 'name': 'محمد صلاح', 'typeCode': 'Z', 'cubage': 18.5},
    {'number': '6547', 'name': 'محمد', 'typeCode': 'Z', 'cubage': 18.5},
    {'number': '6147', 'name': 'سعيد', 'typeCode': 'Z', 'cubage': 18.0},

    {'number': '239', 'name': 'محمد', 'typeCode': 'M', 'cubage': 12.0},
    {'number': '1918', 'name': 'أدهم السوري', 'typeCode': 'M', 'cubage': 20.0},
    {'number': '5482', 'name': 'تحسين وش', 'typeCode': 'M', 'cubage': 20.0},
    {'number': '6439', 'name': 'إسماعيل', 'typeCode': 'M', 'cubage': 20.0},
    {'number': '1543', 'name': 'أبو لويفي', 'typeCode': 'M', 'cubage': 20.0},

    {'number': '5482 - 1478', 'name': 'تحسين', 'typeCode': 'M', 'cubage': 53.0},
    {'number': '1853 - 222', 'name': 'أبو شريف', 'typeCode': 'M', 'cubage': 51.0},
    {'number': '5375 - 333', 'name': 'سعيد', 'typeCode': 'M', 'cubage': 56.0},
    {'number': '2919 - 111', 'name': 'محمد', 'typeCode': 'M', 'cubage': 54.0},
  ];

  // ==========================================
  // قاعدة بيانات العملاء (تستخدم للبحث)
  // ==========================================
  final List<String> _oldSiteClients = [
    'أحمد سعد', 'الأقصي', 'الرجاء (3)', 'العماد', 'شركة السلام', 'جنيدي',
    'شركة طلعت مصطفي', 'شركة مصر التشييد والبناء', 'شركة الغريب', 'محمود صابر',
    'معتمد', 'وطنية المدرسة', 'شركة الغريب (بون رسمي)', 'سامكريت (خط المواسير)',
    'الرجاء (1-2)', 'خلاطة مصر التشييد والبناء', 'خلاطة أبراج', 'خلاطة السلام'
  ];
  final List<String> _newSiteClients = ['بخيت', 'عادل'];

  // ==========================================
  // الذاكرة الاحتياطية للأسعار (لضمان عدم ظهور صفر بالخطأ)
  // ==========================================
  final Map<String, double> _oldGlobalsDefaults = {
    'سعر سائقين الشركة': 40.0,
    'اللودر': 15.0,
    'سعر م٣ خصم الجودة': 60.0,
  };
  final Map<String, double> _newGlobalsDefaults = {
    'سعر سائقين الشركة': 34.0,
    'اللودر': 15.0,
    'سعر م٣ خصم الجودة': 60.0,
    'نسبة الشيخ محمد ابو حسين في الجرارات': 22.0,
    'حساب المكتب عربيات (بعربيات الشركة)': 28.0,
    'حساب المكتب عربيات (بعربيات المكتب)': 64.0,
    'حساب المكتب في الجرارات': 53.0,
  };

  final Map<String, Map<String, double>> _oldClientsDefaults = {
    'أحمد سعد': {'سعر العميل': 115.0, 'سعر المكتب': 105.0},
    'الأقصي': {'سعر العميل': 125.0, 'سعر المكتب': 115.0},
    'الرجاء (3)': {'سعر العميل': 115.0, 'سعر المكتب': 105.0},
    'العماد': {'سعر العميل': 110.0, 'سعر المكتب': 100.0},
    'شركة السلام': {'سعر العميل': 120.0, 'سعر المكتب': 110.0},
    'جنيدي': {'سعر العميل': 125.0, 'سعر المكتب': 115.0},
    'شركة طلعت مصطفي': {'سعر العميل': 120.0, 'سعر المكتب': 110.0},
    'شركة مصر التشييد والبناء': {'سعر العميل': 120.0, 'سعر المكتب': 110.0},
    'شركة الغريب': {'سعر العميل': 126.0, 'سعر المكتب': 115.0},
    'محمود صابر': {'سعر العميل': 120.0, 'سعر المكتب': 110.0},
    'معتمد': {'سعر العميل': 115.0, 'سعر المكتب': 105.0},
    'وطنية المدرسة': {'سعر العميل': 125.0, 'سعر المكتب': 110.0},
    'شركة الغريب (بون رسمي)': {'سعر العميل': 140.0, 'سعر المكتب': 0.0},
    'سامكريت (خط المواسير)': {'سعر العميل': 100.0, 'سعر المكتب': 0.0},
    'الرجاء (1-2)': {'سعر العميل': 95.0, 'سعر المكتب': 0.0},
    'خلاطة مصر التشييد والبناء': {'سعر العميل': 100.0, 'سعر المكتب': 0.0},
    'خلاطة أبراج': {'سعر العميل': 100.0, 'سعر المكتب': 0.0},
    'خلاطة السلام': {'سعر العميل': 105.0, 'سعر المكتب': 0.0},
  };

  final Map<String, Map<String, double>> _newClientsDefaults = {
    'بخيت': {'عربيات': 70.0, 'جرارات': 100.0},
    'عادل': {'عربيات': 70.0, 'جرارات': 100.0},
  };

  // ==========================================
  // المتغيرات اللي سقطت سهواً وتسببت في الخطأ
  // ==========================================
  String? _selectedVehicleNumber;
  String _driverName = '---';
  String _driverType = '---';
  String _typeCode = '';
  double _cubage = 0.0;
  bool _isTractor = false;

  // ================= دالة الرسائل بعد التعديل (تظهر بالأسفل تماماً) =================
  void _showMessage(String message, Color color, {Duration duration = const Duration(milliseconds: 1500), bool isLong = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Cairo', color: Colors.white),
          textAlign: TextAlign.center,
        ),
        backgroundColor: color,
        duration: isLong ? const Duration(seconds: 4) : duration,
        behavior: SnackBarBehavior.fixed, // تجعلها لازقة في أسفل الشاشة تماماً
        elevation: 0,
      ),
    );
  }

  void _handleReadOnlyTap() {
    if (_isReadOnly) {
      _showMessage(_isArabic ? 'البيان محمي 🔒 اضغط (تعديل البيان)' : 'Locked. Click Edit.', Colors.orange.shade800, duration: const Duration(seconds: 1));
    }
  }

  // ================= دوال التاريخ وتحويل الأرقام والفلترة =================
  String _toArabicNumbers(String text) {
    if (!_isArabic) return text;
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    for (int i = 0; i < english.length; i++) {
      text = text.replaceAll(english[i], arabic[i]);
    }
    return text;
  }

  String _normalizeArabic(String? text) {
    if (text == null || text.isEmpty) return '';
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

  Widget _buildFormattedDate() {
    String day = _selectedDate.day.toString().padLeft(2, '0');
    String month = _selectedDate.month.toString().padLeft(2, '0');
    String year = _selectedDate.year.toString();

    if (_isArabic) {
      day = _toArabicNumbers(day);
      month = _toArabicNumbers(month);
      year = _toArabicNumbers(year);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: TextDirection.rtl,
      children: [
        Text(day, style: const TextStyle(fontFamily: 'Cairo', color: Color(0xFF0F2A52), fontSize: 15, fontWeight: FontWeight.bold)),
        const Text('/', style: TextStyle(fontFamily: 'Cairo', color: Color(0xFF0F2A52), fontSize: 15, fontWeight: FontWeight.bold)),
        Text(month, style: const TextStyle(fontFamily: 'Cairo', color: Color(0xFF0F2A52), fontSize: 15, fontWeight: FontWeight.bold)),
        const Text('/', style: TextStyle(fontFamily: 'Cairo', color: Color(0xFF0F2A52), fontSize: 15, fontWeight: FontWeight.bold)),
        Text(year, style: const TextStyle(fontFamily: 'Cairo', color: Color(0xFF0F2A52), fontSize: 15, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF0F2A52))),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  void _changeSite(String site) {
    if (_selectedSite == site && _currentDocId != null) {
      if (!_isReadOnly) {
        _showMessage(_isArabic ? '⚠️ يرجى حفظ التعديلات أولاً' : 'Please save changes first', Colors.red.shade700);
        return;
      }
      setState(() {
        _clientTrips.clear();
        _clearVehicle();
        _currentDocId = null;
        _isReadOnly = false;
      });
      return;
    }

    if (_selectedSite != site) {
      if (_currentDocId != null && !_isReadOnly) {
        _showMessage(_isArabic ? '⚠️ يرجى حفظ التعديلات أولاً' : 'Please save changes first', Colors.red.shade700);
        return;
      }
      setState(() {
        _selectedSite = site;
        _clientTrips.clear();
        _clearVehicle();
        _currentDocId = null;
        _isReadOnly = false;
      });
    }
  }

  void _onVehicleSelected(String? numberStr) {
    if (numberStr == null || numberStr.isEmpty) return;
    try {
      final vehicle = _vehiclesDB.firstWhere((v) => _toArabicNumbers(v['number']) == numberStr || v['number'] == numberStr);
      setState(() {
        _selectedVehicleNumber = _toArabicNumbers(vehicle['number']);
        _driverName = vehicle['name'];
        _cubage = vehicle['cubage'];
        _typeCode = vehicle['typeCode'];
        _isTractor = vehicle['number'].contains('-');

        if (_typeCode == 'Z') {
          _driverType = _isArabic ? 'سائق شركة (Z)' : 'Company (Z)';
        } else if (_typeCode == 'M') {
          _driverType = _isArabic ? 'سائق محجر (M)' : 'Quarry (M)';
        }
      });
    } catch (e) {
      // تجاهل
    }
  }

  void _clearVehicle() {
    setState(() {
      _selectedVehicleNumber = null;
      _driverName = '---';
      _driverType = '---';
      _typeCode = '';
      _cubage = 0.0;
      _isTractor = false;
      _vehicleSearchActive = false;
      _vehicleKeyCounter++;
    });
  }

  void _addClientTrip() {
    setState(() {
      _clientTrips.add({'client': null, 'trips': 1, 'searchActive': false});
    });
  }

  String _formatCubage(double val) {
    String result = val == 0.0 ? '0' : (val % 1 == 0 ? val.toInt().toString() : val.toString());
    return _toArabicNumbers(result);
  }

  // ================= سجل اليوم =================
  Future<void> _showDailyRecords() async {
    String queryDate = '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      backgroundColor: Colors.white,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.5,
          padding: const EdgeInsets.all(15.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isArabic ? 'سجل يوم (${_buildFormattedDateText()}) - الموقع ${_selectedSite == 'old' ? 'القديم' : 'الجديد'}'
                    : 'Records for $queryDate',
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F2A52)),
                textAlign: TextAlign.center,
              ),
              const Divider(),
              Expanded(
                child: FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance.collection('daily_entries')
                      .where('site', isEqualTo: _selectedSite)
                      .where('dateString', isEqualTo: queryDate)
                      .get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFF0F2A52)));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Text(_isArabic ? 'لا توجد بيانات مسجلة في هذا الموقع اليوم' : 'No records found for this site today.',
                            style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, color: Colors.grey)),
                      );
                    }

                    return ListView.builder(
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        var doc = snapshot.data!.docs[index];
                        var data = doc.data() as Map<String, dynamic>;
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          elevation: 2,
                          child: ListTile(
                            leading: Icon(data['isTractor'] == true ? Icons.local_shipping : Icons.airport_shuttle, color: const Color(0xFF4A78B9)),
                            title: Text('${_isArabic ? "مركبة:" : "Vehicle:"} ${data['vehicleNumber']}', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                            subtitle: Text('${data['driverName']} - ${data['clientsTrips']?.length ?? 0} عملاء', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                            onTap: () => _loadEntry(doc),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _buildFormattedDateText() {
    String day = _selectedDate.day.toString().padLeft(2, '0');
    String month = _selectedDate.month.toString().padLeft(2, '0');
    String year = _selectedDate.year.toString();
    return _isArabic ? '${_toArabicNumbers(day)}/${_toArabicNumbers(month)}/${_toArabicNumbers(year)}' : '$day/$month/$year';
  }

  void _loadEntry(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    setState(() {
      _currentDocId = doc.id;
      _selectedVehicleNumber = data['vehicleNumber'];
      _driverName = data['driverName'] ?? '---';
      _typeCode = data['typeCode'] ?? '';
      _cubage = (data['cubage'] ?? 0.0).toDouble();
      _isTractor = data['isTractor'] ?? false;

      _vehicleKeyCounter++;
      _isReadOnly = true;

      if (_typeCode == 'Z') {
        _driverType = _isArabic ? 'سائق شركة (Z)' : 'Company (Z)';
      } else if (_typeCode == 'M') {
        _driverType = _isArabic ? 'سائق محجر (M)' : 'Quarry (M)';
      } else {
        _driverType = '---';
      }

      _clientTrips.clear();
      List<dynamic> trips = data['clientsTrips'] ?? [];
      for (var t in trips) {
        _clientTrips.add({
          'client': t['clientName'] ?? t['client'],
          'trips': t['tripsCount'] ?? t['trips'],
          'searchActive': false,
        });
      }
    });
    Navigator.pop(context);
  }

  // ================= الحفظ والتعديل (الدمج الآلي وتجميد الأسعار) =================
  Future<void> _saveEntry() async {
    if (_selectedVehicleNumber == null) {
      _showMessage(_isArabic ? 'برجاء اختيار المركبة أولاً' : 'Select vehicle first', Colors.red.shade700);
      return;
    }
    if (_clientTrips.isEmpty) {
      _showMessage(_isArabic ? 'برجاء إضافة عميل واحد على الأقل' : 'Add at least one client', Colors.red.shade700);
      return;
    }
    if (_clientTrips.any((trip) => trip['client'] == null || trip['client'].toString().trim().isEmpty)) {
      _showMessage(_isArabic ? 'برجاء اختيار أسماء جميع العملاء في الجدول' : 'Select all client names', Colors.red.shade700);
      return;
    }

    try {
      String globalsDoc = _selectedSite == 'old' ? 'old_site_globals' : 'new_site_globals';
      String clientsDoc = _selectedSite == 'old' ? 'old_site_clients' : 'new_site_clients';

      var globalsSnap = await FirebaseFirestore.instance.collection('settings').doc(globalsDoc).get();
      var clientsSnap = await FirebaseFirestore.instance.collection('settings').doc(clientsDoc).get();

      Map<String, dynamic> globalsData = globalsSnap.exists && globalsSnap.data() != null ? globalsSnap.data()! : {};
      Map<String, dynamic> clientsData = clientsSnap.exists && clientsSnap.data() != null ? clientsSnap.data()! : {};

      bool hasZeroPrice = false;

      // دالة مساعدة لضمان إحضار الثابت سواء من الفايربيز أو الذاكرة الاحتياطية
      double getGlobalValue(String key, bool isOldSite) {
        if (globalsData.containsKey(key)) {
          return double.tryParse(globalsData[key].toString()) ?? 0.0;
        }
        return (isOldSite ? _oldGlobalsDefaults[key] : _newGlobalsDefaults[key]) ?? 0.0;
      }

      // تجميد الثوابت
      Map<String, dynamic> globalSnapshots = {
        'companyDriverPrice': getGlobalValue('سعر سائقين الشركة', _selectedSite == 'old'),
        'loaderPrice': getGlobalValue('اللودر', _selectedSite == 'old'),
        'qualityDiscount': getGlobalValue('سعر م٣ خصم الجودة', _selectedSite == 'old'),
      };

      if (_selectedSite == 'new') {
        globalSnapshots['sheikhMohamedTractors'] = getGlobalValue('نسبة الشيخ محمد ابو حسين في الجرارات', false);
        globalSnapshots['officeTrucksCompany'] = getGlobalValue('حساب المكتب عربيات (بعربيات الشركة)', false);
        globalSnapshots['officeTrucksOffice'] = getGlobalValue('حساب المكتب عربيات (بعربيات المكتب)', false);
        globalSnapshots['officeTractors'] = getGlobalValue('حساب المكتب في الجرارات', false);
      }

      // تجميد أسعار العملاء
      List<String> clientNamesList = [];
      List<Map<String, dynamic>> finalTrips = [];

      for (var t in _clientTrips) {
        String rawName = t['client'].toString().trim();
        String safeKey = _normalizeArabic(rawName);

        clientNamesList.add(rawName);

        double clientPrice = 0.0;
        double officePrice = 0.0;

        // 1. البحث في الفايربيز
        String? matchedDbKey;
        if (clientsData.isNotEmpty) {
          if (clientsData.containsKey(safeKey)) {
            matchedDbKey = safeKey;
          } else {
            try {
              matchedDbKey = clientsData.keys.firstWhere((k) => _normalizeArabic(k) == safeKey);
            } catch (e) {
              matchedDbKey = null;
            }
          }
        }

        if (matchedDbKey != null) {
          var cData = clientsData[matchedDbKey] as Map<String, dynamic>;
          if (_selectedSite == 'old') {
            clientPrice = double.tryParse(cData['سعر العميل']?.toString() ?? '0') ?? 0.0;
            officePrice = double.tryParse(cData['سعر المكتب']?.toString() ?? '0') ?? 0.0;
          } else {
            clientPrice = _isTractor
                ? (double.tryParse(cData['جرارات']?.toString() ?? '0') ?? 0.0)
                : (double.tryParse(cData['عربيات']?.toString() ?? '0') ?? 0.0);
          }
        } else {
          // 2. الفايربيز فاضي (أو العميل مش فيه) -> نستدعي الذاكرة الاحتياطية فوراً
          Map<String, Map<String, double>> defaultsMap = _selectedSite == 'old' ? _oldClientsDefaults : _newClientsDefaults;
          String? matchedDefKey;
          try {
            matchedDefKey = defaultsMap.keys.firstWhere((k) => _normalizeArabic(k) == safeKey);
          } catch (e) {
            matchedDefKey = null;
          }

          if (matchedDefKey != null) {
            var cData = defaultsMap[matchedDefKey]!;
            if (_selectedSite == 'old') {
              clientPrice = cData['سعر العميل'] ?? 0.0;
              officePrice = cData['سعر المكتب'] ?? 0.0;
            } else {
              clientPrice = _isTractor ? (cData['جرارات'] ?? 0.0) : (cData['عربيات'] ?? 0.0);
            }
          }
        }

        // لو بعد الفايربيز وبعد الذاكرة الاحتياطية السعر فضل صفر فعلياً
        if (clientPrice == 0.0) {
          hasZeroPrice = true;
        }

        finalTrips.add({
          'client': rawName,
          'clientName': rawName,
          'trips': t['trips'],
          'tripsCount': t['trips'],
          'totalCubage': t['trips'] * _cubage,
          'cubage': t['trips'] * _cubage,
          'clientPriceSnapshot': clientPrice,
          'officePriceSnapshot': officePrice,
        });
      }

      String dateStringFormatted = '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}';
      bool isUpdate = _currentDocId != null;

      // ================= التجميع الآلي (Auto-Merge) لمنع التكرار =================
      if (!isUpdate) {
        // البحث عن وثيقة لنفس المركبة في نفس الموقع في نفس اليوم
        var existingDocs = await FirebaseFirestore.instance.collection('daily_entries')
            .where('site', isEqualTo: _selectedSite)
            .where('dateString', isEqualTo: dateStringFormatted)
            .where('vehicleNumber', isEqualTo: _selectedVehicleNumber)
            .get();

        if (existingDocs.docs.isNotEmpty) {
          // دمج النقلات الجديدة مع القديمة في نفس الوثيقة
          isUpdate = true;
          _currentDocId = existingDocs.docs.first.id;
          var existingData = existingDocs.docs.first.data();
          List<dynamic> existingTrips = existingData['clientsTrips'] ?? [];

          for (var newT in finalTrips) {
            String safeNewClient = _normalizeArabic(newT['clientName']);
            int matchIndex = existingTrips.indexWhere((t) => _normalizeArabic(t['clientName']) == safeNewClient);

            if (matchIndex >= 0) {
              // العميل موجود: اجمع العدد والتكعيب
              existingTrips[matchIndex]['trips'] = (existingTrips[matchIndex]['trips'] ?? 0) + newT['trips'];
              existingTrips[matchIndex]['tripsCount'] = (existingTrips[matchIndex]['tripsCount'] ?? 0) + newT['tripsCount'];
              existingTrips[matchIndex]['totalCubage'] = (existingTrips[matchIndex]['totalCubage'] ?? 0.0) + newT['totalCubage'];
              existingTrips[matchIndex]['cubage'] = (existingTrips[matchIndex]['cubage'] ?? 0.0) + newT['cubage'];
              // تحديث السعر لو اختلف
              existingTrips[matchIndex]['clientPriceSnapshot'] = newT['clientPriceSnapshot'];
            } else {
              // العميل جديد على الوثيقة دي
              existingTrips.add(newT);
            }
          }
          finalTrips = List<Map<String, dynamic>>.from(existingTrips);
          clientNamesList = finalTrips.map((t) => t['clientName'].toString()).toList();
        }
      }

      // الحفظ النهائي في الفايربيز
      final entryData = {
        'date': Timestamp.fromDate(_selectedDate),
        'dateString': dateStringFormatted,
        'site': _selectedSite,
        'vehicleNumber': _selectedVehicleNumber,
        'driverName': _driverName,
        'typeCode': _typeCode,
        'cubage': _cubage,
        'isTractor': _isTractor,
        'clientNamesList': clientNamesList,
        'clientsTrips': finalTrips,
        'snapshotGlobals': globalSnapshots,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (!isUpdate) {
        entryData['createdAt'] = FieldValue.serverTimestamp();
        DocumentReference docRef = FirebaseFirestore.instance.collection('daily_entries').doc();
        _currentDocId = docRef.id;
        await docRef.set(entryData);
      } else {
        await FirebaseFirestore.instance.collection('daily_entries').doc(_currentDocId).update(entryData);
      }

      setState(() {
        _isReadOnly = true;
      });

      // الرسائل بناءً على الشرط المطلوب حصراً (بالأسفل تماماً)
      if (hasZeroPrice) {
        _showMessage(
            'تم حفظ البيان بنجاح (تنبيه: يوجد عميل مسجل بسعر صفر)',
            Colors.orange.shade800,
            isLong: true
        );
      } else {
        _showMessage('تم حفظ البيان بنجاح', const Color(0xFF28A745));
      }

    } catch (e) {
      _showMessage('Error: $e', Colors.red.shade700);
    }
  }

  // ================= الحذف =================
  Future<void> _deleteEntry() async {
    if (_currentDocId == null) return;
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_isArabic ? 'تأكيد الحذف' : 'Confirm Delete', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontFamily: 'Cairo')),
        content: Text(_isArabic ? 'هل أنت متأكد من حذف هذا البيان بالكامل؟' : 'Are you sure you want to delete this entry?', style: const TextStyle(fontFamily: 'Cairo')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(_isArabic ? 'إلغاء' : 'Cancel', style: const TextStyle(fontFamily: 'Cairo'))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(_isArabic ? 'حذف' : 'Delete', style: const TextStyle(color: Colors.red, fontFamily: 'Cairo'))),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    try {
      await FirebaseFirestore.instance.collection('daily_entries').doc(_currentDocId).delete();

      setState(() {
        _currentDocId = null;
        _clearVehicle();
        _clientTrips.clear();
        _isReadOnly = false;
      });

      _showMessage(_isArabic ? 'تم حذف البيان بنجاح' : 'Entry Deleted Successfully.', Colors.red.shade700);

    } catch (e) {
      _showMessage('Error: $e', Colors.red.shade700);
    }
  }

  Widget _buildAutocompleteOptions(BuildContext context, AutocompleteOnSelected<String> onSelected, Iterable<String> options) {
    return Align(
      alignment: Alignment.topRight,
      child: Material(
        elevation: 6.0,
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: 220, maxWidth: MediaQuery.of(context).size.width * 0.75),
          child: ListView.separated(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemCount: options.length,
            separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade200),
            itemBuilder: (BuildContext context, int index) {
              final String option = options.elementAt(index);
              return InkWell(
                onTap: () => onSelected(option),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                  child: Text(option, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F2A52))),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final availableClients = _selectedSite == 'old' ? _oldSiteClients : _newSiteClients;
    final textDirection = _isArabic ? TextDirection.rtl : TextDirection.ltr;

    Widget vehicleIconWidget = const Icon(Icons.airport_shuttle, size: 18, color: Color(0xFF28A745));
    String vehicleFieldLabel = _isArabic ? 'رقم المركبة' : 'Vehicle No.';

    if (_selectedVehicleNumber != null) {
      vehicleIconWidget = _isTractor
          ? const Icon(Icons.local_shipping, size: 18, color: Color(0xFFE67E22))
          : const Icon(Icons.airport_shuttle, size: 18, color: Color(0xFF28A745));

      vehicleFieldLabel += _isTractor
          ? (_isArabic ? ' - جرار' : ' - Tractor')
          : (_isArabic ? ' - عربية' : ' - Truck');
    }

    return Directionality(
      textDirection: textDirection,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F9),
        appBar: AppBar(
          elevation: 0,
          centerTitle: true,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F2A52), Color(0xFF1E4885)],
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
              ),
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.account_balance_wallet, color: Colors.white),
              tooltip: 'حساب العميل',
              onPressed: () {
                if (_clientTrips.isNotEmpty && _clientTrips[0]['client'] != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ClientDetailsScreen(
                        clientName: _clientTrips[0]['client'],
                        openingBalance: 0.0,
                      ),
                    ),
                  );
                } else {
                  _showMessage(_isArabic ? 'اختر عميل أولاً لعرض حسابه' : 'Select a client first', Colors.orange);
                }
              },
            ),
          ],
          title: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                  _isArabic ? 'البيان اليومي' : 'Daily Entry',
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, fontFamily: 'Cairo')
              ),
            ],
          ),
        ),

        // ================= الزراير في الأرضية =================
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: ElevatedButton.icon(
                          onPressed: _currentDocId != null
                              ? () {
                            if (!_isReadOnly) {
                              _showMessage(_isArabic ? '⚠️ يرجى حفظ التعديلات أولاً' : 'Save changes first', Colors.red.shade700);
                              return;
                            }
                            setState(() {
                              _clientTrips.clear();
                              _clearVehicle();
                              _currentDocId = null;
                              _isReadOnly = false;
                            });
                          }
                              : null,
                          icon: const Icon(Icons.refresh, color: Colors.white, size: 14),
                          label: FittedBox(child: Text(_isArabic ? 'بيان جديد' : 'New', style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _currentDocId != null ? Colors.blue.shade700 : Colors.grey,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: ElevatedButton.icon(
                          onPressed: (_currentDocId != null && _isReadOnly)
                              ? () {
                            setState(() => _isReadOnly = false);
                          }
                              : null,
                          icon: const Icon(Icons.edit, color: Colors.white, size: 14),
                          label: FittedBox(child: Text(_isArabic ? 'تعديل البيان' : 'Edit', style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: (_currentDocId != null && _isReadOnly) ? const Color(0xFFFFA000) : Colors.grey,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: ElevatedButton.icon(
                          onPressed: _currentDocId != null ? _deleteEntry : null,
                          icon: const Icon(Icons.delete_forever, color: Colors.white, size: 14),
                          label: FittedBox(child: Text(_isArabic ? 'حذف البيان' : 'Delete', style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _currentDocId != null ? Colors.red.shade700 : Colors.grey,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    gradient: _isReadOnly ? null : const LinearGradient(colors: [Color(0xFF0F2A52), Color(0xFF1E4885)]),
                    color: _isReadOnly ? Colors.grey : null,
                    boxShadow: _isReadOnly ? null : const [BoxShadow(color: Color(0x4D0F2A52), blurRadius: 4, offset: Offset(0, 2))],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _isReadOnly ? () => _handleReadOnlyTap() : _saveEntry,
                    icon: const Icon(Icons.save, color: Colors.white, size: 18),
                    label: Text(
                        _isArabic
                            ? (_currentDocId != null ? 'حفظ التعديلات' : 'حفظ البيان')
                            : 'Save Entry',
                        style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ================= محتوى الشاشة =================
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. الموقع والتاريخ
                  Card(
                    color: const Color(0xE6FFFFFF),
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Text(_isArabic ? 'اختر الموقع' : 'Select Site', style: const TextStyle(color: Color(0xFF0F2A52), fontSize: 16, fontWeight: FontWeight.w900, fontFamily: 'Cairo')),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    if (_isReadOnly) { _handleReadOnlyTap(); return; }
                                    _changeSite('old');
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _selectedSite == 'old' ? const Color(0xFF4A78B9) : Colors.white,
                                    foregroundColor: _selectedSite == 'old' ? Colors.white : const Color(0xFF4A78B9),
                                    elevation: _selectedSite == 'old' ? 1 : 0,
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    side: BorderSide(color: const Color(0xFF4A78B9), width: _selectedSite == 'old' ? 0 : 1),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                  child: FittedBox(child: Text(_isArabic ? 'الموقع القديم' : 'Old Site', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold))),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    if (_isReadOnly) { _handleReadOnlyTap(); return; }
                                    _changeSite('new');
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _selectedSite == 'new' ? const Color(0xFF28A745) : Colors.white,
                                    foregroundColor: _selectedSite == 'new' ? Colors.white : const Color(0xFF28A745),
                                    elevation: _selectedSite == 'new' ? 1 : 0,
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    side: BorderSide(color: const Color(0xFF28A745), width: _selectedSite == 'new' ? 0 : 1),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                  child: FittedBox(child: Text(_isArabic ? 'الموقع الجديد' : 'New Site', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold))),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: InkWell(
                                  onTap: () {
                                    if (_isReadOnly) { _handleReadOnlyTap(); return; }
                                    _selectDate(context);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(color: const Color(0xCCF2F6FA), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey.shade200)),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.calendar_month, color: Color(0xFF4A78B9), size: 16),
                                            const SizedBox(width: 6),
                                            Text(_isArabic ? 'التاريخ:' : 'Date:', style: const TextStyle(fontFamily: 'Cairo', color: Color(0xFF4A78B9), fontSize: 13, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                        _buildFormattedDate(),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    if (_isReadOnly) { _handleReadOnlyTap(); return; }
                                    _showDailyRecords();
                                  },
                                  icon: const Icon(Icons.history, size: 14, color: Colors.white),
                                  label: Text(_isArabic ? 'سجل اليوم' : 'History', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1E4885),
                                    padding: const EdgeInsets.symmetric(vertical: 7),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // 2. بيانات المركبة والسائق
                  Card(
                    color: const Color(0xE6FFFFFF),
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: _buildCompactInput(
                                  label: vehicleFieldLabel,
                                  iconWidget: vehicleIconWidget,
                                  child: Container(
                                    height: 38,
                                    decoration: _boxDecoration(),
                                    child: Autocomplete<String>(
                                      key: ValueKey('vehicle_${_selectedSite}_$_vehicleKeyCounter'),
                                      initialValue: TextEditingValue(text: _selectedVehicleNumber ?? ''),
                                      optionsViewBuilder: _buildAutocompleteOptions,
                                      optionsBuilder: (TextEditingValue textEditingValue) {
                                        if (_isReadOnly) return const Iterable<String>.empty();
                                        final options = _vehiclesDB.map((v) => _toArabicNumbers(v['number'] as String)).toList();
                                        if (textEditingValue.text.isEmpty) return options;
                                        String searchText = _toArabicNumbers(textEditingValue.text);
                                        return options.where((opt) => opt.contains(searchText));
                                      },
                                      onSelected: (String selection) {
                                        FocusScope.of(context).unfocus();
                                        setState(() => _vehicleSearchActive = false);
                                        _onVehicleSelected(selection);
                                      },
                                      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                        return TextField(
                                          controller: controller,
                                          focusNode: focusNode,
                                          readOnly: _isReadOnly || !_vehicleSearchActive,
                                          maxLines: 1,
                                          textAlignVertical: TextAlignVertical.center,
                                          onTap: () {
                                            if (_isReadOnly) { _handleReadOnlyTap(); return; }
                                            if (!focusNode.hasFocus) focusNode.requestFocus();
                                          },
                                          decoration: InputDecoration(
                                            isDense: true,
                                            hintText: _isArabic ? 'بحث...' : 'Search...',
                                            hintStyle: const TextStyle(fontSize: 11, fontFamily: 'Cairo', color: Colors.grey),
                                            border: InputBorder.none,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                            suffixIconConstraints: const BoxConstraints(maxHeight: 38),
                                            suffixIcon: _isReadOnly ? const SizedBox.shrink() : ValueListenableBuilder<TextEditingValue>(
                                              valueListenable: controller,
                                              builder: (context, value, child) {
                                                return Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  mainAxisAlignment: MainAxisAlignment.end,
                                                  children: [
                                                    if (value.text.isNotEmpty)
                                                      InkWell(
                                                        onTap: () {
                                                          _clearVehicle();
                                                        },
                                                        child: const Padding(
                                                          padding: EdgeInsets.symmetric(horizontal: 4.0),
                                                          child: Icon(Icons.close, size: 16, color: Colors.red),
                                                        ),
                                                      ),
                                                    InkWell(
                                                      onTap: () {
                                                        setState(() => _vehicleSearchActive = true);
                                                        focusNode.requestFocus();
                                                      },
                                                      child: const Padding(
                                                        padding: EdgeInsets.symmetric(horizontal: 4.0),
                                                        child: Icon(Icons.search, size: 16, color: Colors.grey),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                  ],
                                                );
                                              },
                                            ),
                                          ),
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Cairo'),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: _buildCompactInput(
                                  label: _isArabic ? 'التكعيب (م³)' : 'Cubage (m³)',
                                  iconWidget: const Icon(Icons.view_in_ar_outlined, size: 13, color: Color(0xFF4A78B9)),
                                  child: Container(
                                    height: 38,
                                    width: double.infinity,
                                    decoration: BoxDecoration(color: const Color(0x80FFFFFF), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey.shade200)),
                                    child: Center(child: Text(_formatCubage(_cubage), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black, fontFamily: 'Cairo'))),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: _buildCompactInput(
                                  label: _isArabic ? 'اسم السائق' : 'Driver Name',
                                  iconWidget: const Icon(Icons.person_outline, size: 13, color: Color(0xFF4A78B9)),
                                  child: Container(
                                    height: 38,
                                    width: double.infinity,
                                    decoration: BoxDecoration(color: const Color(0x80FFFFFF), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey.shade200)),
                                    child: Center(child: FittedBox(child: Text(_driverName, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12, color: _selectedVehicleNumber == null ? Colors.grey : Colors.black)))),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: _buildCompactInput(
                                  label: _isArabic ? 'التبعية' : 'Type',
                                  iconWidget: const Icon(Icons.badge_outlined, size: 13, color: Color(0xFF4A78B9)),
                                  child: Container(
                                    height: 38,
                                    width: double.infinity,
                                    decoration: BoxDecoration(color: const Color(0x80FFFFFF), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey.shade200)),
                                    child: Center(child: FittedBox(child: Text(_driverType, style: TextStyle(fontFamily: 'Cairo', color: _typeCode == 'Z' ? const Color(0xFF28A745) : const Color(0xFFE67E22), fontWeight: FontWeight.bold, fontSize: 12)))),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // 3. تفاصيل العملاء
                  Card(
                    color: const Color(0xE6FFFFFF),
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_isArabic ? 'تفاصيل النقلات للعملاء' : 'Clients Trips Details', style: const TextStyle(fontFamily: 'Cairo', color: Color(0xFF0F2A52), fontSize: 13, fontWeight: FontWeight.bold)),
                              OutlinedButton.icon(
                                onPressed: (_selectedVehicleNumber == null) ? null : () {
                                  if (_isReadOnly) { _handleReadOnlyTap(); return; }
                                  _addClientTrip();
                                },
                                icon: const Icon(Icons.add, color: Color(0xFF28A745), size: 14),
                                label: Text(_isArabic ? 'إضافة عميل' : 'Add Client', style: const TextStyle(fontFamily: 'Cairo', color: Color(0xFF28A745), fontSize: 11, fontWeight: FontWeight.bold)),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: _selectedVehicleNumber == null ? Colors.grey : const Color(0xFF28A745)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                  minimumSize: const Size(0, 28),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),

                          _clientTrips.isEmpty
                              ? Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            decoration: BoxDecoration(color: const Color(0x80FFFFFF), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey.shade200)),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.assignment_add, size: 30, color: Color(0xFFBDBDBD)),
                                const SizedBox(height: 4),
                                Text(_isArabic ? 'لا توجد نقلات مسجلة حتى الآن' : 'No trips recorded yet', style: const TextStyle(fontFamily: 'Cairo', color: Color(0xFF757575), fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          )
                              : Container(
                            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(6)),
                            child: Column(
                              children: [
                                Container(
                                  color: const Color(0xFF0F2A52),
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: Row(
                                    children: [
                                      Expanded(flex: 12, child: Center(child: Text(_isArabic ? 'اسم العميل' : 'Client', style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 11)))),
                                      Expanded(flex: 4, child: Center(child: Text(_isArabic ? 'النقلات' : 'Trips', style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 11)))),
                                      Expanded(flex: 3, child: Center(child: Text(_isArabic ? 'الكمية' : 'Qty', style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 11)))),
                                      const Expanded(flex: 2, child: Center(child: Icon(Icons.delete, color: Colors.white, size: 14))),
                                    ],
                                  ),
                                ),
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _clientTrips.length,
                                  separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.grey),
                                  itemBuilder: (context, index) {
                                    int currentTrips = _clientTrips[index]['trips'];
                                    double currentCubage = currentTrips * _cubage;

                                    return Container(
                                      color: const Color(0xCCFFFFFF),
                                      padding: const EdgeInsets.symmetric(vertical: 3),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 12,
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                              child: Container(
                                                height: 38,
                                                decoration: _boxDecoration(),
                                                child: Autocomplete<String>(
                                                  initialValue: TextEditingValue(text: _clientTrips[index]['client'] ?? ''),
                                                  optionsViewBuilder: _buildAutocompleteOptions,
                                                  optionsBuilder: (TextEditingValue textEditingValue) {
                                                    if (_isReadOnly) return const Iterable<String>.empty();
                                                    if (textEditingValue.text.isEmpty) return availableClients;
                                                    return availableClients.where((opt) => opt.contains(textEditingValue.text));
                                                  },
                                                  onSelected: (String selection) {
                                                    FocusScope.of(context).unfocus();
                                                    setState(() => _clientTrips[index]['searchActive'] = false);
                                                    bool exists = _clientTrips.any((trip) => trip['client'] == selection && _clientTrips.indexOf(trip) != index);
                                                    if (exists) {
                                                      _showMessage(_isArabic ? 'العميل مضاف بالفعل!' : 'Client already added!', Colors.red.shade700);
                                                    } else {
                                                      setState(() => _clientTrips[index]['client'] = selection);
                                                    }
                                                  },
                                                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                                    return TextField(
                                                      controller: controller,
                                                      focusNode: focusNode,
                                                      readOnly: _isReadOnly || !(_clientTrips[index]['searchActive'] ?? false),
                                                      maxLines: 1,
                                                      textAlignVertical: TextAlignVertical.center,
                                                      onTap: () {
                                                        if (_isReadOnly) { _handleReadOnlyTap(); return; }
                                                        if (!focusNode.hasFocus) focusNode.requestFocus();
                                                      },
                                                      decoration: InputDecoration(
                                                        isDense: true,
                                                        hintText: _isArabic ? 'بحث...' : 'Search...',
                                                        hintStyle: const TextStyle(fontSize: 11, fontFamily: 'Cairo', color: Colors.grey),
                                                        border: InputBorder.none,
                                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                                        suffixIconConstraints: const BoxConstraints(maxHeight: 38),
                                                        suffixIcon: _isReadOnly ? const SizedBox.shrink() : ValueListenableBuilder<TextEditingValue>(
                                                            valueListenable: controller,
                                                            builder: (context, value, child) {
                                                              return Row(
                                                                mainAxisSize: MainAxisSize.min,
                                                                mainAxisAlignment: MainAxisAlignment.end,
                                                                children: [
                                                                  if (value.text.isNotEmpty)
                                                                    InkWell(
                                                                      onTap: () {
                                                                        controller.clear();
                                                                        setState(() {
                                                                          _clientTrips[index]['searchActive'] = false;
                                                                          _clientTrips[index]['client'] = null;
                                                                        });
                                                                        if (!focusNode.hasFocus) focusNode.requestFocus();
                                                                      },
                                                                      child: const Padding(
                                                                        padding: EdgeInsets.symmetric(horizontal: 4.0),
                                                                        child: Icon(Icons.close, size: 16, color: Colors.red),
                                                                      ),
                                                                    ),
                                                                  InkWell(
                                                                    onTap: () {
                                                                      setState(() => _clientTrips[index]['searchActive'] = true);
                                                                      focusNode.requestFocus();
                                                                    },
                                                                    child: const Padding(
                                                                      padding: EdgeInsets.symmetric(horizontal: 4.0),
                                                                      child: Icon(Icons.search, size: 16, color: Colors.grey),
                                                                    ),
                                                                  ),
                                                                  const SizedBox(width: 4),
                                                                ],
                                                              );
                                                            }
                                                        ),
                                                      ),
                                                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 4,
                                            child: Opacity(
                                              opacity: _isReadOnly ? 0.5 : 1.0,
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  InkWell(
                                                    onTap: () {
                                                      if (_isReadOnly) { _handleReadOnlyTap(); return; }
                                                      setState(() => _clientTrips[index]['trips']++);
                                                    },
                                                    child: Container(padding: const EdgeInsets.all(2), decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)), child: const Icon(Icons.add, size: 13)),
                                                  ),
                                                  Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                                    child: Text(_toArabicNumbers(currentTrips.toString()), style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12)),
                                                  ),
                                                  InkWell(
                                                    onTap: () {
                                                      if (_isReadOnly) { _handleReadOnlyTap(); return; }
                                                      setState(() {
                                                        if (currentTrips > 1) _clientTrips[index]['trips']--;
                                                      });
                                                    },
                                                    child: Container(padding: const EdgeInsets.all(2), decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)), child: const Icon(Icons.remove, size: 13)),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                              flex: 3,
                                              child: Center(
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Text(_formatCubage(currentCubage), style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Color(0xFF0F2A52), fontSize: 11)),
                                                    Text('(${_formatCubage(_cubage)}×${_toArabicNumbers(currentTrips.toString())})', style: const TextStyle(fontFamily: 'Cairo', fontSize: 8, color: Colors.grey)),
                                                  ],
                                                ),
                                              )
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Opacity(
                                              opacity: _isReadOnly ? 0.3 : 1.0,
                                              child: IconButton(
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 16),
                                                onPressed: () {
                                                  if (_isReadOnly) { _handleReadOnlyTap(); return; }
                                                  setState(() => _clientTrips.removeAt(index));
                                                },
                                              ),
                                            ),
                                          ),
                                        ],
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
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactInput({required String label, required Widget iconWidget, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            iconWidget,
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4A78B9))),
          ],
        ),
        const SizedBox(height: 2),
        child,
      ],
    );
  }

  BoxDecoration _boxDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: Colors.grey.shade300),
    );
  }
}