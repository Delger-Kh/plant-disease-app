import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models.dart';
import '../services/api_client.dart';
import '../widgets/common.dart';
import 'library_screen.dart';
import 'result_screen.dart';
import 'scan_screen.dart';

/// Дэлгэц 03: Нүүр. Скан руу орох, таньдаг ургамал, сүүлийн оношууд.
class DiagnoseScreen extends StatefulWidget {
  final VoidCallback? onOpenHistory;
  final VoidCallback? onOpenLibrary;
  final Future<void> Function()? onScan;
  const DiagnoseScreen({super.key, this.onOpenHistory, this.onOpenLibrary, this.onScan});

  @override
  State<DiagnoseScreen> createState() => DiagnoseScreenState();
}

class DiagnoseScreenState extends State<DiagnoseScreen> {
  final _picker = ImagePicker();
  List<Diagnosis> _recent = [];
  bool _loaded = false;

  static const _shortNames = {'Эрдэнэ шиш': 'Эрдэнэ', 'Улаан лооль': 'Лооль'};

  @override
  void initState() {
    super.initState();
    reloadRecent();
  }

  Future<void> reloadRecent() async {
    try {
      final h = await ApiClient.instance.history();
      if (mounted) {
        setState(() {
          _recent = h.take(3).toList();
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _scan() async {
    if (widget.onScan != null) {
      await widget.onScan!();
    } else {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanScreen()));
      reloadRecent();
    }
  }

  Future<void> _gallery() async {
    try {
      final x = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1600, maxHeight: 1600, imageQuality: 90);
      if (x == null || !mounted) return;
      final b = await x.readAsBytes();
      if (!mounted) return;
      await Navigator.push(
          context, MaterialPageRoute(builder: (_) => ScanScreen(initialBytes: b, initialName: x.name)));
      reloadRecent();
    } catch (e) {
      if (mounted) showSnack(context, 'Зураг сонгож чадсангүй: $e', error: true);
    }
  }

  Widget _header() {
    final user = ApiClient.instance.user;
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 16),
      child: Row(children: [
        const LeafLogo(size: 36),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Ургамлын эмч', style: serif(size: 16)),
            Text('Сайн байна уу, ${user?.name ?? ''} 👋',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: kMint.withAlpha(205), fontSize: 12)),
          ]),
        ),
        GradientAvatar(user?.name ?? '', size: 40),
      ]),
    );
  }

  Widget _search() => Glass(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
        onTap: widget.onOpenLibrary,
        child: Row(children: [
          Icon(Icons.search, color: kMint.withAlpha(150), size: 19),
          const SizedBox(width: 10),
          const Expanded(child: Text('Өвчин, ургамал хайх...', style: TextStyle(color: kMuted, fontSize: 13))),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0x1AFFFFFF), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.filter_alt_outlined, color: kMint, size: 17),
          ),
        ]),
      );

  Widget _hero() => Glass.card(
        margin: const EdgeInsets.only(bottom: 20),
        padding: EdgeInsets.zero,
        radius: 24,
        border: kBorderStrong,
        child: SizedBox(
          height: 150,
          child: Stack(clipBehavior: Clip.hardEdge, children: [
            const Positioned(right: -6, bottom: -4, child: PlantArt(size: 140)),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 130, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Ургамлаа эрүүл байлгая', style: serif(size: 17, height: 1.25)),
                const SizedBox(height: 6),
                Text('Навчны зураг оруулахад AI өвчнийг таньж, эмчилгээ зөвлөнө.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: kMintSoft.withAlpha(205), fontSize: 12, height: 1.4)),
                const Spacer(),
                Row(children: [
                  PillButton(label: '📷  Камер', small: true, onPressed: _scan),
                  const SizedBox(width: 8),
                  GlassIconButton(icon: Icons.image_outlined, size: 36, tooltip: 'Галерей', onPressed: _gallery),
                ]),
              ]),
            ),
          ]),
        ),
      );

  Widget _crops() {
    final names = kPlantEmoji.keys.toList();
    return Column(children: [
      SectionHeader('Таньдаг ургамал', action: '${names.length} төрөл'),
      Row(children: [
        for (var i = 0; i < names.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Glass(
              radius: 14,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => LibraryScreen(initialPlant: names[i]))),
              child: Column(children: [
                Text(kPlantEmoji[names[i]]!, style: const TextStyle(fontSize: 20)),
                const SizedBox(height: 4),
                Text(_shortNames[names[i]] ?? names[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10.5, color: Color(0xFFE2E8F0))),
              ]),
            ),
          ),
        ],
      ]),
      const SizedBox(height: 20),
    ]);
  }

  Widget _recentRow(Diagnosis d) {
    final c = (d.disease?.isHealthy ?? false) ? kLeaf : severityColor(d.severity);
    return Glass(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => ResultScreen(diagnosis: d)));
        reloadRecent();
      },
      child: Row(children: [
        ClipRRect(borderRadius: BorderRadius.circular(12), child: NetImage(d.imageUrl, width: 44, height: 44)),
        const SizedBox(width: 11),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(d.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kText)),
            const SizedBox(height: 2),
            Text('${formatDate(d.createdAt)} · ${kPlantEmoji[d.disease?.plant] ?? '🌿'} ${d.disease?.plant ?? ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: kMuted)),
          ]),
        ),
        Pill('${(d.confidence * 100).toStringAsFixed(0)}%', color: c),
        const SizedBox(width: 6),
        Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: RefreshIndicator(
            color: kLeaf,
            onRefresh: reloadRecent,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
              children: [
                _header(),
                _search(),
                _hero(),
                _crops(),
                SectionHeader('Сүүлийн оношууд', action: 'Бүгд →', onAction: widget.onOpenHistory),
                if (!_loaded)
                  const Padding(padding: EdgeInsets.all(24), child: LoadingView())
                else if (_recent.isEmpty)
                  Glass(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      const Text('🌱', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text('Одоогоор онош алга. Доорх ногоон "+" товчоор эхний навчаа шалгаарай.',
                            style: TextStyle(color: kSlate, fontSize: 12.5)),
                      ),
                    ]),
                  )
                else
                  ..._recent.map(_recentRow),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
