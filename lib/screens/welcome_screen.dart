import 'package:flutter/material.dart';

import '../services/auth_store.dart';
import 'login_screen.dart';
import 'mode_screen.dart';

/// The restaurant name comes straight off the login response, which is scoped
/// to the staff token - no extra lookup needed.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.session});

  final StaffSession session;

  Future<void> _signOut(BuildContext context) async {
    await AuthStore.clear();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      actions: [IconButton(tooltip: 'Sign out', onPressed: () => _signOut(context), icon: const Icon(Icons.logout))],
    ),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hello,', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              session.restaurantName,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            Align(
              alignment: Alignment.centerLeft,
              child: FloatingActionButton.large(
                heroTag: 'welcome-continue',
                tooltip: 'Continue',
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => ModeScreen(session: session))),
                child: const Icon(Icons.arrow_forward, size: 36),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
