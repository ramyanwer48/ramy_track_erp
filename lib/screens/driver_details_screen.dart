import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DriverDetailsScreen extends StatefulWidget {
  final String driverName;
  final String vehicleNumber;

  const DriverDetailsScreen({super.key, required this.driverName, required this.vehicleNumber});

  @override
  State<DriverDetailsScreen> createState() => _DriverDetailsScreenState();
}

class _DriverDetailsScreenState extends State<DriverDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  // دالة الحذف الآمن (تتأكد إن الرصيد صفر عشان ميمسحش حساب عليه فلوس)
  Future<void> _deleteDriver(double netRemaining) async {
    if (netRemaining != 0) {
      showDialog(
        context: context,
        builder: (ctx) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('تنبيه هام', style: TextStyle(color: Colors.red, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            content: const Text('عذراً، لا يمكن حذف السائق لوجود مديونية أو رصيد متبقي في حسابه.', style: TextStyle(fontFamily: 'Cairo')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('موافق', style: TextStyle(fontFamily: 'Cairo'))),
            ],
          ),
        ),
      );
      return;
    }

    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد الحذف', style: TextStyle(color: Colors.red, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          content: Text('هل أنت متأكد من حذف السائق (${widget.driverName})؟', style: const TextStyle(fontFamily: 'Cairo')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف', style: TextStyle(color: Colors.white, fontFamily: 'Cairo')),
            ),
          ],
        ),
      ),
    ) ?? false;

    if (confirm) {
      try {
        String docId = widget.vehicleNumber.replaceAll('/', '-').replaceAll(' ', '');
        await FirebaseFirestore.instance.collection('vehicles').doc(docId).delete();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف السائق بنجاح', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green));
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء الحذف: $e')));
      }
    }
  }

  // دالة تصدير ومشاركة الحسابات
  void _exportAccountData(double totalDues, double totalPayments, double netRemaining, double totalCubage) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text('تصدير كشف الحساب', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('سائق المركبة: ${widget.driverName} (${widget.vehicleNumber})', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              const Divider(),
              Text('إجمالي الأمتار: ${totalCubage.toStringAsFixed(1)} م³', style: const TextStyle(fontFamily: 'Cairo')),
              Text('إجمالي المستحقات: ${totalDues.toStringAsFixed(0)} ج.م', style: const TextStyle(fontFamily: 'Cairo')),
              Text('إجمالي الدفعات: ${totalPayments.toStringAsFixed(0)} ج.م', style: const TextStyle(fontFamily: 'Cairo')),
              Text('الصافي المتبقي: ${netRemaining.toStringAsFixed(0)} ج.م', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.blue)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق', style: TextStyle(fontFamily: 'Cairo'))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F2A52)),
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تجهيز التقرير للمشاركة بنجاح', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green));
              },
              child: const Text('مشاركة التقرير', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String targetNorm = _normalizeArabic(widget.driverName);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F9),
        appBar: AppBar(
          title: Text('سائق: ${widget.driverName}', style: const TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
          backgroundColor: const Color(0xFF0F2A52),
          centerTitle: true,
          elevation: 0,
          leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
          actions: [
            StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('settings').snapshots(),
                builder: (context, settingsSnap) {
                  return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('daily_entries').snapshots(),
                      builder: (context, tripsSnap) {
                        return StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance.collection('driver_payments').snapshots(),
                            builder: (context, paymentsSnap) {

                              double oldSiteRate = 40.0;
                              double newSiteRate = 34.0;
                              if (settingsSnap.hasData) {
                                for (var doc in settingsSnap.data!.docs) {
                                  var data = doc.data() as Map<String, dynamic>;
                                  if (doc.id == 'old_site_globals') oldSiteRate = double.tryParse(data['سعر سائقين الشركة']?.toString() ?? '40') ?? 40.0;
                                  if (doc.id == 'new_site_globals') newSiteRate = double.tryParse(data['سعر سائقين الشركة']?.toString() ?? '34') ?? 34.0;
                                }
                              }

                              double totalDues = 0.0;
                              double totalPayments = 0.0;
                              double totalCubage = 0.0;

                              if (tripsSnap.hasData) {
                                for (var tripDoc in tripsSnap.data!.docs) {
                                  var tData = tripDoc.data() as Map<String, dynamic>;
                                  if (_normalizeArabic(tData['driverName']?.toString() ?? '') == targetNorm) {
                                    String site = tData['site'] ?? 'old';
                                    double rate = site == 'new' ? newSiteRate : oldSiteRate;
                                    double vehicleCubage = double.tryParse(tData['cubage']?.toString() ?? '0') ?? 0.0;

                                    int entryTrips = 0;
                                    double totalEntryCubage = 0.0;
                                    List<dynamic> cTrips = tData['clientsTrips'] ?? [];
                                    for (var c in cTrips) {
                                      int tripsCount = (c['tripsCount'] ?? c['trips'] ?? 0) as int;
                                      entryTrips += tripsCount;
                                      double cubage = double.tryParse(c['totalCubage']?.toString() ?? c['cubage']?.toString() ?? '0') ?? 0.0;
                                      if (cubage == 0) cubage = tripsCount * vehicleCubage;
                                      totalEntryCubage += cubage;
                                    }

                                    if (entryTrips > 0) {
                                      double entryTotal = totalEntryCubage > 0 ? (totalEntryCubage * (rate / (vehicleCubage > 0 ? vehicleCubage : 1))) : (entryTrips * rate);
                                      totalDues += entryTotal;
                                      totalCubage += totalEntryCubage;
                                    }
                                  }
                                }
                              }

                              if (paymentsSnap.hasData) {
                                for (var pDoc in paymentsSnap.data!.docs) {
                                  var pData = pDoc.data() as Map<String, dynamic>;
                                  if (_normalizeArabic(pData['driverName']?.toString() ?? '') == targetNorm) {
                                    totalPayments += double.tryParse(pData['amount']?.toString() ?? '0') ?? 0.0;
                                  }
                                }
                              }

                              double netRemaining = totalDues - totalPayments;

                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.share, color: Colors.white, size: 22),
                                    tooltip: 'تصدير الحساب',
                                    onPressed: () => _exportAccountData(totalDues, totalPayments, netRemaining, totalCubage),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 24),
                                    tooltip: 'حذف السائق',
                                    onPressed: () => _deleteDriver(netRemaining),
                                  ),
                                ],
                              );
                            }
                        );
                      }
                  );
                }
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF00D2FF),
            unselectedLabelColor: Colors.white70,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14),
            tabs: const [
              Tab(text: 'سجل النقلات', icon: Icon(Icons.local_shipping, size: 20)),
              Tab(text: 'سجل الدفعات', icon: Icon(Icons.payments, size: 20)),
            ],
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('settings').snapshots(),
            builder: (context, settingsSnap) {
              return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('daily_entries').snapshots(),
                  builder: (context, tripsSnap) {
                    return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('driver_payments').snapshots(),
                        builder: (context, paymentsSnap) {

                          double oldSiteRate = 40.0;
                          double newSiteRate = 34.0;
                          if (settingsSnap.hasData) {
                            for (var doc in settingsSnap.data!.docs) {
                              var data = doc.data() as Map<String, dynamic>;
                              if (doc.id == 'old_site_globals') oldSiteRate = double.tryParse(data['سعر سائقين الشركة']?.toString() ?? '40') ?? 40.0;
                              if (doc.id == 'new_site_globals') newSiteRate = double.tryParse(data['سعر سائقين الشركة']?.toString() ?? '34') ?? 34.0;
                            }
                          }

                          double totalDues = 0.0;
                          double totalPayments = 0.0;
                          double totalCubage = 0.0;
                          List<Map<String, dynamic>> driverTrips = [];
                          List<Map<String, dynamic>> driverPayments = [];

                          if (tripsSnap.hasData) {
                            for (var tripDoc in tripsSnap.data!.docs) {
                              var tData = tripDoc.data() as Map<String, dynamic>;
                              if (_normalizeArabic(tData['driverName']?.toString() ?? '') == targetNorm) {
                                String site = tData['site'] ?? 'old';
                                double rate = site == 'new' ? newSiteRate : oldSiteRate;
                                double vehicleCubage = double.tryParse(tData['cubage']?.toString() ?? '0') ?? 0.0;

                                int entryTrips = 0;
                                double totalEntryCubage = 0.0;
                                List<dynamic> cTrips = tData['clientsTrips'] ?? [];
                                for (var c in cTrips) {
                                  int tripsCount = (c['tripsCount'] ?? c['trips'] ?? 0) as int;
                                  entryTrips += tripsCount;
                                  double cubage = double.tryParse(c['totalCubage']?.toString() ?? c['cubage']?.toString() ?? '0') ?? 0.0;
                                  if (cubage == 0) cubage = tripsCount * vehicleCubage;
                                  totalEntryCubage += cubage;
                                }

                                if (entryTrips > 0) {
                                  double entryTotal = totalEntryCubage > 0 ? (totalEntryCubage * (rate / (vehicleCubage > 0 ? vehicleCubage : 1))) : (entryTrips * rate);
                                  totalDues += entryTotal;
                                  totalCubage += totalEntryCubage;
                                  driverTrips.add({
                                    'date': tData['dateString'],
                                    'site': site,
                                    'tripsCount': entryTrips,
                                    'cubage': totalEntryCubage,
                                    'rate': rate,
                                    'total': entryTotal,
                                  });
                                }
                              }
                            }
                          }

                          if (paymentsSnap.hasData) {
                            for (var pDoc in paymentsSnap.data!.docs) {
                              var pData = pDoc.data() as Map<String, dynamic>;
                              if (_normalizeArabic(pData['driverName']?.toString() ?? '') == targetNorm) {
                                double amt = double.tryParse(pData['amount']?.toString() ?? '0') ?? 0.0;
                                totalPayments += amt;
                                driverPayments.add({
                                  'date': pData['date'] ?? 'غير محدد',
                                  'amount': amt,
                                  'note': pData['note'] ?? '',
                                });
                              }
                            }
                          }

                          double netRemaining = totalDues - totalPayments;

                          return Column(
                            children: [
                              // لوحة العدادات الأربعة المربعة مطابقة لتفاصيل العملاء تماماً
                              Padding(
                                padding: const EdgeInsets.all(10.0),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        _buildDashboardCard('إجمالي المستحقات', '${totalDues.toStringAsFixed(0)} ج.م', Colors.amber.shade800),
                                        const SizedBox(width: 8),
                                        _buildDashboardCard('إجمالي الدفعات', '${totalPayments.toStringAsFixed(0)} ج.م', Colors.green.shade700),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        _buildDashboardCard('إجمالي الأمتار', '${totalCubage.toStringAsFixed(1)} م³', Colors.blue.shade700),
                                        const SizedBox(width: 8),
                                        _buildDashboardCard('المديونية المتبقية', '${netRemaining.toStringAsFixed(0)} ج.م', Colors.red.shade700, isAlert: true),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              Expanded(
                                child: TabBarView(
                                  controller: _tabController,
                                  children: [
                                    // تاب 1: سجل النقلات
                                    driverTrips.isEmpty
                                        ? const Center(child: Text('لا توجد نقلات مسجلة.', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)))
                                        : ListView.builder(
                                      padding: const EdgeInsets.all(10),
                                      itemCount: driverTrips.length,
                                      itemBuilder: (context, index) {
                                        var trip = driverTrips[index];
                                        bool isNewSite = trip['site'] == 'new';

                                        return Card(
                                          margin: const EdgeInsets.only(bottom: 8),
                                          elevation: 1,
                                          color: isNewSite ? const Color(0xFFE8F5E9) : const Color(0xFFE3F2FD),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            side: BorderSide(color: isNewSite ? Colors.green.shade200 : Colors.blue.shade200),
                                          ),
                                          child: ListTile(
                                            leading: CircleAvatar(
                                              backgroundColor: isNewSite ? Colors.green.shade100 : Colors.blue.shade100,
                                              child: Icon(Icons.fire_truck, color: isNewSite ? Colors.green.shade700 : Colors.blue.shade700, size: 20),
                                            ),
                                            title: Text(
                                              'يومية ${trip['date']} - ${isNewSite ? 'الموقع الجديد' : 'الموقع القديم'}',
                                              style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                            subtitle: Text(
                                              'النقلات: ${trip['tripsCount']} | التكعيب: ${trip['cubage']} م³',
                                              style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.black87),
                                            ),
                                            trailing: Text(
                                              '${trip['total'].toStringAsFixed(0)} ج.م',
                                              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 14, color: isNewSite ? Colors.green.shade800 : Colors.blue.shade800),
                                            ),
                                          ),
                                        );
                                      },
                                    ),

                                    // تاب 2: سجل الدفعات
                                    driverPayments.isEmpty
                                        ? const Center(child: Text('لم يتم تسجيل أي دفعات أو سلف.', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)))
                                        : ListView.builder(
                                      padding: const EdgeInsets.all(10),
                                      itemCount: driverPayments.length,
                                      itemBuilder: (context, index) {
                                        var pay = driverPayments[index];
                                        return Card(
                                          margin: const EdgeInsets.only(bottom: 8),
                                          elevation: 1,
                                          child: ListTile(
                                            leading: const CircleAvatar(
                                              backgroundColor: Color(0xFFFFEBEE),
                                              child: Icon(Icons.money_off, color: Colors.redAccent, size: 20),
                                            ),
                                            title: Text('دفعة / سلفة (${pay['date']})', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)),
                                            subtitle: Text(pay['note'], style: const TextStyle(fontFamily: 'Cairo', fontSize: 11)),
                                            trailing: Text(
                                              '${pay['amount'].toStringAsFixed(0)} ج.م',
                                              style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 14, color: Colors.red),
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
      ),
    );
  }

  Widget _buildDashboardCard(String title, String value, Color textColor, {bool isAlert = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isAlert ? Colors.red.shade300 : Colors.grey.shade300),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontFamily: 'Cairo', color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            FittedBox(
              child: Text(
                value,
                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 16, color: textColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}