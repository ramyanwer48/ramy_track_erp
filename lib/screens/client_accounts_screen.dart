import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'client_details_screen.dart';
import 'custom_bottom_nav.dart'; // استدعاء الشريط الموحد

class ClientAccountsScreen extends StatefulWidget {
  const ClientAccountsScreen({super.key});

  @override
  State<ClientAccountsScreen> createState() => _ClientAccountsScreenState();
}

class _ClientAccountsScreenState extends State<ClientAccountsScreen> {
  String _selectedSite = 'old';
  final bool _isArabic = true;

  final List<String> _oldSiteNames = [
    'أحمد سعد', 'الأقصي', 'الرجاء (3)', 'العماد', 'شركة السلام', 'جنيدي',
    'شركة طلعت مصطفي', 'شركة مصر التشييد والبناء', 'شركة الغريب', 'محمود صابر',
    'معتمد', 'وطنية المدرسة', 'شركة الغريب (بون رسمي)', 'سامكريت (خط المواسير)',
    'الرجاء (1-2)', 'خلاطة مصر التشييد والبناء', 'خلاطة أبراج', 'خلاطة السلام'
  ];

  final List<String> _newSiteNames = [
    'بخيت', 'عادل'
  ];

  final Map<String, double> _fallbackPrices = {
    'أحمد سعد': 115.0,
    'احمد سعد': 115.0,
    'الأقصي': 125.0,
    'الاقصي': 125.0,
    'الرجاء (3)': 115.0,
    'العماد': 110.0,
    'شركة السلام': 120.0,
    'جنيدي': 125.0,
    'شركة طلعت مصطفي': 120.0,
    'شركة مصر التشييد والبناء': 120.0,
    'شركة الغريب': 125.0,
    'محمود صابر': 120.0,
    'معتمد': 115.0,
    'وطنية المدرسة': 125.0,
    'شركة الغريب (بون رسمي)': 140.0,
    'سامكريت (خط المواسير)': 100.0,
    'الرجاء (1-2)': 95.0,
    'خلاطة مصر التشييد والبناء': 100.0,
    'خلاطة أبراج': 100.0,
    'خلاطة السلام': 105.0,
    'بخيت': 70.0,
    'عادل': 70.0,
  };

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
    if (!_isArabic) return text;
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    for (int i = 0; i < english.length; i++) {
      text = text.replaceAll(english[i], arabic[i]);
    }
    return text;
  }

  void _changeSite(String site) {
    setState(() {
      _selectedSite = site;
    });
  }

  Future<void> _migrateClientsToFirebase() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final clientsCol = FirebaseFirestore.instance.collection('clients');

      for (String name in _oldSiteNames) {
        var existing = await clientsCol.where('name', isEqualTo: name).where('site', isEqualTo: 'old').get();
        if (existing.docs.isEmpty) {
          await clientsCol.add({'name': name, 'site': 'old', 'createdAt': FieldValue.serverTimestamp()});
        }
      }

      for (String name in _newSiteNames) {
        var existing = await clientsCol.where('name', isEqualTo: name).where('site', isEqualTo: 'new').get();
        if (existing.docs.isEmpty) {
          await clientsCol.add({'name': name, 'site': 'new', 'createdAt': FieldValue.serverTimestamp()});
        }
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم رفع جميع العملاء للفايربيز بنجاح!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
    }
  }

  void _showAddClientDialog() {
    final TextEditingController newClientController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('إضافة عميل جديد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Color(0xFF0F2A52))),
          content: TextField(
            controller: newClientController,
            decoration: InputDecoration(
              hintText: 'اسم العميل أو الشركة',
              hintStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              isDense: true,
            ),
            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (newClientController.text.trim().isNotEmpty) {
                  String newName = newClientController.text.trim();

                  var existing = await FirebaseFirestore.instance.collection('clients')
                      .where('name', isEqualTo: newName)
                      .where('site', isEqualTo: _selectedSite)
                      .get();

                  if (existing.docs.isNotEmpty) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('هذا العميل مسجل بالفعل'), backgroundColor: Colors.red),
                    );
                    return;
                  }

                  await FirebaseFirestore.instance.collection('clients').add({
                    'name': newName,
                    'site': _selectedSite,
                    'createdAt': FieldValue.serverTimestamp(),
                  });

                  if (!context.mounted) return;
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم إضافة العميل بنجاح', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                      backgroundColor: Color(0xFF28A745),
                      behavior: SnackBarBehavior.floating,
                      margin: EdgeInsets.all(16),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF28A745)),
              child: const Text('إضافة', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold)),
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
          elevation: 0,
          centerTitle: true,
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
            onPressed: () => Navigator.pop(context),
          ),
          actions: const [SizedBox(width: 48)],
          title: const Text(
            'حسابات العملاء',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, fontFamily: 'Cairo'),
          ),
        ),

        // --- إضافة الشريط السفلي هنا (اندكس 2 للعملاء) ---
        bottomNavigationBar: const CustomBottomNav(currentIndex: 2),

        body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('clients').where('site', isEqualTo: _selectedSite).snapshots(),
            builder: (context, clientsSnapshot) {
              return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('settings').snapshots(),
                  builder: (context, settingsSnapshot) {
                    return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('daily_entries').where('site', isEqualTo: _selectedSite).snapshots(),
                        builder: (context, tripsSnapshot) {
                          return StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance.collection('settlements').where('site', isEqualTo: _selectedSite).snapshots(),
                              builder: (context, paymentsSnapshot) {

                                if (clientsSnapshot.connectionState == ConnectionState.waiting) {
                                  return const Center(child: CircularProgressIndicator(color: Color(0xFF0F2A52)));
                                }

                                List<String> databaseClients = [];
                                if (clientsSnapshot.hasData) {
                                  for (var doc in clientsSnapshot.data!.docs) {
                                    databaseClients.add(doc['name'].toString().trim());
                                  }
                                }

                                Map<String, dynamic> oldClientsSettings = {};
                                Map<String, dynamic> newClientsSettings = {};
                                if (settingsSnapshot.hasData) {
                                  for (var doc in settingsSnapshot.data!.docs) {
                                    if (doc.id == 'old_site_clients') oldClientsSettings = doc.data() as Map<String, dynamic>;
                                    if (doc.id == 'new_site_clients') newClientsSettings = doc.data() as Map<String, dynamic>;
                                  }
                                }

                                List<Map<String, dynamic>> currentClients = [];
                                double totalDuesAll = 0.0;

                                for (String clientName in databaseClients) {
                                  String targetNorm = _normalizeArabic(clientName);
                                  bool isNewSystem = _selectedSite == 'new';

                                  double oldPrice = 115.0;
                                  double truckPrice = 70.0;
                                  double tractorPrice = 100.0;

                                  if (isNewSystem) {
                                    for (var entry in newClientsSettings.entries) {
                                      if (_normalizeArabic(entry.key) == targetNorm) {
                                        truckPrice = double.tryParse(entry.value['عربيات']?.toString() ?? '70') ?? 70.0;
                                        tractorPrice = double.tryParse(entry.value['جرارات']?.toString() ?? '100') ?? 100.0;
                                        break;
                                      }
                                    }
                                  } else {
                                    for (var entry in oldClientsSettings.entries) {
                                      if (_normalizeArabic(entry.key) == targetNorm) {
                                        oldPrice = double.tryParse(entry.value['سعر العميل']?.toString() ?? '115') ?? 115.0;
                                        break;
                                      }
                                    }
                                  }

                                  double totalTrucks = 0.0;
                                  double totalTractors = 0.0;
                                  double totalOld = 0.0;
                                  double totalCubageForStatus = 0.0;

                                  if (tripsSnapshot.hasData) {
                                    for (var tripDoc in tripsSnapshot.data!.docs) {
                                      var tData = tripDoc.data() as Map<String, dynamic>;

                                      if (tData.containsKey('clientsTrips') && tData['clientsTrips'] is List) {
                                        for (var trip in tData['clientsTrips']) {
                                          if (trip is Map && trip['clientName'] != null) {
                                            if (_normalizeArabic(trip['clientName'].toString()) == targetNorm) {
                                              double cubage = double.tryParse(trip['totalCubage']?.toString() ?? trip['cubage']?.toString() ?? '0') ?? 0.0;
                                              totalCubageForStatus += cubage;

                                              if (isNewSystem) {
                                                bool isTractor = trip['isTractor'] == true || tData['isTractor'] == true;
                                                if (!isTractor) {
                                                  String detailsStr = '${tData['vehicleNumber'] ?? ''} ${tData['carType'] ?? ''}'.toLowerCase();
                                                  if (detailsStr.contains('جرار') || detailsStr.contains('tractor')) isTractor = true;
                                                }
                                                if (isTractor) totalTractors += cubage; else totalTrucks += cubage;
                                              } else {
                                                totalOld += cubage;
                                              }
                                            }
                                          }
                                        }
                                      }
                                    }
                                  }

                                  double totalPayments = 0.0;
                                  if (paymentsSnapshot.hasData) {
                                    for (var pDoc in paymentsSnapshot.data!.docs) {
                                      var pData = pDoc.data() as Map<String, dynamic>;
                                      if (_normalizeArabic(pData['name']?.toString() ?? '') == targetNorm) {
                                        totalPayments += double.tryParse(pData['amount']?.toString() ?? pData['totalPayments']?.toString() ?? '0') ?? 0.0;
                                      }
                                    }
                                  }

                                  double totalWorkValue = isNewSystem
                                      ? (totalTrucks * truckPrice) + (totalTractors * tractorPrice)
                                      : (totalOld * oldPrice);

                                  double due = totalWorkValue - totalPayments;
                                  totalDuesAll += due;

                                  currentClients.add({
                                    'name': clientName,
                                    'due': due,
                                    'lastJob': totalCubageForStatus > 0 ? 'نشط' : 'لم يبدأ بعد'
                                  });
                                }

                                String formattedTotalDues = totalDuesAll.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
                                return SafeArea(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(10.0),
                                        child: Column(
                                          children: [
                                            Card(
                                              color: const Color(0xE6FFFFFF),
                                              elevation: 1,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              child: Padding(
                                                padding: const EdgeInsets.all(10.0),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: ElevatedButton(
                                                        onPressed: () => _changeSite('old'),
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: _selectedSite == 'old' ? const Color(0xFF4A78B9) : Colors.white,
                                                          foregroundColor: _selectedSite == 'old' ? Colors.white : const Color(0xFF4A78B9),
                                                          elevation: _selectedSite == 'old' ? 1 : 0,
                                                          padding: const EdgeInsets.symmetric(vertical: 4),
                                                          side: BorderSide(color: const Color(0xFF4A78B9), width: _selectedSite == 'old' ? 0 : 1),
                                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                                        ),
                                                        child: const FittedBox(child: Text('الموقع القديم', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold))),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: ElevatedButton(
                                                        onPressed: () => _changeSite('new'),
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: _selectedSite == 'new' ? const Color(0xFF28A745) : Colors.white,
                                                          foregroundColor: _selectedSite == 'new' ? Colors.white : const Color(0xFF28A745),
                                                          elevation: _selectedSite == 'new' ? 1 : 0,
                                                          padding: const EdgeInsets.symmetric(vertical: 4),
                                                          side: BorderSide(color: const Color(0xFF28A745), width: _selectedSite == 'new' ? 0 : 1),
                                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                                        ),
                                                        child: const FittedBox(child: Text('الموقع الجديد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold))),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 6),

                                            Card(
                                              color: Colors.white,
                                              elevation: 2,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Column(
                                                      crossAxisAlignment: CrossAxisAlignment.center,
                                                      children: [
                                                        const Text('عدد العملاء', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Color(0xFF4A78B9), fontWeight: FontWeight.bold)),
                                                        const SizedBox(height: 2),
                                                        Text(_toArabicNumbers(currentClients.length.toString()), style: const TextStyle(fontFamily: 'Cairo', fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F2A52))),
                                                      ],
                                                    ),

                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                      decoration: BoxDecoration(
                                                        gradient: const LinearGradient(colors: [Color(0xFFD32F2F), Color(0xFFE53935)]),
                                                        borderRadius: BorderRadius.circular(8),
                                                        boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))],
                                                      ),
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.center,
                                                        children: [
                                                          const Text('إجمالي المديونية', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                                                          const SizedBox(height: 2),
                                                          Text('${_toArabicNumbers(formattedTotalDues)} ج.م', style: const TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 6),

                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                const Text('سجل العملاء', style: TextStyle(fontFamily: 'Cairo', color: Color(0xFF0F2A52), fontSize: 14, fontWeight: FontWeight.w900)),
                                                ElevatedButton.icon(
                                                  onPressed: _showAddClientDialog,
                                                  icon: const Icon(Icons.add, color: Colors.white, size: 16),
                                                  label: const Text('إضافة عميل', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: const Color(0xFF28A745),
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                                    minimumSize: const Size(0, 32),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                          ],
                                        ),
                                      ),

                                      Expanded(
                                        child: databaseClients.isEmpty
                                            ? const Center(child: Text("لا يوجد عملاء، اضغط على زر السهم بالأعلى لتأسيس البيانات", style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)))
                                            : GridView.builder(
                                          physics: const BouncingScrollPhysics(),
                                          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 0),
                                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: 2,
                                            childAspectRatio: 1.65,
                                            crossAxisSpacing: 8,
                                            mainAxisSpacing: 8,
                                          ),
                                          itemCount: currentClients.length,
                                          itemBuilder: (context, index) {
                                            final client = currentClients[index];
                                            final double due = client['due'];
                                            final bool isClear = due <= 0;

                                            String formattedDue = due.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');

                                            return Card(
                                              elevation: 1.5,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              child: InkWell(
                                                onTap: () {
                                                  // انتقال فوري وصاروخي بدون أي تأخير أو تأثير Fade
                                                  Navigator.push(
                                                    context,
                                                    PageRouteBuilder(
                                                      pageBuilder: (context, animation, secondaryAnimation) => ClientDetailsScreen(
                                                        clientName: client['name'],
                                                        openingBalance: 0.0,
                                                      ),
                                                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                                        return child;
                                                      },
                                                    ),
                                                  );
                                                },
                                                borderRadius: BorderRadius.circular(8),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                                  children: [
                                                    Container(
                                                      height: 3,
                                                      decoration: BoxDecoration(
                                                        color: isClear ? const Color(0xFF28A745) : const Color(0xFFD32F2F),
                                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                                      ),
                                                    ),
                                                    Expanded(
                                                      child: Padding(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                                          children: [
                                                            Text(
                                                              client['name'],
                                                              style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F2A52)),
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                            Row(
                                                              children: [
                                                                Icon(
                                                                    Icons.account_balance_wallet_outlined,
                                                                    size: 13,
                                                                    color: isClear ? const Color(0xFF28A745) : const Color(0xFFD32F2F)
                                                                ),
                                                                const SizedBox(width: 4),
                                                                const Text(
                                                                  'المديونية: ',
                                                                  style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: Colors.grey),
                                                                ),
                                                                Expanded(
                                                                  child: Text(
                                                                    isClear ? 'خالص' : '${_toArabicNumbers(formattedDue)} ج',
                                                                    style: TextStyle(
                                                                        fontFamily: 'Cairo',
                                                                        fontSize: 12,
                                                                        fontWeight: FontWeight.w900,
                                                                        color: isClear ? const Color(0xFF28A745) : const Color(0xFFD32F2F)
                                                                    ),
                                                                    maxLines: 1,
                                                                    overflow: TextOverflow.ellipsis,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                            Row(
                                                              children: [
                                                                const Icon(Icons.history, size: 13, color: Colors.grey),
                                                                const SizedBox(width: 4),
                                                                Expanded(
                                                                  child: Text(
                                                                    'آخر شغل: ${_toArabicNumbers(client['lastJob'])}',
                                                                    style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: Colors.grey.shade700),
                                                                    maxLines: 1,
                                                                    overflow: TextOverflow.ellipsis,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
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
}