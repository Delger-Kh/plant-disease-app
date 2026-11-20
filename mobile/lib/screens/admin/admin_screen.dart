import 'package:flutter/material.dart';

import '../../models.dart';
import '../../services/api_client.dart';
import '../../widgets/common.dart';
import '../history_screen.dart';
import '../result_screen.dart';
import 'disease_edit_screen.dart';

/// US-09 Админ панель (+ US-10/11/12 өвчний сан удирдах, хэрэглэгч удирдах).
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Админ самбар'),
          bottom: const TabBar(isScrollable: true, tabs: [
            Tab(icon: Icon(Icons.insights), text: 'Тойм'),
            Tab(icon: Icon(Icons.fact_check_outlined), text: 'Хянах'),
            Tab(icon: Icon(Icons.coronavirus_outlined), text: 'Өвчин'),
            Tab(icon: Icon(Icons.group_outlined), text: 'Хэрэглэгч'),
          ]),
        ),
        body: const TabBarView(children: [
          _StatsTab(),
          _ReviewTab(),
          _DiseasesTab(),
          _UsersTab(),
        ]),
      ),
    );
  }
}

// ----------------------------------------------------------------- Тойм
class _StatsTab extends StatefulWidget {
  const _StatsTab();

  @override
  State<_StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<_StatsTab> {
  late Future<AdminStats> _future = ApiClient.instance.adminStats();

  void _reload() => setState(() => _future = ApiClient.instance.adminStats());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AdminStats>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const LoadingView();
        if (snap.hasError) return ErrorView(error: snap.error!, onRetry: _reload);
        final s = snap.data!;
        final maxDay = s.last7Days.fold<int>(1, (m, e) => e.value > m ? e.value : m);
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.8,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                _StatCard('Хэрэглэгч', s.users, Icons.group, kGreen),
                _StatCard('Нийт онош', s.diagnoses, Icons.biotech, Colors.indigo),
                _StatCard('Хянах шаардлагатай', s.needsReview, Icons.fact_check, Colors.orange.shade800),
                _StatCard('Өвчний сан', s.diseases, Icons.menu_book, Colors.teal),
              ],
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Сүүлийн 7 хоногийн оношилгоо',
              icon: Icons.bar_chart,
              child: SizedBox(
                height: 140,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: s.last7Days
                      .map((e) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                                Text('${e.value}', style: const TextStyle(fontSize: 12)),
                                const SizedBox(height: 2),
                                Container(
                                  height: 90 * e.value / maxDay + 2,
                                  decoration: BoxDecoration(
                                      color: kGreen, borderRadius: BorderRadius.circular(4)),
                                ),
                                const SizedBox(height: 4),
                                Text(e.key.length >= 10 ? e.key.substring(5) : e.key,
                                    style: const TextStyle(fontSize: 10)),
                              ]),
                            ),
                          ))
                      .toList(),
                ),
              ),
            ),
            SectionCard(
              title: 'Хамгийн их илэрсэн өвчин',
              icon: Icons.leaderboard,
              child: s.topDiseases.isEmpty
                  ? const Text('Одоогоор өгөгдөл алга')
                  : Column(
                      children: s.topDiseases
                          .map((e) => ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(e.key),
                                trailing: Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ))
                          .toList(),
                    ),
            ),
          ]),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  const _StatCard(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$value', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: color)),
                  Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ]),
        ),
      );
}

// ----------------------------------------------------------------- Хянах
class _ReviewTab extends StatefulWidget {
  const _ReviewTab();

  @override
  State<_ReviewTab> createState() => _ReviewTabState();
}

class _ReviewTabState extends State<_ReviewTab> {
  bool _onlyReview = true;
  late Future<List<Diagnosis>> _future = _load();

  Future<List<Diagnosis>> _load() =>
      ApiClient.instance.adminDiagnoses(status: _onlyReview ? 'needs_review' : '');

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Хянах шаардлагатай')),
            ButtonSegment(value: false, label: Text('Бүх онош')),
          ],
          selected: {_onlyReview},
          onSelectionChanged: (s) {
            _onlyReview = s.first;
            _reload();
          },
        ),
      ),
      Expanded(
        child: FutureBuilder<List<Diagnosis>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const LoadingView();
            if (snap.hasError) return ErrorView(error: snap.error!, onRetry: _reload);
            final items = snap.data!;
            if (items.isEmpty) {
              return const EmptyView(icon: Icons.task_alt, text: 'Хянах онош алга');
            }
            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) => DiagnosisTile(
                  d: items[i],
                  showUser: true,
                  onTap: () async {
                    await Navigator.push(
                        context, MaterialPageRoute(builder: (_) => ResultScreen(diagnosis: items[i])));
                    _reload();
                  },
                ),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

// ----------------------------------------------------------------- Өвчний сан
class _DiseasesTab extends StatefulWidget {
  const _DiseasesTab();

  @override
  State<_DiseasesTab> createState() => _DiseasesTabState();
}

class _DiseasesTabState extends State<_DiseasesTab> {
  late Future<List<Disease>> _future = ApiClient.instance.diseases();

  void _reload() => setState(() => _future = ApiClient.instance.diseases());

  Future<void> _open({int? id}) async {
    Disease? full;
    if (id != null) {
      try {
        full = await ApiClient.instance.disease(id);
      } catch (e) {
        if (mounted) showSnack(context, e.toString(), error: true);
        return;
      }
    }
    if (!mounted) return;
    final changed = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => DiseaseEditScreen(disease: full)));
    if (changed == true) _reload();
  }

  Future<void> _delete(Disease d) async {
    final ok = await confirmDialog(context, 'Устгах уу?',
        '"${d.nameMn}"-г өвчний сангаас устгана. AI энэ ангиллыг таньсан ч мэдээлэл харуулахгүй болно.',
        ok: 'Устгах');
    if (!ok) return;
    try {
      await ApiClient.instance.adminDeleteDisease(d.id);
      _reload();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_disease',
        onPressed: () => _open(),
        icon: const Icon(Icons.add),
        label: const Text('Өвчин нэмэх'),
      ),
      body: FutureBuilder<List<Disease>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingView();
          if (snap.hasError) return ErrorView(error: snap.error!, onRetry: _reload);
          final items = snap.data!;
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final d = items[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  title: Text(d.nameMn),
                  subtitle: Text(d.plant),
                  onTap: () => _open(id: d.id),
                  trailing: IconButton(
                    tooltip: 'Устгах',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _delete(d),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ----------------------------------------------------------------- Хэрэглэгчид
class _UsersTab extends StatefulWidget {
  const _UsersTab();

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  late Future<List<AppUser>> _future = ApiClient.instance.adminUsers();

  void _reload() => setState(() => _future = ApiClient.instance.adminUsers());

  Future<void> _act(AppUser u, String action) async {
    try {
      switch (action) {
        case 'admin':
          await ApiClient.instance.adminUpdateUser(u.id, role: 'admin');
          break;
        case 'user':
          await ApiClient.instance.adminUpdateUser(u.id, role: 'user');
          break;
        case 'toggle':
          await ApiClient.instance.adminUpdateUser(u.id, isActive: !u.isActive);
          break;
        case 'delete':
          if (!await confirmDialog(context, 'Устгах уу?', '${u.name} болон түүний бүх оношийг устгана.',
              ok: 'Устгах')) {
            return;
          }
          await ApiClient.instance.adminDeleteUser(u.id);
          break;
      }
      _reload();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ApiClient.instance.user;
    return FutureBuilder<List<AppUser>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const LoadingView();
        if (snap.hasError) return ErrorView(error: snap.error!, onRetry: _reload);
        final items = snap.data!;
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final u = items[i];
              final isMe = u.id == me?.id;
              return Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: u.isAdmin ? Colors.indigo.shade50 : kLightGreen,
                    child: Icon(u.isAdmin ? Icons.admin_panel_settings : Icons.person,
                        color: u.isAdmin ? Colors.indigo : kGreen),
                  ),
                  title: Text(u.name + (isMe ? ' (та)' : ''),
                      style: TextStyle(
                          decoration: u.isActive ? null : TextDecoration.lineThrough)),
                  subtitle: Text('${u.email}\n${u.isAdmin ? 'Админ' : 'Хэрэглэгч'}'
                      '${u.isActive ? '' : ' · идэвхгүй'}'),
                  isThreeLine: true,
                  trailing: isMe
                      ? null
                      : PopupMenuButton<String>(
                          onSelected: (a) => _act(u, a),
                          itemBuilder: (_) => [
                            if (!u.isAdmin) const PopupMenuItem(value: 'admin', child: Text('Админ болгох')),
                            if (u.isAdmin) const PopupMenuItem(value: 'user', child: Text('Энгийн хэрэглэгч болгох')),
                            PopupMenuItem(
                                value: 'toggle', child: Text(u.isActive ? 'Идэвхгүй болгох' : 'Идэвхжүүлэх')),
                            const PopupMenuItem(value: 'delete', child: Text('Устгах')),
                          ],
                        ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
