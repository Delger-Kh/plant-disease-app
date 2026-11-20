import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../widgets/common.dart';
import 'admin/admin_screen.dart';
import 'server_settings_screen.dart';

/// Дэлгэц 09: Миний профайл.
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Хувийн мэдээлэл засах', style: serif(size: 19)),
        content: Form(
          key: form,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: name,
              decoration: glassInput('Нэр'),
              validator: (v) => (v == null || v.trim().length < 2) ? 'Нэрээ оруулна уу' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: pass,
              obscureText: true,
              decoration: glassInput('Шинэ нууц үг', helper: 'Хоосон бол өөрчлөхгүй'),
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

  Widget _menu(String emoji, String title,
          {String? subtitle, VoidCallback? onTap, Color color = kText, Color border = kBorder}) =>
      Glass(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: border,
        onTap: onTap,
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color == kText ? const Color(0x1AFFFFFF) : color.withAlpha(50),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 15)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13.5)),
              if (subtitle != null)
                Text(subtitle,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kMuted, fontSize: 11.5)),
            ]),
          ),
          Icon(Icons.chevron_right, color: color == kText ? kMuted : color, size: 18),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final api = ApiClient.instance;
    return ListenableBuilder(
      listenable: api,
      builder: (context, _) {
        final u = api.user;
        final isAdmin = u?.isAdmin ?? false;
        return AppScaffold(
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 120), children: [
                const PageHeader('Миний профайл', center: true),
                Glass.card(
                  radius: 24,
                  border: kBorderStrong,
                  padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Column(children: [
                    GradientAvatar(u?.name ?? '', size: 80),
                    const SizedBox(height: 12),
                    Text(u?.name ?? '', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: kText)),
                    const SizedBox(height: 2),
                    Text(u?.email ?? '', style: TextStyle(color: kMint.withAlpha(205), fontSize: 12.5)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: (isAdmin ? kBlue : kEmerald).withAlpha(50),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: (isAdmin ? kBlue : kLeaf).withAlpha(76)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(color: isAdmin ? kBlue : kLeaf, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(isAdmin ? 'Администратор' : 'Хэрэглэгч',
                            style: TextStyle(
                                color: isAdmin ? kBlue : kMint, fontSize: 11.5, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ]),
                ),
                if (isAdmin)
                  _menu('🛠️', 'Админ самбар',
                      subtitle: 'Статистик, оношийн хяналт, өвчний сан, хэрэглэгчид',
                      color: kLeaf,
                      border: kEmerald.withAlpha(90),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminScreen()))),
                _menu('👤', 'Хувийн мэдээлэл засах', onTap: () => _edit(context)),
                _menu('⚙️', 'Серверийн хаяг (API тохиргоо)',
                    subtitle: api.baseUrl,
                    onTap: () =>
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const ServerSettingsScreen()))),
                _menu('ℹ️', 'Апп-ын тухай (v1.0.0)',
                    onTap: () => showAboutDialog(
                          context: context,
                          applicationName: 'Ургамлын эмч',
                          applicationVersion: '1.0.0',
                          applicationIcon: const LeafLogo(size: 44),
                          children: const [
                            Text('Ургамлын өвчин илрүүлэх болон арчилгааны зөвлөх систем.\n'
                                'Баг 16 — Э.Энхсаруул, Х.Дэлгэр, Ч.Оюумаа.\n\n'
                                'AI загвар нь PlantVillage өгөгдөл дээр сургасан CNN. Одоогоор алим, эрдэнэ шиш, '
                                'усан үзэм, төмс, улаан лоолийг таньдаг. Үр дүн нь зөвлөмж бөгөөд эргэлзээтэй үед '
                                'агрономичоос зөвлөгөө аваарай.'),
                          ],
                        )),
                const SizedBox(height: 6),
                _menu('🚪', 'Системээс гарах', color: kCoral, border: kCoral.withAlpha(76), onTap: () async {
                  if (await confirmDialog(context, 'Гарах уу?', 'Системээс гарна.', ok: 'Гарах')) {
                    await api.logout();
                  }
                }),
              ]),
            ),
          ),
        );
      },
    );
  }
}
