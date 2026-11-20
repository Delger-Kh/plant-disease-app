import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../widgets/common.dart';

/// Backend серверийн хаяг тохируулах (жинхэнэ утсаар ажиллахад компьютерын IP хаягийг оруулна).
class ServerSettingsScreen extends StatefulWidget {
  const ServerSettingsScreen({super.key});

  @override
  State<ServerSettingsScreen> createState() => _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends State<ServerSettingsScreen> {
  final _ctrl = TextEditingController(text: ApiClient.instance.baseUrl);
  bool? _ok;
  bool _checking = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _saveAndCheck() async {
    setState(() {
      _checking = true;
      _ok = null;
    });
    await ApiClient.instance.setBaseUrl(_ctrl.text);
    _ctrl.text = ApiClient.instance.baseUrl;
    final ok = await ApiClient.instance.checkServer();
    if (!mounted) return;
    setState(() {
      _checking = false;
      _ok = ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Серверийн хаяг',
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(padding: const EdgeInsets.all(20), children: [
            Glass(
              blur: true,
              radius: 28,
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TextField(
                  controller: _ctrl,
                  keyboardType: TextInputType.url,
                  decoration: glassInput('Backend хаяг', icon: Icons.dns_outlined, hint: 'http://192.168.1.10:8000'),
                ),
                const SizedBox(height: 16),
                PillButton(
                  label: _checking ? 'Шалгаж байна...' : 'Хадгалаад шалгах',
                  icon: Icons.wifi_tethering,
                  expand: true,
                  loading: _checking,
                  onPressed: _saveAndCheck,
                ),
                if (_ok != null) ...[
                  const SizedBox(height: 16),
                  Row(children: [
                    Icon(_ok! ? Icons.check_circle : Icons.error_outline, color: _ok! ? kAccent : kDanger),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _ok!
                            ? 'Сервертэй амжилттай холбогдлоо'
                            : 'Холбогдож чадсангүй. Сервер ажиллаж байгаа, утас компьютер хоёр нэг Wi-Fi-д байгаа эсэхийг шалгана уу.',
                      ),
                    ),
                  ]),
                ],
              ]),
            ),
            const SizedBox(height: 14),
            SectionCard(
              title: 'Зөвлөмж',
              icon: Icons.lightbulb_outline,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('• Android эмулятор: http://10.0.2.2:8000\n'
                    '• Chrome эсвэл iOS симулятор: http://localhost:8000\n'
                    '• Жинхэнэ утас: компьютерын Wi-Fi IP хаяг, жишээ нь http://192.168.1.10:8000 '
                    '(сервер "--host 0.0.0.0"-тай ажиллаж байх ёстой)'),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() => _ctrl.text = ApiClient.defaultBaseUrl()),
                  child: const Text('Анхны утга руу буцаах', style: TextStyle(color: kAccent)),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
