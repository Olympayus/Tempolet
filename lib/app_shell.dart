import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'features/shell/icon_rail.dart';

/// App chrome: the 54px icon rail plus the routed content area.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          IconRail(
            selectedIndex: navigationShell.currentIndex,
            onSelected: _onDestinationSelected,
          ),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}
