import 'package:flutter/material.dart';

import 'screens/login_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/auth_store.dart';
import 'services/notifications.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Notifications.init();
  runApp(SnapOdrApp(session: await AuthStore.read()));
}

class SnapOdrApp extends StatelessWidget {
  const SnapOdrApp({super.key, this.session});

  /// A token restored from secure storage, if the staff member is still signed in.
  final StaffSession? session;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'SnapOdr Staff',
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFFC72C)), useMaterial3: true),
    home: session == null ? const LoginScreen() : WelcomeScreen(session: session!),
  );
}
