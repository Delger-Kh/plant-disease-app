import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../widgets/common.dart';

/// US-01: Бүртгүүлэх дэлгэц (Нэвтрэх дэлгэцийн загвартай).
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _password2 = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _password2.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ApiClient.instance.register(_name.text.trim(), _email.text.trim(), _password.text);
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 6, top: 12),
        child: Text(t, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: kMintSoft.withAlpha(205))),
      );

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(children: [
              Row(children: [
                GlassIconButton(icon: Icons.chevron_left, size: 38, onPressed: () => Navigator.maybePop(context)),
              ]),
              const SizedBox(height: 18),
              Glass.card(
                radius: 26,
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _form,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text('Бүртгүүлэх', style: serif(size: 26)),
                    const SizedBox(height: 4),
                    Text('Ургамлынхаа эрүүл мэндийг хамтдаа хянацгаая.',
                        style: TextStyle(fontSize: 12.5, color: kMintSoft.withAlpha(180))),
                    const SizedBox(height: 8),
                    _label('Нэр'),
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: glassInput('', hint: 'Таны нэр'),
                      validator: (v) => (v == null || v.trim().length < 2) ? 'Нэрээ оруулна уу' : null,
                    ),
                    _label('И-мэйл'),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: glassInput('', hint: 'name@domain.mn'),
                      validator: (v) {
                        final s = v?.trim() ?? '';
                        final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);
                        return ok ? null : 'И-мэйлээ зөв оруулна уу';
                      },
                    ),
                    _label('Нууц үг'),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      decoration: glassInput('', hint: 'Хамгийн багадаа 6 тэмдэгт'),
                      validator: (v) => (v == null || v.length < 6) ? 'Хамгийн багадаа 6 тэмдэгт' : null,
                    ),
                    _label('Нууц үг давтах'),
                    TextFormField(
                      controller: _password2,
                      obscureText: true,
                      decoration: glassInput('', hint: '••••••••'),
                      validator: (v) => v != _password.text ? 'Нууц үг таарахгүй байна' : null,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 24),
                    PillButton(
                        label: 'Бүртгүүлэх', trailingText: '→', expand: true, loading: _loading, onPressed: _submit),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
                const Text('Бүртгэлтэй юу?', style: TextStyle(color: kMuted, fontSize: 13)),
                TextButton(
                  onPressed: () => Navigator.maybePop(context),
                  child: const Text('Нэвтрэх', style: TextStyle(color: kLeaf, fontWeight: FontWeight.w700)),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}
