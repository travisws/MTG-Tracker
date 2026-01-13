import 'package:flutter/material.dart';

import 'routes.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({required this.currentRoute, super.key});

  final String currentRoute;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          children: [
            const DrawerHeader(
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  'MTG Resolution Timeline',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            _NavTile(
              label: 'Timeline',
              icon: Icons.view_timeline,
              selected: currentRoute == AppRoutes.timeline,
              onTap: () => _go(context, AppRoutes.timeline),
            ),
            _NavTile(
              label: 'Decks',
              icon: Icons.style_outlined,
              selected: currentRoute == AppRoutes.decks,
              onTap: () => _go(context, AppRoutes.decks),
            ),
          ],
        ),
      ),
    );
  }

  void _go(BuildContext context, String route) {
    Navigator.of(context).pop();
    if (route == currentRoute) return;
    Navigator.of(context).pushReplacementNamed(route);
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      selected: selected,
      onTap: onTap,
    );
  }
}
