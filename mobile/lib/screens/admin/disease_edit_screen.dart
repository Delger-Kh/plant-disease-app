import 'package:flutter/material.dart';

import '../../models.dart';
import '../../services/api_client.dart';
import '../../widgets/common.dart';

/// US-10/11: Өвчин нэмэх, мэдээлэл засах (эмчилгээний жагсаалттай).
class DiseaseEditScreen extends StatefulWidget {
  final Disease? disease;
  const DiseaseEditScreen({super.key, this.disease});

  @override
  State<DiseaseEditScreen> createState() => _DiseaseEditScreenState();
}

class _TreatmentDraft {
  final TextEditingController method;
  final TextEditingController instructions;
  bool isOrganic;

  _TreatmentDraft(Treatment? t)
      : method = TextEditingController(text: t?.method ?? ''),
        instructions = TextEditingController(text: t?.instructions ?? ''),
        isOrganic = t?.isOrganic ?? true;

  void dispose() {
    method.dispose();
    instructions.dispose();
  }
}

class _DiseaseEditScreenState extends State<DiseaseEditScreen> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _c;
  late bool _healthy;
  final List<_TreatmentDraft> _treatments = [];
  bool _saving = false;

  bool get _isNew => widget.disease == null;

  @override
  void initState() {
    super.initState();
    final d = widget.disease;
    _c = {
      'key': TextEditingController(text: d?.key ?? ''),
      'plant': TextEditingController(text: d?.plant ?? ''),
      'name_mn': TextEditingController(text: d?.nameMn ?? ''),
      'name_en': TextEditingController(text: d?.nameEn ?? ''),
      'pathogen': TextEditingController(text: d?.pathogen ?? ''),
      'symptoms': TextEditingController(text: d?.symptoms ?? ''),
      'description': TextEditingController(text: d?.description ?? ''),
      'prevention': TextEditingController(text: d?.prevention ?? ''),
    };
    _healthy = d?.isHealthy ?? false;
    for (final t in d?.treatments ?? <Treatment>[]) {
      _treatments.add(_TreatmentDraft(t));
    }
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    for (final t in _treatments) {
      t.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final d = Disease(
      id: widget.disease?.id ?? 0,
      key: _c['key']!.text.trim(),
      plant: _c['plant']!.text.trim(),
      nameMn: _c['name_mn']!.text.trim(),
      nameEn: _c['name_en']!.text.trim(),
      isHealthy: _healthy,
      pathogen: _c['pathogen']!.text.trim(),
      symptoms: _c['symptoms']!.text.trim(),
      description: _c['description']!.text.trim(),
      prevention: _c['prevention']!.text.trim(),
      treatments: _treatments
          .where((t) => t.method.text.trim().isNotEmpty)
          .map((t) => Treatment(
              method: t.method.text.trim(), isOrganic: t.isOrganic, instructions: t.instructions.text.trim()))
          .toList(),
    );
    try {
      await ApiClient.instance.adminSaveDisease(d, id: widget.disease?.id);
      if (!mounted) return;
      showSnack(context, 'Хадгалагдлаа');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(String k, String label, {int lines = 1, bool required = false, String? helper}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: _c[k],
          minLines: lines,
          maxLines: lines == 1 ? 1 : lines + 3,
          decoration: glassInput(label, helper: helper),
          validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Заавал бөглөнө' : null : null,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _isNew ? 'Өвчин нэмэх' : 'Өвчин засах',
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GlassIconButton(icon: Icons.save_outlined, size: 40, tooltip: 'Хадгалах', onPressed: _saving ? null : _save),
        ),
      ],
      body: Form(
        key: _form,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
              Glass(
                radius: 26,
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _field('name_mn', 'Нэр (монгол)', required: true),
                  _field('name_en', 'Нэр (англи)'),
                  _field('plant', 'Ургамал', required: true, helper: 'Жишээ нь: Улаан лооль'),
                  _field('key', 'AI ангиллын түлхүүр (key)',
                      required: true,
                      helper: 'AI загварын ангиллын нэртэй яг ижил байх ёстой, жишээ: Tomato___Leaf_Mold'),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Эрүүл ангилал'),
                    subtitle: const Text('Өвчин биш, эрүүл навчны ангилал бол асаана', style: TextStyle(color: kMuted)),
                    value: _healthy,
                    onChanged: (v) => setState(() => _healthy = v),
                  ),
                  const SizedBox(height: 8),
                ]),
              ),
              const SizedBox(height: 12),
              Glass(
                radius: 26,
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _field('pathogen', 'Үүсгэгч'),
                  _field('symptoms', 'Шинж тэмдэг', lines: 3),
                  _field('description', 'Тайлбар', lines: 3),
                  _field('prevention', 'Урьдчилан сэргийлэх', lines: 3),
                ]),
              ),
              const SizedBox(height: 8),
              SectionHeader('Эмчилгээ / зөвлөмж',
                  action: 'Нэмэх', onAction: () => setState(() => _treatments.add(_TreatmentDraft(null)))),
              for (var i = 0; i < _treatments.length; i++)
                Glass(
                  key: ObjectKey(_treatments[i]),
                  margin: const EdgeInsets.only(bottom: 10),
                  radius: 22,
                  padding: const EdgeInsets.all(14),
                  child: Column(children: [
                    Row(children: [
                      Expanded(
                        child: TextFormField(
                          controller: _treatments[i].method,
                          decoration: glassInput('Арга'),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Хасах',
                        icon: const Icon(Icons.remove_circle_outline, color: kDanger),
                        onPressed: () {
                          final removed = _treatments[i];
                          setState(() => _treatments.removeAt(i));
                          WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
                        },
                      ),
                    ]),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _treatments[i].instructions,
                      minLines: 2,
                      maxLines: 5,
                      decoration: glassInput('Заавар'),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_treatments[i].isOrganic ? 'Органик арга' : 'Химийн арга'),
                      value: _treatments[i].isOrganic,
                      onChanged: (v) => setState(() => _treatments[i].isOrganic = v),
                    ),
                  ]),
                ),
              const SizedBox(height: 12),
              PillButton(label: 'Хадгалах', icon: Icons.check, expand: true, loading: _saving, onPressed: _save),
            ]),
          ),
        ),
      ),
    );
  }
}
