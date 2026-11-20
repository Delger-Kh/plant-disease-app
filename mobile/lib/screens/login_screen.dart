import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../widgets/common.dart';
import 'register_screen.dart';
import 'server_settings_screen.dart';

/// Дэлгэц 01 (Угтах) ба 02 (Нэвтрэх). US-02.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  bool _showForm = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ApiClient.instance.login(_email.text.trim(), _password.text);
      // AuthGate автоматаар үндсэн дэлгэц рүү шилжүүлнэ
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openSettings() =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ServerSettingsScreen()));

  // ------------------------------------------------------------ 01. Угтах
  Widget _welcome() {
    Widget bullet(String t) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: kEmerald.withAlpha(50), shape: BoxShape.circle),
              child: const Icon(Icons.check, size: 12, color: kMint),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(t, style: const TextStyle(color: Color(0xE6E2E8F0), fontSize: 13))),
          ]),
        );
    return Column(
      key: const ValueKey('welcome'),
      children: [
        const Spacer(),
        Glass.card(
          radius: 26,
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          border: kBorderStrong,
          child: Column(children: [
            const LeafLogo(size: 64),
            const SizedBox(height: 16),
            Text('Ургамлын эмч', textAlign: TextAlign.center, style: serif(size: 30)),
            const SizedBox(height: 4),
            const Text('Ургамлаа эрүүл байлга',
                style: TextStyle(color: kMint, fontWeight: FontWeight.w500, fontSize: 14)),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0x33000000),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x1AFFFFFF)),
              ),
              child: Column(children: [
                bullet('Навчны зургаа оруул.'),
                bullet('AI өвчнийг нарийн танина.'),
                bullet('Эмчилгээний зөвлөгөө ав.'),
              ]),
            ),
            const SizedBox(height: 22),
            PillButton(
              label: 'Эхлэх',
              trailingText: '→',
              expand: true,
              onPressed: () => setState(() => _showForm = true),
            ),
          ]),
        ),
        const Spacer(),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 24, height: 6, decoration: BoxDecoration(color: kLeaf, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 8),
          for (var i = 0; i < 2; i++) ...[
            Container(
                width: 6, height: 6, decoration: const BoxDecoration(color: Color(0x66FFFFFF), shape: BoxShape.circle)),
            const SizedBox(width: 8),
          ],
        ]),
        const SizedBox(height: 12),
      ],
    );
  }

  // ------------------------------------------------------------ 02. Нэвтрэх
  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 6),
        child: Text(t, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: kMintSoft.withAlpha(205))),
      );

  Widget _loginForm() => Column(
        key: const ValueKey('form'),
        children: [
          Row(children: [
            GlassIconButton(icon: Icons.chevron_left, size: 38, onPressed: () => setState(() => _showForm = false)),
            const Spacer(),
            GlassIconButton(icon: Icons.settings_outlined, size: 38, tooltip: 'Сервер тохиргоо', onPressed: _openSettings),
          ]),
          const Spacer(),
          Glass.card(
            radius: 26,
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _form,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('Нэвтрэх', style: serif(size: 26)),
                const SizedBox(height: 4),
                Text('Тавтай морил! Бүртгэлээрээ нэвтэрнэ үү.',
                    style: TextStyle(fontSize: 12.5, color: kMintSoft.withAlpha(180))),
                const SizedBox(height: 22),
                _label('И-мэйл'),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  style: const TextStyle(fontSize: 14),
                  decoration: glassInput('', hint: 'name@domain.mn'),
                  validator: (v) => (v == null || !v.contains('@')) ? 'И-мэйлээ зөв оруулна уу' : null,
                ),
                const SizedBox(height: 14),
                _label('Нууц үг'),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  style: const TextStyle(fontSize: 14),
                  decoration: glassInput(
                    '',
                    hint: '••••••••',
                    suffix: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: kMuted, size: 20),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Нууц үгээ оруулна уу' : null,
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 24),
                PillButton(label: 'Нэвтрэх', trailingText: '→', expand: true, loading: _loading, onPressed: _submit),
              ]),
            ),
          ),
          const Spacer(),
          Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
            const Text('Бүртгэлгүй юу?', style: TextStyle(color: kMuted, fontSize: 13)),
            TextButton(
              onPressed: _loading
                  ? null
                  : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
              child: const Text('Бүртгүүлэх', style: TextStyle(color: kLeaf, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 4),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: LayoutBuilder(
            builder: (context, c) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: c.maxHeight - 24),
                child: IntrinsicHeight(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _showForm ? _loginForm() : _welcome(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
