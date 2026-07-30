import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettlementsScreen extends StatefulWidget {
  const SettlementsScreen({super.key});

  @override
  State<SettlementsScreen> createState() => _SettlementsScreenState();
}

class _SettlementsScreenState extends State<SettlementsScreen> {
  final List<String> _paymentMethods = ['كاش', 'فودافون كاش', 'إنستاباي', 'تحويل بنكي', 'شيك بنكي'];
  final List<String> _loadersDatabase = ['G', 'K'];

  double _loaderPrice = 15.0;
  double _qualityPrice = 60.0;

  @override
  void initState() {
    super.initState();
    _fetchSettingsPrices();
  }

  Future<void> _fetchSettingsPrices() async {
    try {
      var snapshot = await FirebaseFirestore.instance.collection('settings').get();
      for (var doc in snapshot.docs) {
        if (doc.id == 'constants_old') {
          var data = doc.data();
          if (data['loader'] != null) {
            _loaderPrice = double.tryParse(data['loader'].toString()) ?? 15.0;
          }
          if (data['quality'] != null) {
            _qualityPrice = double.tryParse(data['quality'].toString()) ?? 60.0;
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching prices: $e");
    }
  }

  String _formatFullDate(DateTime d) => '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
  String _formatShortDate(DateTime d) => '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

  Future<void> _saveTransactionToDatabase({
    required String type,
    required String name,
    required double amount,
    String? paymentMethod,
    String? siteName,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('settlements').add({
        'type': type,
        'name': name,
        'amount': amount,
        'paymentMethod': paymentMethod ?? '',
        'siteName': siteName ?? 'عام',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (type == 'client_payment') {
        var clientQuery = await FirebaseFirestore.instance
            .collection('client_accounts')
            .where('clientName', isEqualTo: name)
            .get();

        if (clientQuery.docs.isNotEmpty) {
          var docId = clientQuery.docs.first.id;
          var currentBalance = (clientQuery.docs.first.data()['balance'] ?? 0.0) as double;
          await FirebaseFirestore.instance.collection('client_accounts').doc(docId).update({
            'balance': currentBalance - amount,
          });
        } else {
          await FirebaseFirestore.instance.collection('client_accounts').add({
            'clientName': name,
            'balance': -amount,
          });
        }
      } else if (type == 'driver_payment') {
        await FirebaseFirestore.instance.collection('driver_payments').add({
          'driverName': name,
          'amount': amount,
          'paymentMethod': paymentMethod,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم الحفظ بنجاح', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء الحفظ: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showDriverPaymentDialog() {
    String? selectedDriver;
    final TextEditingController amountController = TextEditingController();
    String selectedMethod = 'كاش';

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            title: const Row(
              children: [
                Icon(Icons.engineering, color: Color(0xFF4A78B9)),
                SizedBox(width: 8),
                Text('دفعات للسائقين', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('daily_entries').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
                }

                List<String> driversList = [];
                if (snapshot.hasData && snapshot.data != null) {
                  for (var doc in snapshot.data!.docs) {
                    var data = doc.data() as Map<String, dynamic>?;
                    if (data != null) {
                      for (var key in data.keys) {
                        if (key.trim().toLowerCase() == 'drivername' || key.trim().toLowerCase() == 'driver_name') {
                          String driver = data[key].toString().trim();
                          if (driver.isNotEmpty && !driversList.contains(driver)) {
                            driversList.add(driver);
                          }
                        }
                      }
                    }
                  }
                }

                if (driversList.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('لا يوجد سائقين مسجلين', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Cairo', color: Colors.red, fontSize: 13)),
                  );
                }

                return SizedBox(
                  width: MediaQuery.of(context).size.width * 0.8,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InputDecorator(
                          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, prefixIcon: Icon(Icons.person, color: Colors.grey)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isDense: true,
                              value: selectedDriver,
                              hint: const Text('اختر اسم السائق', style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                              items: driversList.map((name) => DropdownMenuItem(value: name, child: Text(name, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12)))).toList(),
                              onChanged: (val) => setStateDialog(() => selectedDriver = val),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: amountController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(hintText: 'المبلغ', suffixText: 'ج.م', border: OutlineInputBorder(), isDense: true, prefixIcon: Icon(Icons.attach_money)),
                        ),
                        const SizedBox(height: 12),
                        InputDecorator(
                          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, prefixIcon: Icon(Icons.payment, color: Colors.grey)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isDense: true,
                              value: selectedMethod,
                              items: _paymentMethods.map((method) => DropdownMenuItem(value: method, child: Text(method, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12)))).toList(),
                              onChanged: (val) => setStateDialog(() => selectedMethod = val ?? 'كاش'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey))),
              ElevatedButton(
                onPressed: () {
                  if (selectedDriver != null && amountController.text.isNotEmpty) {
                    double amount = double.tryParse(amountController.text) ?? 0.0;
                    _saveTransactionToDatabase(
                      type: 'driver_payment',
                      name: selectedDriver!,
                      amount: amount,
                      paymentMethod: selectedMethod,
                    );
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF28A745)),
                child: const Text('حفظ وتسديد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showClientPaymentDialog() {
    String? selectedClient;
    final TextEditingController amountController = TextEditingController();
    String selectedMethod = 'كاش';

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            title: const Row(
              children: [
                Icon(Icons.account_balance_wallet, color: Color(0xFF198754)),
                SizedBox(width: 8),
                Text('دفعات العملاء', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('daily_entries').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
                }

                List<String> clientsList = [];
                if (snapshot.hasData && snapshot.data != null) {
                  for (var doc in snapshot.data!.docs) {
                    var data = doc.data() as Map<String, dynamic>?;
                    if (data != null) {
                      for (var key in data.keys) {
                        if (key.trim().toLowerCase() == 'clientname' || key.trim().toLowerCase() == 'client_name') {
                          String clientName = data[key].toString().trim();
                          if (clientName.isNotEmpty && !clientsList.contains(clientName)) {
                            clientsList.add(clientName);
                          }
                        }
                        if (key.trim().toLowerCase() == 'clientstrips' && data[key] is List) {
                          for (var trip in data[key]) {
                            if (trip is Map) {
                              for(var tripKey in trip.keys) {
                                if (tripKey.toString().trim().toLowerCase() == 'clientname' || tripKey.toString().trim().toLowerCase() == 'client_name') {
                                  String clientName = trip[tripKey].toString().trim();
                                  if (clientName.isNotEmpty && !clientsList.contains(clientName)) {
                                    clientsList.add(clientName);
                                  }
                                }
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                }

                if (clientsList.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('لا يوجد عملاء مسجلين', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Cairo', color: Colors.red, fontSize: 13)),
                  );
                }

                return SizedBox(
                  width: MediaQuery.of(context).size.width * 0.8,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InputDecorator(
                          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, prefixIcon: Icon(Icons.business, color: Colors.grey)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isDense: true,
                              value: selectedClient,
                              hint: const Text('اختر اسم العميل', style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                              items: clientsList.map((name) => DropdownMenuItem(value: name, child: Text(name, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12)))).toList(),
                              onChanged: (val) => setStateDialog(() => selectedClient = val),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: amountController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(hintText: 'المبلغ', suffixText: 'ج.م', border: OutlineInputBorder(), isDense: true, prefixIcon: Icon(Icons.attach_money)),
                        ),
                        const SizedBox(height: 12),
                        InputDecorator(
                          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, prefixIcon: Icon(Icons.payment, color: Colors.grey)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isDense: true,
                              value: selectedMethod,
                              items: _paymentMethods.map((method) => DropdownMenuItem(value: method, child: Text(method, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12)))).toList(),
                              onChanged: (val) => setStateDialog(() => selectedMethod = val ?? 'كاش'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey))),
              ElevatedButton(
                onPressed: () {
                  if (selectedClient != null && amountController.text.isNotEmpty) {
                    double amount = double.tryParse(amountController.text) ?? 0.0;
                    _saveTransactionToDatabase(
                      type: 'client_payment',
                      name: selectedClient!,
                      amount: amount,
                      paymentMethod: selectedMethod,
                    );
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF198754)),
                child: const Text('حفظ وتسديد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSiteOptionsBottomSheet(String siteName, Color color) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 20, left: 10, right: 10),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('العهد والخصومات: $siteName', style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                const Divider(),
                ListTile(
                  leading: CircleAvatar(backgroundColor: Colors.blue.shade50, child: Icon(Icons.receipt_long, color: Colors.blue.shade700)),
                  title: const Text('إضافة عهدة مكتب', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                  subtitle: const Text('يخصم من حساب المكتب', style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: Colors.grey)),
                  onTap: () {
                    Navigator.pop(context);
                    _showOfficeExpenseDialog(color: color, siteName: siteName);
                  },
                ),
                ListTile(
                  leading: CircleAvatar(backgroundColor: Colors.orange.shade50, child: Icon(Icons.front_loader, color: Colors.orange.shade700)),
                  title: const Text('إضافة حساب لودر (تلقائي بالتاريخ)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                  subtitle: const Text('تجميع أمتار الفترة × السعر (يخصم من المكتب)', style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: Colors.grey)),
                  onTap: () {
                    Navigator.pop(context);
                    _showLoaderDateDialog(color: color, siteName: siteName);
                  },
                ),
                ListTile(
                  leading: CircleAvatar(backgroundColor: Colors.purple.shade50, child: Icon(Icons.verified, color: Colors.purple.shade700)),
                  title: const Text('إضافة خصم جودة (بالأمتار)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                  subtitle: const Text('يخصم من المكتب (قيمة الأمتار × السعر)', style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: Colors.grey)),
                  onTap: () {
                    Navigator.pop(context);
                    _showQualityDiscountDialog(color: color, siteName: siteName);
                  },
                ),
                const SizedBox(height: 15),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showOfficeExpenseDialog({required Color color, required String siteName}) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController amountController = TextEditingController();
    String selectedMethod = 'كاش';

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            title: Row(
              children: [
                Icon(Icons.receipt_long, color: color),
                const SizedBox(width: 8),
                Text('عهدة مكتب ($siteName)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: color)),
              ],
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(hintText: 'الغرض من العهدة', border: OutlineInputBorder(), isDense: true),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: 'القيمة', suffixText: 'ج.م', border: OutlineInputBorder(), isDense: true, prefixIcon: Icon(Icons.attach_money)),
                    ),
                    const SizedBox(height: 12),
                    InputDecorator(
                      decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, prefixIcon: Icon(Icons.payment, color: Colors.grey)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isDense: true,
                          value: selectedMethod,
                          items: _paymentMethods.map((method) => DropdownMenuItem(value: method, child: Text(method, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12)))).toList(),
                          onChanged: (val) => setStateDialog(() => selectedMethod = val ?? 'كاش'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey))),
              ElevatedButton(
                onPressed: () {
                  String name = nameController.text;
                  double amount = double.tryParse(amountController.text) ?? 0.0;
                  if (name.isNotEmpty && amount > 0) {
                    _saveTransactionToDatabase(
                      type: 'office_expense',
                      name: name,
                      amount: amount,
                      paymentMethod: selectedMethod,
                      siteName: siteName,
                    );
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: color),
                child: const Text('حفظ العهدة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLoaderDateDialog({required Color color, required String siteName}) {
    String? selectedLoader;
    DateTime? startDate;
    DateTime? endDate;
    ValueNotifier<double> totalMetersNotifier = ValueNotifier(0.0);
    ValueNotifier<double> totalAmountNotifier = ValueNotifier(0.0);
    ValueNotifier<bool> isCalculating = ValueNotifier(false);

    Future<void> calculateLoader(BuildContext dialogCtx) async {
      if (startDate == null || endDate == null || selectedLoader == null) return;
      isCalculating.value = true;
      double meters = 0.0;

      try {
        var snapshot = await FirebaseFirestore.instance.collection('daily_entries').get();
        for (var doc in snapshot.docs) {
          var data = doc.data();
          DateTime? docDate;
          if (data['timestamp'] != null) {
            docDate = (data['timestamp'] as Timestamp).toDate();
          }

          if (docDate != null && docDate.isAfter(startDate!.subtract(const Duration(days: 1))) && docDate.isBefore(endDate!.add(const Duration(days: 1)))) {
            double cubage = double.tryParse(data['totalCubage']?.toString() ?? data['cubage']?.toString() ?? '0') ?? 0.0;
            meters += cubage;
          }
        }

        totalMetersNotifier.value = meters;
        totalAmountNotifier.value = meters * _loaderPrice;
      } catch (e) {
        debugPrint("Error: $e");
      } finally {
        isCalculating.value = false;
      }
    }

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          title: Row(
            children: [
              Icon(Icons.front_loader, color: color),
              const SizedBox(width: 8),
              Text('حساب اللودر ($siteName)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: color)),
            ],
          ),
          content: StatefulBuilder(
              builder: (ctx, setStateDialog) {
                return SizedBox(
                  width: MediaQuery.of(context).size.width * 0.8,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InputDecorator(
                          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isDense: true,
                              value: selectedLoader,
                              hint: const Text('اختر فئة اللودر (G أو K)', style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                              items: _loadersDatabase.map((item) => DropdownMenuItem(value: item, child: Text(item, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12)))).toList(),
                              onChanged: (val) {
                                setStateDialog(() => selectedLoader = val);
                                calculateLoader(ctx);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () async {
                            DateTimeRange? picked = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                              builder: (context, child) => Theme(
                                data: Theme.of(context).copyWith(colorScheme: ColorScheme.light(primary: color)),
                                child: child!,
                              ),
                            );
                            if (!ctx.mounted) return;
                            if (picked != null) {
                              setStateDialog(() {
                                startDate = picked.start;
                                endDate = picked.end;
                              });
                              calculateLoader(ctx);
                            }
                          },
                          icon: const Icon(Icons.date_range, color: Colors.white, size: 18),
                          label: Text(
                            startDate == null ? 'تحديد فترة الحساب' : '${_formatFullDate(startDate!)} إلى ${_formatFullDate(endDate!)}',
                            style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 12),
                          ),
                          style: ElevatedButton.styleFrom(backgroundColor: color.withValues(alpha: 0.8), minimumSize: const Size(double.infinity, 40)),
                        ),
                        const SizedBox(height: 15),
                        ValueListenableBuilder<bool>(
                          valueListenable: isCalculating,
                          builder: (context, loading, child) {
                            if (loading) return const CircularProgressIndicator();
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withValues(alpha: 0.3))),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('إجمالي الأمتار:', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12)),
                                      Text('${totalMetersNotifier.value.toStringAsFixed(1)} م³', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: color)),
                                    ],
                                  ),
                                  const Divider(),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('الخصم من المكتب ($_loaderPrice ج):', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12)),
                                      Text('${totalAmountNotifier.value.toStringAsFixed(0)} ج.م', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, color: color, fontSize: 15)),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey))),
            ElevatedButton(
              onPressed: () {
                if (selectedLoader != null && totalAmountNotifier.value > 0) {
                  _saveTransactionToDatabase(
                    type: 'loader_account',
                    name: 'لودر ($selectedLoader) [${_formatShortDate(startDate!)} - ${_formatShortDate(endDate!)}]',
                    amount: totalAmountNotifier.value,
                    siteName: siteName,
                  );
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: color),
              child: const Text('حفظ واعتماد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showQualityDiscountDialog({required Color color, required String siteName}) {
    final TextEditingController metersController = TextEditingController();
    ValueNotifier<double> calculatedTotal = ValueNotifier(0.0);

    void calculate(String value) {
      double meters = double.tryParse(value) ?? 0.0;
      calculatedTotal.value = meters * _qualityPrice;
    }

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          title: Row(
            children: [
              Icon(Icons.verified, color: color),
              const SizedBox(width: 8),
              Text('خصم جودة ($siteName)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: color)),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: metersController,
                    keyboardType: TextInputType.number,
                    onChanged: calculate,
                    decoration: const InputDecoration(
                        hintText: 'عدد أمتار الخصم',
                        suffixText: 'م³',
                        border: OutlineInputBorder(),
                        isDense: true
                    ),
                  ),
                  const SizedBox(height: 15),
                  ValueListenableBuilder<double>(
                    valueListenable: calculatedTotal,
                    builder: (context, value, child) {
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: color.withValues(alpha: 0.3))
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('إجمالي الأمتار:', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12)),
                                Text('${metersController.text.isEmpty ? "0" : metersController.text} م³', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: color)),
                              ],
                            ),
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('الخصم من المكتب ($_qualityPrice ج):', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12)),
                                Text('${value.toStringAsFixed(0)} ج.م', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, color: color, fontSize: 15)),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey))),
            ElevatedButton(
              onPressed: () {
                if (calculatedTotal.value > 0) {
                  _saveTransactionToDatabase(
                    type: 'quality_discount',
                    name: 'خصم جودة - $siteName',
                    amount: calculatedTotal.value,
                    siteName: siteName,
                  );
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: color),
              child: const Text('حفظ وخصم', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
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
          title: const Text('الدفعات والخصومات', style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF0F2A52),
          centerTitle: true,
          elevation: 0,
          leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(
                child: Text('تسويات عامة (شاملة)', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F2A52))),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildActionCard(title: 'دفعات\nللسائقين', icon: Icons.engineering, color: const Color(0xFF4A78B9), onTap: _showDriverPaymentDialog),
                  const SizedBox(width: 12),
                  _buildActionCard(title: 'دفعات\nالعملاء', icon: Icons.account_balance_wallet, color: const Color(0xFF198754), onTap: _showClientPaymentDialog),
                ],
              ),
              const SizedBox(height: 30),
              const Divider(thickness: 1.5),
              const SizedBox(height: 20),
              const Text('العهد والخصومات', style: TextStyle(fontFamily: 'Cairo', fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F2A52))),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildActionCard(title: 'العهد والخصومات\nالموقع القديم', icon: Icons.domain, color: const Color(0xFFD97706), onTap: () => _showSiteOptionsBottomSheet('الموقع القديم', const Color(0xFFD97706))),
                  const SizedBox(width: 12),
                  _buildActionCard(title: 'العهد والخصومات\nالموقع الجديد', icon: Icons.add_business, color: const Color(0xFF6F42C1), onTap: () => _showSiteOptionsBottomSheet('الموقع الجديد', const Color(0xFF6F42C1))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard({required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 4))],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(height: 16),
              Text(title, textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.w900, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}