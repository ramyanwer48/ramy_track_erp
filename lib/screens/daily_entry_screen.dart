import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'custom_bottom_nav.dart';

class DailyEntryScreen extends StatefulWidget {
  const DailyEntryScreen({super.key});

  static Future<bool> checkUnsavedChanges(BuildContext context) async {
    FocusManager.instance.primaryFocus?.unfocus();

    final state = context.findAncestorStateOfType<_DailyEntryScreenState>();
    if (state != null && !state._isReadOnly && (state._selectedVehicleNumber != null || state._clientTrips.isNotEmpty)) {
      bool? result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: const Text('تنبيه: بيان غير محفوظ!', style: TextStyle(color: Colors.red, fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
            content: const Text('لديك بيانات لم يتم حفظها. هل تريد حفظ البيان الحالي أولاً؟', style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء والعودة', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey))),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تجاهل ومتابعة', style: TextStyle(fontFamily: 'Cairo', color: Colors.red))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF28A745)),
                onPressed: () async {
                  Navigator.pop(ctx, false);
                  await state._saveEntry();
                },
                child: const Text('حفظ ومتابعة', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
              ),
            ],
          ),
        ),
      );
      return result ?? false;
    }
    return true;
  }

  @override
  State<DailyEntryScreen> createState() => _DailyEntryScreenState();
}

class _DailyEntryScreenState extends State<DailyEntryScreen> {
  String _selectedSite = 'old';
  DateTime _selectedDate = DateTime.now();
  final bool _isArabic = true;
  String? _currentDocId;
  final bool _forceHideDropdowns = false;
  bool _vehicleSearchActive = false;
  bool _isReadOnly = false;
  int _vehicleKeyCounter = 0;

  final List<Map<String, dynamic>> _clientTrips = [];

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

  List<Map<String, dynamic>> _liveVehiclesDB = [];
  StreamSubscription<QuerySnapshot>? _vehiclesSub;

  final List<String> _oldSiteClients = [
    'أحمد سعد', 'الأقصي', 'الرجاء (3)', 'العماد', 'شركة السلام', 'جنيدي',
    'شركة طلعت مصطفي', 'شركة مصر التشييد والبناء', 'شركة الغريب', 'محمود صابر',
    'معتمد', 'وطنية المدرسة', 'شركة الغريب (بون رسمي)', 'سامكريت (خط المواسير)',
    'الرجاء (1-2)', 'خلاطة مصر التشييد والبناء', 'خلاطة أبراج', 'خلاطة السلام'
  ];
  final List<String> _newSiteClients = ['بخيت', 'عادل'];

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

  String? _selectedVehicleNumber;
  String _driverName = '---';
  String _driverType = '---';
  String _typeCode = '';
  double _cubage = 0.0;
  bool _isTractor = false;

  @override
  void initState() {
    super.initState();
    _listenToVehicles();
    if (_vehiclesDB.isEmpty) {}
  }

  @override
  void dispose() {
    _vehiclesSub?.cancel();
    super.dispose();
  }

  void _listenToVehicles() {
    _vehiclesSub = FirebaseFirestore.instance.collection('vehicles').snapshots().listen((snapshot) {
      if (mounted) {
        setState(() {
          _liveVehiclesDB = snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
        });
      }
    });
  }

  void _showMessage(String message, Color color, {Duration duration = const Duration(milliseconds: 1500), bool isLong = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Cairo', color: Colors.white),
          textAlign: TextAlign.center,
        ),
        backgroundColor: color,
        duration: isLong ? const Duration(seconds: 4) : duration,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(),
        elevation: 0,
      ),
    );
  }

  void _handleReadOnlyTap() {
    if (_isReadOnly) {
      _showMessage(_isArabic ? 'البيان محمي 🔒 اضغط (تعديل البيان)' : 'Locked. Click Edit.', Colors.orange.shade800, duration: const Duration(seconds: 1));
    }
  }

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
        Text(day, style: const TextStyle(fontFamily: 'Cairo', color: Color(0xFF0F2A52), fontSize: 13, fontWeight: FontWeight.bold)),
        const Text('/', style: TextStyle(fontFamily: 'Cairo', color: Color(0xFF0F2A52), fontSize: 13, fontWeight: FontWeight.bold)),
        Text(month, style: const TextStyle(fontFamily: 'Cairo', color: Color(0xFF0F2A52), fontSize: 13, fontWeight: FontWeight.bold)),
        const Text('/', style: TextStyle(fontFamily: 'Cairo', color: Color(0xFF0F2A52), fontSize: 13, fontWeight: FontWeight.bold)),
        Text(year, style: const TextStyle(fontFamily: 'Cairo', color: Color(0xFF0F2A52), fontSize: 13, fontWeight: FontWeight.bold)),
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

  Future<void> _changeSite(String site) async {
    if (_selectedSite == site) return;
    bool hasUnsavedData = !_isReadOnly && (_selectedVehicleNumber != null || _clientTrips.isNotEmpty);

    if (hasUnsavedData) {
      bool? shouldSave = await showDialog<bool>(
        context: context,
        builder: (ctx) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: const Text('تنبيه: بيان غير محفوظ!', style: TextStyle(color: Colors.red, fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
            content: const Text('لديك بيانات لم يتم حفظها. هل تريد حفظ البيان قبل الانتقال للموقع الآخر؟', style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('تجاهل وانتقال', style: TextStyle(color: Colors.red, fontFamily: 'Cairo'))),
              ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF28A745)),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('حفظ وانتقال', style: TextStyle(color: Colors.white, fontFamily: 'Cairo'))
              ),
            ],
          ),
        ),
      );

      if (shouldSave == null) return;
      if (shouldSave == true) {
        await _saveEntry();
        if (!_isReadOnly) return;
      }
    }

    setState(() {
      _selectedSite = site;
      _clientTrips.clear();
      _clearVehicle();
      _currentDocId = null;
      _isReadOnly = false;
    });
  }

  void _onVehicleSelected(String? numberStr) {
    if (numberStr == null || numberStr.isEmpty) return;
    try {
      final vehicle = _liveVehiclesDB.firstWhere((v) => _toArabicNumbers(v['number']) == numberStr || v['number'] == numberStr);
      setState(() {
        _selectedVehicleNumber = _toArabicNumbers(vehicle['number']);
        _driverName = vehicle['name'];
        _cubage = vehicle['cubage'] is int ? (vehicle['cubage'] as int).toDouble() : vehicle['cubage'];
        _typeCode = vehicle['typeCode'];
        _isTractor = vehicle['number'].contains('-');

        if (_typeCode == 'Z') {
          _driverType = _isArabic ? 'سائق شركة (Z)' : 'Company (Z)';
        } else if (_typeCode == 'M') {
          _driverType = _isArabic ? 'سائق محجر (M)' : 'Quarry (M)';
        }
      });
    } catch (_) {}
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

  // الانتقال لشاشة السجل المستقلة (حل نهائي لمشكلة القوائم المعلقة)
  void _openRecordsScreen() {
    FocusScope.of(context).unfocus();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DailyRecordsScreen(
          selectedSite: _selectedSite,
          onLoadEntry: (doc) {
            _loadEntry(doc);
          },
        ),
      ),
    );
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
      _vehicleSearchActive = false;

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
  }

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

      double getGlobalValue(String key, bool isOldSite) {
        if (globalsData.containsKey(key)) {
          return double.tryParse(globalsData[key].toString()) ?? 0.0;
        }
        return (isOldSite ? _oldGlobalsDefaults[key] : _newGlobalsDefaults[key]) ?? 0.0;
      }

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

      List<String> clientNamesList = [];
      List<Map<String, dynamic>> finalTrips = [];

      for (var t in _clientTrips) {
        String rawName = t['client'].toString().trim();
        String safeKey = _normalizeArabic(rawName);

        clientNamesList.add(rawName);

        double clientPrice = 0.0;
        double officePrice = 0.0;

        String? matchedDbKey;
        if (clientsData.isNotEmpty) {
          if (clientsData.containsKey(safeKey)) {
            matchedDbKey = safeKey;
          } else {
            try {
              matchedDbKey = clientsData.keys.firstWhere((k) => _normalizeArabic(k) == safeKey);
            } catch (_) {
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
          Map<String, Map<String, double>> defaultsMap = _selectedSite == 'old' ? _oldClientsDefaults : _newClientsDefaults;
          String? matchedDefKey;
          try {
            matchedDefKey = defaultsMap.keys.firstWhere((k) => _normalizeArabic(k) == safeKey);
          } catch (_) {
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

      if (!isUpdate) {
        var existingDocs = await FirebaseFirestore.instance.collection('daily_entries')
            .where('site', isEqualTo: _selectedSite)
            .where('dateString', isEqualTo: dateStringFormatted)
            .where('vehicleNumber', isEqualTo: _selectedVehicleNumber)
            .get();

        if (existingDocs.docs.isNotEmpty) {
          isUpdate = true;
          _currentDocId = existingDocs.docs.first.id;
          var existingData = existingDocs.docs.first.data();
          List<dynamic> existingTrips = existingData['clientsTrips'] ?? [];

          for (var newT in finalTrips) {
            String safeNewClient = _normalizeArabic(newT['clientName']);
            int matchIndex = existingTrips.indexWhere((t) => _normalizeArabic(t['clientName']) == safeNewClient);

            if (matchIndex >= 0) {
              existingTrips[matchIndex]['trips'] = (existingTrips[matchIndex]['trips'] ?? 0) + newT['trips'];
              existingTrips[matchIndex]['tripsCount'] = (existingTrips[matchIndex]['tripsCount'] ?? 0) + newT['tripsCount'];
              existingTrips[matchIndex]['totalCubage'] = (existingTrips[matchIndex]['totalCubage'] ?? 0.0) + newT['totalCubage'];
              existingTrips[matchIndex]['cubage'] = (existingTrips[matchIndex]['cubage'] ?? 0.0) + newT['cubage'];
              existingTrips[matchIndex]['clientPriceSnapshot'] = newT['clientPriceSnapshot'];
            } else {
              existingTrips.add(newT);
            }
          }
          finalTrips = List<Map<String, dynamic>>.from(existingTrips);
          clientNamesList = finalTrips.map((t) => t['clientName'].toString()).toList();
        }
      }

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

      setState(() => _isReadOnly = true);

      if (hasZeroPrice) {
        _showMessage('تم حفظ البيان بنجاح (تنبيه: يوجد عميل مسجل بسعر صفر)', Colors.orange.shade800, isLong: true);
      } else {
        _showMessage('تم حفظ البيان بنجاح', const Color(0xFF28A745));
      }
    } catch (e) {
      _showMessage('Error: $e', Colors.red.shade700);
    }
  }

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
          constraints: BoxConstraints(maxHeight: 180, maxWidth: MediaQuery.of(context).size.width * 0.75),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                  child: Text(option, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F2A52))),
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

    Widget vehicleIconWidget = const Icon(Icons.airport_shuttle, size: 16, color: Color(0xFF28A745));
    String vehicleFieldLabel = _isArabic ? 'رقم المركبة' : 'Vehicle No.';

    if (_selectedVehicleNumber != null) {
      vehicleIconWidget = _isTractor
          ? const Icon(Icons.local_shipping, size: 16, color: Color(0xFFE67E22))
          : const Icon(Icons.airport_shuttle, size: 16, color: Color(0xFF28A745));

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
          toolbarHeight: 45,
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
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
            onPressed: () async {
              bool canLeave = await DailyEntryScreen.checkUnsavedChanges(context);
              if (canLeave && mounted) Navigator.pop(context);
            },
          ),
          title: Text(
            _isArabic ? 'البيان اليومي' : 'Daily Entry',
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Cairo'),
          ),
          actions: const [SizedBox(width: 48)],
        ),
        bottomNavigationBar: const CustomBottomNav(currentIndex: 1),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    color: Colors.white,
                    elevation: 1,
                    margin: const EdgeInsets.only(bottom: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    child: Padding(
                      padding: const EdgeInsets.all(6.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 30,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      if (_isReadOnly) { _handleReadOnlyTap(); return; }
                                      _changeSite('old');
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _selectedSite == 'old' ? const Color(0xFF4A78B9) : Colors.white,
                                      foregroundColor: _selectedSite == 'old' ? Colors.white : const Color(0xFF4A78B9),
                                      elevation: 0,
                                      padding: EdgeInsets.zero,
                                      side: BorderSide(color: const Color(0xFF4A78B9), width: _selectedSite == 'old' ? 0 : 1),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                    ),
                                    child: const Text('الموقع القديم', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 11)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: SizedBox(
                                  height: 30,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      if (_isReadOnly) { _handleReadOnlyTap(); return; }
                                      _changeSite('new');
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _selectedSite == 'new' ? const Color(0xFF28A745) : Colors.white,
                                      foregroundColor: _selectedSite == 'new' ? Colors.white : const Color(0xFF28A745),
                                      elevation: 0,
                                      padding: EdgeInsets.zero,
                                      side: BorderSide(color: const Color(0xFF28A745), width: _selectedSite == 'new' ? 0 : 1),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                    ),
                                    child: const Text('الموقع الجديد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 11)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
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
                                    height: 30,
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    decoration: BoxDecoration(color: const Color(0xFFF2F6FA), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.grey.shade200)),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Row(
                                          children: [
                                            Icon(Icons.calendar_month, color: Color(0xFF4A78B9), size: 14),
                                            SizedBox(width: 4),
                                            Text('التاريخ:', style: TextStyle(fontFamily: 'Cairo', color: Color(0xFF4A78B9), fontSize: 11, fontWeight: FontWeight.bold)),
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
                                child: SizedBox(
                                  height: 30,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      if (_isReadOnly) { _handleReadOnlyTap(); return; }
                                      _openRecordsScreen(); // فتح شاشة السجل المستقلة
                                    },
                                    icon: const Icon(Icons.list_alt, size: 12, color: Colors.white),
                                    label: const Text('السجل', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1E4885),
                                      padding: EdgeInsets.zero,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  Card(
                    color: Colors.white,
                    elevation: 1,
                    margin: const EdgeInsets.only(bottom: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    child: Padding(
                      padding: const EdgeInsets.all(6.0),
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
                                    height: 32,
                                    decoration: _boxDecoration(),
                                    child: Autocomplete<String>(
                                      key: ValueKey('vehicle_${_selectedSite}_$_vehicleKeyCounter'),
                                      initialValue: TextEditingValue(text: _selectedVehicleNumber ?? ''),
                                      optionsViewBuilder: _buildAutocompleteOptions,
                                      optionsBuilder: (TextEditingValue textEditingValue) {
                                        if (_isReadOnly || _forceHideDropdowns) return const Iterable<String>.empty();
                                        final options = _liveVehiclesDB.map((v) => _toArabicNumbers(v['number'] as String)).toList();
                                        if (textEditingValue.text.isEmpty) return options;
                                        return options.where((opt) => opt.contains(_toArabicNumbers(textEditingValue.text)));
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
                                          decoration: InputDecoration(
                                            isDense: true,
                                            hintText: 'بحث...',
                                            hintStyle: const TextStyle(fontSize: 10, fontFamily: 'Cairo', color: Colors.grey),
                                            border: InputBorder.none,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                                            suffixIconConstraints: const BoxConstraints(maxHeight: 32),
                                            suffixIcon: _isReadOnly ? const SizedBox.shrink() : Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (controller.text.isNotEmpty)
                                                  InkWell(onTap: () => _clearVehicle(), child: const Icon(Icons.close, size: 14, color: Colors.red)),
                                                InkWell(onTap: () { setState(() => _vehicleSearchActive = true); focusNode.requestFocus(); }, child: const Padding(padding: EdgeInsets.all(2.0), child: Icon(Icons.search, size: 14, color: Colors.grey))),
                                                const SizedBox(width: 4),
                                              ],
                                            ),
                                          ),
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Cairo'),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 2,
                                child: _buildCompactInput(
                                  label: 'التكعيب (م³)',
                                  iconWidget: const Icon(Icons.view_in_ar_outlined, size: 12, color: Color(0xFF4A78B9)),
                                  child: Container(
                                    height: 32,
                                    decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.grey.shade200)),
                                    child: Center(child: Text(_formatCubage(_cubage), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black, fontFamily: 'Cairo'))),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: _buildCompactInput(
                                  label: 'اسم السائق',
                                  iconWidget: const Icon(Icons.person_outline, size: 12, color: Color(0xFF4A78B9)),
                                  child: Container(
                                    height: 32,
                                    decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.grey.shade200)),
                                    child: Center(child: FittedBox(child: Text(_driverName, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 11, color: _selectedVehicleNumber == null ? Colors.grey : Colors.black)))),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 2,
                                child: _buildCompactInput(
                                  label: 'التبعية',
                                  iconWidget: const Icon(Icons.badge_outlined, size: 12, color: Color(0xFF4A78B9)),
                                  child: Container(
                                    height: 32,
                                    decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.grey.shade200)),
                                    child: Center(child: FittedBox(child: Text(_driverType, style: TextStyle(fontFamily: 'Cairo', color: _typeCode == 'Z' ? const Color(0xFF28A745) : const Color(0xFFE67E22), fontWeight: FontWeight.bold, fontSize: 11)))),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  Expanded(
                    child: Card(
                      color: Colors.white,
                      elevation: 1,
                      margin: const EdgeInsets.only(bottom: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      child: Padding(
                        padding: const EdgeInsets.all(6.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('تفاصيل النقلات للعملاء', style: TextStyle(fontFamily: 'Cairo', color: Color(0xFF0F2A52), fontSize: 12, fontWeight: FontWeight.bold)),
                                SizedBox(
                                  height: 24,
                                  child: OutlinedButton.icon(
                                    onPressed: (_selectedVehicleNumber == null) ? null : () {
                                      if (_isReadOnly) { _handleReadOnlyTap(); return; }
                                      _addClientTrip();
                                    },
                                    icon: const Icon(Icons.add, color: Color(0xFF28A745), size: 12),
                                    label: const Text('إضافة عميل', style: TextStyle(fontFamily: 'Cairo', color: Color(0xFF28A745), fontSize: 10, fontWeight: FontWeight.bold)),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(color: _selectedVehicleNumber == null ? Colors.grey : const Color(0xFF28A745)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),

                            Expanded(
                              child: _clientTrips.isEmpty
                                  ? Container(
                                decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.grey.shade200)),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.assignment_add, size: 24, color: Color(0xFFBDBDBD)),
                                    SizedBox(height: 2),
                                    Text('لا توجد نقلات مسجلة', style: TextStyle(fontFamily: 'Cairo', color: Color(0xFF757575), fontSize: 11, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              )
                                  : Container(
                                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(4)),
                                child: Column(
                                  children: [
                                    Container(
                                      color: const Color(0xFF0F2A52),
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: const Row(
                                        children: [
                                          Expanded(flex: 12, child: Center(child: Text('اسم العميل', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 10)))),
                                          Expanded(flex: 5, child: Center(child: Text('النقلات', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 10)))),
                                          Expanded(flex: 4, child: Center(child: Text('الكمية', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 10)))),
                                          Expanded(flex: 2, child: Center(child: Icon(Icons.delete, color: Colors.white, size: 12))),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: ListView.separated(
                                        itemCount: _clientTrips.length,
                                        separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.grey),
                                        itemBuilder: (context, index) {
                                          int currentTrips = _clientTrips[index]['trips'];
                                          double currentCubage = currentTrips * _cubage;

                                          return Container(
                                            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  flex: 12,
                                                  child: Container(
                                                    height: 30,
                                                    decoration: _boxDecoration(),
                                                    child: Autocomplete<String>(
                                                      initialValue: TextEditingValue(text: _clientTrips[index]['client'] ?? ''),
                                                      optionsViewBuilder: _buildAutocompleteOptions,
                                                      optionsBuilder: (TextEditingValue textEditingValue) {
                                                        if (_isReadOnly || _forceHideDropdowns) return const Iterable<String>.empty();
                                                        if (textEditingValue.text.isEmpty) return availableClients;
                                                        return availableClients.where((opt) => opt.contains(textEditingValue.text));
                                                      },
                                                      onSelected: (String selection) {
                                                        FocusScope.of(context).unfocus();
                                                        bool exists = _clientTrips.any((trip) => trip['client'] == selection && _clientTrips.indexOf(trip) != index);
                                                        if (exists) {
                                                          _showMessage('العميل موجود بالفعل', Colors.red.shade700);
                                                          setState(() {
                                                            _clientTrips[index]['searchActive'] = false;
                                                            _clientTrips[index]['client'] = null;
                                                          });
                                                        } else {
                                                          setState(() {
                                                            _clientTrips[index]['client'] = selection;
                                                            _clientTrips[index]['searchActive'] = false;
                                                          });
                                                        }
                                                      },
                                                      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                                        if (_clientTrips[index]['client'] == null && controller.text.isNotEmpty) {
                                                          WidgetsBinding.instance.addPostFrameCallback((_) => controller.clear());
                                                        }
                                                        return TextField(
                                                          controller: controller,
                                                          focusNode: focusNode,
                                                          readOnly: _isReadOnly || !(_clientTrips[index]['searchActive'] ?? false),
                                                          maxLines: 1,
                                                          textAlignVertical: TextAlignVertical.center,
                                                          decoration: InputDecoration(
                                                            isDense: true,
                                                            hintText: 'بحث...',
                                                            hintStyle: const TextStyle(fontSize: 10, fontFamily: 'Cairo', color: Colors.grey),
                                                            border: InputBorder.none,
                                                            contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                                                            suffixIconConstraints: const BoxConstraints(maxHeight: 30),
                                                            suffixIcon: _isReadOnly ? const SizedBox.shrink() : Row(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                if (controller.text.isNotEmpty)
                                                                  InkWell(
                                                                    onTap: () {
                                                                      controller.clear();
                                                                      setState(() {
                                                                        _clientTrips[index]['searchActive'] = false;
                                                                        _clientTrips[index]['client'] = null;
                                                                      });
                                                                    },
                                                                    child: const Icon(Icons.close, size: 14, color: Colors.red),
                                                                  ),
                                                                InkWell(
                                                                  onTap: () {
                                                                    setState(() => _clientTrips[index]['searchActive'] = true);
                                                                    focusNode.requestFocus();
                                                                  },
                                                                  child: const Padding(
                                                                    padding: EdgeInsets.symmetric(horizontal: 2.0),
                                                                    child: Icon(Icons.search, size: 14, color: Colors.grey),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          style: const TextStyle(fontFamily: 'Cairo', fontSize: 10, fontWeight: FontWeight.bold),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 5,
                                                  child: Opacity(
                                                    opacity: _isReadOnly ? 0.5 : 1.0,
                                                    child: Row(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        InkWell(
                                                          onTap: () { if (!_isReadOnly) setState(() => _clientTrips[index]['trips']++); },
                                                          child: Container(padding: const EdgeInsets.all(1), decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(3)), child: const Icon(Icons.add, size: 12)),
                                                        ),
                                                        Padding(
                                                          padding: const EdgeInsets.symmetric(horizontal: 3.0),
                                                          child: Text(_toArabicNumbers(currentTrips.toString()), style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 11)),
                                                        ),
                                                        InkWell(
                                                          onTap: () { if (!_isReadOnly && currentTrips > 1) setState(() => _clientTrips[index]['trips']--); },
                                                          child: Container(padding: const EdgeInsets.all(1), decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(3)), child: const Icon(Icons.remove, size: 12)),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 4,
                                                  child: Center(
                                                    child: Text(_formatCubage(currentCubage), style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Color(0xFF0F2A52), fontSize: 10)),
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 2,
                                                  child: IconButton(
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(),
                                                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 14),
                                                    onPressed: () { if (!_isReadOnly) setState(() => _clientTrips.removeAt(index)); },
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
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

                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 36,
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          gradient: _isReadOnly ? null : const LinearGradient(colors: [Color(0xFF0F2A52), Color(0xFF1E4885)]),
                          color: _isReadOnly ? Colors.grey : null,
                          boxShadow: _isReadOnly ? null : [const BoxShadow(color: Color(0x4D0F2A52), blurRadius: 2, offset: Offset(0, 1))],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _isReadOnly ? () => _handleReadOnlyTap() : _saveEntry,
                          icon: const Icon(Icons.save, color: Colors.white, size: 16),
                          label: Text(
                              _isArabic ? (_currentDocId != null ? 'حفظ التعديلات' : 'حفظ البيان') : 'Save Entry',
                              style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 30,
                              child: ElevatedButton.icon(
                                onPressed: _currentDocId != null ? () {
                                  if (!_isReadOnly) return;
                                  setState(() { _clientTrips.clear(); _clearVehicle(); _currentDocId = null; _isReadOnly = false; });
                                } : null,
                                icon: const Icon(Icons.refresh, color: Colors.white, size: 12),
                                label: const Text('بيان جديد', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(backgroundColor: _currentDocId != null ? Colors.blue.shade700 : Colors.grey, padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: SizedBox(
                              height: 30,
                              child: ElevatedButton.icon(
                                onPressed: (_currentDocId != null && _isReadOnly) ? () => setState(() => _isReadOnly = false) : null,
                                icon: const Icon(Icons.edit, color: Colors.white, size: 12),
                                label: const Text('تعديل البيان', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(backgroundColor: (_currentDocId != null && _isReadOnly) ? const Color(0xFFFFA000) : Colors.grey, padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: SizedBox(
                              height: 30,
                              child: ElevatedButton.icon(
                                onPressed: _currentDocId != null ? _deleteEntry : null,
                                icon: const Icon(Icons.delete_forever, color: Colors.white, size: 12),
                                label: const Text('حذف البيان', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(backgroundColor: _currentDocId != null ? Colors.red.shade700 : Colors.grey, padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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
            const SizedBox(width: 3),
            Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF4A78B9))),
          ],
        ),
        const SizedBox(height: 1),
        child,
      ],
    );
  }

  BoxDecoration _boxDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: Colors.grey.shade300),
    );
  }
}

// ==========================================
// شاشة "السجل المستقلة" (الحل النهائي الجذري)
// ==========================================
class DailyRecordsScreen extends StatefulWidget {
  final String selectedSite;
  final Function(DocumentSnapshot) onLoadEntry;

  const DailyRecordsScreen({super.key, required this.selectedSite, required this.onLoadEntry});

  @override
  State<DailyRecordsScreen> createState() => _DailyRecordsScreenState();
}

class _DailyRecordsScreenState extends State<DailyRecordsScreen> {
  DateTime startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime endDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F9),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F2A52),
          title: Text(
            'سجل البيانات (${widget.selectedSite == 'old' ? 'الموقع القديم' : 'الموقع الجديد'})',
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            children: [
              // فلتر "من وإلى" في سطر واحد وبتنسيق اليوم/الشهر/السنة
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: startDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setState(() => startDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(6)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.calendar_today, size: 14, color: Color(0xFF4A78B9)),
                            const SizedBox(width: 6),
                            Text('من: ${startDate.day}/${startDate.month}/${startDate.year}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: endDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setState(() => endDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(6)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.calendar_today, size: 14, color: Color(0xFF4A78B9)),
                            const SizedBox(width: 6),
                            Text('إلى: ${endDate.day}/${endDate.month}/${endDate.year}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('daily_entries')
                      .where('site', isEqualTo: widget.selectedSite)
                      .orderBy('date', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFF0F2A52)));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('لا توجد بيانات مسجلة', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)));
                    }

                    var filteredDocs = snapshot.data!.docs.where((doc) {
                      var data = doc.data() as Map<String, dynamic>;
                      Timestamp? ts = data['date'] as Timestamp?;
                      if (ts == null) return false;
                      DateTime docDate = ts.toDate();

                      DateTime cleanDocDate = DateTime(docDate.year, docDate.month, docDate.day);
                      DateTime cleanStart = DateTime(startDate.year, startDate.month, startDate.day);
                      DateTime cleanEnd = DateTime(endDate.year, endDate.month, endDate.day);

                      return cleanDocDate.compareTo(cleanStart) >= 0 && cleanDocDate.compareTo(cleanEnd) <= 0;
                    }).toList();

                    if (filteredDocs.isEmpty) {
                      return const Center(child: Text('لا توجد بيانات في الفترة المحددة', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)));
                    }

                    return ListView.builder(
                      itemCount: filteredDocs.length,
                      itemBuilder: (context, index) {
                        var doc = filteredDocs[index];
                        var data = doc.data() as Map<String, dynamic>;
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          elevation: 2,
                          child: ListTile(
                            leading: Icon(data['isTractor'] == true ? Icons.local_shipping : Icons.airport_shuttle, color: const Color(0xFF4A78B9)),
                            title: Text('مركبة: ${data['vehicleNumber']} (${data['dateString'] ?? ''})', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)),
                            subtitle: Text('السائق: ${data['driverName']} - ${data['clientsTrips']?.length ?? 0} عملاء', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11)),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                            onTap: () {
                              widget.onLoadEntry(doc);
                              Navigator.pop(context);
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}