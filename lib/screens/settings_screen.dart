import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // =========================================================================
  // 1. الفلتر الحديدي (لضمان تطابق الأسماء 100% ومنع أي ثغرة في الهمزات والحروف)
  // =========================================================================
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

  // =========================================================================
  // 2. تفريغ بيانات ملفات الـ PDF كقيم افتراضية ثابتة بالمفاتيح المفلترة
  // =========================================================================

  // ثوابت الموقع القديم
  final Map<String, double> _oldGlobals = {
    'سعر سائقين الشركة': 40.0,
    'اللودر': 15.0,
    'سعر م٣ خصم الجودة': 60.0,
  };

  // عملاء الموقع القديم (18 عميل)
  final Map<String, Map<String, double>> _oldClients = {
    'احمد سعد': {'سعر العميل': 115.0, 'سعر المكتب': 105.0},
    'الاقصي': {'سعر العميل': 125.0, 'سعر المكتب': 115.0},
    'الرجاء (3)': {'سعر العميل': 115.0, 'سعر المكتب': 105.0},
    'العماد': {'سعر العميل': 110.0, 'سعر المكتب': 100.0},
    'شركه السلام': {'سعر العميل': 120.0, 'سعر المكتب': 110.0},
    'جنيدي': {'سعر العميل': 125.0, 'سعر المكتب': 115.0},
    'شركه طلعت مصطفي': {'سعر العميل': 120.0, 'سعر المكتب': 110.0},
    'شركه مصر التشييد والبناء': {'سعر العميل': 120.0, 'سعر المكتب': 110.0},
    'شركه الغريب': {'سعر العميل': 125.0, 'سعر المكتب': 115.0},
    'محمود صابر': {'سعر العميل': 120.0, 'سعر المكتب': 110.0},
    'معتمد': {'سعر العميل': 115.0, 'سعر المكتب': 105.0},
    'وطنيه المدرسه': {'سعر العميل': 125.0, 'سعر المكتب': 110.0},
    'شركه الغريب ( بون رسمي)': {'سعر العميل': 140.0, 'سعر المكتب': 0.0},
    'سامكريت (خط المواسير)': {'سعر العميل': 100.0, 'سعر المكتب': 0.0},
    'الرجاء (1-2)': {'سعر العميل': 95.0, 'سعر المكتب': 0.0},
    'خلاطه مصر التشييد والبناء': {'سعر العميل': 100.0, 'سعر المكتب': 0.0},
    'خلاطه ابراج': {'سعر العميل': 100.0, 'سعر المكتب': 0.0},
    'خلاطه السلام': {'سعر العميل': 105.0, 'سعر المكتب': 0.0},
  };

  // ثوابت الموقع الجديد
  final Map<String, double> _newGlobals = {
    'سعر سائقين الشركة': 34.0,
    'اللودر': 15.0,
    'سعر م٣ خصم الجودة': 60.0,
    'نسبة الشيخ محمد ابو حسين في الجرارات': 22.0,
    'حساب المكتب عربيات (بعربيات الشركة)': 28.0,
    'حساب المكتب عربيات (بعربيات المكتب)': 64.0,
    'حساب المكتب في الجرارات': 53.0,
  };

  // عملاء الموقع الجديد
  final Map<String, Map<String, double>> _newClients = {
    'بخيت': {'عربيات': 70.0, 'جرارات': 100.0},
    'عادل': {'عربيات': 70.0, 'جرارات': 100.0},
  };

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

  // =========================================================================
  // الدالة السحرية: تأسيس ورفع الأسعار دفعة واحدة للفايربيز
  // =========================================================================
  Future<void> _migrateSettingsToFirebase() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator(color: Color(0xFF0F2A52))),
    );

    try {
      final settingsCol = FirebaseFirestore.instance.collection('settings');

      // رفع الثوابت
      await settingsCol.doc('old_site_globals').set(_oldGlobals, SetOptions(merge: true));
      await settingsCol.doc('new_site_globals').set(_newGlobals, SetOptions(merge: true));

      // رفع العملاء
      await settingsCol.doc('old_site_clients').set(_oldClients, SetOptions(merge: true));
      await settingsCol.doc('new_site_clients').set(_newClients, SetOptions(merge: true));

      if (mounted) {
        Navigator.pop(context); // قفل اللودينج
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تأسيس الإعدادات والأسعار في الفايربيز بنجاح!', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: $e', style: const TextStyle(fontFamily: 'Cairo'))));
      }
    }
  }

  // =========================================================================
  // 3. دوال التعديل والإضافة والحذف في الفايربيز
  // =========================================================================

  Future<void> _editGlobalValue(String docName, String fieldKey, double currentValue) async {
    TextEditingController controller = TextEditingController(text: currentValue.toString());

    await showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('تعديل: $fieldKey', style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'القيمة الجديدة', border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () async {
                double? newVal = double.tryParse(controller.text);
                if (newVal != null) {
                  await FirebaseFirestore.instance.collection('settings').doc(docName).set({
                    fieldKey: newVal,
                  }, SetOptions(merge: true));
                  if (mounted) Navigator.pop(ctx);
                }
              },
              child: const Text('حفظ', style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  Future<void> _editClientPrice(String docName, String clientKey, String priceType, double currentValue) async {
    TextEditingController controller = TextEditingController(text: currentValue.toString());

    await showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('تعديل $priceType لـ ($clientKey)', style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'السعر الجديد', border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () async {
                double? newVal = double.tryParse(controller.text);
                if (newVal != null) {
                  await FirebaseFirestore.instance.collection('settings').doc(docName).set({
                    clientKey: {priceType: newVal},
                  }, SetOptions(merge: true));
                  if (mounted) Navigator.pop(ctx);
                }
              },
              child: const Text('حفظ', style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  Future<void> _addNewClient(String docName, bool isOldSite) async {
    TextEditingController nameCtrl = TextEditingController();
    TextEditingController price1Ctrl = TextEditingController();
    TextEditingController price2Ctrl = TextEditingController();

    String label1 = isOldSite ? 'سعر العميل' : 'عربيات';
    String label2 = isOldSite ? 'سعر المكتب' : 'جرارات';

    await showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إضافة تسعيرة عميل جديد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم العميل')),
              const SizedBox(height: 8),
              TextField(controller: price1Ctrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: label1)),
              const SizedBox(height: 8),
              TextField(controller: price2Ctrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: label2)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F2A52)),
              onPressed: () async {
                String rawName = nameCtrl.text.trim();
                String safeKey = _normalizeArabic(rawName);

                double? p1 = double.tryParse(price1Ctrl.text);
                double? p2 = double.tryParse(price2Ctrl.text);

                if (safeKey.isNotEmpty && p1 != null && p2 != null) {
                  await FirebaseFirestore.instance.collection('settings').doc(docName).set({
                    safeKey: {label1: p1, label2: p2}
                  }, SetOptions(merge: true));
                  if (mounted) Navigator.pop(ctx);
                }
              },
              child: const Text('إضافة', style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 4. بناء الواجهة (Widgets)
  // =========================================================================

  Widget _buildGlobalsSection(String title, String docName, Map<String, double> defaults) {
    return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('settings').doc(docName).snapshots(),
        builder: (context, snapshot) {
          Map<String, dynamic> dbData = {};
          if (snapshot.hasData && snapshot.data!.exists && snapshot.data!.data() != null) {
            dbData = snapshot.data!.data() as Map<String, dynamic>;
          }

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFF0F2A52),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  child: Text(title, style: const TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                ...defaults.keys.map((key) {
                  double val = dbData.containsKey(key) ? (double.tryParse(dbData[key].toString()) ?? defaults[key]!) : defaults[key]!;

                  return Container(
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
                    child: ListTile(
                      dense: true,
                      title: Text(key, style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$val ج.م', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w900, fontSize: 14)),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.edit_square, color: Colors.blueAccent, size: 22),
                            onPressed: () => _editGlobalValue(docName, key, val),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          );
        }
    );
  }

  Widget _buildClientsSection(String title, String docName, Map<String, Map<String, double>> defaults, bool isOldSite) {
    return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('settings').doc(docName).snapshots(),
        builder: (context, snapshot) {
          Map<String, dynamic> dbData = {};
          if (snapshot.hasData && snapshot.data!.exists && snapshot.data!.data() != null) {
            dbData = snapshot.data!.data() as Map<String, dynamic>;
          }

          Map<String, Map<String, dynamic>> allClients = {};

          defaults.forEach((key, value) {
            allClients[key] = value;
          });

          dbData.forEach((key, value) {
            if (value is Map) {
              allClients[key] = Map<String, dynamic>.from(value);
            }
          });

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE65100),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(title, style: const TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15)),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: Colors.white, size: 26),
                        tooltip: 'إضافة تسعيرة عميل',
                        onPressed: () => _addNewClient(docName, isOldSite),
                      )
                    ],
                  ),
                ),
                ...allClients.entries.map((clientEntry) {
                  String clientKey = clientEntry.key;
                  Map<String, dynamic> prices = clientEntry.value;

                  return Container(
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade300))),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('● $clientKey', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F2A52))),
                        const SizedBox(height: 6),
                        ...prices.keys.map((priceType) {
                          double val = double.tryParse(prices[priceType]?.toString() ?? '0') ?? 0.0;

                          return Padding(
                            padding: const EdgeInsets.only(right: 16.0, bottom: 4.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('- $priceType:', style: const TextStyle(fontFamily: 'Cairo', fontSize: 13)),
                                Row(
                                  children: [
                                    Text('$val ج.م', style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.w900, color: Colors.black87)),
                                    const SizedBox(width: 8),
                                    InkWell(
                                      onTap: () => _editClientPrice(docName, clientKey, priceType, val),
                                      child: const Icon(Icons.edit, color: Colors.orange, size: 20),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          );
        }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F9),
        appBar: AppBar(
          title: const Text('إعدادات الأسعار الشاملة', style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF0F2A52),
          centerTitle: true,
          elevation: 0,
          leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
          actions: const [SizedBox(width: 48)],
          bottom: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF00D2FF),
            unselectedLabelColor: Colors.white70,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14),
            tabs: const [
              Tab(text: 'الموقع القديم', icon: Icon(Icons.location_city, size: 20)),
              Tab(text: 'الموقع الجديد', icon: Icon(Icons.fiber_new_rounded, size: 20)),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            // التاب الأول: الموقع القديم
            ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 20),
              children: [
                _buildGlobalsSection('ثوابت الموقع القديم', 'old_site_globals', _oldGlobals),
                _buildClientsSection('أسعار عملاء الموقع القديم', 'old_site_clients', _oldClients, true),
              ],
            ),

            // التاب الثاني: الموقع الجديد
            ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 20),
              children: [
                _buildGlobalsSection('ثوابت الموقع الجديد', 'new_site_globals', _newGlobals),
                _buildClientsSection('أسعار عملاء الموقع الجديد', 'new_site_clients', _newClients, false),
              ],
            ),
          ],
        ),
      ),
    );
  }
}