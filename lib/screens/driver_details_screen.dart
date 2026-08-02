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

  String _toArabicNumbers(String text) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    for (int i = 0; i < english.length; i++) {
      text = text.replaceAll(english[i], arabic[i]);
    }
    return text;
  }

  String _formatDate(String date) {
    if (date.isEmpty) return '';
    if (date.contains('/')) {
      List<String> parts = date.split('/');
      if (parts.length == 3) {
        if (parts[0].length == 4) {
          return '${parts[2]}-${parts[1]}-${parts[0]}';
        } else {
          return '${parts[0]}-${parts[1]}-${parts[2]}';
        }
      }
    }
    return date.replaceAll('/', '-');
  }

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

  Future<void> _deleteDriver(double netRemaining) async {
    if (netRemaining != 0) {
      if (!mounted) return;
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

        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف السائق بنجاح', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء الحذف: $e')));
      }
    }
  }

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
              Text('إجمالي الأمتار: ${_toArabicNumbers(totalCubage.toStringAsFixed(1))} م³', style: const TextStyle(fontFamily: 'Cairo')),
              Text('إجمالي المستحقات: ${_toArabicNumbers(totalDues.toStringAsFixed(0))} ج.م', style: const TextStyle(fontFamily: 'Cairo')),
              Text('إجمالي الدفعات: ${_toArabicNumbers(totalPayments.toStringAsFixed(0))} ج.م', style: const TextStyle(fontFamily: 'Cairo')),
              Text('الصافي المتبقي: ${_toArabicNumbers(netRemaining.toStringAsFixed(0))} ج.م', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.blue)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق', style: TextStyle(fontFamily: 'Cairo'))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F2A52)),
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم تجهيز التقرير للمشاركة بنجاح', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green),
                );
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
                                double entryTotal = totalEntryCubage * rate;
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
                      },
                    );
                  },
                );
              },
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
                      double totalOldSiteCubage = 0.0;
                      double totalNewSiteCubage = 0.0;

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

                            List<String> clientNames = [];
                            List<dynamic> cTrips = tData['clientsTrips'] ?? [];
                            for (var c in cTrips) {
                              int tripsCount = (c['tripsCount'] ?? c['trips'] ?? 0) as int;
                              entryTrips += tripsCount;
                              double cubage = double.tryParse(c['totalCubage']?.toString() ?? c['cubage']?.toString() ?? '0') ?? 0.0;
                              if (cubage == 0) cubage = tripsCount * vehicleCubage;
                              totalEntryCubage += cubage;

                              String cName = c['clientName'] ?? c['name'] ?? '';
                              if (cName.isNotEmpty && !clientNames.contains(cName)) {
                                clientNames.add(cName);
                              }
                            }

                            if (entryTrips > 0) {
                              double entryTotal = totalEntryCubage * rate;
                              totalDues += entryTotal;
                              totalCubage += totalEntryCubage;

                              if (site == 'new') {
                                totalNewSiteCubage += totalEntryCubage;
                              } else {
                                totalOldSiteCubage += totalEntryCubage;
                              }

                              String companiesStr = clientNames.join(' و ');
                              if (companiesStr.isEmpty) {
                                companiesStr = tData['clientName'] ?? tData['client_name'] ?? 'شركة غير محددة';
                              }

                              driverTrips.add({
                                'date': tData['dateString'],
                                'site': site,
                                'clientName': companiesStr,
                                'tripsCount': entryTrips,
                                'vehicleCubage': vehicleCubage,
                                'totalCubage': totalEntryCubage,
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

                      // المنطق المحاسبي الجديد لكارت المديونية المتبقية
                      Color netColor;
                      String netText;
                      if (netRemaining > 0) {
                        netColor = Colors.blue.shade700;
                        netText = 'له: ${_toArabicNumbers(netRemaining.toStringAsFixed(0))} ج.م';
                      } else if (netRemaining < 0) {
                        netColor = Colors.red.shade700;
                        netText = 'عليه: ${_toArabicNumbers(netRemaining.abs().toStringAsFixed(0))} ج.م';
                      } else {
                        netColor = Colors.green.shade700;
                        netText = 'خالص';
                      }

                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildDashboardCard(
                                        title: 'إجمالي المستحقات',
                                        value: '${_toArabicNumbers(totalDues.toStringAsFixed(0))} ج.م',
                                        textColor: Colors.amber.shade800,
                                        subTitle: 'قديم: ${_toArabicNumbers(oldSiteRate.toStringAsFixed(0))}ج | جديد: ${_toArabicNumbers(newSiteRate.toStringAsFixed(0))}ج',
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildDashboardCard(
                                        title: 'إجمالي الدفعات',
                                        value: '${_toArabicNumbers(totalPayments.toStringAsFixed(0))} ج.م',
                                        textColor: Colors.green.shade700,
                                        subTitle: 'المسجل في الدفعات',
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildDashboardCard(
                                        title: 'الرصيد الصافي',
                                        value: netText,
                                        textColor: netColor,
                                        isAlert: netRemaining < 0, // الإطار أحمر لو عليه فلوس بس
                                        subTitle: 'حالة حساب السائق',
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildDashboardCard(
                                        title: 'إجمالي الأمتار',
                                        value: '${_toArabicNumbers(totalCubage.toStringAsFixed(1))} م³',
                                        textColor: Colors.blue.shade700,
                                        subTitle: 'قديم: ${_toArabicNumbers(totalOldSiteCubage.toStringAsFixed(1))}م³ | جديد: ${_toArabicNumbers(totalNewSiteCubage.toStringAsFixed(1))}م³',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          Expanded(
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                driverTrips.isEmpty
                                    ? const Center(child: Text('لا توجد نقلات مسجلة.', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)))
                                    : ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  itemCount: driverTrips.length,
                                  itemBuilder: (context, index) {
                                    var trip = driverTrips[index];
                                    bool isNewSite = trip['site'] == 'new';
                                    String formattedDate = _formatDate(trip['date'].toString());

                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 6),
                                      elevation: 0.5,
                                      color: isNewSite ? const Color(0xFFE8F5E9) : const Color(0xFFE3F2FD),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                        side: BorderSide(color: isNewSite ? Colors.green.shade300 : Colors.blue.shade300, width: 1.0),
                                      ),
                                      child: ListTile(
                                        dense: true,
                                        visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                        leading: CircleAvatar(
                                          radius: 14,
                                          backgroundColor: isNewSite ? Colors.green.shade100 : Colors.blue.shade100,
                                          child: Icon(Icons.fire_truck, color: isNewSite ? Colors.green.shade700 : Colors.blue.shade700, size: 14),
                                        ),
                                        title: Text(
                                          '${_toArabicNumbers(formattedDate)} - ${isNewSite ? 'الموقع الجديد' : 'الموقع القديم'} - ${trip['clientName']}',
                                          style: TextStyle(
                                              fontFamily: 'Cairo',
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                              color: isNewSite ? Colors.green.shade900 : Colors.blue.shade900
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerRight,
                                          child: Text(
                                            'نقلات: ${_toArabicNumbers(trip['tripsCount'].toString())} | عربية: ${_toArabicNumbers(trip['vehicleCubage'].toString())}م³ | الإجمالي: ${_toArabicNumbers(trip['totalCubage'].toString())}م³',
                                            style: TextStyle(fontFamily: 'Cairo', fontSize: 9, color: Colors.grey.shade800, fontWeight: FontWeight.bold),
                                            maxLines: 1,
                                          ),
                                        ),
                                        trailing: Text(
                                          '${_toArabicNumbers(trip['total'].toStringAsFixed(0))} ج',
                                          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 12, color: isNewSite ? Colors.green.shade800 : Colors.blue.shade800),
                                        ),
                                      ),
                                    );
                                  },
                                ),

                                driverPayments.isEmpty
                                    ? const Center(child: Text('لم يتم تسجيل أي دفعات أو سلف.', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)))
                                    : ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  itemCount: driverPayments.length,
                                  itemBuilder: (context, index) {
                                    var pay = driverPayments[index];
                                    String formattedDate = _formatDate(pay['date'].toString());
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 6),
                                      elevation: 0.5,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6), side: BorderSide(color: Colors.red.shade100, width: 1.0)),
                                      child: ListTile(
                                        dense: true,
                                        visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                        leading: const CircleAvatar(
                                          radius: 14,
                                          backgroundColor: Color(0xFFFFEBEE),
                                          child: Icon(Icons.money_off, color: Colors.redAccent, size: 14),
                                        ),
                                        title: Text('دفعة / سلفة (${_toArabicNumbers(formattedDate)})', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 11)),
                                        subtitle: Text(pay['note'], style: const TextStyle(fontFamily: 'Cairo', fontSize: 9), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        trailing: Text(
                                          '${_toArabicNumbers(pay['amount'].toStringAsFixed(0))} ج',
                                          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 12, color: Colors.red),
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
                    },
                  );
                },
              );
            }
        ),
      ),
    );
  }

  Widget _buildDashboardCard({required String title, required String value, required Color textColor, bool isAlert = false, String? subTitle}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isAlert ? Colors.red.shade300 : Colors.grey.shade300),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2))],
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
          if (subTitle != null) ...[
            const SizedBox(height: 6),
            FittedBox(
              child: Text(
                subTitle,
                style: TextStyle(fontFamily: 'Cairo', color: Colors.grey.shade600, fontSize: 9, fontWeight: FontWeight.bold),
              ),
            ),
          ]
        ],
      ),
    );
  }
}