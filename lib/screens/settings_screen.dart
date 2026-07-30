import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLocked = true;
  bool _isLoading = true;

  // أسعار الشركات الافتراضية
  final Map<String, List<TextEditingController>> _companiesControllers = {
    'أحمد سعد': [TextEditingController(text: '115'), TextEditingController(text: '105')],
    'الأقصي': [TextEditingController(text: '125'), TextEditingController(text: '115')],
    'الرجاء (3)': [TextEditingController(text: '115'), TextEditingController(text: '105')],
    'العماد': [TextEditingController(text: '110'), TextEditingController(text: '100')],
    'شركة السلام': [TextEditingController(text: '120'), TextEditingController(text: '110')],
    'جنيدي': [TextEditingController(text: '125'), TextEditingController(text: '115')],
    'شركة طلعت مصطفي': [TextEditingController(text: '120'), TextEditingController(text: '110')],
    'شركة مصر التشييد والبناء': [TextEditingController(text: '120'), TextEditingController(text: '110')],
    'شركة الغريب': [TextEditingController(text: '125'), TextEditingController(text: '115')],
    'محمود صابر': [TextEditingController(text: '120'), TextEditingController(text: '110')],
    'معتمد': [TextEditingController(text: '115'), TextEditingController(text: '105')],
    'وطنية المدرسة': [TextEditingController(text: '125'), TextEditingController(text: '110')],
    'شركة الغريب (بون رسمي)': [TextEditingController(text: '140'), TextEditingController(text: '0')],
    'سامكريت (خط المواسير)': [TextEditingController(text: '100'), TextEditingController(text: '0')],
    'الرجاء (1-2)': [TextEditingController(text: '95'), TextEditingController(text: '0')],
    'خلاطة مصر التشييد والبناء': [TextEditingController(text: '100'), TextEditingController(text: '0')],
    'خلاطة أبراج': [TextEditingController(text: '100'), TextEditingController(text: '0')],
    'خلاطة السلام': [TextEditingController(text: '105'), TextEditingController(text: '0')],
  };

  final TextEditingController _bakhitTruckCtrl = TextEditingController(text: '70');
  final TextEditingController _bakhitTractorCtrl = TextEditingController(text: '100');
  final TextEditingController _adelTruckCtrl = TextEditingController(text: '70');
  final TextEditingController _adelTractorCtrl = TextEditingController(text: '100');

  // كونترولر جديد مخصص للشيخ محمد
  final TextEditingController _sheikhTractorCtrl = TextEditingController(text: '22');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initAndLoadSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _bakhitTruckCtrl.dispose();
    _bakhitTractorCtrl.dispose();
    _adelTruckCtrl.dispose();
    _adelTractorCtrl.dispose();
    _sheikhTractorCtrl.dispose();
    for (var controllers in _companiesControllers.values) {
      controllers[0].dispose();
      controllers[1].dispose();
    }
    super.dispose();
  }

  // دالة لجلب الأسعار من الفايربيز
  Future<void> _initAndLoadSettings() async {
    try {
      var firestore = FirebaseFirestore.instance;
      var snapshot = await firestore.collection('settings').get();

      if (snapshot.docs.isEmpty) {
        for (var entry in _companiesControllers.entries) {
          await firestore.collection('settings').doc(entry.key).set({
            'clientName': entry.key,
            'price': double.tryParse(entry.value[0].text) ?? 0.0,
            'officePrice': double.tryParse(entry.value[1].text) ?? 0.0,
          });
        }
        // حقن إعدادات الشيخ محمد المبدئية
        await firestore.collection('settings').doc('sheikh_settings').set({
          'tractorRate': 22.0,
        });
      } else {
        for (var doc in snapshot.docs) {
          var data = doc.data();
          String id = doc.id;

          if (_companiesControllers.containsKey(id)) {
            if (data['price'] != null) _companiesControllers[id]![0].text = data['price'].toString();
            if (data['officePrice'] != null) _companiesControllers[id]![1].text = data['officePrice'].toString();
          }

          if (id == 'sheikh_settings') {
            if (data['tractorRate'] != null) _sheikhTractorCtrl.text = data['tractorRate'].toString();
          }
        }
      }
    } catch (e) {
      debugPrint("Error loading settings: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // حفظ التعديلات في الفايربيز
  Future<void> _saveSettingsToFirebase() async {
    try {
      var firestore = FirebaseFirestore.instance;

      // حفظ أسعار الشركات
      for (var entry in _companiesControllers.entries) {
        String companyName = entry.key;
        double clientPrice = double.tryParse(entry.value[0].text) ?? 0.0;
        double officePrice = double.tryParse(entry.value[1].text) ?? 0.0;

        await firestore.collection('settings').doc(companyName).set({
          'clientName': companyName,
          'price': clientPrice,
          'officePrice': officePrice,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // حفظ نسبة الشيخ محمد
      double sheikhRate = double.tryParse(_sheikhTractorCtrl.text) ?? 22.0;
      await firestore.collection('settings').doc('sheikh_settings').set({
        'tractorRate': sheikhRate,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ وتحديث الأسعار في قاعدة البيانات بنجاح!', style: TextStyle(fontFamily: 'Cairo')),
            backgroundColor: Color(0xFF28A745),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء الحفظ: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _toggleLock() async {
    if (_isLocked) {
      setState(() => _isLocked = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم فتح الإعدادات. يمكنك تعديل الأسعار الآن.', style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: Color(0xFF28A745),
        ),
      );
    } else {
      await _saveSettingsToFirebase();
      setState(() => _isLocked = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F6F9),
        appBar: AppBar(title: const Text('إعدادات النظام والتسعير', style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold)), backgroundColor: const Color(0xFF0F2A52)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F9),
        appBar: AppBar(
          title: const Text('إعدادات النظام والتسعير', style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF0F2A52),
          centerTitle: true,
          leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
          actions: [
            IconButton(
              icon: Icon(_isLocked ? Icons.lock : Icons.lock_open, color: _isLocked ? Colors.redAccent : Colors.greenAccent, size: 28),
              tooltip: _isLocked ? 'فتح القفل للتعديل' : 'حفظ وقفل',
              onPressed: _toggleLock,
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF00D2FF),
            unselectedLabelColor: Colors.white70,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14),
            tabs: const [
              Tab(text: 'الموقع القديم', icon: Icon(Icons.location_on, size: 18)),
              Tab(text: 'الموقع الجديد', icon: Icon(Icons.add_location_alt, size: 18)),
            ],
          ),
        ),
        body: Column(
          children: [
            Container(
              color: Colors.amber.shade100,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'تنبيه: يتم مزامنة الأسعار وحفظها أوتوماتيكياً في الفايربيز.',
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12.0, right: 4),
                        child: Text('حسابات الشركات (18 شركة)', style: TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F2A52))),
                      ),
                      ..._companiesControllers.entries.map((entry) {
                        int index = _companiesControllers.keys.toList().indexOf(entry.key) + 1;
                        return _buildCompanyCard(
                          companyName: '$index. ${entry.key}',
                          clientCtrl: entry.value[0],
                          officeCtrl: entry.value[1],
                        );
                      }),
                    ],
                  ),
                  ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12.0, right: 4),
                        child: Text('الشركاء المستقطعين', style: TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F2A52))),
                      ),
                      // كارت الشيخ محمد
                      Card(
                        elevation: 1.5,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('حساب الشيخ محمد', style: TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F2A52))),
                              const Divider(),
                              _buildInputField('نسبة الجرارات (للمتر)', _sheikhTractorCtrl, Icons.local_shipping),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12.0, right: 4),
                        child: Text('أسعار عملاء الموقع الجديد', style: TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F2A52))),
                      ),
                      _buildNewSiteClientCard(clientName: 'العميل: بخيت', truckCtrl: _bakhitTruckCtrl, tractorCtrl: _bakhitTractorCtrl),
                      _buildNewSiteClientCard(clientName: 'العميل: عادل', truckCtrl: _adelTruckCtrl, tractorCtrl: _adelTractorCtrl),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: _isLocked ? null : FloatingActionButton.extended(
          onPressed: _toggleLock,
          backgroundColor: const Color(0xFF28A745),
          icon: const Icon(Icons.save, color: Colors.white),
          label: const Text('حفظ وقفل', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      ),
    );
  }

  Widget _buildCompanyCard({required String companyName, required TextEditingController clientCtrl, required TextEditingController officeCtrl}) {
    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(companyName, style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F2A52))),
            const Divider(),
            Row(
              children: [
                Expanded(child: _buildInputField('سعر العميل', clientCtrl, Icons.monetization_on_outlined)),
                const SizedBox(width: 12),
                Expanded(child: _buildInputField('سعر المكتب', officeCtrl, Icons.account_balance_wallet_outlined)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewSiteClientCard({required String clientName, required TextEditingController truckCtrl, required TextEditingController tractorCtrl}) {
    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(clientName, style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F2A52))),
            const Divider(),
            Row(
              children: [
                Expanded(child: _buildInputField('سعر العربيات', truckCtrl, Icons.local_shipping)),
                const SizedBox(width: 12),
                Expanded(child: _buildInputField('سعر الجرارات', tractorCtrl, Icons.fire_truck)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, IconData? icon) {
    return TextField(
      controller: controller,
      readOnly: _isLocked,
      keyboardType: TextInputType.number,
      style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: _isLocked ? Colors.grey.shade700 : Colors.black),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 11),
        prefixIcon: icon != null ? Icon(icon, size: 18) : null,
        suffixText: 'ج.م',
        suffixStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 10, color: Colors.grey),
        filled: _isLocked,
        fillColor: _isLocked ? Colors.grey.shade100 : Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}