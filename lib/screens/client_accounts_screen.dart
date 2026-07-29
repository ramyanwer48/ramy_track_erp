import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'client_details_screen.dart';

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

  // جدول الأسعار الاحتياطي المضمون بالهمزات
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
                  await FirebaseFirestore.instance.collection('clients').add({
                    'name': newName,
                    'site': _selectedSite,
                    'createdAt': FieldValue.serverTimestamp(),
                  });

                  if (!mounted) return;
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

        body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('clients').where('site', isEqualTo: _selectedSite).snapshots(),
            builder: (context, clientsSnapshot) {
              return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('settings').snapshots(),
                  builder: (context, settingsSnapshot) {
                    return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('daily_entries').snapshots(),
                        builder: (context, tripsSnapshot) {
                          return StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance.collection('settlements').snapshots(),
                              builder: (context, paymentsSnapshot) {

                                List<String> combinedNames = List.from(_selectedSite == 'old' ? _oldSiteNames : _newSiteNames);

                                if (clientsSnapshot.hasData) {
                                  for (var doc in clientsSnapshot.data!.docs) {
                                    var data = doc.data() as Map<String, dynamic>;
                                    String newName = data['name'].toString().trim();
                                    if (!combinedNames.contains(newName)) {
                                      combinedNames.insert(0, newName);
                                    }
                                  }
                                }

                                Map<String, double> livePrices = {};
                                if (settingsSnapshot.hasData) {
                                  for (var doc in settingsSnapshot.data!.docs) {
                                    var data = doc.data() as Map<String, dynamic>;
                                    double price = 0.0;
                                    for (var val in data.values) {
                                      double? p = double.tryParse(val.toString());
                                      if (p != null && p > 0) {
                                        price = p;
                                        break;
                                      }
                                    }
                                    if (price > 0) {
                                      livePrices[doc.id.trim()] = price;
                                    }
                                  }
                                }

                                List<Map<String, dynamic>> currentClients = [];
                                double totalDuesAll = 0.0;

                                for (String clientName in combinedNames) {
                                  double clientPrice = 0.0;

                                  if (livePrices.containsKey(clientName)) {
                                    clientPrice = livePrices[clientName]!;
                                  } else {
                                    for (var entry in livePrices.entries) {
                                      if (_normalizeArabic(entry.key) == _normalizeArabic(clientName)) {
                                        clientPrice = entry.value;
                                        break;
                                      }
                                    }
                                  }

                                  if (clientPrice == 0.0) {
                                    for (var entry in _fallbackPrices.entries) {
                                      if (_normalizeArabic(entry.key) == _normalizeArabic(clientName)) {
                                        clientPrice = entry.value;
                                        break;
                                      }
                                    }
                                    if (clientPrice == 0.0) clientPrice = 115.0;
                                  }

                                  double totalCubage = 0.0;
                                  String targetNorm = _normalizeArabic(clientName);

                                  if (tripsSnapshot.hasData) {
                                    for (var tripDoc in tripsSnapshot.data!.docs) {
                                      var tData = tripDoc.data() as Map<String, dynamic>;
                                      bool matches = false;

                                      tData.forEach((k, v) {
                                        if (v != null && _normalizeArabic(v.toString()).contains(targetNorm)) {
                                          matches = true;
                                        }
                                      });

                                      if (!matches && tData.containsKey('clientStrips') && tData['clientStrips'] is List) {
                                        for (var strip in tData['clientStrips']) {
                                          if (strip is Map) {
                                            strip.forEach((sk, sv) {
                                              if (sv != null && _normalizeArabic(sv.toString()).contains(targetNorm)) {
                                                matches = true;
                                              }
                                            });
                                          }
                                        }
                                      }

                                      if (matches) {
                                        double cubage = double.tryParse(tData['totalCubage']?.toString() ?? tData['cubage']?.toString() ?? '0') ?? 0.0;
                                        totalCubage += cubage;
                                      }
                                    }
                                  }

                                  double totalPayments = 0.0;
                                  if (paymentsSnapshot.hasData) {
                                    for (var pDoc in paymentsSnapshot.data!.docs) {
                                      var pData = pDoc.data() as Map<String, dynamic>;
                                      String pName = pData['name']?.toString().trim() ?? '';
                                      if (_normalizeArabic(pName) == targetNorm) {
                                        totalPayments += double.tryParse(pData['amount']?.toString() ?? pData['totalPayments']?.toString() ?? '0') ?? 0.0;
                                      }
                                    }
                                  }

                                  double due = (totalCubage * clientPrice) - totalPayments;
                                  totalDuesAll += due;

                                  currentClients.add({
                                    'name': clientName,
                                    'due': due,
                                    'lastJob': totalCubage > 0 ? 'نشط' : 'لم يبدأ بعد'
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
                                                        boxShadow: [BoxShadow(color: Colors.red.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2))],
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
                                        child: GridView.builder(
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
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) => ClientDetailsScreen(
                                                        clientName: client['name'],
                                                        openingBalance: 0.0,
                                                      ),
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