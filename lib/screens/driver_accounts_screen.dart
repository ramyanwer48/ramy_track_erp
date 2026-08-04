import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'driver_details_screen.dart';
import 'custom_bottom_nav.dart'; // استدعاء ملف الشريط الموحد

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

  String _toArabicNumbers(String text) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    for (int i = 0; i < english.length; i++) {
      text = text.replaceAll(english[i], arabic[i]);
    }
    return text;
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

                  if (ctx.mounted) Navigator.pop(ctx);
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
        ),
        // وضع الشريط السفلي في الشاشة الرئيسية مع تحديد الاندكس رقم 3 (السائقين)
        bottomNavigationBar: const CustomBottomNav(currentIndex: 3),
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

                                String driverName = vData['name'] ?? vData['driverName'] ?? '';
                                if (driverName.trim().isEmpty) driverName = 'سائق بدون اسم';

                                String vehicleNum = vData['number'] ?? '';
                                String targetNorm = _normalizeArabic(driverName);

                                double totalDues = 0.0;
                                double totalPayments = 0.0;
                                int totalTripsCount = 0;

                                if (tripsSnap.hasData) {
                                  for (var tripDoc in tripsSnap.data!.docs) {
                                    var tData = tripDoc.data() as Map<String, dynamic>;
                                    String tripDriver = tData['driverName'] ?? tData['driver'] ?? '';
                                    if (_normalizeArabic(tripDriver) == targetNorm) {
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
                                      double entryTotal = totalEntryCubage * rate;
                                      totalDues += entryTotal;
                                    }
                                  }
                                }

                                if (paymentsSnap.hasData) {
                                  for (var pDoc in paymentsSnap.data!.docs) {
                                    var pData = pDoc.data() as Map<String, dynamic>;
                                    String payDriver = pData['driverName'] ?? pData['driver'] ?? '';
                                    if (_normalizeArabic(payDriver) == targetNorm) {
                                      totalPayments += double.tryParse(pData['amount']?.toString() ?? '0') ?? 0.0;
                                    }
                                  }
                                }

                                double netRemaining = totalDues - totalPayments;
                                bool isActive = totalTripsCount > 0;

                                // فلترة ذكية: إذا كان السائق لم يعمل نهائياً وليس لديه رصيد أو مديونية، يتم استبعاده تماماً
                                if (!isActive && netRemaining == 0) {
                                  continue;
                                }

                                totalDriversDueAll += netRemaining;

                                driversList.add({
                                  'name': driverName,
                                  'number': vehicleNum,
                                  'due': netRemaining,
                                  'active': isActive,
                                });
                              }

                              return Column(
                                children: [
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
                                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))],
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text('صافي مديونيات السائقين', style: TextStyle(fontFamily: 'Cairo', color: Colors.white70, fontSize: 11)),
                                                const SizedBox(height: 4),
                                                FittedBox(
                                                  child: Text(
                                                    '${_toArabicNumbers(totalDriversDueAll.toStringAsFixed(0))} ج.م',
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
                                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
                                              border: Border.all(color: Colors.grey.shade200),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text('عدد السائقين', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey, fontSize: 11)),
                                                const SizedBox(height: 4),
                                                Text(
                                                  _toArabicNumbers(driversList.length.toString()),
                                                  style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF0F2A52)),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 4.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        // سجل السائقين على اليمين
                                        const Text('سجل السائقين', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F2A52))),
                                        // إضافة سائق على الشمال
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
                                      ],
                                    ),
                                  ),

                                  Expanded(
                                    child: driversList.isEmpty
                                        ? const Center(child: Text('لا يوجد سائقين شركة مسجلين أو لديهم نشاط.', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)))
                                        : GridView.builder(
                                      padding: const EdgeInsets.all(12),
                                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        crossAxisSpacing: 10,
                                        mainAxisSpacing: 10,
                                        childAspectRatio: 1.15,
                                      ),
                                      itemCount: driversList.length,
                                      itemBuilder: (context, index) {
                                        var driver = driversList[index];
                                        double netRemaining = driver['due'];

                                        Color statusColor;
                                        String statusText;

                                        if (netRemaining > 0) {
                                          statusColor = Colors.blue.shade600;
                                          statusText = 'له: ${_toArabicNumbers(netRemaining.toStringAsFixed(0))} ج.م';
                                        } else if (netRemaining < 0) {
                                          statusColor = Colors.red.shade600;
                                          statusText = 'عليه: ${_toArabicNumbers(netRemaining.abs().toStringAsFixed(0))} ج.م';
                                        } else {
                                          statusColor = Colors.green.shade600;
                                          statusText = 'خالص';
                                        }

                                        return Card(
                                          margin: EdgeInsets.zero,
                                          elevation: 2,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          clipBehavior: Clip.antiAlias,
                                          child: InkWell(
                                            onTap: () {
                                              // انتقال فوري وصاروخي بدون أي تأخير أو تدرج بصري ثقيل
                                              Navigator.push(
                                                context,
                                                PageRouteBuilder(
                                                  pageBuilder: (context, animation, secondaryAnimation) => DriverDetailsScreen(
                                                    driverName: driver['name'],
                                                    vehicleNumber: driver['number'],
                                                  ),
                                                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                                    return child;
                                                  },
                                                ),
                                              );
                                            },
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                border: Border(
                                                  top: BorderSide(color: statusColor, width: 4),
                                                ),
                                              ),
                                              padding: const EdgeInsets.all(10),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                                children: [
                                                  Text(
                                                    driver['name'],
                                                    style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F2A52)),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.account_balance_wallet_outlined, size: 14, color: statusColor),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          statusText,
                                                          style: TextStyle(
                                                            fontFamily: 'Cairo',
                                                            fontWeight: FontWeight.w900,
                                                            fontSize: 12,
                                                            color: statusColor,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    child: Row(
                                                      children: [
                                                        const Icon(Icons.access_time, size: 13, color: Colors.grey),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          driver['active'] ? 'آخر شغل: نشط' : 'آخر شغل: غير متاح',
                                                          style: const TextStyle(fontFamily: 'Cairo', fontSize: 10, color: Colors.grey),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
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