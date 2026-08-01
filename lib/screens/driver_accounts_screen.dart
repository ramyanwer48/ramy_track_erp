import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'driver_details_screen.dart';

class DriverAccountsScreen extends StatefulWidget {
  const DriverAccountsScreen({super.key});

  @override
  State<DriverAccountsScreen> createState() => _DriverAccountsScreenState();
}

class _DriverAccountsScreenState extends State<DriverAccountsScreen> {

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

  Future<void> _showAddDriverDialog() async {
    TextEditingController nameCtrl = TextEditingController();
    TextEditingController numCtrl = TextEditingController();
    TextEditingController cubageCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Row(
            children: [
              Icon(Icons.person_add_alt_1, color: Color(0xFF0F2A52)),
              SizedBox(width: 8),
              Text('إضافة سائق شركة (Z)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم السائق', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: numCtrl, decoration: const InputDecoration(labelText: 'رقم المركبة', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: cubageCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'التكعيب (م³)', border: OutlineInputBorder())),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF28A745)),
              onPressed: () async {
                if (nameCtrl.text.isNotEmpty && numCtrl.text.isNotEmpty && cubageCtrl.text.isNotEmpty) {
                  double cubage = double.tryParse(cubageCtrl.text) ?? 0.0;
                  String docId = numCtrl.text.trim().replaceAll('/', '-').replaceAll(' ', '');

                  await FirebaseFirestore.instance.collection('vehicles').doc(docId).set({
                    'name': nameCtrl.text.trim(),
                    'number': numCtrl.text.trim(),
                    'cubage': cubage,
                    'typeCode': 'Z',
                  }, SetOptions(merge: true));

                  if (mounted) Navigator.pop(ctx);
                }
              },
              child: const Text('حفظ السائق', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold)),
            )
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
          title: const Text('حسابات سائقي الشركة', style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF0F2A52),
          centerTitle: true,
          elevation: 0,
          leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('vehicles').where('typeCode', isEqualTo: 'Z').snapshots(),
          builder: (context, vehiclesSnap) {
            return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('settings').snapshots(),
                builder: (context, settingsSnap) {
                  return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('daily_entries').snapshots(),
                      builder: (context, tripsSnap) {
                        return StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance.collection('driver_payments').snapshots(),
                            builder: (context, paymentsSnap) {

                              if (!vehiclesSnap.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF0F2A52)));

                              double oldSiteRate = 40.0;
                              double newSiteRate = 34.0;
                              if (settingsSnap.hasData) {
                                for (var doc in settingsSnap.data!.docs) {
                                  var data = doc.data() as Map<String, dynamic>;
                                  if (doc.id == 'old_site_globals') oldSiteRate = double.tryParse(data['سعر سائقين الشركة']?.toString() ?? '40') ?? 40.0;
                                  if (doc.id == 'new_site_globals') newSiteRate = double.tryParse(data['سعر سائقين الشركة']?.toString() ?? '34') ?? 34.0;
                                }
                              }

                              List<Map<String, dynamic>> driversList = [];
                              double totalDriversDueAll = 0.0;

                              for (var vDoc in vehiclesSnap.data!.docs) {
                                var vData = vDoc.data() as Map<String, dynamic>;
                                String driverName = vData['name'] ?? '';
                                String vehicleNum = vData['number'] ?? '';
                                String targetNorm = _normalizeArabic(driverName);

                                double totalDues = 0.0;
                                double totalPayments = 0.0;
                                int totalTripsCount = 0;

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

                                      totalTripsCount += entryTrips;
                                      double entryTotal = totalEntryCubage > 0 ? (totalEntryCubage * (rate / (vehicleCubage > 0 ? vehicleCubage : 1))) : (entryTrips * rate);
                                      totalDues += entryTotal;
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
                                totalDriversDueAll += netRemaining;

                                driversList.add({
                                  'name': driverName,
                                  'number': vehicleNum,
                                  'due': netRemaining,
                                  'active': totalTripsCount > 0,
                                });
                              }

                              return Column(
                                children: [
                                  // 1. الكروت العلوية (إجمالي المديونية + عدد السائقين) مطابقة لتصميم العملاء
                                  Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.all(14),
                                            decoration: BoxDecoration(
                                              color: Colors.red.shade600,
                                              borderRadius: BorderRadius.circular(12),
                                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text('إجمالي المستحقات', style: TextStyle(fontFamily: 'Cairo', color: Colors.white70, fontSize: 11)),
                                                const SizedBox(height: 4),
                                                FittedBox(
                                                  child: Text(
                                                    '${totalDriversDueAll.toStringAsFixed(0)} ج.م',
                                                    style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.all(14),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(12),
                                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
                                              border: Border.all(color: Colors.grey.shade200),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text('عدد السائقين', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey, fontSize: 11)),
                                                const SizedBox(height: 4),
                                                Text(
                                                  driversList.length.toString(),
                                                  style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF0F2A52)),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // 2. زرار إضافة سائق + عنوان القسم
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 4.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        ElevatedButton.icon(
                                          onPressed: _showAddDriverDialog,
                                          icon: const Icon(Icons.add, color: Colors.white, size: 18),
                                          label: const Text('إضافة سائق', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF28A745),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                            elevation: 0,
                                          ),
                                        ),
                                        const Text('سجل السائقين', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F2A52))),
                                      ],
                                    ),
                                  ),

                                  // 3. شبكة كروت السائقين مطابقة للعملاء تماماً
                                  Expanded(
                                    child: driversList.isEmpty
                                        ? const Center(child: Text('لا يوجد سائقين شركة مسجلين.', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)))
                                        : GridView.builder(
                                      padding: const EdgeInsets.all(12),
                                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        crossAxisSpacing: 10,
                                        mainAxisSpacing: 10,
                                        childAspectRatio: 1.2,
                                      ),
                                      itemCount: driversList.length,
                                      itemBuilder: (context, index) {
                                        var driver = driversList[index];
                                        bool hasDue = driver['due'] > 0;

                                        return InkWell(
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(builder: (context) => DriverDetailsScreen(driverName: driver['name'], vehicleNumber: driver['number'])),
                                            );
                                          },
                                          borderRadius: BorderRadius.circular(12),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(12),
                                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 5, offset: const Offset(0, 2))],
                                              // الإطار الملون فوق الكارت (أحمر لو عليه فلوس، أخضر لو خالص زي العملاء)
                                              border: Border(
                                                top: BorderSide(color: hasDue ? Colors.red.shade600 : Colors.green.shade600, width: 4),
                                                right: BorderSide(color: Colors.grey.shade200),
                                                left: BorderSide(color: Colors.grey.shade200),
                                                bottom: BorderSide(color: Colors.grey.shade200),
                                              ),
                                            ),
                                            padding: const EdgeInsets.all(12),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  driver['name'],
                                                  style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F2A52)),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                Row(
                                                  children: [
                                                    const Icon(Icons.account_balance_wallet_outlined, size: 14, color: Colors.grey),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      hasDue ? '${driver['due'].toStringAsFixed(0)} ج.م' : 'خالص',
                                                      style: TextStyle(
                                                        fontFamily: 'Cairo',
                                                        fontWeight: FontWeight.w900,
                                                        fontSize: 13,
                                                        color: hasDue ? Colors.red.shade700 : Colors.green.shade700,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                Row(
                                                  children: [
                                                    const Icon(Icons.access_time, size: 13, color: Colors.grey),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      driver['active'] ? 'آخر شغل: نشط' : 'آخر شغل: لم يبدأ بعد',
                                                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 10, color: Colors.grey),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              );
                            }
                        );
                      }
                  );
                }
            );
          },
        ),
      ),
    );
  }
}