import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'custom_bottom_nav.dart';

class DailyEntryScreen extends StatefulWidget {
  const DailyEntryScreen({super.key});

  static Future<bool> checkUnsavedChanges(BuildContext context) async {
    final state = context.findAncestorStateOfType<_DailyEntryScreenState>();
    if (state != null) {
      return await state.checkUnsavedChangesInternal();
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

  bool _isReadOnly = false;

  final List<Map<String, dynamic>> _clientTrips = [];
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
  }

  @override
  void dispose() {
    _vehiclesSub?.cancel();
    super.dispose();
  }

  Future<bool> checkUnsavedChangesInternal() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Future.delayed(const Duration(milliseconds: 250));

    if (!_isReadOnly && (_selectedVehicleNumber != null || _clientTrips.isNotEmpty)) {
      bool? result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: const Text('تنبيه: بيان غير محفوظ!', style: TextStyle(color: Colors.red, fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
            content: const Text('لديك بيانات لم يتم حفظها. هل تريد حفظ البيان الحالي أولاً؟', style: TextStyle(fontFamily: 'Cairo', fontSize: 14)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء والعودة', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey))),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تجاهل ومتابعة', style: TextStyle(fontFamily: 'Cairo', color: Colors.red))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF28A745)),
                onPressed: () async {
                  final saved = await _saveEntry();
                  if (!ctx.mounted) return;
                  if (saved) {
                    Navigator.pop(ctx, true);
                  }
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
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Cairo', color: Colors.white),
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

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text(
        '$day / $month / $year',
        style: const TextStyle(fontFamily: 'Cairo', color: Color(0xFF0F2A52), fontSize: 14, fontWeight: FontWeight.bold),
      ),
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
            content: const Text('لديك بيانات لم يتم حفظها. هل تريد حفظ البيان قبل الانتقال للموقع الآخر؟', style: TextStyle(fontFamily: 'Cairo', fontSize: 14)),
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
        final saved = await _saveEntry();
        if (!saved) return;
      }
    }

    setState(() {
      _selectedSite = site;
      _clientTrips.clear();
      _resetVehicleFieldsOnly();
      _currentDocId = null;
      _isReadOnly = false;
    });
  }

  void _onVehicleSelected(Map<String, dynamic> vehicle) {
    setState(() {
      _selectedVehicleNumber = _toArabicNumbers(vehicle['number'].toString());
      _driverName = vehicle['name'].toString();
      _cubage = double.tryParse(vehicle['cubage'].toString()) ?? 0.0;
      _typeCode = vehicle['typeCode'].toString();

      // 🔥 قراءة النوع من الحقل الجديد vehicleType 🔥
      _isTractor = vehicle['vehicleType'] == 'tractor';

      if (_typeCode == 'Z') {
        _driverType = _isArabic ? 'سائق شركة (Z)' : 'Company (Z)';
      } else if (_typeCode == 'M') {
        _driverType = _isArabic ? 'سائق محجر (M)' : 'Quarry (M)';
      }
    });
  }

  void _resetVehicleFieldsOnly() {
    _selectedVehicleNumber = null;
    _driverName = '---';
    _driverType = '---';
    _typeCode = '';
    _cubage = 0.0;
    _isTractor = false;
  }

  void _clearVehicle() {
    setState(() {
      _resetVehicleFieldsOnly();
    });
  }

  void _addClientTrip() {
    setState(() {
      _clientTrips.add({'client': null, 'trips': 1});
    });
  }

  String _formatCubage(double val) {
    String result = val == 0.0 ? '0' : (val % 1 == 0 ? val.toInt().toString() : val.toString());
    return _toArabicNumbers(result);
  }

  Future<void> _checkAndOpenRecords() async {
    if (_isReadOnly) { _handleReadOnlyTap(); return; }

    bool canLeave = await checkUnsavedChangesInternal();
    if (!mounted) return;

    if (canLeave) {
      await Navigator.push(
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
  }

  void _loadEntry(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    setState(() {
      _currentDocId = doc.id;
      _selectedVehicleNumber = data['vehicleNumber']?.toString();
      _driverName = data['driverName']?.toString() ?? '---';
      _typeCode = data['typeCode']?.toString() ?? '';
      _cubage = double.tryParse((data['cubage'] ?? 0.0).toString()) ?? 0.0;
      _isTractor = data['isTractor'] == true;

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
          'client': t['clientName']?.toString() ?? t['client']?.toString(),
          'trips': int.tryParse(t['tripsCount']?.toString() ?? t['trips']?.toString() ?? '1') ?? 1,
        });
      }
    });
  }

  Future<bool> _saveEntry() async {
    if (_selectedVehicleNumber == null) {
      _showMessage(_isArabic ? 'برجاء اختيار المركبة أولاً' : 'Select vehicle first', Colors.red.shade700);
      return false;
    }
    if (_clientTrips.isEmpty) {
      _showMessage(_isArabic ? 'برجاء إضافة عميل واحد على الأقل' : 'Add at least one client', Colors.red.shade700);
      return false;
    }
    if (_clientTrips.any((trip) => trip['client'] == null || trip['client'].toString().trim().isEmpty)) {
      _showMessage(_isArabic ? 'برجاء اختيار أسماء جميع العملاء في الجدول' : 'Select all client names', Colors.red.shade700);
      return false;
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

        int tripsCount = int.tryParse(t['trips'].toString()) ?? 1;

        finalTrips.add({
          'client': rawName,
          'clientName': rawName,
          'trips': tripsCount,
          'tripsCount': tripsCount,
          'totalCubage': tripsCount * _cubage,
          'cubage': tripsCount * _cubage,
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
        'isTractor': _isTractor, // تم الاعتماد على الحقل الجديد
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
        _currentDocId = null;
        _resetVehicleFieldsOnly();
        _clientTrips.clear();
        _isReadOnly = false;
      });

      if (!mounted) return false;
      if (hasZeroPrice) {
        _showMessage('تم حفظ البيان بنجاح (تنبيه: يوجد عميل مسجل بسعر صفر)', Colors.orange.shade800, isLong: true);
      } else {
        _showMessage('تم حفظ البيان بنجاح', const Color(0xFF28A745));
      }

      return true;

    } catch (e) {
      if (!mounted) return false;
      _showMessage('Error: $e', Colors.red.shade700);
      return false;
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
        _resetVehicleFieldsOnly();
        _clientTrips.clear();
        _isReadOnly = false;
      });
      if (!mounted) return;
      _showMessage(_isArabic ? 'تم حذف البيان بنجاح' : 'Entry Deleted Successfully.', Colors.red.shade700);
    } catch (e) {
      if (!mounted) return;
      _showMessage('Error: $e', Colors.red.shade700);
    }
  }

  // 🔥 1. الشاشة المنبثقة لاختيار المركبات (بديل الـ Autocomplete) ترتيب الجرارات أولاً 🔥
  void _showVehicleSelectionSheet(BuildContext context) {
    if (_isReadOnly) { _handleReadOnlyTap(); return; }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {

            var filteredVehicles = _liveVehiclesDB.where((v) {
              return v['number'].toString().contains(searchQuery) ||
                  v['name'].toString().contains(searchQuery);
            }).toList();

            // 🔥 الذكاء في ترتيب الجرارات فوق 🔥
            filteredVehicles.sort((a, b) {
              bool isATractor = a['vehicleType'] == 'tractor';
              bool isBTractor = b['vehicleType'] == 'tractor';

              if (isATractor && !isBTractor) return -1;
              if (!isATractor && isBTractor) return 1;

              return a['number'].toString().compareTo(b['number'].toString());
            });

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Color(0xFF0F2A52),
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              ),
              padding: const EdgeInsets.only(top: 10, left: 16, right: 16),
              child: Column(
                children: [
                  Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(10))),
                  const SizedBox(height: 20),
                  const Text('ابحث واختر المركبة', style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  TextField(
                    onChanged: (val) => setModalState(() => searchQuery = val),
                    style: const TextStyle(color: Colors.white, fontFamily: 'Cairo'),
                    decoration: InputDecoration(
                      hintText: 'ابحث برقم العربية أو الاسم...',
                      hintStyle: const TextStyle(color: Colors.white54, fontFamily: 'Cairo'),
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF4A78B9)),
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
                        bool isTractorItem = vehicle['vehicleType'] == 'tractor';

                        return Card(
                          color: Colors.white.withOpacity(0.05),
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                            side: BorderSide(color: isTractorItem ? const Color(0xFFE67E22).withOpacity(0.5) : Colors.transparent),
                          ),
                          child: ListTile(
                            leading: Icon(
                                isTractorItem ? Icons.local_shipping : Icons.airport_shuttle,
                                color: isTractorItem ? const Color(0xFFE67E22) : const Color(0xFF28A745)
                            ),
                            title: Text(vehicle['name'].toString(), style: const TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15)),
                            subtitle: Text('رقم: ${_toArabicNumbers(vehicle['number'].toString())}  |  تكعيب: ${_formatCubage(double.tryParse(vehicle['cubage'].toString()) ?? 0)}', style: const TextStyle(color: Colors.white70, fontFamily: 'Cairo')),
                            trailing: Text(isTractorItem ? 'جرار' : 'عربية', style: TextStyle(color: isTractorItem ? const Color(0xFFE67E22) : const Color(0xFF28A745), fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold)),
                            onTap: () {
                              _onVehicleSelected(vehicle);
                              FocusScope.of(context).unfocus();
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

  // 🔥 2. الشاشة المنبثقة لاختيار العميل (بديل الـ Autocomplete) 🔥
  void _showClientSelectionSheet(BuildContext context, int index) {
    if (_isReadOnly) { _handleReadOnlyTap(); return; }
    final availableClients = _selectedSite == 'old' ? _oldSiteClients : _newSiteClients;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            var filteredClients = availableClients.where((c) => c.contains(searchQuery)).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Color(0xFF0F2A52),
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              ),
              padding: const EdgeInsets.only(top: 10, left: 16, right: 16),
              child: Column(
                children: [
                  Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(10))),
                  const SizedBox(height: 20),
                  const Text('ابحث واختر العميل', style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  TextField(
                    onChanged: (val) => setModalState(() => searchQuery = val),
                    style: const TextStyle(color: Colors.white, fontFamily: 'Cairo'),
                    decoration: InputDecoration(
                      hintText: 'ابحث باسم العميل...',
                      hintStyle: const TextStyle(color: Colors.white54, fontFamily: 'Cairo'),
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF4A78B9)),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredClients.length,
                      itemBuilder: (context, i) {
                        var clientName = filteredClients[i];
                        return Card(
                          color: Colors.white.withOpacity(0.05),
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          child: ListTile(
                            leading: const Icon(Icons.business, color: Color(0xFF4A78B9)),
                            title: Text(clientName, style: const TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15)),
                            onTap: () {
                              bool exists = _clientTrips.any((trip) => trip['client'] == clientName && _clientTrips.indexOf(trip) != index);
                              if (exists) {
                                Navigator.pop(context);
                                _showMessage('العميل موجود بالفعل في القائمة', Colors.red.shade700);
                              } else {
                                setState(() {
                                  _clientTrips[index]['client'] = clientName;
                                });
                                FocusScope.of(context).unfocus();
                                Navigator.pop(context);
                              }
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


  @override
  Widget build(BuildContext context) {
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
          toolbarHeight: 50,
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
            onPressed: () async {
              bool canLeave = await checkUnsavedChangesInternal();
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
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  color: Colors.white,
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 🔥 3. تكبير زراير الموقع 🔥
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 45,
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
                                    side: BorderSide(color: const Color(0xFF4A78B9), width: _selectedSite == 'old' ? 0 : 1.5),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text('الموقع القديم', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: SizedBox(
                                height: 45,
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
                                    side: BorderSide(color: const Color(0xFF28A745), width: _selectedSite == 'new' ? 0 : 1.5),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text('الموقع الجديد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // 🔥 4. تكبير شريط التاريخ والسجل 🔥
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
                                  height: 45,
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  decoration: BoxDecoration(color: const Color(0xFFF2F6FA), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(Icons.calendar_month, color: Color(0xFF4A78B9), size: 18),
                                          SizedBox(width: 6),
                                          Text('التاريخ:', style: TextStyle(fontFamily: 'Cairo', color: Color(0xFF4A78B9), fontSize: 13, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                      _buildFormattedDate(),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: SizedBox(
                                height: 45,
                                child: ElevatedButton.icon(
                                  onPressed: _checkAndOpenRecords,
                                  icon: const Icon(Icons.list_alt, size: 16, color: Colors.white),
                                  label: const Text('السجل', style: TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1E4885),
                                    padding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            // 🔥 5. استبدال Autocomplete المركبة بالشاشة المنبثقة 🔥
                            Expanded(
                              flex: 3,
                              child: _buildCompactInput(
                                label: vehicleFieldLabel,
                                iconWidget: vehicleIconWidget,
                                child: InkWell(
                                  onTap: () => _showVehicleSelectionSheet(context),
                                  child: Container(
                                    height: 38,
                                    decoration: _boxDecoration(),
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                            _selectedVehicleNumber ?? 'بحث برقم المركبة...',
                                            style: TextStyle(
                                                fontFamily: 'Cairo',
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: _selectedVehicleNumber == null ? Colors.grey : Colors.black
                                            )
                                        ),
                                        Row(
                                          children: [
                                            if (_selectedVehicleNumber != null && !_isReadOnly)
                                              InkWell(
                                                  onTap: () => _clearVehicle(),
                                                  child: const Icon(Icons.close, size: 16, color: Colors.red)
                                              ),
                                            if (!_isReadOnly)
                                              const Padding(
                                                  padding: EdgeInsets.only(right: 6.0),
                                                  child: Icon(Icons.search, size: 18, color: Color(0xFF4A78B9))
                                              ),
                                          ],
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: _buildCompactInput(
                                label: 'التكعيب (م³)',
                                iconWidget: const Icon(Icons.view_in_ar_outlined, size: 16, color: Color(0xFF4A78B9)),
                                child: Container(
                                  height: 38,
                                  decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey.shade200)),
                                  child: Center(child: Text(_formatCubage(_cubage), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black, fontFamily: 'Cairo'))),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: _buildCompactInput(
                                label: 'اسم السائق',
                                iconWidget: const Icon(Icons.person_outline, size: 16, color: Color(0xFF4A78B9)),
                                child: Container(
                                  height: 38,
                                  decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey.shade200)),
                                  child: Center(child: FittedBox(child: Text(_driverName, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13, color: _selectedVehicleNumber == null ? Colors.grey : Colors.black)))),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: _buildCompactInput(
                                label: 'التبعية',
                                iconWidget: const Icon(Icons.badge_outlined, size: 16, color: Color(0xFF4A78B9)),
                                child: Container(
                                  height: 38,
                                  decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey.shade200)),
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

                Expanded(
                  child: Card(
                    color: Colors.white,
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('تفاصيل النقلات للعملاء', style: TextStyle(fontFamily: 'Cairo', color: Color(0xFF0F2A52), fontSize: 14, fontWeight: FontWeight.bold)),
                              SizedBox(
                                height: 32,
                                child: OutlinedButton.icon(
                                  onPressed: (_selectedVehicleNumber == null) ? null : () {
                                    if (_isReadOnly) { _handleReadOnlyTap(); return; }
                                    _addClientTrip();
                                  },
                                  icon: const Icon(Icons.add, color: Color(0xFF28A745), size: 16),
                                  label: const Text('إضافة عميل', style: TextStyle(fontFamily: 'Cairo', color: Color(0xFF28A745), fontSize: 12, fontWeight: FontWeight.bold)),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: _selectedVehicleNumber == null ? Colors.grey : const Color(0xFF28A745), width: 1.5),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          Expanded(
                            child: _clientTrips.isEmpty
                                ? Container(
                              decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.assignment_add, size: 36, color: Color(0xFFBDBDBD)),
                                  SizedBox(height: 6),
                                  Text('لا توجد نقلات مسجلة', style: TextStyle(fontFamily: 'Cairo', color: Color(0xFF757575), fontSize: 14, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            )
                                : Container(
                              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                              child: Column(
                                children: [
                                  Container(
                                    color: const Color(0xFF0F2A52),
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    child: const Row(
                                      children: [
                                        Expanded(flex: 12, child: Center(child: Text('اسم العميل', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)))),
                                        Expanded(flex: 5, child: Center(child: Text('النقلات', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)))),
                                        Expanded(flex: 4, child: Center(child: Text('الكمية', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)))),
                                        Expanded(flex: 2, child: Center(child: Icon(Icons.delete, color: Colors.white, size: 16))),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: ListView.separated(
                                      itemCount: _clientTrips.length,
                                      separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.grey),
                                      itemBuilder: (context, index) {
                                        int currentTrips = int.tryParse(_clientTrips[index]['trips'].toString()) ?? 1;
                                        double currentCubage = currentTrips * _cubage;

                                        return Container(
                                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                                          child: Row(
                                            children: [
                                              // 🔥 6. استبدال Autocomplete العميل بالشاشة المنبثقة 🔥
                                              Expanded(
                                                flex: 12,
                                                child: InkWell(
                                                  onTap: () => _showClientSelectionSheet(context, index),
                                                  child: Container(
                                                    height: 36,
                                                    decoration: _boxDecoration(),
                                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                                    child: Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            _clientTrips[index]['client'] ?? 'اختر العميل...',
                                                            style: TextStyle(
                                                                fontFamily: 'Cairo',
                                                                fontSize: 12,
                                                                fontWeight: FontWeight.bold,
                                                                color: _clientTrips[index]['client'] == null ? Colors.grey : Colors.black
                                                            ),
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                        if (!_isReadOnly)
                                                          const Icon(Icons.search, size: 16, color: Color(0xFF4A78B9)),
                                                      ],
                                                    ),
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
                                                        child: Container(padding: const EdgeInsets.all(2), decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)), child: const Icon(Icons.add, size: 14)),
                                                      ),
                                                      Padding(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6.0),
                                                        child: Text(_toArabicNumbers(currentTrips.toString()), style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)),
                                                      ),
                                                      InkWell(
                                                        onTap: () { if (!_isReadOnly && currentTrips > 1) setState(() => _clientTrips[index]['trips']--); },
                                                        child: Container(padding: const EdgeInsets.all(2), decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)), child: const Icon(Icons.remove, size: 14)),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 4,
                                                child: Center(
                                                  child: Text(_formatCubage(currentCubage), style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Color(0xFF0F2A52), fontSize: 12)),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: IconButton(
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(),
                                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
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
                      height: 45,
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: _isReadOnly ? null : const LinearGradient(colors: [Color(0xFF0F2A52), Color(0xFF1E4885)]),
                        color: _isReadOnly ? Colors.grey : null,
                        boxShadow: _isReadOnly ? null : [const BoxShadow(color: Color(0x4D0F2A52), blurRadius: 4, offset: Offset(0, 2))],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _isReadOnly ? () => _handleReadOnlyTap() : () async { await _saveEntry(); },
                        icon: const Icon(Icons.save, color: Colors.white, size: 20),
                        label: Text(
                            _isArabic ? (_currentDocId != null ? 'حفظ التعديلات' : 'حفظ البيان') : 'Save Entry',
                            style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 38,
                            child: ElevatedButton.icon(
                              onPressed: _currentDocId != null ? () {
                                if (!_isReadOnly) return;
                                setState(() { _clientTrips.clear(); _resetVehicleFieldsOnly(); _currentDocId = null; _isReadOnly = false; });
                              } : null,
                              icon: const Icon(Icons.refresh, color: Colors.white, size: 14),
                              label: const Text('بيان جديد', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(backgroundColor: _currentDocId != null ? Colors.blue.shade700 : Colors.grey, padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: SizedBox(
                            height: 38,
                            child: ElevatedButton.icon(
                              onPressed: (_currentDocId != null && _isReadOnly) ? () => setState(() => _isReadOnly = false) : null,
                              icon: const Icon(Icons.edit, color: Colors.white, size: 14),
                              label: const Text('تعديل البيان', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(backgroundColor: (_currentDocId != null && _isReadOnly) ? const Color(0xFFFFA000) : Colors.grey, padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
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
                              label: const Text('حذف البيان', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(backgroundColor: _currentDocId != null ? Colors.red.shade700 : Colors.grey, padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
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
            Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4A78B9))),
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

// ==========================================
// شاشة "السجل المستقلة" - لم يتم تغييرها
// ==========================================
class DailyRecordsScreen extends StatefulWidget {
  final String selectedSite;
  final Function(DocumentSnapshot) onLoadEntry;

  const DailyRecordsScreen({super.key, required this.selectedSite, required this.onLoadEntry});

  @override
  State<DailyRecordsScreen> createState() => _DailyRecordsScreenState();
}

class _DailyRecordsScreenState extends State<DailyRecordsScreen> {
  DateTimeRange _selectedDateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 7)),
    end: DateTime.now(),
  );

  String _toArabicNumbers(String text) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    for (int i = 0; i < english.length; i++) {
      text = text.replaceAll(english[i], arabic[i]);
    }
    return text;
  }

  Widget _buildStrictDateText(DateTime date) {
    String d = _toArabicNumbers(date.day.toString().padLeft(2, '0'));
    String m = _toArabicNumbers(date.month.toString().padLeft(2, '0'));
    String y = _toArabicNumbers(date.year.toString());

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text(
        '$d / $m / $y',
        style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F2A52)),
      ),
    );
  }

  DateTime? _extractEntryDate(Map<String, dynamic> data) {
    final dynamic rawDate = data['date'];
    if (rawDate is Timestamp) return rawDate.toDate();
    if (rawDate is DateTime) return rawDate;

    final rawDateString = (data['dateString'] ?? '').toString().trim();
    final parts = rawDateString.split('/');
    if (parts.length != 3) return null;

    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;

    return DateTime(year, month, day);
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
              InkWell(
                onTap: () async {
                  DateTimeRange? picked = await showDateRangePicker(
                    context: context,
                    initialDateRange: _selectedDateRange,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                    cancelText: 'إلغاء',
                    confirmText: 'حفظ',
                    saveText: 'حفظ',
                    helpText: 'اختر فترة البحث',
                    fieldStartHintText: 'تاريخ البداية',
                    fieldEndHintText: 'تاريخ النهاية',
                    locale: const Locale('ar', 'EG'),
                    builder: (context, child) {
                      return Theme(
                        data: ThemeData.light().copyWith(
                          colorScheme: const ColorScheme.light(primary: Color(0xFF0F2A52)),
                        ),
                        child: Directionality(
                          textDirection: TextDirection.rtl,
                          child: child!,
                        ),
                      );
                    },
                  );
                  if (picked != null) {
                    setState(() => _selectedDateRange = picked);
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(6)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    textDirection: TextDirection.rtl,
                    children: [
                      const Icon(Icons.date_range, size: 18, color: Color(0xFF4A78B9)),
                      const SizedBox(width: 8),
                      const Text('من: ', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F2A52))),
                      _buildStrictDateText(_selectedDateRange.start),
                      const SizedBox(width: 15),
                      const Text('إلى: ', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F2A52))),
                      _buildStrictDateText(_selectedDateRange.end),
                    ],
                  ),
                ),
              ),
              const Divider(height: 20),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('daily_entries')
                      .where('site', isEqualTo: widget.selectedSite)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFF0F2A52)));
                    }

                    if (snapshot.hasError) {
                      return const Center(
                        child: Text(
                          'حدث خطأ أثناء تحميل البيانات',
                          style: TextStyle(fontFamily: 'Cairo', color: Colors.red),
                        ),
                      );
                    }

                    final docs = snapshot.data?.docs ?? const [];
                    if (docs.isEmpty) {
                      return const Center(child: Text('لا توجد بيانات مسجلة', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)));
                    }

                    var filteredDocs = docs.where((doc) {
                      var data = doc.data() as Map<String, dynamic>;
                      final docDate = _extractEntryDate(data);
                      if (docDate == null) return false;

                      DateTime cleanDocDate = DateTime(docDate.year, docDate.month, docDate.day);
                      DateTime cleanStart = DateTime(_selectedDateRange.start.year, _selectedDateRange.start.month, _selectedDateRange.start.day);
                      DateTime cleanEnd = DateTime(_selectedDateRange.end.year, _selectedDateRange.end.month, _selectedDateRange.end.day);

                      return cleanDocDate.compareTo(cleanStart) >= 0 && cleanDocDate.compareTo(cleanEnd) <= 0;
                    }).toList();

                    filteredDocs.sort((a, b) {
                      final aDate = _extractEntryDate(a.data() as Map<String, dynamic>) ?? DateTime(1970);
                      final bDate = _extractEntryDate(b.data() as Map<String, dynamic>) ?? DateTime(1970);
                      return bDate.compareTo(aDate);
                    });

                    if (filteredDocs.isEmpty) {
                      return const Center(child: Text('لا توجد بيانات في الفترة المحددة', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)));
                    }

                    return ListView.builder(
                      itemCount: filteredDocs.length,
                      itemBuilder: (context, index) {
                        var doc = filteredDocs[index];
                        var data = doc.data() as Map<String, dynamic>;

                        String vNumber = _toArabicNumbers(data['vehicleNumber']?.toString() ?? '');
                        String dString = _toArabicNumbers(data['dateString']?.toString() ?? '');
                        String tripsCount = _toArabicNumbers((data['clientsTrips']?.length ?? 0).toString());

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          elevation: 2,
                          child: ListTile(
                            leading: Icon(data['isTractor'] == true ? Icons.local_shipping : Icons.airport_shuttle, color: const Color(0xFF4A78B9)),
                            title: Text('مركبة: $vNumber ($dString)', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)),
                            subtitle: Text('السائق: ${data['driverName']} - $tripsCount عملاء', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11)),
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