import 'package:flutter/material.dart';

import '../widgets/common.dart';
import 'diagnose_screen.dart';
import 'history_screen.dart';
import 'library_screen.dart';
import 'profile_screen.dart';
import 'scan_screen.dart';

/// Үндсэн дэлгэц: хөвөгч шилэн доод цэс (Нүүр · Түүх · [+] · Сан · Профайл).
/// Голын "+" товч скан (камер) дэлгэцийг нээнэ. Админ самбар Профайл дотор.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final _historyKey = GlobalKey<HistoryScreenState>();
  final _homeKey = GlobalKey<DiagnoseScreenState>();

  void _go(int i) {
    setState(() => _index = i);
    if (i == 1) _historyKey.currentState?.reload();
    if (i == 0) _homeKey.currentState?.reloadRecent();
  }

  Future<void> _openScan() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanScreen()));
    _historyKey.currentState?.reload();
    _homeKey.currentState?.reloadRecent();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      DiagnoseScreen(key: _homeKey, onOpenHistory: () => _go(1), onOpenLibrary: () => _go(2), onScan: _openScan),
      HistoryScreen(key: _historyKey),
      const LibraryScreen(),
      const ProfileScreen(),
    ];
    return Scaffold(
      backgroundColor: kBg1,
      extendBody: true,
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: SizedBox(
          height: 78,
          child: Stack(clipBehavior: Clip.none, alignment: Alignment.bottomCenter, children: [
            Glass.card(
              radius: 18,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              border: const Color(0x40FFFFFF),
              child: SizedBox(
                height: 50,
                child: Row(children: [
                  _NavItem(icon: Icons.home_rounded, label: 'Нүүр', selected: _index == 0, onTap: () => _go(0)),
                  _NavItem(icon: Icons.schedule, label: 'Түүх', selected: _index == 1, onTap: () => _go(1)),
                  const Expanded(child: SizedBox()),
                  _NavItem(icon: Icons.inventory_2_outlined, label: 'Сан', selected: _index == 2, onTap: () => _go(2)),
                  _NavItem(icon: Icons.person_outline, label: 'Профайл', selected: _index == 3, onTap: () => _go(3)),
                ]),
              ),
            ),
            Positioned(
              top: 0,
              child: Tooltip(
                message: 'Шинэ оношилгоо',
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _openScan,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.bottomLeft,
                          end: Alignment.topRight,
                          colors: [kEmerald, kLeaf],
                        ),
                        border: Border.all(color: const Color(0xFF123023), width: 3),
                        boxShadow: [BoxShadow(color: const Color(0xFF047857).withAlpha(160), blurRadius: 16)],
                      ),
                      child: const Icon(Icons.add, color: Colors.white, size: 28),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 21, color: selected ? kLeaf : kMuted),
            const SizedBox(height: 3),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  color: selected ? kLeaf : kMuted,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                )),
          ]),
        ),
      );
}
