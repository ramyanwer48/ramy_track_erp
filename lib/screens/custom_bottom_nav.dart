import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'daily_entry_screen.dart';
import 'client_accounts_screen.dart';
import 'driver_accounts_screen.dart';
import 'settlements_screen.dart';
import 'settings_screen.dart';

class CustomBottomNav extends StatelessWidget {
  final int currentIndex;

  const CustomBottomNav({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 65,
      decoration: BoxDecoration(
        color: const Color(0xFF0F2A52),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, -3))
        ],
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(context, icon: Icons.home_rounded, label: 'الرئيسية', index: 0, targetScreen: const DashboardScreen()),
            _buildNavItem(context, icon: Icons.receipt_long_rounded, label: 'البيان', index: 1, targetScreen: const DailyEntryScreen()),
            _buildNavItem(context, icon: Icons.people_alt_rounded, label: 'العملاء', index: 2, targetScreen: const ClientAccountsScreen()),
            _buildNavItem(context, icon: Icons.local_shipping_rounded, label: 'السائقين', index: 3, targetScreen: const DriverAccountsScreen()),
            _buildNavItem(context, icon: Icons.business_rounded, label: 'المكتب', index: 4, targetScreen: const SettlementsScreen()),
            _buildNavItem(context, icon: Icons.settings_rounded, label: 'الإعدادات', index: 5, targetScreen: const SettingsScreen()),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, {required IconData icon, required String label, required int index, required Widget? targetScreen}) {
    bool isSelected = currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () async {
          // إزالة التركيز وإغلاق أي كيبورد أو قوائم منبثقة تماماً أولاً
          FocusManager.instance.primaryFocus?.unfocus();
          // إغلاق أي نافذة منبثقة سابقة لو موجودة
          while (Navigator.canPop(context) && currentIndex != 1) {
            // للتأكد من عدم ترك بوب أب معلق
            break;
          }

          if (!isSelected && targetScreen != null) {
            if (currentIndex == 1) {
              bool canLeave = await DailyEntryScreen.checkUnsavedChanges(context);
              if (!canLeave) return;
            }

            if (index == 0) {
              Navigator.pushAndRemoveUntil(
                context,
                PageRouteBuilder(pageBuilder: (context, a1, a2) => targetScreen, transitionDuration: Duration.zero),
                    (route) => false,
              );
            } else if (currentIndex == 0) {
              Navigator.push(
                context,
                PageRouteBuilder(pageBuilder: (context, a1, a2) => targetScreen, transitionDuration: Duration.zero),
              );
            } else {
              Navigator.pushReplacement(
                context,
                PageRouteBuilder(pageBuilder: (context, a1, a2) => targetScreen, transitionDuration: Duration.zero),
              );
            }
          }
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? const Color(0xFF00D2FF) : Colors.white54, size: 24),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? const Color(0xFF00D2FF) : Colors.white54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}