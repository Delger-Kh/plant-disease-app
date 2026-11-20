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
    return Scaffold(
      appBar: AppBar(title: const Text('Серверийн хаяг')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        TextField(
          controller: _ctrl,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(labelText: 'Backend хаяг', hintText: 'http://192.168.1.10:8000'),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _checking ? null : _saveAndCheck,
          icon: const Icon(Icons.wifi_tethering),
          label: Text(_checking ? 'Шалгаж байна...' : 'Хадгалаад шалгах'),
        ),
        const SizedBox(height: 16),
        if (_ok == true)
          const ListTile(
            leading: Icon(Icons.check_circle, color: kGreen),
            title: Text('Сервертэй амжилттай холбогдлоо'),
          ),
        if (_ok == false)
          const ListTile(
            leading: Icon(Icons.error, color: Colors.red),
            title: Text('Холбогдож чадсангүй'),
            subtitle: Text('Сервер ажиллаж байгаа, утас компьютер хоёр нэг Wi-Fi-д байгаа эсэхийг шалгана уу.'),
          ),
        const Divider(height: 32),
        Text('Зөвлөмж', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text('• Android эмулятор: http://10.0.2.2:8000\n'
            '• Chrome (flutter run -d chrome) эсвэл iOS симулятор: http://localhost:8000\n'
            '• Жинхэнэ утас: компьютерын Wi-Fi IP хаяг, жишээ нь http://192.168.1.10:8000\n'
            '  (сервер "--host 0.0.0.0"-тай ажиллаж байх ёстой)'),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => setState(() => _ctrl.text = ApiClient.defaultBaseUrl()),
          child: const Text('Анхны утга руу буцаах'),
        ),
      ]),
    );
  }
}
