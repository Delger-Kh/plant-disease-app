import 'package:flutter/material.dart';

import '../services/api_client.dart';
import 'admin/admin_screen.dart';
import 'diagnose_screen.dart';
import 'history_screen.dart';
import 'library_screen.dart';
import 'profile_screen.dart';

/// Доод навигацитай үндсэн дэлгэц. Админ хэрэглэгчид "Админ" таб нэмэгдэнэ.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final _historyKey = GlobalKey<HistoryScreenState>();

  @override
  Widget build(BuildContext context) {
    final isAdmin = ApiClient.instance.user?.isAdmin ?? false;
    final pages = <Widget>[
      DiagnoseScreen(onDiagnosed: () => _historyKey.currentState?.reload()),
      HistoryScreen(key: _historyKey),
      const LibraryScreen(),
      if (isAdmin) const AdminScreen(),
      const ProfileScreen(),
    ];
    final destinations = <NavigationDestination>[
      const NavigationDestination(icon: Icon(Icons.camera_alt_outlined), selectedIcon: Icon(Icons.camera_alt), label: 'Оношлох'),
      const NavigationDestination(icon: Icon(Icons.history), label: 'Түүх'),
      const NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Өвчний сан'),
      if (isAdmin)
        const NavigationDestination(
            icon: Icon(Icons.admin_panel_settings_outlined), selectedIcon: Icon(Icons.admin_panel_settings), label: 'Админ'),
      const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Профайл'),
    ];
    final index = _index.clamp(0, pages.length - 1);
    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) {
          setState(() => _index = i);
          if (i == 1) _historyKey.currentState?.reload();
        },
        destinations: destinations,
      ),
    );
  }
}
