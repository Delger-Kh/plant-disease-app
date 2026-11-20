import 'package:flutter/material.dart';

import '../models.dart';
import '../services/api_client.dart';
import '../widgets/common.dart';
import 'result_screen.dart';

/// Дэлгэц 06: Оношилгооны түүх.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen> {
  late Future<List<Diagnosis>> _future = ApiClient.instance.history();
  int _filter = 0; // 0 бүгд, 1 өвчтэй, 2 эрүүл

  void reload() {
    if (!mounted) return;
    setState(() => _future = ApiClient.instance.history());
  }

  bool _healthy(Diagnosis d) => d.disease?.isHealthy ?? false;

  Widget _summary(List<Diagnosis> items) {
    final healthy = items.where(_healthy).length;
    final review = items.where((d) => d.needsReview).length;
    Widget cell(String v, String l, Color c) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: const Color(0x33000000), borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              Text(v, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c)),
              const SizedBox(height: 2),
              Text(l, style: const TextStyle(fontSize: 11, color: kSlate)),
            ]),
          ),
        );
    return Glass.card(
      radius: 18,
      blur: false,
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(children: [
        Row(children: [
          cell('${items.length}', 'Нийт онош', kText),
          const SizedBox(width: 8),
          cell('${items.length - healthy}', 'Өвчин илэрсэн', kCoral),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          cell('$healthy', 'Эрүүл навч', kLeaf),
          const SizedBox(width: 8),
          cell('$review', 'Хянагдаж буй', kAmber),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: FutureBuilder<List<Diagnosis>>(
            future: _future,
            builder: (context, snap) {
              final header = const PageHeader('Оношилгооны түүх', subtitle: 'Нийт хийсэн оношлогооны бүртгэл');
              if (snap.connectionState != ConnectionState.done) {
                return Column(children: [
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: header),
                  const Expanded(child: LoadingView()),
                ]);
              }
              if (snap.hasError) return ErrorView(error: snap.error!, onRetry: reload);
              final all = snap.data!;
              final sick = all.where((d) => !_healthy(d)).toList();
              final healthy = all.where(_healthy).toList();
              final items = [all, sick, healthy][_filter];
              return RefreshIndicator(
                color: kLeaf,
                onRefresh: () async => reload(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                  children: [
                    header,
                    _summary(all),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        FilterPill('Бүгд (${all.length})', selected: _filter == 0, onTap: () => setState(() => _filter = 0)),
                        FilterPill('Өвчтэй (${sick.length})',
                            selected: _filter == 1, onTap: () => setState(() => _filter = 1)),
                        FilterPill('Эрүүл (${healthy.length})',
                            selected: _filter == 2, onTap: () => setState(() => _filter = 2)),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    if (items.isEmpty)
                      EmptyView(
                        icon: Icons.history,
                        text: all.isEmpty
                            ? 'Одоогоор онош байхгүй.\nДоорх ногоон "+" товчоор эхлээрэй.'
                            : 'Энэ ангилалд онош алга.',
                      )
                    else
                      ...items.map((d) => DiagnosisTile(
                            d: d,
                            onTap: () async {
                              await Navigator.push(
                                  context, MaterialPageRoute(builder: (_) => ResultScreen(diagnosis: d)));
                              reload();
                            },
                          )),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class DiagnosisTile extends StatelessWidget {
  final Diagnosis d;
  final VoidCallback onTap;
  final bool showUser;
  const DiagnosisTile({super.key, required this.d, required this.onTap, this.showUser = false});

  @override
  Widget build(BuildContext context) {
    final healthy = d.disease?.isHealthy ?? false;
    return Glass(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(children: [
        ClipRRect(borderRadius: BorderRadius.circular(12), child: NetImage(d.imageUrl, width: 46, height: 46)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(healthy ? 'Эрүүл навч' : d.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kText)),
            const SizedBox(height: 2),
            Text(
              '${kPlantEmoji[d.disease?.plant] ?? '🌿'} ${d.disease?.plant ?? ''} · '
              '${(d.confidence * 100).toStringAsFixed(0)}% ${healthy ? 'эрүүл' : 'итгэлцэл'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: kSlate),
            ),
            const SizedBox(height: 2),
            Text(
              showUser ? '${d.userName} · ${formatDate(d.createdAt)}' : formatDate(d.createdAt),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10.5, color: kMuted),
            ),
          ]),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Pill(d.needsReview ? 'Хянах' : d.severity, color: d.needsReview ? kAmber : severityColor(d.severity)),
          const SizedBox(height: 6),
          const Icon(Icons.chevron_right, color: kMuted, size: 18),
        ]),
      ]),
    );
  }
}
