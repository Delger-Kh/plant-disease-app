import 'package:flutter/material.dart';

import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'services/api_client.dart';
import 'widgets/common.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PlantDoctorApp());
}

class PlantDoctorApp extends StatelessWidget {
  const PlantDoctorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ургамлын эмч',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const AuthGate(),
    );
  }
}

/// Нэвтэрсэн эсэхээс хамаарч нэвтрэх эсвэл үндсэн дэлгэцийг харуулна.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final api = ApiClient.instance;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    api.addListener(_onChange);
    api.init().whenComplete(() {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    api.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const AppScaffold(body: LoadingView(text: 'Ачаалж байна...'));
    }
    return api.isLoggedIn ? HomeShell(key: ValueKey(api.user!.id)) : const LoginScreen();
  }
}
