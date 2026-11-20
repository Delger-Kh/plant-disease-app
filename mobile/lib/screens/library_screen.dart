import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';
import '../services/api_client.dart';
import '../widgets/common.dart';
import 'scan_screen.dart';

/// Дэлгэц 07: Өвчний сан. US-07/08.
class LibraryScreen extends StatefulWidget {
  final String initialPlant;
  const LibraryScreen({super.key, this.initialPlant = ''});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  late String _plant = widget.initialPlant;
  List<String> _plants = kPlantEmoji.keys.toList();
  late Future<List<Disease>> _future = _load();

  static const _shortNames = {'Улаан лооль': 'Лооль'};

  @override
  void initState() {
    super.initState();
    ApiClient.instance.plants().then((p) {
      if (mounted && p.isNotEmpty) setState(() => _plants = p);
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

  Widget _row(Disease x) {
    final st = pathogenStyle(x.pathogen, x.isHealthy);
    final latin = latinName(x.pathogen);
    final plantLabel = _shortNames[x.plant] ?? x.plant;
    return Glass(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DiseaseDetailScreen(diseaseId: x.id))),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: st.color.withAlpha(50), borderRadius: BorderRadius.circular(12)),
          child: Text(st.emoji, style: const TextStyle(fontSize: 17)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(x.nameMn,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kText)),
            const SizedBox(height: 2),
            Text('${kPlantEmoji[x.plant] ?? '🌿'} $plantLabel · ${latin.isNotEmpty ? latin : x.nameEn}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: kMuted, fontStyle: FontStyle.italic)),
          ]),
        ),
        const Icon(Icons.chevron_right, color: kMuted, size: 18),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pushed = Navigator.of(context).canPop();
    return AppScaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: FutureBuilder<List<Disease>>(
            future: _future,
            builder: (context, snap) {
              final items = snap.data ?? const <Disease>[];
              final diseases = items.where((x) => !x.isHealthy).length;
              final subtitle = snap.hasData
                  ? 'Нийт $diseases төрлийн өвчин · ${items.length - diseases} эрүүл ангилал'
                  : 'Ургамлын өвчний мэдлэгийн сан';
              return ListView(
                padding: EdgeInsets.fromLTRB(16, 4, 16, pushed ? 24 : 120),
                children: [
                  PageHeader('Өвчний нэгдсэн сан', subtitle: subtitle),
                  TextField(
                    controller: _search,
                    style: const TextStyle(fontSize: 13.5),
                    decoration: glassInput(
                      '',
                      icon: Icons.search,
                      hint: 'Өвчний нэрээр хайх...',
                      suffix: _search.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear, color: kMuted, size: 18),
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
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      for (final p in ['', ..._plants])
                        FilterPill(
                          p.isEmpty ? 'Бүгд' : '${kPlantEmoji[p] ?? '🌱'} $p',
                          selected: _plant == p,
                          onTap: () {
                            _plant = p;
                            _reload();
                          },
                        ),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  if (snap.connectionState != ConnectionState.done)
                    const Padding(padding: EdgeInsets.all(32), child: LoadingView())
                  else if (snap.hasError)
                    ErrorView(error: snap.error!, onRetry: _reload)
                  else if (items.isEmpty)
                    const EmptyView(icon: Icons.search_off, text: 'Илэрц олдсонгүй')
                  else
                    ...items.map(_row),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Дэлгэц 08: Өвчний мэдээллийн хуудас.
class DiseaseDetailScreen extends StatefulWidget {
  final int diseaseId;
  const DiseaseDetailScreen({super.key, required this.diseaseId});

  @override
  State<DiseaseDetailScreen> createState() => _DiseaseDetailScreenState();
}

class _DiseaseDetailScreenState extends State<DiseaseDetailScreen> {
  late Future<Disease> _future = ApiClient.instance.disease(widget.diseaseId);

  Widget _hero(Disease d) {
    final st = pathogenStyle(d.pathogen, d.isHealthy);
    final latin = latinName(d.pathogen);
    return Container(
      height: 180,
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kBorderStrong),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF1F5A3D), Color(0xFF0F2E20), Color(0xFF07150E)],
        ),
      ),
      child: Stack(children: [
        Positioned(
          right: -20,
          top: -18,
          child: Transform.rotate(angle: 0.4, child: Icon(Icons.eco, size: 170, color: kLeaf.withAlpha(30))),
        ),
        Positioned(
          right: 18,
          top: 14,
          child: Text(kPlantEmoji[d.plant] ?? '🌿', style: const TextStyle(fontSize: 64)),
        ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0xCC000000), Color(0x4D000000), Color(0x00000000)],
              ),
            ),
          ),
        ),
        Positioned(
          left: 14,
          right: 14,
          bottom: 14,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 6, children: [
              Pill('${kPlantEmoji[d.plant] ?? '🌿'} ${d.plant}', color: kEmerald, solid: true),
              Pill(st.type, color: st.color == kLeaf ? kEmerald : st.color, solid: true),
            ]),
            const SizedBox(height: 6),
            Text(d.nameMn, style: serif(size: 21, height: 1.15)),
            if (latin.isNotEmpty || d.nameEn.isNotEmpty)
              Text(latin.isNotEmpty ? latin : d.nameEn,
                  style: const TextStyle(color: kMintSoft, fontSize: 12, fontStyle: FontStyle.italic)),
          ]),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: FutureBuilder<Disease>(
            future: _future,
            builder: (context, snap) {
              final top = Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(children: [
                  GlassIconButton(icon: Icons.chevron_left, size: 36, onPressed: () => Navigator.maybePop(context)),
                  const Expanded(
                    child: Text('Мэдээллийн хуудас',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kText)),
                  ),
                  const SizedBox(width: 36),
                ]),
              );
              if (snap.connectionState != ConnectionState.done) {
                return Column(children: [top, const Expanded(child: LoadingView())]);
              }
              if (snap.hasError) {
                return Column(children: [
                  top,
                  Expanded(
                    child: ErrorView(
                      error: snap.error!,
                      onRetry: () => setState(() => _future = ApiClient.instance.disease(widget.diseaseId)),
                    ),
                  ),
                ]);
              }
              final d = snap.data!;
              return ListView(padding: const EdgeInsets.only(bottom: 28), children: [
                top,
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    _hero(d),
                    DiseaseDetails(d),
                    const SizedBox(height: 10),
                    PillButton(
                      label: 'Оношилгоо хийж эхлэх',
                      icon: Icons.center_focus_strong,
                      expand: true,
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanScreen())),
                    ),
                  ]),
                ),
              ]);
            },
          ),
        ),
      ),
    );
  }
}
