import 'package:flutter/material.dart';

import '../models.dart';
import '../services/api_client.dart';
import '../widgets/common.dart';
import 'result_screen.dart';

/// Оношилгооны түүх.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen> {
  late Future<List<Diagnosis>> _future = ApiClient.instance.history();

  void reload() {
    if (!mounted) return;
    setState(() => _future = ApiClient.instance.history());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Оношилгооны түүх')),
      body: FutureBuilder<List<Diagnosis>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingView();
          if (snap.hasError) return ErrorView(error: snap.error!, onRetry: reload);
          final items = snap.data!;
          if (items.isEmpty) {
            return const EmptyView(icon: Icons.history, text: 'Одоогоор онош байхгүй.\n"Оношлох" цэсээс эхлээрэй.');
          }
          return RefreshIndicator(
            onRefresh: () async => reload(),
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) => DiagnosisTile(
                d: items[i],
                onTap: () async {
                  await Navigator.push(
                      context, MaterialPageRoute(builder: (_) => ResultScreen(diagnosis: items[i])));
                  reload();
                },
              ),
            ),
          );
        },
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
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: NetImage(d.overlayUrl, width: 72, height: 72),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(
                    '${d.disease?.plant ?? ''} · ${(d.confidence * 100).toStringAsFixed(0)}% · ${d.severity}',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Row(children: [
                    StatusChip(d),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        showUser ? '${d.userName} · ${formatDate(d.createdAt)}' : formatDate(d.createdAt),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ),
                  ]),
                ]),
              ),
              const Icon(Icons.chevron_right),
            ]),
          ),
        ),
      );
}
