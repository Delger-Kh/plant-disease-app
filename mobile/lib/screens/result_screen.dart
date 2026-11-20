import 'package:flutter/material.dart';

import '../models.dart';
import '../services/api_client.dart';
import '../widgets/common.dart';
import 'scan_screen.dart';

/// Дэлгэц 05: Үр дүн. US-04/05/06.
class ResultScreen extends StatefulWidget {
  final Diagnosis diagnosis;
  const ResultScreen({super.key, required this.diagnosis});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late Diagnosis d = widget.diagnosis;
  bool _showOverlay = true;

  Future<void> _delete() async {
    final ok = await confirmDialog(context, 'Устгах уу?', 'Энэ оношийг түүхээс устгана.', ok: 'Устгах');
    if (!ok || !mounted) return;
    try {
      await ApiClient.instance.deleteDiagnosis(d.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  /// Админ: итгэлцэл багатай оношийг хянаж, зөв өвчнийг сонгон батална.
  Future<void> _review() async {
    try {
      final all = await ApiClient.instance.diseases();
      if (!mounted) return;
      final picked = await showDialog<Disease>(
        context: context,
        builder: (c) => SimpleDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('Зөв оношийг сонгоно уу', style: serif(size: 19)),
          children: [
            SizedBox(
              width: 400,
              height: 420,
              child: ListView(
                children: all
                    .map((x) => ListTile(
                          dense: true,
                          leading: Text(kPlantEmoji[x.plant] ?? '🌿', style: const TextStyle(fontSize: 20)),
                          title: Text(x.nameMn),
                          subtitle: Text(x.plant, style: const TextStyle(color: kMuted)),
                          trailing: x.key == d.disease?.key
                              ? const Icon(Icons.smart_toy_outlined, size: 18, color: kLeaf)
                              : null,
                          onTap: () => Navigator.pop(c, x),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      );
      if (picked == null) return;
      final updated = await ApiClient.instance.adminReview(d.id, picked.id);
      if (!mounted) return;
      setState(() => d = updated);
      showSnack(context, 'Онош баталгаажлаа');
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  Widget _toggle() {
    Widget seg(String label, bool value) {
      final sel = _showOverlay == value;
      return GestureDetector(
        onTap: () => setState(() => _showOverlay = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: sel ? kEmerald : Colors.transparent, borderRadius: BorderRadius.circular(20)),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12, color: sel ? Colors.white : kSlate, fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: kGlassDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kBorderStrong),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [seg('Гэмтэл', true), seg('Эх зураг', false)]),
    );
  }

  Widget _imageHeader(double h) => SizedBox(
        height: h,
        width: double.infinity,
        child: Stack(fit: StackFit.expand, children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: NetImage(_showOverlay ? d.overlayUrl : d.imageUrl, key: ValueKey(_showOverlay), fit: BoxFit.cover),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.35, 1.0],
                colors: [Color(0x66000000), Color(0x00000000), kBg1],
              ),
            ),
          ),
          if (_showOverlay && !(d.disease?.isHealthy ?? false))
            Positioned(
              left: 16,
              bottom: 48,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: kCoral.withAlpha(60),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kCoral, width: 1.5),
                ),
                child: const Text('● Гэмтсэн хэсэг', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ),
        ]),
      );

  Widget _topBar(bool isAdmin) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
          child: Row(children: [
            GlassIconButton(icon: Icons.close, size: 36, tooltip: 'Хаах', onPressed: () => Navigator.maybePop(context)),
            const Spacer(),
            _toggle(),
            const Spacer(),
            if (isAdmin) ...[
              GlassIconButton(icon: Icons.fact_check_outlined, size: 36, tooltip: 'Хянаж батлах', onPressed: _review),
              const SizedBox(width: 8),
            ],
            GlassIconButton(icon: Icons.delete_outline, size: 36, tooltip: 'Устгах', onPressed: _delete),
          ]),
        ),
      );

  Widget _sheet() {
    final disease = d.disease;
    final healthy = disease?.isHealthy ?? false;
    final others = d.topPredictions.skip(1).toList();
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: const BoxDecoration(
        color: kGlassCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [BoxShadow(color: Color(0x1FFFFFFF), offset: Offset(0, -1))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 8, runSpacing: 6, children: [
          StatusChip(d),
          Pill(d.severity, color: severityColor(d.severity)),
        ]),
        const SizedBox(height: 10),
        Text(d.title, style: serif(size: 23, height: 1.2)),
        if (disease != null) ...[
          const SizedBox(height: 3),
          Text('${kPlantEmoji[disease.plant] ?? '🌿'} ${disease.plant} · ${disease.nameEn}',
              style: TextStyle(color: kMint.withAlpha(205), fontSize: 12.5, fontStyle: FontStyle.italic)),
        ],
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
              child: MetricTile(
                  value: '${(d.confidence * 100).toStringAsFixed(0)}%',
                  label: 'AI итгэлцэл',
                  color: d.needsReview ? kAmber : kLeaf)),
          const SizedBox(width: 8),
          Expanded(
              child: MetricTile(
                  value: '${d.affectedPct.toStringAsFixed(d.affectedPct < 10 ? 1 : 0)}%',
                  label: 'Гэмтсэн талбай',
                  color: healthy ? kLeaf : kCoral)),
          const SizedBox(width: 8),
          Expanded(child: MetricTile(value: '${disease?.treatments.length ?? 0}', label: 'Зөвлөмж', color: kTeal)),
        ]),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0x4D064E3B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kEmerald.withAlpha(76)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('💡', style: TextStyle(fontSize: 15)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(d.message, style: const TextStyle(color: Color(0xFFD1FAE5), fontSize: 12.5, height: 1.45)),
            ),
          ]),
        ),
        for (final w in d.warnings)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kAmber.withAlpha(30),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kAmber.withAlpha(76)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('⚠️', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              Expanded(child: Text(w, style: const TextStyle(color: Color(0xFFFDE68A), fontSize: 12.5))),
            ]),
          ),
        if (d.note.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('Тэмдэглэл: ${d.note}', style: const TextStyle(color: kMuted, fontSize: 12)),
        ],
        if (others.isNotEmpty) ...[
          const SizedBox(height: 18),
          const CapsLabel('Бусад боломжит онош'),
          for (final p in others)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(
                    child: Text('${p.nameMn} (${p.plant})',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kSlate, fontSize: 12)),
                  ),
                  Text('${(p.confidence * 100).toStringAsFixed(1)}%', style: const TextStyle(color: kSlate, fontSize: 12)),
                ]),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: p.confidence.clamp(0.0, 1.0),
                    minHeight: 6,
                    color: const Color(0xFF64748B),
                    backgroundColor: const Color(0xFF1E293B),
                  ),
                ),
              ]),
            ),
        ],
        if (disease != null && disease.treatments.isNotEmpty) ...[
          const SizedBox(height: 14),
          CapsLabel(healthy ? 'Арчилгааны зөвлөгөө' : 'Эмчилгээний зөвлөмж'),
          ...disease.treatments.map((t) => TreatmentRow(t)),
        ],
        if (disease != null) ...[
          const SizedBox(height: 14),
          DiseaseDetails(disease, showTreatments: false),
        ],
        const SizedBox(height: 10),
        PillButton(
          label: 'Дахин оношлох',
          icon: Icons.center_focus_strong,
          expand: true,
          onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ScanScreen())),
        ),
        const SizedBox(height: 10),
        Text(formatDate(d.createdAt), textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5, color: kMuted)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ApiClient.instance.user?.isAdmin ?? false;
    final width = MediaQuery.of(context).size.width.clamp(0.0, 520.0);
    final imageH = width * 0.82;
    return Scaffold(
      backgroundColor: kBg1,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Stack(children: [
            SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _imageHeader(imageH),
                Transform.translate(offset: const Offset(0, -32), child: _sheet()),
              ]),
            ),
            _topBar(isAdmin),
          ]),
        ),
      ),
    );
  }
}
