import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// 5 Tab 底部导航壳，由 go_router 的 StatefulShellRoute 注入 [navigationShell]。
class ScaffoldShell extends StatelessWidget {
  const ScaffoldShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const _items = <_NavItem>[
    _NavItem(label: '取景', icon: PhosphorIconsRegular.aperture),
    _NavItem(label: '计算', icon: PhosphorIconsRegular.ruler),
    _NavItem(label: '胶卷', icon: PhosphorIconsRegular.filmReel),
    _NavItem(label: '暗房', icon: PhosphorIconsRegular.timer),
    _NavItem(label: '我的', icon: PhosphorIconsRegular.user),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (i) => navigationShell.goBranch(
          i,
          initialLocation: i == navigationShell.currentIndex,
        ),
        destinations: [
          for (final item in _items)
            NavigationDestination(
              icon: Icon(item.icon),
              label: item.label,
            ),
        ],
      ),
    );
  }
}

class _NavItem {
  const _NavItem({required this.label, required this.icon});
  final String label;
  final IconData icon;
}
