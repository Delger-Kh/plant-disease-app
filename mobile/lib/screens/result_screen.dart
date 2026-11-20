import 'package:flutter/material.dart';

import '../models.dart';
import '../services/api_client.dart';
import '../widgets/common.dart';

/// US-04/05/06: Оношийн үр дүн, гэмтсэн хэсгийн зураг, эмчилгээний зөвлөмж.
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
          title: const Text('Зөв оношийг сонгоно уу'),
          children: [
            SizedBox(
              width: 400,
              height: 420,
              child: ListView(
                children: all
                    .map((x) => ListTile(
                          dense: true,
                          title: Text(x.nameMn),
                          subtitle: Text(x.plant),
                          trailing: x.key == d.disease?.key ? const Icon(Icons.smart_toy, size: 18) : null,
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

  @override
  Widget build(BuildContext context) {
    final disease = d.disease;
    final isAdmin = ApiClient.instance.user?.isAdmin ?? false;
    final healthy = disease?.isHealthy ?? false;
    final mainColor = d.needsReview ? Colors.orange.shade800 : (healthy ? kGreen : Colors.red.shade700);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Оношийн үр дүн'),
        actions: [
          if (isAdmin)
            IconButton(tooltip: 'Хянаж батлах', onPressed: _review, icon: const Icon(Icons.fact_check)),
          IconButton(tooltip: 'Устгах', onPressed: _delete, icon: const Icon(Icons.delete_outline)),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // ------------------------------------------------ Зураг (эх / гэмтэл тодруулсан)
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 1,
            child: NetImage(_showOverlay ? d.overlayUrl : d.imageUrl, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, icon: Icon(Icons.layers), label: Text('Гэмтэл')),
              ButtonSegment(value: false, icon: Icon(Icons.image), label: Text('Эх зураг')),
            ],
            selected: {_showOverlay},
            onSelectionChanged: (s) => setState(() => _showOverlay = s.first),
          ),
        ),
        if (_showOverlay)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Улаан — гэмтсэн хэсэг, ногоон хүрээ — навчны хил',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          ),
        const SizedBox(height: 16),

        // ------------------------------------------------ Гол дүгнэлт
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(healthy ? Icons.verified : Icons.coronavirus_outlined, color: mainColor, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(d.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(color: mainColor)),
                    if (disease != null)
                      Text('${disease.plant} · ${disease.nameEn}',
                          style: TextStyle(color: Colors.grey.shade700)),
                  ]),
                ),
              ]),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 6, children: [
                StatusChip(d),
                Pill('Зэрэг: ${d.severity}', color: severityColor(d.severity)),
              ]),
              const SizedBox(height: 14),
              _Metric(label: 'AI итгэлцэл', value: d.confidence, color: mainColor),
              const SizedBox(height: 10),
              _Metric(
                  label: 'Гэмтсэн талбай', value: d.affectedPct / 100, color: severityColor(d.severity)),
              const SizedBox(height: 14),
              Text(d.message),
              if (d.note.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Тэмдэглэл: ${d.note}', style: TextStyle(color: Colors.grey.shade700)),
              ],
              const SizedBox(height: 6),
              Text(formatDate(d.createdAt), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ]),
          ),
        ),
        const SizedBox(height: 12),

        // ------------------------------------------------ Анхааруулга
        for (final w in d.warnings)
          Card(
            color: Colors.orange.shade50,
            child: ListTile(
              leading: Icon(Icons.warning_amber, color: Colors.orange.shade800),
              title: Text(w, style: const TextStyle(fontSize: 14)),
            ),
          ),

        // ------------------------------------------------ Бусад магадлал
        if (d.topPredictions.length > 1)
          SectionCard(
            title: 'Бусад боломжит онош',
            icon: Icons.format_list_numbered,
            child: Column(
              children: d.topPredictions
                  .map((p) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(children: [
                          Expanded(child: Text('${p.nameMn} (${p.plant})')),
                          Text('${(p.confidence * 100).toStringAsFixed(1)}%',
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                        ]),
                      ))
                  .toList(),
            ),
          ),

        // ------------------------------------------------ Өвчний мэдээлэл, эмчилгээ
        if (disease != null) DiseaseDetails(disease),
        const SizedBox(height: 24),
      ]),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final double value; // 0..1
  final Color color;
  const _Metric({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(label)),
        Text('${(v * 100).toStringAsFixed(v < 0.1 ? 1 : 0)}%', style: const TextStyle(fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 4),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
            value: v, minHeight: 8, color: color, backgroundColor: Colors.grey.shade200),
      ),
    ]);
  }
}
