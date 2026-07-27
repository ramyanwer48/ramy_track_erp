import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ClientAccountsScreen extends StatefulWidget {
  const ClientAccountsScreen({super.key});

  @override
  State<ClientAccountsScreen> createState() => _ClientAccountsScreenState();
}

class _ClientAccountsScreenState extends State<ClientAccountsScreen> {
  // المتغيرات الأساسية
  String _selectedSite = 'old';
  final bool _isArabic = true;
  bool _isLoading = false;

  // العميل المختار للتصفية وعرض السجل
  String? _selectedClient;
  bool _isReadOnly = true;

  // قواعد بيانات العملاء الافتراضية (نفس اللي في البيان اليومي لتتطابق البيانات)
  final List<String> _oldSiteClients = [
    'أحمد سعد', 'الأقصي', 'الرجاء (3)', 'العماد', 'شركة السلام', 'جنيدي',
    'شركة طلعت مصطفي', 'شركة مصر التشييد والبناء', 'شركة الغريب', 'محمود صابر',
    'معتمد', 'وطنية المدرسة', 'شركة الغريب (بون رسمي)', 'سامكريت (خط المواسير)',
    'الرجاء (1-2)', 'خلاطة مصر التشييد والبناء', 'خلاطة أبراج', 'خلاطة السلام'
  ];
  final List<String> _newSiteClients = ['بخيت', 'عادل'];

  // دالة الرسائل الموحدة في الأسفل
  void _showMessage(String message, Color color, {Duration duration = const Duration(milliseconds: 1500)}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Cairo', color: Colors.white),
        ),
        backgroundColor: color,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
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
      _selectedClient = null; // إعادة تعيين العميل عند تغيير الموقع
    });
  }

  // نافذة إضافة عميل جديد
  void _showAddClientDialog() {
    final TextEditingController newClientController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_isArabic ? 'إضافة عميل جديد' : 'Add New Client', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Color(0xFF0F2A52))),
        content: TextField(
          controller: newClientController,
          decoration: InputDecoration(
            hintText: _isArabic ? 'اسم العميل أو الشركة' : 'Client/Company Name',
            hintStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_isArabic ? 'إلغاء' : 'Cancel', style: const TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              if (newClientController.text.trim().isNotEmpty) {
                setState(() {
                  if (_selectedSite == 'old') {
                    _oldSiteClients.add(newClientController.text.trim());
                  } else {
                    _newSiteClients.add(newClientController.text.trim());
                  }
                });
                Navigator.pop(context);
                _showMessage(_isArabic ? 'تم إضافة العميل بنجاح' : 'Client added successfully', const Color(0xFF28A745));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF28A745)),
            child: Text(_isArabic ? 'إضافة' : 'Add', style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final availableClients = _selectedSite == 'old' ? _oldSiteClients : _newSiteClients;
    final textDirection = _isArabic ? TextDirection.rtl : TextDirection.ltr;

    return Directionality(
      textDirection: textDirection,
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
          title: Text(
            _isArabic ? 'حسابات العملاء' : 'Client Accounts',
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, fontFamily: 'Cairo'),
          ),
        ),

        // ================= الأزرار في الأرضية بنفس الهوية المطلوبة =================
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    // زر اعتماد (أخضر)
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: ElevatedButton.icon(
                          onPressed: () => _showMessage(_isArabic ? 'تم اعتماد الحساب بنجاح' : 'Account Approved', const Color(0xFF28A745)),
                          icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 14),
                          label: FittedBox(child: Text(_isArabic ? 'اعتماد' : 'Approve', style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF28A745),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // زر تعديل (برتقالي)
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: ElevatedButton.icon(
                          onPressed: () => setState(() => _isReadOnly = false),
                          icon: const Icon(Icons.edit, color: Colors.white, size: 14),
                          label: FittedBox(child: Text(_isArabic ? 'تعديل' : 'Edit', style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFA000),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // زر حذف (أحمر)
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: ElevatedButton.icon(
                          onPressed: () => _showMessage(_isArabic ? 'تم حذف السجل بنجاح' : 'Deleted Successfully', Colors.red.shade700),
                          icon: const Icon(Icons.delete_forever, color: Colors.white, size: 14),
                          label: FittedBox(child: Text(_isArabic ? 'حذف' : 'Delete', style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade700,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // زر حفظ (أزرق متدرج)
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    gradient: const LinearGradient(colors: [Color(0xFF0F2A52), Color(0xFF1E4885)]),
                    boxShadow: const [BoxShadow(color: Color(0x4D0F2A52), blurRadius: 4, offset: Offset(0, 2))],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() => _isReadOnly = true);
                      _showMessage(_isArabic ? 'تم حفظ التعديلات بنجاح' : 'Saved Successfully', const Color(0xFF28A745));
                    },
                    icon: const Icon(Icons.save, color: Colors.white, size: 18),
                    label: Text(
                      _isArabic ? 'حفظ' : 'Save',
                      style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ================= المحتوى الرئيسي =================
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. اختيار الموقع (مطابق تماماً للبيان اليومي)
                  Card(
                    color: const Color(0xE6FFFFFF),
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Text(_isArabic ? 'اختر الموقع' : 'Select Site', style: const TextStyle(color: Color(0xFF0F2A52), fontSize: 16, fontWeight: FontWeight.w900, fontFamily: 'Cairo')),
                          ),
                          const SizedBox(height: 6),
                          Row(
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
                                  child: FittedBox(child: Text(_isArabic ? 'الموقع القديم' : 'Old Site', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold))),
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
                                  child: FittedBox(child: Text(_isArabic ? 'الموقع الجديد' : 'New Site', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold))),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // 2. بطاقة الملخص (عدد العملاء وإجمالي المستحقات)
                  Card(
                    color: const Color(0xE6FFFFFF),
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text(_isArabic ? 'عدد العملاء' : 'Clients Count', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Color(0xFF4A78B9), fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(_toArabicNumbers(availableClients.length.toString()), style: const TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F2A52))),
                            ],
                          ),
                          Container(height: 30, width: 1, color: Colors.grey.shade300),
                          Column(
                            children: [
                              Text(_isArabic ? 'إجمالي المستحقات' : 'Total Dues', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Color(0xFF4A78B9), fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(_toArabicNumbers('٠ م³'), style: const TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF28A745))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // 3. قسم التصفية واختيار العميل + زر إضافة عميل جديد
                  Card(
                    color: const Color(0xE6FFFFFF),
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_isArabic ? 'تصفية وحسابات عميل' : 'Client Filter', style: const TextStyle(fontFamily: 'Cairo', color: Color(0xFF0F2A52), fontSize: 13, fontWeight: FontWeight.bold)),
                              OutlinedButton.icon(
                                onPressed: _showAddClientDialog,
                                icon: const Icon(Icons.add, color: Color(0xFF28A745), size: 14),
                                label: Text(_isArabic ? 'إضافة عميل' : 'Add Client', style: const TextStyle(fontFamily: 'Cairo', color: Color(0xFF28A745), fontSize: 11, fontWeight: FontWeight.bold)),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFF28A745)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                  minimumSize: const Size(0, 28),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // خانة اختيار / بحث العميل
                          Container(
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Autocomplete<String>(
                              optionsBuilder: (TextEditingValue textEditingValue) {
                                if (textEditingValue.text.isEmpty) return availableClients;
                                return availableClients.where((opt) => opt.contains(textEditingValue.text));
                              },
                              onSelected: (String selection) {
                                setState(() {
                                  _selectedClient = selection;
                                });
                              },
                              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                return TextField(
                                  controller: controller,
                                  focusNode: focusNode,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    hintText: _isArabic ? 'اختر أو ابحث عن اسم العميل...' : 'Select or search client...',
                                    hintStyle: const TextStyle(fontSize: 11, fontFamily: 'Cairo', color: Colors.grey),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    suffixIcon: const Icon(Icons.search, size: 16, color: Colors.grey),
                                  ),
                                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // 4. سجل العمليات والدفعات للعميل المختار
                  Card(
                    color: const Color(0xE6FFFFFF),
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _selectedClient == null
                                ? (_isArabic ? 'برجاء اختيار عميل لعرض السجل' : 'Select a client to view records')
                                : (_isArabic ? 'سجل معاملات: $_selectedClient' : 'Records for: $_selectedClient'),
                            style: const TextStyle(fontFamily: 'Cairo', color: Color(0xFF0F2A52), fontSize: 13, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),

                          // جلب السجلات المرتبطة بالعميل من فايربيس
                          _selectedClient == null
                              ? Container(
                            padding: const EdgeInsets.symmetric(vertical: 30),
                            alignment: Alignment.center,
                            child: const Text('---', style: TextStyle(color: Colors.grey)),
                          )
                              : StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('daily_entries')
                                .where('site', isEqualTo: _selectedSite)
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const Center(child: CircularProgressIndicator(color: Color(0xFF0F2A52)));
                              }

                              // تصفية السجلات محلياً للعميل المختار
                              var docs = snapshot.data!.docs.where((doc) {
                                var data = doc.data() as Map<String, dynamic>;
                                List trips = data['clientsTrips'] ?? [];
                                return trips.any((t) => t['clientName'] == _selectedClient);
                              }).toList();

                              if (docs.isEmpty) {
                                return Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Center(
                                    child: Text(
                                      _isArabic ? 'لا توجد نقلات مسجلة لهذا العميل' : 'No records found for this client',
                                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey),
                                    ),
                                  ),
                                );
                              }

                              return ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: docs.length,
                                itemBuilder: (context, index) {
                                  var data = docs[index].data() as Map<String, dynamic>;
                                  var clientTrip = (data['clientsTrips'] as List).firstWhere((t) => t['clientName'] == _selectedClient);

                                  return Card(
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    elevation: 1,
                                    child: ListTile(
                                      title: Text('${_isArabic ? "التاريخ:" : "Date:"} ${data['dateString']} | ${_isArabic ? "مركبة:" : "Car:"} ${data['vehicleNumber']}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold)),
                                      subtitle: Text('${_isArabic ? "السائق:" : "Driver:"} ${data['driverName']} | ${_isArabic ? "النقلات:" : "Trips:"} ${_toArabicNumbers(clientTrip['tripsCount'].toString())}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11)),
                                      trailing: Text('${_toArabicNumbers(clientTrip['totalCubage'].toString())} م³', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Color(0xFF0F2A52), fontSize: 12)),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}