import 'package:flutter/material.dart';

class DailyEntryScreen extends StatefulWidget {
  const DailyEntryScreen({super.key});

  @override
  State<DailyEntryScreen> createState() => _DailyEntryScreenState();
}

class _DailyEntryScreenState extends State<DailyEntryScreen> {
  // متغير للتحكم في اختيار الموقع (0 للقديم، 1 للجديد)
  int selectedLocation = 1;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA), // لون الخلفية الفاتح
        appBar: AppBar(
          backgroundColor: const Color(0xFF0A182E), // اللون الكحلي للهيدر
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          centerTitle: true,
          title: const Text(
            'البيان اليومي',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          actions: [
            TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.save, color: Colors.white, size: 20),
              label: const Text('حفظ', style: TextStyle(color: Colors.white, fontSize: 14)),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. اختيار الموقع
              const Center(
                child: Text('اختر الموقع', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0A182E))),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildLocationToggle(
                      title: 'الموقع الجديد',
                      icon: Icons.business,
                      isSelected: selectedLocation == 1,
                      onTap: () => setState(() => selectedLocation = 1),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildLocationToggle(
                      title: 'الموقع القديم',
                      icon: Icons.domain,
                      isSelected: selectedLocation == 0,
                      onTap: () => setState(() => selectedLocation = 0),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 2. التاريخ
              _buildSectionContainer(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Icon(Icons.calendar_month, color: Color(0xFF0A182E)),
                    const Text('الخميس 16/07/2025', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    Text('التاريخ', style: TextStyle(fontSize: 14, color: Colors.blue[800], fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 3. بيانات الإدخال
              const Text('بيانات الإدخال', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0066FF))),
              const SizedBox(height: 10),
              _buildSectionContainer(
                child: Column(
                  children: [
                    _buildInputFieldRow(label: 'السائق', icon: Icons.person_outline, isRequired: true, isDropdown: true, value: 'أحمد محمد علي'),
                    const SizedBox(height: 12),
                    _buildInputFieldRow(label: 'نوع السائق', icon: Icons.person, value: 'سائق شركة - Z', valueColor: Colors.green),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('يتم تحديده تلقائياً حسب السائق', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ),
                    const SizedBox(height: 12),
                    _buildInputFieldRow(label: 'رقم العربية', icon: Icons.local_shipping, value: 'ق ل ح 1234'),
                    const SizedBox(height: 12),
                    _buildInputFieldRow(label: 'تكعيب العربية (م³)', icon: Icons.inventory_2_outlined, value: '15'),
                    const SizedBox(height: 12),
                    _buildCounterField(label: 'عدد النقلات', icon: Icons.numbers, value: '5', isRequired: true),
                    const SizedBox(height: 20),
                    // كروت الحساب التلقائي الصغيرتين
                    Row(
                      children: [
                        Expanded(child: _buildMiniCalcCard('إجمالي الأمتار (تلقائي)', '75', 'متر مكعب', Colors.green)),
                        const SizedBox(width: 10),
                        Expanded(child: _buildMiniCalcCard('قيمة الأمتار (تلقائي)', '1,125', 'جنيه', Colors.blue)),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(5)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('سيتم حساب باقي البيانات تلقائياً', style: TextStyle(fontSize: 12, color: Colors.blue)),
                          const SizedBox(width: 5),
                          Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                        ],
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 4. تفاصيل العملاء (النقلات)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.add, color: Colors.green, size: 18),
                    label: const Text('إضافة عميل', style: TextStyle(color: Colors.green)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.green),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    ),
                  ),
                  const Text('تفاصيل العملاء (النقلات)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0A182E))),
                ],
              ),
              const SizedBox(height: 10),
              _buildClientsTable(),
              const SizedBox(height: 20),

              // 5. بيانات محسوبة تلقائياً
              const Text('بيانات محسوبة تلقائياً', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0A182E))),
              const SizedBox(height: 10),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.2, // نسبة الطول للعرض للكروت
                children: [
                  _buildAutoCalcCard('سعر المكتب (ج/م³)', '60.00', Icons.business, Colors.blue),
                  _buildAutoCalcCard('سعر العميل (ج/م³)', '150.00', Icons.money, Colors.blue),
                  _buildAutoCalcCard('ربح الشركة (ج)', '27,000.00', Icons.trending_up, Colors.green),
                  _buildAutoCalcCard('إجمالي الأمتار (م³)', '300', Icons.inventory_2, Colors.blue),
                  _buildAutoCalcCard('قيمة المكتب (ج)', '18,000.00', Icons.business, Colors.blue),
                  _buildAutoCalcCard('قيمة العميل (ج)', '45,000.00', Icons.money, Colors.blue),
                ],
              ),
              const SizedBox(height: 25),

              // 6. أزرار الإجراءات
              Row(
                children: [
                  Expanded(child: _buildActionButton('حفظ البيان', Icons.save, Colors.blue.shade700)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildActionButton('تعديل البيان', Icons.edit, Colors.orange)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildActionButton('حذف البيان', Icons.delete, Colors.red)),
                ],
              ),
              const SizedBox(height: 15),

              // 7. ملاحظة سفلية
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue.shade800),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'ملاحظة: عند حفظ البيان يتم تحديث حساب العميل وحساب المكتب وربح الشركة تلقائياً.',
                        style: TextStyle(fontSize: 11, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== الدوال المساعدة لبناء العناصر ====================

  Widget _buildLocationToggle({required String title, required IconData icon, required bool isSelected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green.withOpacity(0.05) : Colors.white,
          border: Border.all(color: isSelected ? Colors.green : Colors.blue.shade200, width: 1.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: TextStyle(color: isSelected ? Colors.green : Colors.blue.shade800, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Icon(icon, color: isSelected ? Colors.green : Colors.blue.shade800, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, spreadRadius: 1)],
      ),
      child: child,
    );
  }

  Widget _buildInputFieldRow({required String label, required IconData icon, bool isRequired = false, bool isDropdown = false, required String value, Color valueColor = Colors.black87}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // حقل الإدخال
        Expanded(
          flex: 2,
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(5),
            ),
            alignment: Alignment.center,
            child: isDropdown
                ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                Text(value, style: TextStyle(color: valueColor, fontSize: 13)),
              ],
            )
                : Text(value, style: TextStyle(color: valueColor, fontSize: 13, fontWeight: valueColor == Colors.green ? FontWeight.bold : FontWeight.normal)),
          ),
        ),
        const SizedBox(width: 15),
        // التسمية والأيقونة
        Expanded(
          flex: 1,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isRequired) const Text(' * ', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              Text(label, style: const TextStyle(fontSize: 13, color: Colors.black87)),
              const SizedBox(width: 8),
              Icon(icon, color: const Color(0xFF0A182E), size: 20),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCounterField({required String label, required IconData icon, required String value, bool isRequired = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          flex: 2,
          child: Row(
            children: [
              Container(
                width: 35,
                height: 35,
                decoration: BoxDecoration(color: const Color(0xFF0A182E), borderRadius: BorderRadius.circular(5)),
                child: const Icon(Icons.remove, color: Colors.white, size: 20),
              ),
              Expanded(
                child: Container(
                  height: 35,
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(5)),
                  alignment: Alignment.center,
                  child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
              Container(
                width: 35,
                height: 35,
                decoration: BoxDecoration(color: const Color(0xFF0A182E), borderRadius: BorderRadius.circular(5)),
                child: const Icon(Icons.add, color: Colors.white, size: 20),
              ),
            ],
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          flex: 1,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isRequired) const Text(' * ', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              Text(label, style: const TextStyle(fontSize: 13, color: Colors.black87)),
              const SizedBox(width: 8),
              Icon(icon, color: const Color(0xFF0A182E), size: 20),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMiniCalcCard(String title, String value, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(fontSize: 10, color: color)),
          const SizedBox(height: 5),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          Text(subtitle, style: TextStyle(fontSize: 10, color: color)),
        ],
      ),
    );
  }

  Widget _buildClientsTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: const BoxDecoration(color: Color(0xFF0A182E), borderRadius: BorderRadius.vertical(top: Radius.circular(10))),
            child: const Row(
              children: [
                Expanded(flex: 1, child: Center(child: Text('م', style: TextStyle(color: Colors.white, fontSize: 11)))),
                Expanded(flex: 3, child: Center(child: Text('اسم العميل', style: TextStyle(color: Colors.white, fontSize: 11)))),
                Expanded(flex: 2, child: Center(child: Text('عدد النقلات', style: TextStyle(color: Colors.white, fontSize: 11)))),
                Expanded(flex: 2, child: Center(child: Text('الكميات (م³)', style: TextStyle(color: Colors.white, fontSize: 11)))),
                Expanded(flex: 2, child: Center(child: Text('الإجراءات', style: TextStyle(color: Colors.white, fontSize: 11)))),
              ],
            ),
          ),
          // Rows
          _buildClientTableRow('1', 'شركة السلام', '5', '75', '15 × 5'),
          _buildClientTableRow('2', 'شركة الرضا', '5', '75', '15 × 5'),
          _buildClientTableRow('3', 'شركة الرحمة', '10', '150', '15 × 10', isLast: true),

          // Totals Footer
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10))),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inventory_2, color: Color(0xFF0A182E), size: 20),
                      const SizedBox(width: 8),
                      Column(
                        children: [
                          const Text('إجمالي الكميات (م³)', style: TextStyle(fontSize: 10)),
                          Text('300', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
                        ],
                      )
                    ],
                  ),
                ),
                Container(width: 1, height: 30, color: Colors.grey.shade300),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.local_shipping, color: Color(0xFF0A182E), size: 20),
                      const SizedBox(width: 8),
                      Column(
                        children: [
                          const Text('إجمالي النقلات', style: TextStyle(fontSize: 10)),
                          Text('20', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
                        ],
                      )
                    ],
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildClientTableRow(String id, String name, String trips, String qty, String calc, {bool isLast = false}) {
    return Container(
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(flex: 1, child: Center(child: Text(id, style: const TextStyle(fontSize: 12)))),
          Expanded(flex: 3, child: Center(child: Text(name, style: const TextStyle(fontSize: 12)))),
          Expanded(
            flex: 2,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(4)),
                child: Text(trips, style: const TextStyle(fontSize: 12)),
              ),
            ),
          ),
          Expanded(
              flex: 2,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('م $qty', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  Text(calc, style: const TextStyle(fontSize: 9, color: Colors.grey)),
                ],
              )
          ),
          Expanded(
              flex: 2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.edit, color: Colors.green.shade400, size: 18),
                  const SizedBox(width: 10),
                  const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                ],
              )
          ),
        ],
      ),
    );
  }

  Widget _buildAutoCalcCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: TextStyle(fontSize: 9, color: color == Colors.green ? Colors.green : Colors.black54)),
                Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color == Colors.green ? Colors.green : Colors.blue.shade800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String title, IconData icon, Color color) {
    return ElevatedButton.icon(
      onPressed: () {},
      icon: Icon(icon, color: Colors.white, size: 16),
      label: Text(title, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}