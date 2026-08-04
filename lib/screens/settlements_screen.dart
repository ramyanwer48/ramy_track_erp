import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'custom_bottom_nav.dart'; // <-- استدعاء شريط التنقل

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

  // الانتقال لشاشة دفعات السائقين المستقلة
  void _openDriverPaymentScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettlementFormScreen(
          title: 'دفعات للسائقين',
          type: 'driver_payment',
          fetchTargetField: 'driverName',
          paymentMethods: _paymentMethods,
        ),
      ),
    );
  }

  // الانتقال لشاشة دفعات العملاء المستقلة
  void _openClientPaymentScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettlementFormScreen(
          title: 'دفعات العملاء',
          type: 'client_payment',
          fetchTargetField: 'clientName',
          paymentMethods: _paymentMethods,
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
                onPressed: () async {
                  String name = nameController.text;
                  double amount = double.tryParse(amountController.text) ?? 0.0;
                  if (name.isNotEmpty && amount > 0) {
                    await _saveTransactionToDatabase(
                      type: 'office_expense',
                      name: name,
                      amount: amount,
                      paymentMethod: selectedMethod,
                      siteName: siteName,
                    );
                    if (!context.mounted) return;
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
    } catch (e) {
      debugPrint("Error saving transaction: $e");
    }
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
              onPressed: () async {
                if (selectedLoader != null && totalAmountNotifier.value > 0) {
                  await _saveTransactionToDatabase(
                    type: 'loader_account',
                    name: 'لودر ($selectedLoader) [${_formatShortDate(startDate!)} - ${_formatShortDate(endDate!)}]',
                    amount: totalAmountNotifier.value,
                    siteName: siteName,
                  );
                  if (!context.mounted) return;
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
                                Text('الخصم من المكتب ($_qualityPrice ج):', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12)),
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
              onPressed: () async {
                if (calculatedTotal.value > 0) {
                  await _saveTransactionToDatabase(
                    type: 'quality_discount',
                    name: 'خصم جودة - $siteName',
                    amount: calculatedTotal.value,
                    siteName: siteName,
                  );
                  if (!context.mounted) return;
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
          title: const Text('الخصومات والتسويات', style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold)),
          elevation: 0,
          centerTitle: true,
          automaticallyImplyLeading: false,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F2A52), Color(0xFF1E4885)],
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
              ),
            ),
          ),
        ),
        bottomNavigationBar: const CustomBottomNav(currentIndex: 4),
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
                  _buildActionCard(title: 'دفعات\nللسائقين', icon: Icons.engineering, color: const Color(0xFF4A78B9), onTap: _openDriverPaymentScreen),
                  const SizedBox(width: 12),
                  _buildActionCard(title: 'دفعات\nالعملاء', icon: Icons.account_balance_wallet, color: const Color(0xFF198754), onTap: _openClientPaymentScreen),
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

// ====================================================================
// شاشة مستقلة بالكامل (Full-Screen Form) لدفعات السائقين والعملاء (فلترة دقيقة للسائقين الفاعلين فقط)
// ====================================================================
class SettlementFormScreen extends StatefulWidget {
  final String title;
  final String type; // 'driver_payment' or 'client_payment'
  final String fetchTargetField; // 'driverName' or 'clientName'
  final List<String> paymentMethods;

  const SettlementFormScreen({
    super.key,
    required this.title,
    required this.type,
    required this.fetchTargetField,
    required this.paymentMethods,
  });

  @override
  State<SettlementFormScreen> createState() => _SettlementFormScreenState();
}

class _SettlementFormScreenState extends State<SettlementFormScreen> {
  String? _selectedName;
  final TextEditingController _amountController = TextEditingController();
  String _selectedMethod = 'كاش';
  bool _isLoadingNames = true;
  List<String> _namesList = [];

  @override
  void initState() {
    super.initState();
    _fetchNamesFromDatabase();
  }

  Future<void> _fetchNamesFromDatabase() async {
    try {
      var snapshot = await FirebaseFirestore.instance.collection('daily_entries').get();
      List<String> list = [];

      for (var doc in snapshot.docs) {
        var data = doc.data();

        if (widget.type == 'driver_payment') {
          // سحب أسماء السائقين الفعليين الذين ظهروا في حقول السائقين فقط
          for (var key in data.keys) {
            String lowerKey = key.trim().toLowerCase();
            if (lowerKey == 'drivername' || lowerKey == 'driver_name' || lowerKey == 'driver') {
              String name = data[key]?.toString().trim() ?? '';
              if (name.isNotEmpty && !list.contains(name)) {
                list.add(name);
              }
            }
          }
        } else {
          // سحب أسماء العملاء (شاملة الموقعين وبدون تغيير حسب رغبتك)
          for (var key in data.keys) {
            String lowerKey = key.trim().toLowerCase();
            if (lowerKey == 'clientname' || lowerKey == 'client_name') {
              String name = data[key]?.toString().trim() ?? '';
              if (name.isNotEmpty && !list.contains(name)) {
                list.add(name);
              }
            }
            if (lowerKey == 'clientstrips' && data[key] is List) {
              for (var trip in data[key]) {
                if (trip is Map) {
                  for (var tripKey in trip.keys) {
                    if (tripKey.toString().trim().toLowerCase() == 'clientname' || tripKey.toString().trim().toLowerCase() == 'client_name') {
                      String name = trip[tripKey]?.toString().trim() ?? '';
                      if (name.isNotEmpty && !list.contains(name)) {
                        list.add(name);
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _namesList = list;
          _isLoadingNames = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching names: $e");
      if (mounted) {
        setState(() => _isLoadingNames = false);
      }
    }
  }

  Future<void> _submitData() async {
    if (_selectedName == null || _amountController.text.isEmpty) return;
    double amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) return;

    try {
      await FirebaseFirestore.instance.collection('settlements').add({
        'type': widget.type,
        'name': _selectedName!,
        'amount': amount,
        'paymentMethod': _selectedMethod,
        'siteName': 'عام',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (widget.type == 'client_payment') {
        var clientQuery = await FirebaseFirestore.instance
            .collection('client_accounts')
            .where('clientName', isEqualTo: _selectedName)
            .get();

        if (clientQuery.docs.isNotEmpty) {
          var docId = clientQuery.docs.first.id;
          var currentBalance = (clientQuery.docs.first.data()['balance'] ?? 0.0) as double;
          await FirebaseFirestore.instance.collection('client_accounts').doc(docId).update({
            'balance': currentBalance - amount,
          });
        } else {
          await FirebaseFirestore.instance.collection('client_accounts').add({
            'clientName': _selectedName,
            'balance': -amount,
          });
        }
      } else if (widget.type == 'driver_payment') {
        await FirebaseFirestore.instance.collection('driver_payments').add({
          'driverName': _selectedName,
          'amount': amount,
          'paymentMethod': _selectedMethod,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;
      Navigator.pop(context); // العودة الصامتة بنظافة تامة
    } catch (e) {
      debugPrint("Error saving settlement: $e");
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color themeColor = widget.type == 'driver_payment' ? const Color(0xFF4A78B9) : const Color(0xFF198754);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F9),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F2A52),
          title: Text(widget.title, style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: _isLoadingNames
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.type == 'driver_payment' ? 'اختر اسم السائق' : 'اختر اسم العميل',
                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: themeColor, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const SeparatedEdgeInsets(), // handled by padding below
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedName,
                      hint: Text(widget.type == 'driver_payment' ? 'اختر السائق الذي اشتغل فقط' : 'اختر العميل من القائمة', style: const TextStyle(fontFamily: 'Cairo')),
                      isExpanded: true,
                      items: _namesList.map((name) => DropdownMenuItem(value: name, child: Text(name, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)))).toList(),
                      onChanged: (val) => setState(() => _selectedName = val),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('المبلغ (ج.م)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Color(0xFF0F2A52), fontSize: 14)),
              const SizedBox(height: 8),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                autofocus: false, // تم منع الفتح التلقائي للكيبورد
                decoration: const InputDecoration(
                  hintText: 'أدخل المبلغ',
                  suffixText: 'ج.م',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              const Text('طريقة التحويل', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Color(0xFF0F2A52), fontSize: 14)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedMethod,
                    isExpanded: true,
                    items: widget.paymentMethods.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedMethod = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _submitDate, // calling submit helper
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('حفظ وتسديد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper alias to match previous submit function name
  Future<void> _submitDate() async => _submitData();
}

class SeparatedEdgeInsets extends EdgeInsets {
  const SeparatedEdgeInsets() : super.all(0);
}