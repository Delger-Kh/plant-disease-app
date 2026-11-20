import 'package:flutter/material.dart';

import '../../models.dart';
import '../../services/api_client.dart';
import '../../widgets/common.dart';
import '../history_screen.dart';
import '../result_screen.dart';
import 'disease_edit_screen.dart';

/// Дэлгэц 10: Админ удирдлага. US-09 (+ US-10/11/12 өвчний сан, хэрэглэгч удирдах).
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int _tab = 0;
  bool? _online;
  int _reviewCount = 0;

  @override
  void initState() {
    super.initState();
    ApiClient.instance.checkServer().then((ok) {
      if (mounted) setState(() => _online = ok);
    });
    _refreshCount();
  }

  Future<void> _refreshCount() async {
    try {
      final s = await ApiClient.instance.adminStats();
      if (mounted) setState(() => _reviewCount = s.needsReview);
    } catch (_) {}
  }

  Widget _header() {
    final ok = _online ?? true;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(children: [
        if (Navigator.of(context).canPop()) ...[
          GlassIconButton(icon: Icons.chevron_left, size: 36, onPressed: () => Navigator.maybePop(context)),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: ok ? kLeaf : kCoral, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(_online == null ? 'ШАЛГАЖ БАЙНА' : (ok ? 'СИСТЕМ ХЭВИЙН' : 'СЕРВЕРТЭЙ ХОЛБОГДОХГҮЙ'),
                  style: TextStyle(
                      fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w600, color: ok ? kLeaf : kCoral)),
            ]),
            const SizedBox(height: 2),
            Text('Админ удирдлага', style: serif(size: 20)),
          ]),
        ),
        const Pill('Администратор', color: kLeaf),
      ]),
    );
  }

  Widget _tabs() {
    final labels = ['Тойм', 'Хянах ($_reviewCount)', 'Өвчин', 'Хэрэглэгч'];
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: kGlassDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder)),
      child: Row(children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _tab = i);
                _refreshCount();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(color: _tab == i ? kEmerald : Colors.transparent, borderRadius: BorderRadius.circular(10)),
                child: Text(labels[i],
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11.5,
                        color: _tab == i ? Colors.white : kSlate,
                        fontWeight: _tab == i ? FontWeight.w700 : FontWeight.w500)),
              ),
            ),
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgBottom,
      body: LeafBackground(
        foliage: false,
        child: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(children: [
                _header(),
                _tabs(),
                Expanded(
                  child: IndexedStack(index: _tab, children: [
                    const _StatsTab(),
                    _ReviewTab(onChanged: _refreshCount),
                    const _DiseasesTab(),
                    const _UsersTab(),
                  ]),
                ),
              ]),
            ),
          ),
        ),
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

  Widget _metric(String label, String value, String sub, Color valueColor, {bool alert = false}) => Glass(
        color: alert ? kCoral.withAlpha(14) : kGlassCard,
        border: alert ? kCoral.withAlpha(76) : const Color(0x26FFFFFF),
        padding: const EdgeInsets.all(13),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11.5, color: kSlate)),
          const SizedBox(height: 3),
          Text(value, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: valueColor)),
          const SizedBox(height: 3),
          Text(sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: alert ? kCoral : kLeaf)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AdminStats>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const LoadingView();
        if (snap.hasError) return ErrorView(error: snap.error!, onRetry: _reload);
        final s = snap.data!;
        final week = s.last7Days;
        final weekTotal = week.fold<int>(0, (a, e) => a + e.value);
        final maxDay = week.fold<int>(1, (m, e) => e.value > m ? e.value : m);
        final avg = week.isEmpty ? 0 : (weekTotal / week.length);
        return RefreshIndicator(
          color: kLeaf,
          onRefresh: () async => _reload(),
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), children: [
            Row(children: [
              Expanded(child: _metric('Хэрэглэгч', '${s.users}', 'Бүртгэлтэй хэрэглэгч', kText)),
              const SizedBox(width: 8),
              Expanded(child: _metric('Нийт онош', '${s.diagnoses}', '7 хоногт: $weekTotal', kText)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                  child: _metric('Хянах шаардлагатай', '${s.needsReview}', 'Шинжээчийн хяналт', kCoral, alert: true)),
              const SizedBox(width: 8),
              Expanded(child: _metric('Өвчний сан', '${s.diseases}', '5 төрлийн таримал', kTeal)),
            ]),
            const SizedBox(height: 12),
            Glass(
              color: kGlassCard,
              border: const Color(0x26FFFFFF),
              padding: const EdgeInsets.all(14),
              child: Column(children: [
                Row(children: [
                  const Expanded(
                    child: Text('Сүүлийн 7 хоногийн оношилгоо',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kText)),
                  ),
                  Text('Дундаж: ${avg.toStringAsFixed(1)}/өдөр', style: const TextStyle(fontSize: 11, color: kLeaf)),
                ]),
                const SizedBox(height: 12),
                SizedBox(
                  height: 120,
                  child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    for (final e in week)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Builder(builder: (_) {
                            final date = DateTime.tryParse(e.key) ?? DateTime.now();
                            final isMax = e.value == maxDay && e.value > 0;
                            return Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                              Text('${e.value}', style: TextStyle(fontSize: 10, color: isMax ? kLeaf : kMuted)),
                              const SizedBox(height: 3),
                              Container(
                                height: 76 * e.value / maxDay + 4,
                                decoration: BoxDecoration(
                                  color: isMax ? kEmerald : kEmeraldDeep.withAlpha(110 + (e.value * 100 ~/ maxDay)),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                                  boxShadow: isMax ? [BoxShadow(color: kEmerald.withAlpha(180), blurRadius: 8)] : null,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(kWeekdays[(date.weekday - 1) % 7],
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: isMax ? kLeaf : kMuted,
                                      fontWeight: isMax ? FontWeight.w700 : FontWeight.w400)),
                            ]);
                          }),
                        ),
                      ),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            Glass(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const CapsLabel('Хамгийн их илэрсэн өвчин'),
                if (s.topDiseases.isEmpty)
                  const Text('Одоогоор өгөгдөл алга', style: TextStyle(color: kMuted, fontSize: 12.5))
                else
                  for (var i = 0; i < s.topDiseases.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(children: [
                        Expanded(
                          child: Text('${i + 1}. ${s.topDiseases[i].key}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: kText, fontSize: 12.5)),
                        ),
                        Pill('${s.topDiseases[i].value} удаа', color: i == 0 ? kCoral : (i == 1 ? kAmber : kLeaf)),
                      ]),
                    ),
              ]),
            ),
          ]),
        );
      },
    );
  }
}

// ----------------------------------------------------------------- Хянах
class _ReviewTab extends StatefulWidget {
  final VoidCallback? onChanged;
  const _ReviewTab({this.onChanged});

  @override
  State<_ReviewTab> createState() => _ReviewTabState();
}

class _ReviewTabState extends State<_ReviewTab> {
  bool _onlyReview = true;
  late Future<List<Diagnosis>> _future = _load();

  Future<List<Diagnosis>> _load() => ApiClient.instance.adminDiagnoses(status: _onlyReview ? 'needs_review' : '');

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Row(children: [
          FilterPill('Хянах шаардлагатай', selected: _onlyReview, onTap: () {
            _onlyReview = true;
            _reload();
          }),
          FilterPill('Бүх онош', selected: !_onlyReview, onTap: () {
            _onlyReview = false;
            _reload();
          }),
        ]),
      ),
      Expanded(
        child: FutureBuilder<List<Diagnosis>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const LoadingView();
            if (snap.hasError) return ErrorView(error: snap.error!, onRetry: _reload);
            final items = snap.data!;
            if (items.isEmpty) return const EmptyView(icon: Icons.task_alt, text: 'Хянах онош алга');
            return RefreshIndicator(
              color: kLeaf,
              onRefresh: () async => _reload(),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                itemCount: items.length,
                itemBuilder: (context, i) => DiagnosisTile(
                  d: items[i],
                  showUser: true,
                  onTap: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => ResultScreen(diagnosis: items[i])));
                    _reload();
                    widget.onChanged?.call();
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
    final changed =
        await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => DiseaseEditScreen(disease: full)));
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
    return Stack(children: [
      FutureBuilder<List<Disease>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingView();
          if (snap.hasError) return ErrorView(error: snap.error!, onRetry: _reload);
          final items = snap.data!;
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final d = items[i];
              final st = pathogenStyle(d.pathogen, d.isHealthy);
              return Glass(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
                onTap: () => _open(id: d.id),
                child: Row(children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: st.color.withAlpha(50), borderRadius: BorderRadius.circular(10)),
                    child: Text(st.emoji, style: const TextStyle(fontSize: 15)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(d.nameMn,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600, color: kText, fontSize: 13)),
                      Text('${kPlantEmoji[d.plant] ?? '🌿'} ${d.plant}',
                          style: const TextStyle(color: kMuted, fontSize: 11.5)),
                    ]),
                  ),
                  IconButton(
                    tooltip: 'Устгах',
                    icon: const Icon(Icons.delete_outline, color: kMuted, size: 20),
                    onPressed: () => _delete(d),
                  ),
                ]),
              );
            },
          );
        },
      ),
      Positioned(
        right: 18,
        bottom: 24,
        child: PillButton(label: 'Өвчин нэмэх', icon: Icons.add, onPressed: () => _open()),
      ),
    ]);
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
          color: kLeaf,
          onRefresh: () async => _reload(),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final u = items[i];
              final isMe = u.id == me?.id;
              final c = u.isAdmin ? kBlue : kLeaf;
              return Glass(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                child: Row(children: [
                  GradientAvatar(u.name, size: 38),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${u.name}${isMe ? ' (та)' : ''}',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: kText,
                              decoration: u.isActive ? null : TextDecoration.lineThrough)),
                      Text(u.email, style: const TextStyle(color: kMuted, fontSize: 11.5)),
                      const SizedBox(height: 4),
                      Wrap(spacing: 6, children: [
                        Pill(u.isAdmin ? 'Админ' : 'Хэрэглэгч', color: c),
                        if (!u.isActive) const Pill('Идэвхгүй', color: kCoral),
                      ]),
                    ]),
                  ),
                  if (!isMe)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: kMuted),
                      onSelected: (a) => _act(u, a),
                      itemBuilder: (_) => [
                        if (!u.isAdmin) const PopupMenuItem(value: 'admin', child: Text('Админ болгох')),
                        if (u.isAdmin) const PopupMenuItem(value: 'user', child: Text('Энгийн хэрэглэгч болгох')),
                        PopupMenuItem(value: 'toggle', child: Text(u.isActive ? 'Идэвхгүй болгох' : 'Идэвхжүүлэх')),
                        const PopupMenuItem(value: 'delete', child: Text('Устгах')),
                      ],
                    ),
                ]),
              );
            },
          ),
        );
      },
    );
  }
}
