import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';
import '../services/api_client.dart';
import '../widgets/common.dart';

/// US-07/08: Ургамлын жагсаалт ба өвчний сангаас хайх.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _plant = '';
  List<String> _plants = [];
  late Future<List<Disease>> _future = _load();

  @override
  void initState() {
    super.initState();
    ApiClient.instance.plants().then((p) {
      if (mounted) setState(() => _plants = p);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<List<Disease>> _load() => ApiClient.instance.diseases(q: _search.text.trim(), plant: _plant);

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Өвчний сан')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            controller: _search,
            decoration: InputDecoration(
              hintText: 'Өвчин, шинж тэмдгээр хайх...',
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _search.clear();
                        _reload();
                      }),
            ),
            onChanged: (_) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 400), _reload);
            },
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final p in ['', ..._plants])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(p.isEmpty ? 'Бүгд' : p),
                    selected: _plant == p,
                    onSelected: (_) {
                      _plant = p;
                      _reload();
                    },
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Disease>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return const LoadingView();
              if (snap.hasError) return ErrorView(error: snap.error!, onRetry: _reload);
              final items = snap.data!;
              if (items.isEmpty) return const EmptyView(icon: Icons.search_off, text: 'Илэрц олдсонгүй');
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final x = items[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: x.isHealthy ? kLightGreen : Colors.red.shade50,
                        child: Icon(x.isHealthy ? Icons.eco : Icons.coronavirus_outlined,
                            color: x.isHealthy ? kGreen : Colors.red.shade700),
                      ),
                      title: Text(x.nameMn),
                      subtitle: Text('${x.plant} · ${x.nameEn}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                          context, MaterialPageRoute(builder: (_) => DiseaseDetailScreen(diseaseId: x.id))),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}

class DiseaseDetailScreen extends StatefulWidget {
  final int diseaseId;
  const DiseaseDetailScreen({super.key, required this.diseaseId});

  @override
  State<DiseaseDetailScreen> createState() => _DiseaseDetailScreenState();
}

class _DiseaseDetailScreenState extends State<DiseaseDetailScreen> {
  late Future<Disease> _future = ApiClient.instance.disease(widget.diseaseId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Өвчний мэдээлэл')),
      body: FutureBuilder<Disease>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingView();
          if (snap.hasError) {
            return ErrorView(
                error: snap.error!,
                onRetry: () => setState(() => _future = ApiClient.instance.disease(widget.diseaseId)));
          }
          final d = snap.data!;
          return ListView(padding: const EdgeInsets.all(16), children: [
            Text(d.nameMn, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text('${d.plant} · ${d.nameEn}', style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 16),
            DiseaseDetails(d),
          ]);
        },
      ),
    );
  }
}
