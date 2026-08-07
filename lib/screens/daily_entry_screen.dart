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

  double _clientPriceOldTruck = 0.0;
  double _clientPriceOldTractor = 0.0;
  double _clientPriceNewTruck = 0.0;
  double _clientPriceNewTractor = 0.0;
  double _defaultOfficePrice = 0.0;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchDatabaseData(showMessages: false);
    });
  }

  @override
  void dispose() {
    _vehiclesSub?.cancel();
    super.dispose();
  }

  Future<void> _fetchDatabaseData({bool showMessages = true}) async {
    try {
      var settingsSnap = await FirebaseFirestore.instance.collection('settings').doc('prices').get();
      if(settingsSnap.exists && mounted) {
        var data = settingsSnap.data()!;
        setState(() {
          _clientPriceOldTruck = (data['clientPriceOldTruck'] ?? 100.0).toDouble();
          _clientPriceOldTractor = (data['clientPriceOldTractor'] ?? 120.0).toDouble();
          _clientPriceNewTruck = (data['clientPriceNewTruck'] ?? 100.0).toDouble();
          _clientPriceNewTractor = (data['clientPriceNewTractor'] ?? 120.0).toDouble();
          _defaultOfficePrice = (data['defaultOfficePrice'] ?? 10.0).toDouble();
        });
      }
    } catch (e) {
      debugPrint('Error fetching prices: $e');
    }
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
        .replaceAll('٠', '0')
        .replaceAll('١', '1')
        .replaceAll('٢', '2')
        .replaceAll('٣', '3')
        .replaceAll('٤', '4')
        .replaceAll('٥', '5')
        .replaceAll('٦', '6')
        .replaceAll('٧', '7')
        .replaceAll('٨', '8')
        .replaceAll('٩', '9')
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
    String result = val == 0.0 ? '0' : val.toInt().toString();
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

  Future<void> _rollbackSingleEntry(String docId) async {
    DocumentSnapshot entryDoc = await FirebaseFirestore.instance.collection('daily_entries').doc(docId).get();

    if (entryDoc.exists) {
      Map<String, dynamic> entryData = entryDoc.data() as Map<String, dynamic>;
      String driverName = entryData['driverName']?.toString() ?? '';
      String dateString = entryData['dateString']?.toString() ?? '';
      List<dynamic> clientsTrips = entryData['clientsTrips'] ?? [];

      WriteBatch batch = FirebaseFirestore.instance.batch();

      for (var clientTrip in clientsTrips) {
        String clientName = clientTrip['clientName']?.toString() ?? clientTrip['client']?.toString() ?? '';
        if (clientName.isEmpty) continue;

        double cubageVal = double.tryParse(clientTrip['totalCubage']?.toString() ?? '0') ?? 0.0;
        double priceSnap = double.tryParse(clientTrip['clientPriceSnapshot']?.toString() ?? '0') ?? 0.0;
        double financialValueToDeduct = cubageVal * priceSnap;

        if (financialValueToDeduct > 0) {
          DocumentReference accountRef = FirebaseFirestore.instance.collection('client_accounts').doc(clientName);
          batch.set(accountRef, {
            'balance': FieldValue.increment(-financialValueToDeduct),
            'lastUpdate': FieldValue.serverTimestamp()
          }, SetOptions(merge: true));
        }

        QuerySnapshot transSnap = await FirebaseFirestore.instance
            .collection('client_transactions')
            .where('clientName', isEqualTo: clientName)
            .where('driverName', isEqualTo: driverName)
            .where('dateString', isEqualTo: dateString)
            .get();

        for (var doc in transSnap.docs) {
          batch.delete(doc.reference);
        }
      }

      batch.delete(entryDoc.reference);
      await batch.commit();
    }
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
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator(color: Color(0xFF0F2A52))),
      );

      if (_currentDocId != null) {
        await _rollbackSingleEntry(_currentDocId!);
        _currentDocId = null;
      }

      WriteBatch batch = FirebaseFirestore.instance.batch();
      CollectionReference entriesRef = FirebaseFirestore.instance.collection('daily_entries');
      CollectionReference clientAccountsRef = FirebaseFirestore.instance.collection('client_accounts');
      CollectionReference clientTransactionsRef = FirebaseFirestore.instance.collection('client_transactions');

      String formattedDateForLog = '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}';

      double unitPrice = _selectedSite == 'old'
          ? (_isTractor ? _clientPriceOldTractor : _clientPriceOldTruck)
          : (_isTractor ? _clientPriceNewTractor : _clientPriceNewTruck);

      for (var t in _clientTrips) {
        String clientName = t['client'].toString().trim();
        String engTrips = _normalizeArabic(t['trips'].toString());
        int clientTripsCount = int.tryParse(engTrips) ?? 1;

        if (clientName.isEmpty || clientTripsCount <= 0) continue;

        double tripsCubageForClient = clientTripsCount * _cubage;
        double financialValue = tripsCubageForClient * unitPrice;

        DocumentReference accountRef = clientAccountsRef.doc(clientName);
        batch.set(accountRef, {
          'clientName': clientName,
          'balance': FieldValue.increment(financialValue),
          'lastUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        DocumentReference transDoc = clientTransactionsRef.doc();
        batch.set(transDoc, {
          'clientName': clientName,
          'dateString': formattedDateForLog,
          'timestamp': FieldValue.serverTimestamp(),
          'driverName': _driverName,
          'carNumber': _normalizeArabic(_selectedVehicleNumber),
          'site': _selectedSite,
          'tripsCount': clientTripsCount,
          'totalCubage': tripsCubageForClient,
          'unitPrice': unitPrice,
          'totalValue': financialValue,
          'type': 'debit',
          'description': 'توريد عدد $clientTripsCount نقلة (إدخال يدوي)',
        });

        DocumentReference entryDocRef = entriesRef.doc();
        batch.set(entryDocRef, {
          'site': _selectedSite,
          'driverName': _driverName,
          'vehicleNumber': _normalizeArabic(_selectedVehicleNumber),
          'dateString': formattedDateForLog,
          'date': Timestamp.fromDate(_selectedDate),
          'timestamp': FieldValue.serverTimestamp(),
          'clientNamesList': [clientName],
          'clientsTrips': [{
            'clientName': clientName,
            'tripsCount': clientTripsCount,
            'totalCubage': tripsCubageForClient,
            'cubage': _cubage,
            'clientPriceSnapshot': unitPrice,
            'officePriceSnapshot': _defaultOfficePrice,
          }],
          'cubage': _cubage,
          'totalCubage': tripsCubageForClient,
          'isTractor': _isTractor,
          'typeCode': _typeCode,
          'isAiGenerated': false,
        });
      }

      await batch.commit();

      if (!mounted) return false;
      Navigator.pop(context);

      setState(() {
        _currentDocId = null;
        _resetVehicleFieldsOnly();
        _clientTrips.clear();
        _isReadOnly = false;
      });

      _showMessage('تم حفظ البيان وترحيل الحسابات بنجاح', const Color(0xFF28A745));
      return true;

    } catch (e) {
      if (!mounted) return false;
      Navigator.pop(context);
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
        content: Text(_isArabic ? 'هل أنت متأكد من حذف هذا البيان وعكس قيوده المالية بالكامل؟' : 'Are you sure you want to delete this entry and its transactions?', style: const TextStyle(fontFamily: 'Cairo')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(_isArabic ? 'إلغاء' : 'Cancel', style: const TextStyle(fontFamily: 'Cairo'))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(_isArabic ? 'حذف وعكس القيود' : 'Delete', style: const TextStyle(color: Colors.red, fontFamily: 'Cairo'))),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator(color: Color(0xFF0F2A52))),
      );

      await _rollbackSingleEntry(_currentDocId!);

      if (!mounted) return;
      Navigator.pop(context);

      setState(() {
        _currentDocId = null;
        _resetVehicleFieldsOnly();
        _clientTrips.clear();
        _isReadOnly = false;
      });
      _showMessage(_isArabic ? 'تم الحذف وعكس القيود المالية بنجاح' : 'Entry Deleted Successfully.', Colors.red.shade700);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showMessage('Error: $e', Colors.red.shade700);
    }
  }

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
              if (!canLeave || !mounted) return;
              Navigator.pop(context);
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
// 🔥 شاشة "السجل المدمج" بالهندسة والتعديل المباشر 🔥
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

  String _formatArabicDateString(String dateString) {
    try {
      var parts = dateString.split('/');
      if (parts.length == 3) {
        String day = _toArabicNumbers(parts[0].padLeft(2, '0'));
        String month = _toArabicNumbers(parts[1].padLeft(2, '0'));
        String year = _toArabicNumbers(parts[2]);

        int d = int.tryParse(parts[0]) ?? 1;
        int m = int.tryParse(parts[1]) ?? 1;
        int y = int.tryParse(parts[2]) ?? 2026;
        DateTime dt = DateTime(y, m, d);

        const weekdays = ['الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
        String dayName = weekdays[dt.weekday - 1];

        return '$dayName - $day / $month / $year';
      }
    } catch (_) {}
    return _toArabicNumbers(dateString);
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
            'سجل اليوميات (${widget.selectedSite == 'old' ? 'القديم' : 'الجديد'})',
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(8.0),
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
                    builder: (context, child) {
                      return Theme(
                        data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF0F2A52))),
                        child: Directionality(textDirection: TextDirection.rtl, child: child!),
                      );
                    },
                  );
                  if (picked != null) setState(() => _selectedDateRange = picked);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(6)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.date_range, size: 18, color: Color(0xFF4A78B9)),
                      const SizedBox(width: 8),
                      const Text('من: ', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold)),
                      _buildStrictDateText(_selectedDateRange.start),
                      const SizedBox(width: 15),
                      const Text('إلى: ', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold)),
                      _buildStrictDateText(_selectedDateRange.end),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('daily_entries')
                      .where('site', isEqualTo: widget.selectedSite)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFF0F2A52)));
                    if (snapshot.hasError) return const Center(child: Text('حدث خطأ', style: TextStyle(fontFamily: 'Cairo', color: Colors.red)));

                    final docs = snapshot.data?.docs ?? const [];
                    if (docs.isEmpty) return const Center(child: Text('لا توجد بيانات', style: TextStyle(fontFamily: 'Cairo')));

                    var filteredDocs = docs.where((doc) {
                      var data = doc.data() as Map<String, dynamic>;
                      final docDate = _extractEntryDate(data);
                      if (docDate == null) return false;
                      DateTime cleanDocDate = DateTime(docDate.year, docDate.month, docDate.day);
                      DateTime cleanStart = DateTime(_selectedDateRange.start.year, _selectedDateRange.start.month, _selectedDateRange.start.day);
                      DateTime cleanEnd = DateTime(_selectedDateRange.end.year, _selectedDateRange.end.month, _selectedDateRange.end.day);
                      return cleanDocDate.compareTo(cleanStart) >= 0 && cleanDocDate.compareTo(cleanEnd) <= 0;
                    }).toList();

                    if (filteredDocs.isEmpty) return const Center(child: Text('لا توجد بيانات في الفترة المحددة', style: TextStyle(fontFamily: 'Cairo')));

                    Map<String, List<DocumentSnapshot>> groupedByDate = {};
                    for (var doc in filteredDocs) {
                      var data = doc.data() as Map<String, dynamic>;
                      String dString = data['dateString']?.toString() ?? 'بدون تاريخ';
                      if (!groupedByDate.containsKey(dString)) groupedByDate[dString] = [];
                      groupedByDate[dString]!.add(doc);
                    }

                    List<String> sortedDates = groupedByDate.keys.toList()..sort((a, b) {
                      var partsA = a.split('/'); var partsB = b.split('/');
                      if (partsA.length == 3 && partsB.length == 3) {
                        DateTime dA = DateTime(int.parse(partsA[2]), int.parse(partsA[1]), int.parse(partsA[0]));
                        DateTime dB = DateTime(int.parse(partsB[2]), int.parse(partsB[1]), int.parse(partsB[0]));
                        return dB.compareTo(dA);
                      }
                      return 0;
                    });

                    return ListView.builder(
                      itemCount: sortedDates.length,
                      itemBuilder: (context, index) {
                        String dateTitle = sortedDates[index];
                        List<DocumentSnapshot> dayDocs = groupedByDate[dateTitle]!;

                        dayDocs.sort((a, b) {
                          var dataA = a.data() as Map<String, dynamic>;
                          var dataB = b.data() as Map<String, dynamic>;

                          List<dynamic> tripsA = dataA['clientsTrips'] ?? [];
                          String clientA = tripsA.isNotEmpty ? (tripsA[0]['clientName']?.toString() ?? '') : '';

                          List<dynamic> tripsB = dataB['clientsTrips'] ?? [];
                          String clientB = tripsB.isNotEmpty ? (tripsB[0]['clientName']?.toString() ?? '') : '';

                          if (clientA == 'بخيت' && clientB != 'بخيت') return -1;
                          if (clientB == 'بخيت' && clientA != 'بخيت') return 1;
                          if (clientA == 'عادل' && clientB != 'عادل') return -1;
                          if (clientB == 'عادل' && clientA != 'عادل') return 1;

                          bool isTractorA = dataA['isTractor'] == true;
                          bool isTractorB = dataB['isTractor'] == true;
                          if (isTractorA && !isTractorB) return -1;
                          if (!isTractorA && isTractorB) return 1;

                          return 0;
                        });

                        String formattedArabicDateTitle = _formatArabicDateString(dateTitle);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 3,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                decoration: const BoxDecoration(color: Color(0xFF0F2A52), borderRadius: BorderRadius.vertical(top: Radius.circular(10))),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Center(
                                  child: Text('يومية: $formattedArabicDateTitle', style: const TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
                                ),
                              ),
                              Container(
                                color: Colors.grey.shade200,
                                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                child: const Row(
                                  children: [
                                    Expanded(flex: 3, child: Text('السائق', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                                    Expanded(flex: 3, child: Text('العربية', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                                    Expanded(flex: 2, child: Text('م٣', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                                    Expanded(flex: 3, child: Text('العميل', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                                    Expanded(flex: 2, child: Text('نقلات', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                                  ],
                                ),
                              ),
                              ...dayDocs.map((doc) {
                                var data = doc.data() as Map<String, dynamic>;

                                String driver = data['driverName']?.toString() ?? '';
                                String vehicle = _toArabicNumbers(data['vehicleNumber']?.toString() ?? '');
                                double cubageVal = double.tryParse((data['cubage'] ?? 0).toString()) ?? 0.0;
                                String cubage = _toArabicNumbers(cubageVal.toInt().toString());

                                List<dynamic> trips = data['clientsTrips'] ?? [];
                                String client = trips.isNotEmpty ? (trips[0]['clientName']?.toString() ?? '') : '';
                                String tripsCount = _toArabicNumbers(trips.isNotEmpty ? (trips[0]['tripsCount']?.toString() ?? '0') : '0');

                                Color rowColor = Colors.transparent;
                                if (client == 'بخيت') {
                                  rowColor = const Color(0xFFE3F2FD);
                                } else if (client == 'عادل') {
                                  rowColor = const Color(0xFFE8F5E9);
                                }

                                return InkWell(
                                  onTap: () {
                                    widget.onLoadEntry(doc);
                                    Navigator.pop(context);
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                        color: rowColor,
                                        border: Border(bottom: BorderSide(color: Colors.grey.shade300))
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                    child: Row(
                                      children: [
                                        Expanded(flex: 3, child: Text(driver, style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.black87), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis)),
                                        Expanded(flex: 3, child: Text(vehicle, style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4A78B9)), textAlign: TextAlign.center)),
                                        Expanded(flex: 2, child: Text(cubage, style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.black87), textAlign: TextAlign.center)),
                                        Expanded(flex: 3, child: Text(client, style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.black87), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis)),
                                        Expanded(flex: 2, child: Text(tripsCount, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF28A745)), textAlign: TextAlign.center)),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
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