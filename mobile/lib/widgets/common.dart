import 'package:flutter/material.dart';

import '../models.dart';
import '../services/api_client.dart';

const kGreen = Color(0xFF2E7D32);
const kLightGreen = Color(0xFFE8F5E9);

String formatDate(DateTime d) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d.year}.${two(d.month)}.${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
}

void showSnack(BuildContext context, String text, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(text),
    backgroundColor: error ? Colors.red.shade700 : null,
  ));
}

Future<bool> confirmDialog(BuildContext context, String title, String body, {String ok = 'Тийм'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Болих')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(ok)),
      ],
    ),
  );
  return r ?? false;
}

class LoadingView extends StatelessWidget {
  final String? text;
  const LoadingView({super.key, this.text});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(),
          if (text != null) ...[const SizedBox(height: 16), Text(text!, textAlign: TextAlign.center)],
        ]),
      );
}

class ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;
  const ErrorView({super.key, required this.error, this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.cloud_off, size: 56, color: Colors.grey.shade500),
            const SizedBox(height: 12),
            Text(error.toString(), textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Дахин оролдох')),
            ],
          ]),
        ),
      );
}

class EmptyView extends StatelessWidget {
  final IconData icon;
  final String text;
  const EmptyView({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
          ]),
        ),
      );
}

/// Серверийн зураг (алдаа гарвал дүрс харуулна).
class NetImage extends StatelessWidget {
  final String path;
  final double? height;
  final double? width;
  final BoxFit fit;
  const NetImage(this.path, {super.key, this.height, this.width, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) => Image.network(
        ApiClient.instance.mediaUrl(path),
        height: height,
        width: width,
        fit: fit,
        errorBuilder: (_, __, ___) => Container(
          height: height,
          width: width,
          color: Colors.grey.shade200,
          child: const Icon(Icons.broken_image, color: Colors.grey),
        ),
        loadingBuilder: (c, child, p) => p == null
            ? child
            : SizedBox(height: height, width: width, child: const Center(child: CircularProgressIndicator())),
      );
}

Color severityColor(String severity) {
  switch (severity) {
    case 'Эрүүл':
      return Colors.green.shade600;
    case 'Анхан шат':
      return Colors.lightGreen.shade700;
    case 'Бага':
      return Colors.amber.shade700;
    case 'Дунд':
      return Colors.orange.shade800;
    case 'Хүнд':
      return Colors.red.shade700;
    default:
      return Colors.grey.shade600;
  }
}

class StatusChip extends StatelessWidget {
  final Diagnosis d;
  const StatusChip(this.d, {super.key});

  @override
  Widget build(BuildContext context) {
    final color = d.needsReview
        ? Colors.orange.shade800
        : d.status == 'confirmed'
            ? Colors.blue.shade700
            : kGreen;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(20)),
      child: Text(d.statusLabel, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class Pill extends StatelessWidget {
  final String text;
  final Color color;
  const Pill(this.text, {super.key, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      );
}

class SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const SectionCard({super.key, required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, color: kGreen, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
            ]),
            const SizedBox(height: 10),
            child,
          ]),
        ),
      );
}

class TreatmentTile extends StatelessWidget {
  final Treatment t;
  const TreatmentTile(this.t, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(t.isOrganic ? Icons.eco : Icons.science, color: t.isOrganic ? kGreen : Colors.indigo, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(t.method, style: const TextStyle(fontWeight: FontWeight.w600)),
                Pill(t.isOrganic ? 'Органик' : 'Химийн', color: t.isOrganic ? kGreen : Colors.indigo),
              ]),
              if (t.instructions.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(t.instructions, style: TextStyle(color: Colors.grey.shade800)),
              ],
            ]),
          ),
        ]),
      );
}

/// Өвчний дэлгэрэнгүй мэдээлэл (оношийн үр дүн ба өвчний санд хоёуланд ашиглана).
class DiseaseDetails extends StatelessWidget {
  final Disease d;
  const DiseaseDetails(this.d, {super.key});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (d.symptoms.isNotEmpty)
          SectionCard(title: 'Шинж тэмдэг', icon: Icons.visibility, child: Text(d.symptoms)),
        if (d.description.isNotEmpty || d.pathogen.isNotEmpty)
          SectionCard(
            title: 'Өвчний тухай',
            icon: Icons.info_outline,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (d.pathogen.isNotEmpty && d.pathogen != '—') ...[
                Text('Үүсгэгч: ${d.pathogen}', style: const TextStyle(fontStyle: FontStyle.italic)),
                const SizedBox(height: 6),
              ],
              Text(d.description),
            ]),
          ),
        if (d.treatments.isNotEmpty)
          SectionCard(
            title: d.isHealthy ? 'Арчилгааны зөвлөгөө' : 'Эмчилгээний зөвлөмж',
            icon: Icons.healing,
            child: Column(children: d.treatments.map((t) => TreatmentTile(t)).toList()),
          ),
        if (d.prevention.isNotEmpty)
          SectionCard(title: 'Урьдчилан сэргийлэх', icon: Icons.shield_outlined, child: Text(d.prevention)),
        if (!d.isHealthy)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Text(
              'Химийн бодис хэрэглэхдээ шошгон дээрх тун, хамгаалалт, хураалтын өмнөх хүлээх хугацааг заавал баримтална уу.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ),
      ]);
}
