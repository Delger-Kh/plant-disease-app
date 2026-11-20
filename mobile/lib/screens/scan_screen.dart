import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_client.dart';
import '../widgets/common.dart';
import 'result_screen.dart';

/// Дэлгэц 04: Скан. Хүрээ (4 булан) + гүйдэг скан шугам.
/// Төв товч: зураггүй үед камер нээнэ, зурагтай үед серверт илгээж оношилно.
class ScanScreen extends StatefulWidget {
  final Uint8List? initialBytes;
  final String initialName;
  const ScanScreen({super.key, this.initialBytes, this.initialName = 'leaf.jpg'});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with SingleTickerProviderStateMixin {
  final _picker = ImagePicker();
  late final AnimationController _anim =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat(reverse: true);
  late Uint8List? _bytes = widget.initialBytes;
  late String _filename = widget.initialName;
  String _note = '';
  bool _sending = false;

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final x = await _picker.pickImage(source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 90);
      if (x == null) return;
      final b = await x.readAsBytes();
      if (!mounted) return;
      setState(() {
        _bytes = b;
        _filename = x.name.isEmpty ? 'leaf.jpg' : x.name;
      });
    } catch (e) {
      if (mounted) showSnack(context, 'Зураг авч чадсангүй: $e', error: true);
    }
  }

  Future<void> _editNote() async {
    final ctrl = TextEditingController(text: _note);
    final r = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Тэмдэглэл', style: serif(size: 20)),
        content: TextField(
          controller: ctrl,
          maxLength: 300,
          autofocus: true,
          decoration: glassInput('', hint: 'Жишээ нь: хүлэмжийн улаан лооль, 2-р эгнээ'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Болих')),
          FilledButton(onPressed: () => Navigator.pop(c, ctrl.text.trim()), child: const Text('Хадгалах')),
        ],
      ),
    );
    if (r != null) setState(() => _note = r);
  }

  Future<void> _send() async {
    final bytes = _bytes;
    if (bytes == null) return;
    setState(() => _sending = true);
    try {
      final d = await ApiClient.instance.diagnose(bytes, _filename, note: _note);
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ResultScreen(diagnosis: d)));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      if (e.statusCode == 422 && e.details.isNotEmpty) {
        // <<extend>> Нэмэлт зураг хүсэх
        await showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            icon: const Icon(Icons.photo_camera_back_outlined, color: kAmber, size: 40),
            title: Text('Дахин зураг авна уу', style: serif(size: 20)),
            content: Text('${e.message}\n\n• ${e.details.join('\n• ')}', style: const TextStyle(color: kSlate)),
            actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Ойлголоо'))],
          ),
        );
        if (mounted) setState(() => _bytes = null);
      } else {
        showSnack(context, e.toString(), error: true);
      }
    }
  }

  Widget _bracket({required bool top, required bool left}) => Positioned(
        top: top ? 0 : null,
        bottom: top ? null : 0,
        left: left ? 0 : null,
        right: left ? null : 0,
        child: CustomPaint(size: const Size(36, 36), painter: _BracketPainter(top: top, left: left)),
      );

  Widget _roundButton(Widget child, VoidCallback? onTap, {String? tooltip}) {
    final b = Material(
      color: const Color(0x33FFFFFF),
      shape: const CircleBorder(side: BorderSide(color: kBorderStrong)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 46, height: 46, child: Center(child: child)),
      ),
    );
    return tooltip == null ? b : Tooltip(message: tooltip, child: b);
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _bytes != null;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(fit: StackFit.expand, children: [
        // ---------------------------------------------- Дэвсгэр: сонгосон зураг эсвэл навчны хээ
        if (hasImage)
          Image.memory(_bytes!, fit: BoxFit.cover)
        else
          const LeafBackground(child: SizedBox()),
        Container(color: Colors.black.withAlpha(hasImage ? 70 : 40)),
        SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
                child: Column(children: [
                  // ---------------------------------------------- Дээд мөр
                  Row(children: [
                    _roundButton(const Icon(Icons.close, color: Colors.white, size: 20), () => Navigator.maybePop(context),
                        tooltip: 'Хаах'),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0x80000000),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: kBorderStrong),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        FadeTransition(
                          opacity: _anim,
                          child: Container(
                              width: 8, height: 8, decoration: const BoxDecoration(color: kLeaf, shape: BoxShape.circle)),
                        ),
                        const SizedBox(width: 7),
                        const Text('AI Идэвхтэй',
                            style: TextStyle(color: kMint, fontSize: 12, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                    const Spacer(),
                    _roundButton(
                      Icon(_note.isEmpty ? Icons.edit_note : Icons.sticky_note_2, color: kAmber, size: 22),
                      _editNote,
                      tooltip: 'Тэмдэглэл',
                    ),
                  ]),
                  const Spacer(),
                  // ---------------------------------------------- Хүрээ + скан шугам
                  SizedBox(
                    width: 256,
                    height: 288,
                    child: Stack(children: [
                      _bracket(top: true, left: true),
                      _bracket(top: true, left: false),
                      _bracket(top: false, left: true),
                      _bracket(top: false, left: false),
                      if (!hasImage)
                        AnimatedBuilder(
                          animation: _anim,
                          builder: (context, _) => Positioned(
                            left: 8,
                            right: 8,
                            top: 20 + 244 * Curves.easeInOut.transform(_anim.value),
                            child: Opacity(
                              opacity: 0.35 + 0.6 * (1 - (2 * _anim.value - 1).abs()),
                              child: Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                      colors: [Color(0x0034D399), Color(0xFF6EE7B7), Color(0x0034D399)]),
                                  boxShadow: [BoxShadow(color: kLeaf.withAlpha(200), blurRadius: 18)],
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (hasImage)
                        Positioned(
                          top: 14,
                          left: 14,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: kEmeraldDeep.withAlpha(210),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: kMint.withAlpha(100)),
                            ),
                            child: const Text('ЗУРАГ БЭЛЭН',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                          ),
                        ),
                    ]),
                  ),
                  const Spacer(),
                  // ---------------------------------------------- Төлөвийн карт
                  Glass.card(
                    radius: 18,
                    padding: const EdgeInsets.all(11),
                    border: const Color(0x40FFFFFF),
                    child: Row(children: [
                      Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: kEmeraldDeep.withAlpha(76),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: kLeaf.withAlpha(100)),
                        ),
                        child: const Text('🌿', style: TextStyle(fontSize: 18)),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(hasImage ? 'Навчны зураг бэлэн' : 'Навчаа хүрээнд багтаана уу',
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(
                            hasImage
                                ? (_note.isEmpty ? 'Ногоон товчийг дарж оношилно уу' : 'Тэмдэглэл: $_note')
                                : (kIsWeb ? 'Ногоон товчоор зураг сонгоно уу' : 'Камераа тогтвортой барина уу'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: kMintSoft.withAlpha(205), fontSize: 11.5),
                          ),
                        ]),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0x99022C22),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: kEmerald.withAlpha(76)),
                        ),
                        child: Text(hasImage ? 'Бэлэн' : 'Хүлээж байна',
                            style: TextStyle(
                                color: hasImage ? kMint : kSlate, fontSize: 11.5, fontWeight: FontWeight.w600)),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 18),
                  // ---------------------------------------------- Товчнууд
                  Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                    _roundButton(const Icon(Icons.photo_library_outlined, color: Colors.white, size: 21),
                        _sending ? null : () => _pick(ImageSource.gallery),
                        tooltip: 'Галерей'),
                    Tooltip(
                      message: hasImage ? 'Оношлох' : (kIsWeb ? 'Зураг сонгох' : 'Зураг авах'),
                      child: GestureDetector(
                        onTap: _sending
                            ? null
                            : (hasImage ? _send : () => _pick(kIsWeb ? ImageSource.gallery : ImageSource.camera)),
                        child: Container(
                          width: 76,
                          height: 76,
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withAlpha(205), width: 4),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                  begin: Alignment.bottomLeft, end: Alignment.topRight, colors: [kEmerald, kLeaf]),
                              boxShadow: [BoxShadow(color: kEmerald.withAlpha(200), blurRadius: 20)],
                            ),
                            child: _sending
                                ? const Padding(
                                    padding: EdgeInsets.all(18),
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                                : Icon(hasImage ? Icons.biotech : Icons.add, color: Colors.white, size: 28),
                          ),
                        ),
                      ),
                    ),
                    _roundButton(const Icon(Icons.refresh, color: Colors.white, size: 22),
                        _sending || !hasImage ? null : () => setState(() => _bytes = null),
                        tooltip: 'Дахин авах'),
                  ]),
                  if (_sending) ...[
                    const SizedBox(height: 12),
                    const Text('AI навчийг шинжилж байна...', style: TextStyle(color: kMint, fontSize: 12.5)),
                  ],
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Хүрээний нэг булан (L хэлбэр, бөөрөнхий өнцөгтэй).
class _BracketPainter extends CustomPainter {
  final bool top;
  final bool left;
  const _BracketPainter({required this.top, required this.left});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    const r = 14.0;
    final paint = Paint()
      ..color = kLeaf
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.save();
    if (!left) {
      canvas.translate(w, 0);
      canvas.scale(-1, 1);
    }
    if (!top) {
      canvas.translate(0, h);
      canvas.scale(1, -1);
    }
    final path = Path()
      ..moveTo(2, h)
      ..lineTo(2, r + 2)
      ..arcToPoint(const Offset(r + 2, 2), radius: const Radius.circular(r))
      ..lineTo(w, 2);
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BracketPainter old) => old.top != top || old.left != left;
}
