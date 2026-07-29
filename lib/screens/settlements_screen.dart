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

  // دالة الحفظ والتسميع المباشر في قاعدة البيانات
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

      if (type == 'client_payment' || type == 'quality_discount') {
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
          const SnackBar(content: Text('تم الحفظ والتسميع بنجاح', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء الحفظ: $e', style: const TextStyle(fontFamily: 'Cairo'))),
        );
      }
    }
  }

  // 1. نافذة دفعات السائقين (بحث ذكي)
  void _showDriverPaymentDialog() {
    String? selectedDriver;
    final TextEditingController amountController = TextEditingController();
    String? selectedMethod;

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
              }

              List<String> driversList = [];
              int scannedDocs = 0;
              String debugKeys = "";

              if (snapshot.hasData && snapshot.data != null) {
                scannedDocs = snapshot.data!.docs.length;
                for (var doc in snapshot.data!.docs) {
                  var data = doc.data() as Map<String, dynamic>?;
                  if (data != null) {
                    debugKeys = data.keys.join(", ");
                    // بحث ذكي يتجاهل المسافات وحالة الأحرف
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
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('لا يوجد سائقين\n(تم فحص $scannedDocs سجلات)\nالحقول المتاحة: $debugKeys', textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Cairo', color: Colors.red, fontSize: 11)),
                );
              }

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, prefixIcon: Icon(Icons.person, color: Colors.grey)),
                      hint: const Text('اختر اسم السائق', style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                      items: driversList.map((name) => DropdownMenuItem(value: name, child: Text(name, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12)))).toList(),
                      onChanged: (val) => selectedDriver = val,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: 'المبلغ', suffixText: 'ج.م', border: OutlineInputBorder(), isDense: true, prefixIcon: Icon(Icons.attach_money)),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, prefixIcon: Icon(Icons.payment, color: Colors.grey)),
                      hint: const Text('طريقة التحويل', style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                      items: _paymentMethods.map((method) => DropdownMenuItem(value: method, child: Text(method, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12)))).toList(),
                      onChanged: (val) => selectedMethod = val,
                    ),
                  ],
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
                    paymentMethod: selectedMethod ?? 'كاش',
                  );
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF28A745)),
              child: const Text('حفظ وتسديد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // 2. نافذة دفعات العملاء (بحث ذكي مضاعف)
  void _showClientPaymentDialog() {
    String? selectedClient;
    final TextEditingController amountController = TextEditingController();
    String? selectedMethod;

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
              }

              List<String> clientsList = [];
              int scannedDocs = 0;
              String debugKeys = "";

              if (snapshot.hasData && snapshot.data != null) {
                scannedDocs = snapshot.data!.docs.length;
                for (var doc in snapshot.data!.docs) {
                  var data = doc.data() as Map<String, dynamic>?;
                  if (data != null) {
                    debugKeys = data.keys.join(", ");

                    // البحث الذكي في الحقول الأساسية
                    for (var key in data.keys) {
                      if (key.trim().toLowerCase() == 'clientname' || key.trim().toLowerCase() == 'client_name') {
                        String clientName = data[key].toString().trim();
                        if (clientName.isNotEmpty && !clientsList.contains(clientName)) {
                          clientsList.add(clientName);
                        }
                      }

                      // البحث الاحتياطي لو متسجلة جوه مصفوفة clientsTrips القديمة
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
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('لا يوجد عملاء\n(تم فحص $scannedDocs سجلات)\nالحقول المتاحة: $debugKeys', textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Cairo', color: Colors.red, fontSize: 11)),
                );
              }

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, prefixIcon: Icon(Icons.business, color: Colors.grey)),
                      hint: const Text('اختر اسم العميل', style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                      items: clientsList.map((name) => DropdownMenuItem(value: name, child: Text(name, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12)))).toList(),
                      onChanged: (val) => selectedClient = val,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: 'المبلغ', suffixText: 'ج.م', border: OutlineInputBorder(), isDense: true, prefixIcon: Icon(Icons.attach_money)),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, prefixIcon: Icon(Icons.payment, color: Colors.grey)),
                      hint: const Text('طريقة التحويل', style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                      items: _paymentMethods.map((method) => DropdownMenuItem(value: method, child: Text(method, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12)))).toList(),
                      onChanged: (val) => selectedMethod = val,
                    ),
                  ],
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
                    paymentMethod: selectedMethod ?? 'كاش',
                  );
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF198754)),
              child: const Text('حفظ وتسديد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // 3. قائمة خيارات الموقع (شاملة العهدة واللودر والخصم)
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
                Text('تسويات: $siteName', style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                const Divider(),
                ListTile(
                  leading: CircleAvatar(backgroundColor: Colors.blue.shade50, child: Icon(Icons.receipt_long, color: Colors.blue.shade700)),
                  title: const Text('إضافة عهدة / مصروف مكتب', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                  subtitle: const Text('يخصم من حساب المكتب', style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: Colors.grey)),
                  onTap: () {
                    Navigator.pop(context);
                    _showGenericInputDialog(title: 'إضافة عهدة مكتب', hintText: 'الغرض من العهدة', icon: Icons.receipt_long, color: color, siteName: siteName, type: 'office_expense');
                  },
                ),
                ListTile(
                  leading: CircleAvatar(backgroundColor: Colors.orange.shade50, child: Icon(Icons.front_loader, color: Colors.orange.shade700)),
                  title: const Text('إضافة حساب لودر (عدد الأمتار × 15 ج)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                  subtitle: const Text('يخصم من المكتب لتحديد ربح الموقع', style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: Colors.grey)),
                  onTap: () {
                    Navigator.pop(context);
                    _showLoaderInputDialog(color: color, siteName: siteName);
                  },
                ),
                ListTile(
                  leading: CircleAvatar(backgroundColor: Colors.purple.shade50, child: Icon(Icons.verified, color: Colors.purple.shade700)),
                  title: const Text('إضافة خصم جودة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                  subtitle: const Text('يخصم من المكتب لصالح العميل', style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: Colors.grey)),
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

  void _showQualityDiscountDialog({required Color color, required String siteName}) {
    String? selectedClient;
    final TextEditingController amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              Icon(Icons.verified, color: color),
              const SizedBox(width: 8),
              Text('خصم جودة ($siteName)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: color)),
            ],
          ),
          content: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('daily_entries').snapshots(),
            builder: (context, snapshot) {
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
                    }
                  }
                }
              }

              if (clientsList.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('لا يوجد عملاء مسجلين', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Cairo', color: Colors.red)),
                );
              }

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                      hint: const Text('اختر العميل المخصوم لصالحه', style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                      items: clientsList.map((item) => DropdownMenuItem(value: item, child: Text(item, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12)))).toList(),
                      onChanged: (val) => selectedClient = val,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: 'قيمة الخصم', suffixText: 'ج.م', border: OutlineInputBorder(), isDense: true),
                    ),
                  ],
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
                    type: 'quality_discount',
                    name: selectedClient!,
                    amount: amount,
                    siteName: siteName,
                  );
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: color),
              child: const Text('حفظ وتسديد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showLoaderInputDialog({required Color color, required String siteName}) {
    String? selectedLoader;
    final TextEditingController metersController = TextEditingController();
    ValueNotifier<double> calculatedTotal = ValueNotifier(0.0);

    void calculate(String value) {
      double meters = double.tryParse(value) ?? 0.0;
      calculatedTotal.value = meters * 15.0;
    }

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              Icon(Icons.front_loader, color: color),
              const SizedBox(width: 8),
              Text('حساب اللودر ($siteName)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: color)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                  hint: const Text('اختر فئة اللودر (G أو K)', style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                  items: _loadersDatabase.map((item) => DropdownMenuItem(value: item, child: Text(item, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12)))).toList(),
                  onChanged: (val) => selectedLoader = val,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: metersController,
                  keyboardType: TextInputType.number,
                  onChanged: calculate,
                  decoration: const InputDecoration(hintText: 'عدد الأمتار (م³)', suffixText: 'م³', border: OutlineInputBorder(), isDense: true),
                ),
                const SizedBox(height: 15),
                ValueListenableBuilder<double>(
                  valueListenable: calculatedTotal,
                  builder: (context, value, child) {
                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('إجمالي حساب اللودر:', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                          Text('${value.toStringAsFixed(0)} ج.م', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: color, fontSize: 16)),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey))),
            ElevatedButton(
              onPressed: () {
                if (selectedLoader != null && metersController.text.isNotEmpty) {
                  double meters = double.tryParse(metersController.text) ?? 0.0;
                  double totalAmount = meters * 15.0;
                  _saveTransactionToDatabase(
                    type: 'loader_account',
                    name: 'لودر ($selectedLoader) - $siteName',
                    amount: totalAmount,
                    siteName: siteName,
                  );
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: color),
              child: const Text('حفظ وتسديد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showGenericInputDialog({required String title, required String hintText, required IconData icon, required Color color, required String siteName, required String type}) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: color)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(hintText: hintText, border: const OutlineInputBorder(), isDense: true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: 'القيمة / المبلغ', suffixText: 'ج.م', border: OutlineInputBorder(), isDense: true),
                ),
              ],
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
                    type: type,
                    name: name,
                    amount: amount,
                    siteName: siteName,
                  );
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: color),
              child: const Text('حفظ وتسديد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
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
          title: const Text('الخصومات والتسويات', style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF0F2A52),
          centerTitle: true,
          elevation: 0,
          leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('تسويات عامة (شاملة)', style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F2A52))),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildActionCard(title: 'دفعات\nللسائقين', icon: Icons.engineering, color: const Color(0xFF4A78B9), onTap: _showDriverPaymentDialog),
                  const SizedBox(width: 10),
                  _buildActionCard(title: 'دفعات\nالعملاء', icon: Icons.account_balance_wallet, color: const Color(0xFF198754), onTap: _showClientPaymentDialog),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              const Text('تسويات المواقع (مصروفات وخصومات)', style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F2A52))),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildActionCard(title: 'تسويات\nالموقع القديم', icon: Icons.domain, color: const Color(0xFFD97706), onTap: () => _showSiteOptionsBottomSheet('الموقع القديم', const Color(0xFFD97706))),
                  const SizedBox(width: 10),
                  _buildActionCard(title: 'تسويات\nالموقع الجديد', icon: Icons.add_business, color: const Color(0xFF6F42C1), onTap: () => _showSiteOptionsBottomSheet('الموقع الجديد', const Color(0xFF6F42C1))),
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
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(radius: 26, backgroundColor: color.withOpacity(0.1), child: Icon(icon, size: 28, color: color)),
              const SizedBox(height: 12),
              Text(title, textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}