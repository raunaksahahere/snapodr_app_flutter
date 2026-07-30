import 'package:flutter/material.dart';

import '../services/auth_store.dart';
import 'kitchen_screen.dart';
import 'waiter_screen.dart';

/// Mode is chosen fresh every time - it is not tied to the staff account, so
/// one login can work the pass in the morning and the floor in the evening.
class ModeScreen extends StatelessWidget {
  const ModeScreen({super.key, required this.session});

  final StaffSession session;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Choose your view')),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Expanded(
              child: _ModeButton(
                label: 'Kitchen',
                caption: 'Accept orders and cook',
                icon: Icons.soup_kitchen_outlined,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => KitchenScreen(session: session))),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _ModeButton(
                label: 'Waiter',
                caption: 'Serve tables and collect bills',
                icon: Icons.room_service_outlined,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => WaiterScreen(session: session))),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({required this.label, required this.caption, required this.icon, required this.onTap});

  final String label;
  final String caption;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => FilledButton.tonal(
    onPressed: onTap,
    style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 64),
        const SizedBox(height: 12),
        Text(label, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(caption, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
  );
}
