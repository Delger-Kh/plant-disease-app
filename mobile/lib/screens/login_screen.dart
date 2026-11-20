import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../widgets/common.dart';
import 'register_screen.dart';
import 'server_settings_screen.dart';

/// US-02: Нэвтрэх дэлгэц.
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Серверийн хаяг',
            icon: const Icon(Icons.settings_ethernet),
            onPressed: () =>
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ServerSettingsScreen())),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Icon(Icons.local_florist, size: 72, color: kGreen),
                  const SizedBox(height: 12),
                  Text('Ургамлын эмч',
                      textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 4),
                  Text('Навчны зургаар өвчнийг таних, арчилгааны зөвлөгөө авах',
                      textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(labelText: 'И-мэйл', prefixIcon: Icon(Icons.email_outlined)),
                    validator: (v) => (v == null || !v.contains('@')) ? 'И-мэйлээ зөв оруулна уу' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _password,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'Нууц үг',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? 'Нууц үгээ оруулна уу' : null,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                    child: _loading
                        ? const SizedBox(
                            height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                        : const Text('Нэвтрэх'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => Navigator.push(
                            context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                    child: const Text('Бүртгэлгүй юу? Бүртгүүлэх'),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
