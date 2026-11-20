import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_client.dart';
import '../widgets/common.dart';
import 'result_screen.dart';

/// US-03: Навчны зураг авах/сонгох, серверт илгээж оношлуулах.
class DiagnoseScreen extends StatefulWidget {
  final VoidCallback? onDiagnosed;
  const DiagnoseScreen({super.key, this.onDiagnosed});

  @override
  State<DiagnoseScreen> createState() => _DiagnoseScreenState();
}

class _DiagnoseScreenState extends State<DiagnoseScreen> {
  final _picker = ImagePicker();
  final _note = TextEditingController();
  Uint8List? _bytes;
  String _filename = 'leaf.jpg';
  bool _sending = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final x = await _picker.pickImage(source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 90);
      if (x == null) return;
      final b = await x.readAsBytes();
      setState(() {
        _bytes = b;
        _filename = x.name.isEmpty ? 'leaf.jpg' : x.name;
      });
    } catch (e) {
      if (mounted) showSnack(context, 'Зураг авч чадсангүй: $e', error: true);
    }
  }

  Future<void> _send() async {
    final bytes = _bytes;
    if (bytes == null) return;
    setState(() => _sending = true);
    try {
      final d = await ApiClient.instance.diagnose(bytes, _filename, note: _note.text.trim());
      widget.onDiagnosed?.call();
      if (!mounted) return;
      setState(() {
        _bytes = null;
        _note.clear();
      });
      Navigator.push(context, MaterialPageRoute(builder: (_) => ResultScreen(diagnosis: d)));
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 422 && e.details.isNotEmpty) {
        // <<extend>> Нэмэлт зураг хүсэх
        await showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
            icon: const Icon(Icons.photo_camera_back, color: Colors.orange, size: 40),
            title: const Text('Дахин зураг авна уу'),
            content: Text('${e.message}\n\n• ${e.details.join('\n• ')}'),
            actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Ойлголоо'))],
          ),
        );
      } else {
        showSnack(context, e.toString(), error: true);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ApiClient.instance.user;
    return Scaffold(
      appBar: AppBar(title: const Text('Ургамлын эмч')),
      body: _sending
          ? const LoadingView(text: 'AI навчийг шинжилж байна...\nТүр хүлээнэ үү')
          : ListView(padding: const EdgeInsets.all(16), children: [
              Text('Сайн байна уу, ${user?.name ?? ''}!', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('Өвчилсөн байж болзошгүй навчны зургийг оруулаарай.',
                  style: TextStyle(color: Colors.grey.shade700)),
              const SizedBox(height: 16),
              AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: kLightGreen,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kGreen.withAlpha(80), width: 1.5),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _bytes == null
                      ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.eco, size: 72, color: kGreen),
                          const SizedBox(height: 8),
                          Text('Зураг сонгоогүй байна', style: TextStyle(color: Colors.grey.shade700)),
                        ])
                      : Stack(fit: StackFit.expand, children: [
                          Image.memory(_bytes!, fit: BoxFit.cover),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: IconButton.filledTonal(
                              tooltip: 'Арилгах',
                              onPressed: () => setState(() => _bytes = null),
                              icon: const Icon(Icons.close),
                            ),
                          ),
                        ]),
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pick(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera),
                    label: const Text('Камер'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pick(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: Text(kIsWeb ? 'Файл сонгох' : 'Галерей'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                maxLength: 300,
                decoration: const InputDecoration(
                  labelText: 'Тэмдэглэл (заавал биш)',
                  hintText: 'Жишээ нь: хүлэмжийн улаан лооль, 2-р эгнээ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _bytes == null ? null : _send,
                icon: const Icon(Icons.biotech),
                label: const Text('Оношлох'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              ),
              const SizedBox(height: 20),
              const _TipsCard(),
            ]),
    );
  }
}

class _TipsCard extends StatelessWidget {
  const _TipsCard();

  @override
  Widget build(BuildContext context) => const SectionCard(
        title: 'Сайн зураг авах зөвлөгөө',
        icon: Icons.tips_and_updates_outlined,
        child: Text('• Нэг навчийг ойроос, бүтнээр нь авна\n'
            '• Өдрийн гэрэлд, сүүдэргүй газар авна\n'
            '• Камераа тогтвортой барьж, навч руу фокуслана\n'
            '• Энгийн, нэг өнгийн дэвсгэр (цаас, ширээ) дээр тавибал илүү нарийвчлалтай\n'
            '• Одоогоор алим, эрдэнэ шиш, усан үзэм, төмс, улаан лоолийг таньдаг'),
      );
}
