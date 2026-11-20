import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../widgets/common.dart';
import 'server_settings_screen.dart';

/// Профайл: хувийн мэдээлэл засах, серверийн хаяг, гарах.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _edit(BuildContext context) async {
    final api = ApiClient.instance;
    final name = TextEditingController(text: api.user?.name ?? '');
    final pass = TextEditingController();
    final form = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Мэдээлэл засах'),
        content: Form(
          key: form,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Нэр'),
              validator: (v) => (v == null || v.trim().length < 2) ? 'Нэрээ оруулна уу' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: pass,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Шинэ нууц үг (хоосон бол өөрчлөхгүй)'),
              validator: (v) => (v != null && v.isNotEmpty && v.length < 6) ? 'Хамгийн багадаа 6 тэмдэгт' : null,
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Болих')),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(c, true);
            },
            child: const Text('Хадгалах'),
          ),
        ],
      ),
    );
    if (saved != true) return;
    try {
      await api.updateProfile(name: name.text.trim(), password: pass.text);
      if (context.mounted) showSnack(context, 'Хадгалагдлаа');
    } catch (e) {
      if (context.mounted) showSnack(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = ApiClient.instance;
    return ListenableBuilder(
      listenable: api,
      builder: (context, _) {
        final u = api.user;
        return Scaffold(
          appBar: AppBar(title: const Text('Профайл')),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: kLightGreen,
                    child: Text(
                      (u?.name.isNotEmpty ?? false) ? u!.name.substring(0, 1).toUpperCase() : '?',
                      style: const TextStyle(fontSize: 28, color: kGreen),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(u?.name ?? '', style: Theme.of(context).textTheme.titleLarge),
                  Text(u?.email ?? '', style: TextStyle(color: Colors.grey.shade700)),
                  const SizedBox(height: 8),
                  Pill(u?.isAdmin == true ? 'Админ' : 'Хэрэглэгч',
                      color: u?.isAdmin == true ? Colors.indigo : kGreen),
                ]),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(children: [
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Мэдээлэл засах'),
                  onTap: () => _edit(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.settings_ethernet),
                  title: const Text('Серверийн хаяг'),
                  subtitle: Text(api.baseUrl),
                  onTap: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const ServerSettingsScreen())),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Апп-ын тухай'),
                  onTap: () => showAboutDialog(
                    context: context,
                    applicationName: 'Ургамлын эмч',
                    applicationVersion: '1.0.0',
                    applicationIcon: const Icon(Icons.local_florist, color: kGreen, size: 40),
                    children: const [
                      Text('Ургамлын өвчин илрүүлэх болон арчилгааны зөвлөх систем.\n'
                          'Баг 16 — Э.Энхсаруул, Х.Дэлгэр, Ч.Оюумаа.\n\n'
                          'AI загвар нь PlantVillage өгөгдөл дээр сургасан CNN. '
                          'Үр дүн нь зөвлөмж бөгөөд эргэлзээтэй үед агрономичоос зөвлөгөө аваарай.'),
                    ],
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () async {
                if (await confirmDialog(context, 'Гарах уу?', 'Системээс гарна.', ok: 'Гарах')) {
                  await api.logout();
                }
              },
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Гарах', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
          ]),
        );
      },
    );
  }
}
