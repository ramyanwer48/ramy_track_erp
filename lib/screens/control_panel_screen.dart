import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;

class ControlPanelScreen extends StatefulWidget {
  const ControlPanelScreen({super.key});

  @override
  State<ControlPanelScreen> createState() => _ControlPanelScreenState();
}

class _ControlPanelScreenState extends State<ControlPanelScreen> {
  int _touchedIndex = -1; // للتحكم في الأنيميشن بتاع الدائرة (Pie Chart)

  String _toArabicNumbers(String text) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    for (int i = 0; i < english.length; i++) {
      text = text.replaceAll(english[i], arabic[i]);
    }
    return text;
  }

  String _formatCleanNumber(double num) {
    String numStr = num % 1 == 0 ? num.toInt().toString() : num.toStringAsFixed(1);
    return numStr.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }

  String _formatDateToKey(String date) {
    if (date.isEmpty) return '';
    String normalized = date.replaceAll('-', '/');
    List<String> parts = normalized.split('/');
    if (parts.length == 3) {
      if (parts[0].length == 4) return '${parts[0]}/${parts[1]}/${parts[2]}'; // YYYY/MM/DD
      return '${parts[2]}/${parts[1]}/${parts[0]}'; // DD/MM/YYYY -> YYYY/MM/DD
    }
    return normalized;
  }

  // دالة الحسابات العميقة التي تجمع وتلخص كل شيء
  Map<String, dynamic> _calculateDashboardData(
      List<QueryDocumentSnapshot> tripsDocs,
      List<QueryDocumentSnapshot> driverPaymentsDocs,
      List<QueryDocumentSnapshot> clientPaymentsDocs,
      List<QueryDocumentSnapshot> settlementsDocs,
      List<QueryDocumentSnapshot> settingsDocs,
      ) {
    // 1. إعدادات الأسعار الثابتة (للتأكد)
    double tractorRate = 22.0;
    double loaderRate = 15.0;
    double oldDriverRate = 40.0;
    double newDriverRate = 34.0;

    for (var doc in settingsDocs) {
      var data = doc.data() as Map<String, dynamic>;
      if (doc.id == 'sheikh_settings' && data.containsKey('tractorRate')) tractorRate = double.tryParse(data['tractorRate'].toString()) ?? 22.0;
      if (data.containsKey('loaderRate')) loaderRate = double.tryParse(data['loaderRate'].toString()) ?? 15.0;
      if (doc.id == 'old_site_globals' && data.containsKey('سعر سائقين الشركة')) oldDriverRate = double.tryParse(data['سعر سائقين الشركة'].toString()) ?? 40.0;
      if (doc.id == 'new_site_globals' && data.containsKey('سعر سائقين الشركة')) newDriverRate = double.tryParse(data['سعر سائقين الشركة'].toString()) ?? 34.0;
    }

    // المتغيرات المجمعة
    double totalOldCubage = 0;
    double totalNewCubage = 0;
    double totalTractorCubage = 0;
    double totalLoaderCubage = 0;

    double totalDriverDues = 0; // مستحقات السائقين الكلية
    Map<String, double> driverDuesMap = {}; // تفصيل مستحقات كل سائق

    double totalClientDues = 0; // إجمالي ما على العملاء
    Map<String, double> clientDuesMap = {}; // تفصيل ما على كل عميل

    Map<String, double> last7DaysCubage = {}; // للأعمدة البيانية (آخر 7 أيام)

    DateTime now = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      DateTime d = now.subtract(Duration(days: i));
      String key = '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
      last7DaysCubage[key] = 0.0;
    }

    // معالجة النقلات
    for (var doc in tripsDocs) {
      var data = doc.data() as Map<String, dynamic>;
      String site = data['site'] ?? 'old';
      String dateStr = data['dateString'] ?? '';
      String formattedDateKey = _formatDateToKey(dateStr);

      String driverName = data['driverName'] ?? '';
      String carType = (data['carType'] ?? data['vehicleType'] ?? data['type'] ?? '').toString();
      double vehicleCubage = double.tryParse(data['cubage']?.toString() ?? '0') ?? 0.0;

      double tripTotalCubage = 0;

      List<dynamic> cTrips = data['clientsTrips'] ?? [];
      for (var c in cTrips) {
        int tripsCount = (c['tripsCount'] ?? c['trips'] ?? 0) as int;
        if (tripsCount > 0) {
          double cubage = double.tryParse(c['totalCubage']?.toString() ?? c['cubage']?.toString() ?? '0') ?? 0.0;
          if (cubage == 0) cubage = tripsCount * vehicleCubage;

          tripTotalCubage += cubage;

          // حساب المواقع
          if (site == 'new') totalNewCubage += cubage; else totalOldCubage += cubage;

          // حساب الشيخ محمد (جرارات بخيت وعادل)
          String clientName = c['clientName'] ?? c['name'] ?? '';
          if ((clientName.contains('بخيت') || clientName.contains('عادل')) && carType.contains('جرار')) {
            totalTractorCubage += cubage;
          }

          // حساب اللودر (رمل)
          String material = c['material']?.toString() ?? data['material']?.toString() ?? '';
          if (material.isEmpty || material.contains('رمل')) {
            totalLoaderCubage += cubage;
          }

          // حساب مستحقات العملاء
          double priceForClient = double.tryParse(c['price']?.toString() ?? '0') ?? 0.0;
          double dueFromClient = cubage * priceForClient;
          totalClientDues += dueFromClient;
          clientDuesMap[clientName] = (clientDuesMap[clientName] ?? 0) + dueFromClient;

          // حساب مستحقات السائقين
          if (driverName.isNotEmpty && !carType.contains('مكتب') && !carType.contains('جرار')) {
            double dRate = (site == 'new') ? newDriverRate : oldDriverRate;
            double dueToDriver = cubage * dRate;
            totalDriverDues += dueToDriver;
            driverDuesMap[driverName] = (driverDuesMap[driverName] ?? 0) + dueToDriver;
          }
        }
      }

      // إضافة للرسم البياني إذا كان ضمن آخر 7 أيام
      if (last7DaysCubage.containsKey(formattedDateKey)) {
        last7DaysCubage[formattedDateKey] = (last7DaysCubage[formattedDateKey]!) + tripTotalCubage;
      }
    }

    // خصم مدفوعات السائقين
    double totalDriverPayments = 0;
    for (var doc in driverPaymentsDocs) {
      var data = doc.data() as Map<String, dynamic>;
      String dName = data['driverName'] ?? '';
      double amt = double.tryParse(data['amount']?.toString() ?? '0') ?? 0.0;
      totalDriverPayments += amt;
      if (driverDuesMap.containsKey(dName)) {
        driverDuesMap[dName] = driverDuesMap[dName]! - amt;
      }
    }

    // خصم مدفوعات العملاء
    double totalClientPayments = 0;
    for (var doc in clientPaymentsDocs) {
      var data = doc.data() as Map<String, dynamic>;
      String cName = data['clientName'] ?? '';
      double amt = double.tryParse(data['amount']?.toString() ?? '0') ?? 0.0;
      totalClientPayments += amt;
      if (clientDuesMap.containsKey(cName)) {
        clientDuesMap[cName] = clientDuesMap[cName]! - amt;
      }
    }

    // تسويات الشيخ محمد
    double totalSheikhPayments = 0;
    for (var doc in settlementsDocs) {
      var data = doc.data() as Map<String, dynamic>;
      if (data['type'] == 'sheikh_payment') {
        totalSheikhPayments += double.tryParse(data['amount']?.toString() ?? '0') ?? 0.0;
      }
    }

    double netDriversDue = totalDriverDues - totalDriverPayments;
    double netSheikhDue = (totalTractorCubage * tractorRate) - totalSheikhPayments;
    // افتراض عدم وجود دفعات مسجلة للودر حالياً، المستحق بالكامل
    double netLoaderDue = (totalLoaderCubage * loaderRate);

    double totalMarketMoney = totalClientDues - totalClientPayments; // فلوسنا اللي برة
    double totalObligations = netDriversDue + netSheikhDue + netLoaderDue; // التزاماتنا

    // ترتيب أعلى المديونيات
    var sortedClients = clientDuesMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    var sortedDrivers = driverDuesMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return {
      'totalMarketMoney': totalMarketMoney,
      'totalObligations': totalObligations,
      'totalOldCubage': totalOldCubage,
      'totalNewCubage': totalNewCubage,
      'chartData': last7DaysCubage,
      'topClients': sortedClients.take(3).toList(),
      'topDrivers': sortedDrivers.take(3).toList(),
      'tractorPercent': (totalOldCubage + totalNewCubage) == 0 ? 0.0 : (totalTractorCubage / (totalOldCubage + totalNewCubage)),
      'collectedPercent': totalClientDues == 0 ? 0.0 : (totalClientPayments / totalClientDues),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F9),
        appBar: AppBar(
          title: const Text('لوحة التحكم والإحصائيات', style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
          backgroundColor: const Color(0xFF103667),
          centerTitle: true,
          elevation: 0,
          leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
        ),
        body: FutureBuilder(
            future: Future.wait([
              FirebaseFirestore.instance.collection('daily_entries').get(),
              FirebaseFirestore.instance.collection('driver_payments').get(),
              FirebaseFirestore.instance.collection('client_payments').get(),
              FirebaseFirestore.instance.collection('settlements').get(),
              FirebaseFirestore.instance.collection('settings').get(),
            ]),
            builder: (context, AsyncSnapshot<List<QuerySnapshot>> snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF103667)));
              }

              if (!snapshot.hasData || snapshot.hasError) {
                return const Center(child: Text('حدث خطأ في تحميل البيانات', style: TextStyle(fontFamily: 'Cairo')));
              }

              var data = _calculateDashboardData(
                snapshot.data![0].docs,
                snapshot.data![1].docs,
                snapshot.data![2].docs,
                snapshot.data![3].docs,
                snapshot.data![4].docs,
              );

              double marketMoney = data['totalMarketMoney'];
              double obligations = data['totalObligations'];
              double oldCubage = data['totalOldCubage'];
              double newCubage = data['totalNewCubage'];
              Map<String, double> chartData = data['chartData'];
              List<MapEntry<String, double>> topClients = data['topClients'];
              List<MapEntry<String, double>> topDrivers = data['topDrivers'];
              double tractorPercent = data['tractorPercent'];
              double collectedPercent = data['collectedPercent'];

              double totalCubage = oldCubage + newCubage;
              double estimatedProfit = marketMoney - obligations; // ربح تقديري تقريبي

              return SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // 1. كروت الخلاصة المالية العلوية
                    Row(
                      children: [
                        Expanded(
                          child: _buildMiniCard('فلوسنا في السوق', marketMoney, Colors.green),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMiniCard('إجمالي الالتزامات', obligations, Colors.red),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF103667), Color(0xFF00D2FF)], begin: Alignment.centerRight, end: Alignment.centerLeft),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
                      ),
                      child: Column(
                        children: [
                          const Text('صافي أرباح المكتب التقديرية (غير محصلة)', style: TextStyle(color: Colors.white70, fontFamily: 'Cairo', fontSize: 11)),
                          const SizedBox(height: 4),
                          Text('${_toArabicNumbers(_formatCleanNumber(estimatedProfit))} ج.م', style: const TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 24)),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 2. الرسوم البيانية (Pie Chart - الأمتار)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('خريطة أمتار المواقع (تراكمي)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF103667))),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 180,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                PieChart(
                                  PieChartData(
                                    pieTouchData: PieTouchData(
                                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                        setState(() {
                                          if (!event.isInterestedForInteractions || pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
                                            _touchedIndex = -1;
                                            return;
                                          }
                                          _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                        });
                                      },
                                    ),
                                    borderData: FlBorderData(show: false),
                                    sectionsSpace: 2,
                                    centerSpaceRadius: 50,
                                    sections: [
                                      PieChartSectionData(
                                        color: Colors.blue.shade600,
                                        value: oldCubage,
                                        title: '${_toArabicNumbers(((oldCubage / (totalCubage == 0 ? 1 : totalCubage)) * 100).toStringAsFixed(1))} %',
                                        radius: _touchedIndex == 0 ? 35.0 : 25.0,
                                        titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Cairo'),
                                      ),
                                      PieChartSectionData(
                                        color: Colors.green.shade500,
                                        value: newCubage,
                                        title: '${_toArabicNumbers(((newCubage / (totalCubage == 0 ? 1 : totalCubage)) * 100).toStringAsFixed(1))} %',
                                        radius: _touchedIndex == 1 ? 35.0 : 25.0,
                                        titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Cairo'),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('إجمالي', style: TextStyle(fontSize: 10, color: Colors.grey, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                                    Text('${_toArabicNumbers(_formatCleanNumber(totalCubage))}\nم³', textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF103667), fontFamily: 'Cairo')),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildLegend(Colors.blue.shade600, 'القديم'),
                              const SizedBox(width: 16),
                              _buildLegend(Colors.green.shade500, 'الجديد'),
                            ],
                          )
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 3. الرسم البياني العمودي (Bar Chart - آخر 7 أيام)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('حجم الشغل (أمتار) - آخر 7 أيام', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF103667))),
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 160,
                            child: BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                maxY: chartData.values.isEmpty ? 100 : (chartData.values.reduce(math.max) * 1.2),
                                barTouchData: BarTouchData(enabled: false),
                                titlesData: FlTitlesData(
                                  show: true,
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        int index = value.toInt();
                                        if (index < 0 || index >= chartData.length) return const SizedBox();
                                        String date = chartData.keys.elementAt(index);
                                        String day = date.split('/')[2];
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 6),
                                          child: Text(_toArabicNumbers(day), style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                                        );
                                      },
                                      reservedSize: 22,
                                    ),
                                  ),
                                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                ),
                                gridData: FlGridData(show: false),
                                borderData: FlBorderData(show: false),
                                barGroups: List.generate(chartData.length, (index) {
                                  return BarChartGroupData(
                                    x: index,
                                    barRods: [
                                      BarChartRodData(
                                        toY: chartData.values.elementAt(index),
                                        color: const Color(0xFF00D2FF),
                                        width: 16,
                                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
                                      )
                                    ],
                                  );
                                }),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 4. مؤشرات الأداء التشغيلي (Progress Bars)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('مؤشرات الأداء التشغيلي', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF103667))),
                          const SizedBox(height: 12),
                          _buildProgressBar('نسبة تحصيل مستحقات العملاء', collectedPercent, Colors.green),
                          const SizedBox(height: 12),
                          _buildProgressBar('الاعتماد على الجرارات (الشيخ محمد)', tractorPercent, Colors.amber.shade700),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 5. مراكز الانتباه (Red Flags)
                    const Text(' مراكز الانتباه العاجلة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red)),
                    const SizedBox(height: 8),

                    // عملاء عليهم فلوس
                    if (topClients.isNotEmpty) ...[
                      Card(
                        elevation: 0.5,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.red.shade200)),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('أكبر مديونيات بالسوق (عملاء)', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                              const Divider(),
                              ...topClients.map((c) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(c.key, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold)),
                                    Text('${_toArabicNumbers(_formatCleanNumber(c.value))} ج', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w900, color: Colors.red)),
                                  ],
                                ),
                              )),
                            ],
                          ),
                        ),
                      ),
                    ],

                    // سائقين ليهم مستحقات
                    if (topDrivers.isNotEmpty) ...[
                      Card(
                        elevation: 0.5,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.orange.shade200)),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('أكبر مستحقات متأخرة (سائقين)', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                              const Divider(),
                              ...topDrivers.map((d) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(d.key, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold)),
                                    Text('${_toArabicNumbers(_formatCleanNumber(d.value))} ج', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w900, color: Colors.orange)),
                                  ],
                                ),
                              )),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),
                  ],
                ),
              );
            }
        ),
      ),
    );
  }

  Widget _buildMiniCard(String title, double value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4)],
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontFamily: 'Cairo', fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          FittedBox(child: Text('${_toArabicNumbers(_formatCleanNumber(value))} ج', style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w900, color: color))),
        ],
      ),
    );
  }

  Widget _buildLegend(Color color, String text) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildProgressBar(String title, double percent, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold)),
            Text('${_toArabicNumbers((percent * 100).toStringAsFixed(0))}%', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percent.isNaN || percent.isInfinite ? 0 : percent,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}