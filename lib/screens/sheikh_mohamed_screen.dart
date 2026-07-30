import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SheikhMohamedScreen extends StatefulWidget {
  const SheikhMohamedScreen({super.key});

  @override
  State<SheikhMohamedScreen> createState() => _SheikhMohamedScreenState();
}

class _SheikhMohamedScreenState extends State<SheikhMohamedScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _paymentMethods = ['كاش', 'فودافون كاش', 'إنستاباي', 'تحويل بنكي', 'شيك بنكي'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _toArabicNumbers(String text) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    for (int i = 0; i < english.length; i++) {
      text = text.replaceAll(english[i], arabic[i]);
    }
    return text;
  }

  String _formatNumber(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }

  String _formatFullDate(DateTime d) => '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

  // 1. نافذة تسجيل دفعة جديدة (تمت استعادة الـ Dropdown مع تثبيت الشاشة من جذورها)
  void _showAddPaymentDialog() {
    final TextEditingController amountController = TextEditingController();
    String? selectedMethod;
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(
            children: [
              Icon(Icons.payments, color: Color(0xFF28A745)),
              SizedBox(width: 8),
              Text('تسجيل دفعة للشيخ محمد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          content: StatefulBuilder(
              builder: (ctx, setStateDialog) {
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: 'قيمة الدفعة',
                          suffixText: 'ج.م',
                          border: OutlineInputBorder(),
                          isDense: true,
                          prefixIcon: Icon(Icons.attach_money),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                          prefixIcon: Icon(Icons.payment, color: Colors.grey),
                        ),
                        hint: const Text('طريقة التحويل', style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                        items: _paymentMethods.map((m) => DropdownMenuItem(value: m, child: Text(m, style: TextStyle(fontFamily: 'Cairo', fontSize: 12)))).toList(),
                        onChanged: (val) => selectedMethod = val,
                        menuMaxHeight: 180,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          DateTime? picked = await showDatePicker(
                            context: ctx,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                            builder: (context, child) => Theme(
                              data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF28A745))),
                              child: child!,
                            ),
                          );
                          if (picked != null) {
                            setStateDialog(() => selectedDate = picked);
                          }
                        },
                        icon: const Icon(Icons.calendar_month, size: 18, color: Color(0xFF28A745)),
                        label: Text('تاريخ الدفعة: ${_toArabicNumbers(_formatFullDate(selectedDate))}', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.black87)),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 42),
                          side: const BorderSide(color: Colors.grey),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                );
              }
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey))),
            ElevatedButton(
              onPressed: () async {
                if (amountController.text.isNotEmpty) {
                  double amount = double.tryParse(amountController.text) ?? 0.0;
                  await FirebaseFirestore.instance.collection('settlements').add({
                    'type': 'sheikh_payment',
                    'name': 'الشيخ محمد',
                    'amount': amount,
                    'paymentMethod': selectedMethod ?? 'كاش',
                    'dateString': _formatFullDate(selectedDate),
                    'timestamp': FieldValue.serverTimestamp(),
                  });
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسجيل الدفعة بنجاح', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)), backgroundColor: Colors.green));
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF28A745)),
              child: const Text('حفظ وتسديد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // 2. نافذة تعديل أو حذف دفعة سابقة
  void _showEditOrDeletePaymentDialog(String docId, Map<String, dynamic> paymentData) {
    final TextEditingController amountController = TextEditingController(text: paymentData['amount']?.toString() ?? '');
    String? selectedMethod = paymentData['paymentMethod'] ?? 'كاش';
    String dateStr = paymentData['dateString'] ?? _formatFullDate(DateTime.now());

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(
            children: [
              Icon(Icons.edit_note, color: Color(0xFF0F2A52)),
              SizedBox(width: 8),
              Text('تعديل أو حذف الدفعة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'قيمة الدفعة',
                    suffixText: 'ج.م',
                    border: OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _paymentMethods.contains(selectedMethod) ? selectedMethod : 'كاش',
                  decoration: const InputDecoration(
                    labelText: 'طريقة التحويل',
                    border: OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: Icon(Icons.payment, color: Colors.grey),
                  ),
                  items: _paymentMethods.map((m) => DropdownMenuItem(value: m, child: Text(m, style: TextStyle(fontFamily: 'Cairo', fontSize: 12)))).toList(),
                  onChanged: (val) => selectedMethod = val,
                  menuMaxHeight: 180,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month, size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text('التاريخ المسجل: ${_toArabicNumbers(dateStr)}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                // تأكيد الحذف
                bool? confirm = await showDialog(
                  context: context,
                  builder: (context) => Directionality(
                    textDirection: TextDirection.rtl,
                    child: AlertDialog(
                      title: const Text('تأكيد الحذف', style: TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold)),
                      content: const Text('هل أنت متأكد من حذف هذه الدفعة نهائياً؟', style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          child: const Text('حذف', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                );

                if (confirm == true) {
                  await FirebaseFirestore.instance.collection('settlements').doc(docId).delete();
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف الدفعة بنجاح', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red));
                  }
                }
              },
              child: const Text('حذف الدفعة', style: TextStyle(fontFamily: 'Cairo', color: Colors.red, fontWeight: FontWeight.bold)),
            ),
            const Spacer(),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey))),
            ElevatedButton(
              onPressed: () async {
                if (amountController.text.isNotEmpty) {
                  double amount = double.tryParse(amountController.text) ?? 0.0;
                  await FirebaseFirestore.instance.collection('settlements').doc(docId).update({
                    'amount': amount,
                    'paymentMethod': selectedMethod,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تعديل الدفعة بنجاح', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)), backgroundColor: Colors.blue));
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F2A52)),
              child: const Text('حفظ التعديل', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
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
          title: const Text('حساب الشيخ محمد', style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF0F2A52),
          centerTitle: true,
          elevation: 0,
          leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
          bottom: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF00D2FF),
            unselectedLabelColor: Colors.white70,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12),
            tabs: const [
              Tab(text: 'أمتار الجرارات', icon: Icon(Icons.local_shipping, size: 18)),
              Tab(text: 'سجل الدفعات', icon: Icon(Icons.receipt_long, size: 18)),
            ],
          ),
        ),

        body: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('settings').doc('sheikh_settings').snapshots(),
            builder: (context, settingsSnapshot) {
              double meterPrice = 22.0;

              if (settingsSnapshot.hasData && settingsSnapshot.data!.exists) {
                var data = settingsSnapshot.data!.data() as Map<String, dynamic>?;
                if (data != null && data.containsKey('tractorRate')) {
                  meterPrice = double.tryParse(data['tractorRate'].toString()) ?? 22.0;
                }
              }

              return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('daily_entries').snapshots(),
                  builder: (context, tripsSnapshot) {

                    return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('settlements').where('type', isEqualTo: 'sheikh_payment').snapshots(),
                        builder: (context, paymentsSnapshot) {

                          double totalTractorMeters = 0.0;
                          List<Map<String, dynamic>> tractorTrips = [];

                          if (tripsSnapshot.hasData) {
                            for (var doc in tripsSnapshot.data!.docs) {
                              var data = doc.data() as Map<String, dynamic>;

                              String clientName = (data['clientName'] ?? data['client_name'] ?? '').toString().trim();
                              String carType = (data['carType'] ?? data['vehicleType'] ?? data['type'] ?? '').toString().trim();

                              if ((clientName.contains('بخيت') || clientName.contains('عادل')) && (carType.contains('جرار') || carType.contains('جرارات'))) {
                                tractorTrips.add(data);
                                double cubage = double.tryParse(data['totalCubage']?.toString() ?? data['cubage']?.toString() ?? '0') ?? 0.0;
                                totalTractorMeters += cubage;
                              }
                            }
                          }

                          double totalDues = totalTractorMeters * meterPrice;

                          double totalPayments = 0.0;
                          List<QueryDocumentSnapshot> paymentsDocs = [];
                          if (paymentsSnapshot.hasData) {
                            paymentsDocs = paymentsSnapshot.data!.docs;
                            for (var doc in paymentsDocs) {
                              var pData = doc.data() as Map<String, dynamic>;
                              totalPayments += double.tryParse(pData['amount']?.toString() ?? '0') ?? 0.0;
                            }
                          }

                          // ترتيب القائمة حسب التاريخ أو الوّقت تصاعدياً أو تنازلياً
                          paymentsDocs.sort((a, b) => (b['timestamp']?.millisecondsSinceEpoch ?? 0).compareTo(a['timestamp']?.millisecondsSinceEpoch ?? 0));

                          double netRemaining = totalDues - totalPayments;
                          bool isClear = netRemaining <= 0;

                          return Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                color: Colors.white,
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        _buildDashCard('مستحقات (سعر $meterPrice ج)', totalDues, Colors.amber.shade900, Icons.account_balance_wallet),
                                        const SizedBox(width: 8),
                                        _buildDashCard('إجمالي الدفعات', totalPayments, Colors.green.shade700, Icons.payments),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: isClear ? Colors.green.shade50 : Colors.red.shade50,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: isClear ? Colors.green.shade700 : Colors.red.shade700, width: 1.5),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('المتبقي للشيخ محمد', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: isClear ? Colors.green.shade700 : Colors.red.shade700)),
                                                const SizedBox(height: 4),
                                                Text('${_toArabicNumbers(_formatNumber(netRemaining))} ج.م', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w900, color: isClear ? Colors.green.shade700 : Colors.red.shade700)),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        _buildDashCard('إجمالي الأمتار', totalTractorMeters, const Color(0xFF4A78B9), Icons.local_shipping, suffix: ' م³'),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              Expanded(
                                child: TabBarView(
                                  controller: _tabController,
                                  children: [
                                    tractorTrips.isEmpty
                                        ? const Center(child: Text('لا يوجد شغل جرارات مسجل حتى الآن', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)))
                                        : ListView.builder(
                                      padding: const EdgeInsets.all(10),
                                      itemCount: tractorTrips.length,
                                      itemBuilder: (context, index) {
                                        var trip = tractorTrips[index];
                                        String dateStr = trip['dateString'] ?? trip['date'] ?? '';
                                        String cubage = trip['totalCubage']?.toString() ?? trip['cubage']?.toString() ?? '0';
                                        return Card(
                                          child: ListTile(
                                            leading: const CircleAvatar(backgroundColor: Color(0xFF4A78B9), child: Icon(Icons.local_shipping, color: Colors.white, size: 18)),
                                            title: Text('العميل: ${trip['clientName'] ?? 'غير محدد'} | السائق: ${trip['driverName'] ?? ''}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold)),
                                            subtitle: Text('التاريخ: $dateStr', style: const TextStyle(fontFamily: 'Cairo', fontSize: 10)),
                                            trailing: Text('${_toArabicNumbers(cubage)} م³', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
                                          ),
                                        );
                                      },
                                    ),

                                    paymentsDocs.isEmpty
                                        ? const Center(child: Text('لم يتم تسجيل أي دفعات للشيخ محمد', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)))
                                        : ListView.builder(
                                      padding: const EdgeInsets.all(10),
                                      itemCount: paymentsDocs.length,
                                      itemBuilder: (context, index) {
                                        var doc = paymentsDocs[index];
                                        var p = doc.data() as Map<String, dynamic>;
                                        String displayDate = p['dateString'] ?? (p['timestamp'] != null ? _formatFullDate((p['timestamp'] as Timestamp).toDate()) : 'بدون تاريخ');

                                        return Card(
                                          child: ListTile(
                                            onTap: () => _showEditOrDeletePaymentDialog(doc.id, p), // النقر لتعديل أو حذف الدفعة
                                            leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.attach_money, color: Colors.white, size: 18)),
                                            title: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text('المبلغ: ${_toArabicNumbers(p['amount'].toString())} ج.م', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
                                                const Icon(Icons.edit, size: 16, color: Colors.grey),
                                              ],
                                            ),
                                            subtitle: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const SizedBox(height: 4),
                                                Text('طريقة الدفع: ${p['paymentMethod'] ?? 'كاش'}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.grey)),
                                                Text('التاريخ: ${_toArabicNumbers(displayDate)}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
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
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showAddPaymentDialog,
          backgroundColor: const Color(0xFF0F2A52),
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('صرف دفعة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      ),
    );
  }

  Widget _buildDashCard(String title, double amount, Color color, IconData icon, {String suffix = ''}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 4),
                Text(title, style: TextStyle(fontFamily: 'Cairo', fontSize: 10, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
            const SizedBox(height: 6),
            Text('${_toArabicNumbers(_formatNumber(amount))}$suffix', style: TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
      ),
    );
  }
}