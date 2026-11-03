import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:starq_app/app/theme/app_theme.dart';

class NavItem {
  final IconData icon;
  final String label;
  final String? route; // null = screen not built yet
  const NavItem({required this.icon, required this.label, this.route});
}

const customerNavItems = [
  NavItem(icon: Icons.water_drop, label: 'home', route: '/home'),
  NavItem(icon: Icons.directions_car, label: 'bookings', route: '/bookings'),
  NavItem(icon: Icons.star_border, label: 'rewards', route: '/rewards'),
  NavItem(icon: Icons.person, label: 'profile', route: '/profile'),
];

/// Shared bottom navigation bar used across Home, Wash Guide, My Garage, etc.
/// Tapping a tab with no route yet shows a "coming soon" snackbar instead
/// of crashing on an undefined route.
class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final List<NavItem> items;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (i) {
          final item = items[i];
          final bool selected = i == currentIndex;
          final Color color = selected ? AppColors.primary : AppColors.textLight;

          return InkWell(
            onTap: () {
              if (selected) return;
              if (item.route != null) {
                context.go(item.route!);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${item.label} — coming soon')),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(item.icon, color: color, size: 22),
                  const SizedBox(height: 3),
                  Text(item.label,
                      style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w400)),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}