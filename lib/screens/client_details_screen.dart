import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  final Map<String, Map<String, double>> _fallbackPrices = {
    'بخيت': {'truck': 70.0, 'tractor': 100.0},
    'عادل': {'truck': 70.0, 'tractor': 100.0},
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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

  String _formatNumber(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }

  Future<void> _confirmAndDeleteClient() async {
    bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
              SizedBox(width: 8),
              Text('تحذير خطير بالحذف!', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.red, fontSize: 16)),
            ],
          ),
          content: Text('هل أنت متأكد تماماً من حذف العميل (${widget.clientName}) وكل سجلاته المالية؟ هذا الإجراء نهائي ولا يمكن التراجع عنه.', style: const TextStyle(fontFamily: 'Cairo', fontSize: 13)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('تراجع', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('تأكيد الحذف النهائي', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (confirmDelete == true) {
      try {
        var clientQuery = await FirebaseFirestore.instance.collection('clients').where('name', isEqualTo: widget.clientName).get();
        for (var doc in clientQuery.docs) {
          await FirebaseFirestore.instance.collection('clients').doc(doc.id).delete();
        }

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حذف العميل بنجاح تام', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)), backgroundColor: Colors.red),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ أثناء الحذف: $e', style: const TextStyle(fontFamily: 'Cairo'))),
          );
        }
      }
    }
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
              const Text('أدخل بريد العميل. سيتمكن من الدخول للمشاهدة فقط.', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey)),
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
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الإرسال بنجاح!', style: TextStyle(fontFamily: 'Cairo'))));
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF28A745)),
              child: const Text('إرسال دعوة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showExportMenu() { Navigator.pop(context); }

  @override
  Widget build(BuildContext context) {
    String clientCleanName = widget.clientName.trim();
    String targetNorm = _normalizeArabic(clientCleanName);

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
            IconButton(icon: const Icon(Icons.delete_forever, color: Colors.redAccent), tooltip: 'حذف العميل', onPressed: _confirmAndDeleteClient),
            IconButton(icon: const Icon(Icons.person_add_alt_1, color: Colors.white), tooltip: 'إضافة صلاحية', onPressed: _showAddClientAccessDialog),
            IconButton(icon: const Icon(Icons.ios_share, color: Colors.white), tooltip: 'تصدير', onPressed: _showExportMenu),
          ],
          bottom: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF00D2FF),
            unselectedLabelColor: Colors.white70,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12),
            tabs: const [
              Tab(text: 'سجل النقلات', icon: Icon(Icons.local_shipping, size: 18)),
              Tab(text: 'سجل الدفعات', icon: Icon(Icons.payments_outlined, size: 18)),
              Tab(text: 'الأرشيف المرفق', icon: Icon(Icons.folder_zip, size: 18)),
            ],
          ),
        ),

        // 1. جلب الأسعار من إعدادات الفايربيز
        body: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('settings').doc(clientCleanName).snapshots(),
            builder: (context, settingsSnapshot) {
              double truckPrice = 70.0;
              double tractorPrice = 100.0;

              if (settingsSnapshot.hasData && settingsSnapshot.data!.exists) {
                var data = settingsSnapshot.data!.data() as Map<String, dynamic>?;
                if (data != null) {
                  for (var entry in data.entries) {
                    String key = entry.key.toLowerCase();
                    double? val = double.tryParse(entry.value.toString());
                    if (val != null && val > 0) {
                      if (key.contains('truck') || key.contains('عربيات') || key.contains('سيارات')) {
                        truckPrice = val;
                      } else if (key.contains('tractor') || key.contains('جرار') || key.contains('جرارات')) {
                        tractorPrice = val;
                      }
                    }
                  }
                }
              }

              if (truckPrice == 70.0 && tractorPrice == 100.0) {
                for (var entry in _fallbackPrices.entries) {
                  if (_normalizeArabic(entry.key) == targetNorm) {
                    truckPrice = entry.value['truck']!;
                    tractorPrice = entry.value['tractor']!;
                    break;
                  }
                }
              }

              // 2. الاستماع اللحظي للبيان اليومي
              return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('daily_entries').snapshots(),
                  builder: (context, tripsSnapshot) {

                    // 3. جلب الدفعات
                    return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('settlements').where('name', isEqualTo: clientCleanName).where('type', isEqualTo: 'client_payment').snapshots(),
                        builder: (context, paymentsSnapshot) {

                          double totalTruckMeters = 0.0;
                          double totalTractorMeters = 0.0;
                          List<Map<String, dynamic>> clientTrips = [];

                          if (tripsSnapshot.hasData) {
                            for (var doc in tripsSnapshot.data!.docs) {
                              var data = doc.data() as Map<String, dynamic>;

                              // فحص دقيق واحترافي عبر حقل clientNamesList أو المصفوفة الفرعية clientsTrips
                              List<dynamic> namesList = data['clientNamesList'] ?? [];
                              bool matchesMain = namesList.any((n) => _normalizeArabic(n.toString()) == targetNorm);

                              List<dynamic> tripsList = data['clientsTrips'] ?? [];
                              for (var tripItem in tripsList) {
                                if (tripItem is Map) {
                                  String tripClientName = tripItem['clientName']?.toString() ?? tripItem['client']?.toString() ?? '';
                                  if (_normalizeArabic(tripClientName) == targetNorm || matchesMain) {
                                    // دمج بيانات البيان الرئيسي مع تفاصيل نقلة العميل المحددة
                                    Map<String, dynamic> combinedTrip = Map<String, dynamic>.from(data);
                                    combinedTrip.addAll(Map<String, dynamic>.from(tripItem));
                                    clientTrips.add(combinedTrip);

                                    double cubage = double.tryParse(tripItem['totalCubage']?.toString() ?? tripItem['cubage']?.toString() ?? '0') ?? 0.0;

                                    String detailsStr = '${data['vehicleNumber'] ?? ''} ${data['carType'] ?? ''} ${data['type'] ?? ''}'.toLowerCase();
                                    if (detailsStr.contains('جرار') || detailsStr.contains('tractor')) {
                                      totalTractorMeters += cubage;
                                    } else {
                                      totalTruckMeters += cubage;
                                    }
                                  }
                                }
                              }
                            }
                          }

                          double newWorkValue = (totalTruckMeters * truckPrice) + (totalTractorMeters * tractorPrice);
                          double totalSandMeters = totalTruckMeters + totalTractorMeters;

                          double totalPayments = 0.0;
                          List<Map<String, dynamic>> paymentDetails = [];
                          if (paymentsSnapshot.hasData) {
                            for (var doc in paymentsSnapshot.data!.docs) {
                              var pData = doc.data() as Map<String, dynamic>;
                              paymentDetails.add(pData);
                              totalPayments += double.tryParse(pData['amount']?.toString() ?? '0') ?? 0.0;
                            }
                          }

                          double netRemaining = newWorkValue - totalPayments;
                          bool isClear = netRemaining <= 0;

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
                                    Row(
                                      children: [
                                        _buildDashboardCard(
                                            'إجمالي المستحقات',
                                            newWorkValue,
                                            Colors.amber.shade900,
                                            Icons.account_balance_wallet,
                                            subtitle: '(عربيات: $truckPrice ج | جرارات: $tractorPrice ج)'
                                        ),
                                        const SizedBox(width: 8),
                                        _buildDashboardCard('إجمالي الدفعات', totalPayments, Colors.green.shade700, Icons.payments),
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
                                                Row(
                                                  children: [
                                                    Icon(Icons.warning_amber_rounded, size: 16, color: isClear ? Colors.green.shade700 : Colors.red.shade700),
                                                    const SizedBox(width: 4),
                                                    Text('المديونية المتبقية', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: isClear ? Colors.green.shade700 : Colors.red.shade700)),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${_toArabicNumbers(_formatNumber(netRemaining))} ج.م',
                                                  style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w900, color: isClear ? Colors.green.shade700 : Colors.red.shade700),
                                                ),
                                                const SizedBox(height: 2),
                                                const Text(
                                                  'الحساب صافي ولايف من الفايربيز',
                                                  style: TextStyle(fontFamily: 'Cairo', fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        _buildDashboardCard('إجمالي أمتار الرمل', totalSandMeters, const Color(0xFF4A78B9), Icons.layers, suffix: ' م³'),
                                      ],
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
                                          child: clientTrips.isEmpty
                                              ? _buildEmptyState(Icons.local_shipping_outlined, 'لم يتم تسجيل أي نقلات بعد')
                                              : ListView.builder(
                                            key: ValueKey(clientTrips.length),
                                            padding: const EdgeInsets.all(8),
                                            itemCount: clientTrips.length,
                                            itemBuilder: (context, index) {
                                              var trip = clientTrips[index];
                                              String formattedDate = _extractAndFormatDate(trip);

                                              String driver = trip['driverName'] ?? trip['driver'] ?? 'غير محدد';
                                              String carNo = trip['vehicleNumber'] ?? trip['carNumber'] ?? 'بدون رقم';
                                              String tripsCount = trip['tripsCount']?.toString() ?? trip['trips']?.toString() ?? '1';
                                              String cubage = trip['cubage']?.toString() ?? '0';
                                              String totalCubage = trip['totalCubage']?.toString() ?? cubage;

                                              String detailsStr = '$carNo ${trip['carType'] ?? ''} ${trip['type'] ?? ''}'.toLowerCase();
                                              String vehicleTypeLabel = (detailsStr.contains('جرار') || detailsStr.contains('tractor')) ? 'جرار' : 'عربية';

                                              return Card(
                                                margin: const EdgeInsets.only(bottom: 6),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                                child: Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                  child: Directionality(
                                                    textDirection: TextDirection.rtl,
                                                    child: FittedBox(
                                                      fit: BoxFit.scaleDown,
                                                      alignment: Alignment.centerRight,
                                                      child: Text(
                                                        '$formattedDate  |  $driver  |  $vehicleTypeLabel ${_toArabicNumbers(carNo)}  |  نقلات: ${_toArabicNumbers(tripsCount)}  |  تكعيب: ${_toArabicNumbers(cubage)}  |  الإجمالي: ${_toArabicNumbers(totalCubage)}م³',
                                                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF0F2A52)),
                                                      ),
                                                    ),
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
                                                  ),
                                                );
                                              },
                                            )
                                        ),
                                      ],
                                    ),

                                    // 3. الأرشيف المرفق
                                    Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.folder_zip, size: 60, color: Colors.grey),
                                          const SizedBox(height: 16),
                                          const Text('أرشيف العميل', style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F2A52))),
                                        ],
                                      ),
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

  Widget _buildDashboardCard(String title, double amount, Color color, IconData icon, {String suffix = '', String? subtitle}) {
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
                Text(title, style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
            const SizedBox(height: 6),
            FittedBox(
              child: Text(
                '${_toArabicNumbers(_formatNumber(amount))}$suffix',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w900, color: color),
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontFamily: 'Cairo', fontSize: 8.5, color: Colors.grey, fontWeight: FontWeight.bold)),
            ]
          ],
        ),
      ),
    );
  }
}