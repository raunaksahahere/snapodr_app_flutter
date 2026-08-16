import 'package:flutter/material.dart';

import '../models/menu.dart';
import '../services/api_client.dart';

/// Waiter-side ordering for a table that did not order from its own phone.
///
/// The cart lives only for as long as this screen does. That is deliberate: the
/// waiter is standing at the table reading the order back, and a basket that
/// survived being backed out of would be a basket someone sends to the kitchen
/// by accident an hour later.
class NewOrderScreen extends StatefulWidget {
  const NewOrderScreen({super.key, required this.client, required this.tableLabel});

  final ApiClient client;
  final String tableLabel;

  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen> {
  List<MenuCategory> categories = const [];
  final Map<String, int> quantities = {};
  final TextEditingController noteController = TextEditingController();
  String? error;
  bool loading = true;
  bool submitting = false;

  @override
  void dispose() {
    noteController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  Future<void> _loadMenu() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final next = await widget.client.fetchMenu();
      if (!mounted) return;
      setState(() {
        categories = next;
        loading = false;
      });
    } on Object catch (failure) {
      if (!mounted) return;
      setState(() {
        error = failure is ApiException ? failure.message : 'Could not load the menu.';
        loading = false;
      });
    }
  }

  void _change(MenuItem item, int delta) => setState(() {
    final next = (quantities[item.id] ?? 0) + delta;
    if (next > 0) {
      // The order endpoint clamps each line to 20; stopping here keeps the
      // count on screen honest about what would actually be sent.
      quantities[item.id] = next.clamp(1, 20);
    } else {
      quantities.remove(item.id);
    }
  });

  List<MenuItem> get _allItems => [for (final category in categories) ...category.items];

  int get _lineCount => quantities.values.fold(0, (sum, quantity) => sum + quantity);

  double get _total => _allItems.fold(0, (sum, item) => sum + item.price * (quantities[item.id] ?? 0));

  Future<void> _submit() async {
    if (quantities.isEmpty || submitting) return;
    setState(() => submitting = true);
    try {
      // Find-or-create runs at submit, not at open: a waiter who browses the
      // menu and walks away should not leave an empty visit on the floor.
      final sessionId = await widget.client.openTableSession(widget.tableLabel);
      await widget.client.placeOrder(sessionId, quantities, note: noteController.text);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on Object catch (failure) {
      if (!mounted) return;
      setState(() => submitting = false);
      final message = failure is ApiException ? failure.message : 'Could not place the order.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('New order · ${widget.tableLabel}')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              children: [
                if (error != null)
                  Card(
                    color: theme.colorScheme.errorContainer,
                    child: ListTile(
                      leading: const Icon(Icons.cloud_off),
                      title: Text(error!),
                      trailing: TextButton(onPressed: _loadMenu, child: const Text('Retry')),
                    ),
                  ),
                if (error == null && categories.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 64),
                    child: Center(child: Text('No items are available to order.')),
                  ),
                ...categories.map(
                  (category) => Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                          child: Text(
                            category.name,
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        ...category.items.map((item) {
                          final quantity = quantities[item.id] ?? 0;
                          return ListTile(
                            title: Text(item.name),
                            subtitle: Text('₹${item.price.toStringAsFixed(2)}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Remove one',
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: quantity == 0 ? null : () => _change(item, -1),
                                ),
                                SizedBox(
                                  width: 24,
                                  child: Text(
                                    '$quantity',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontWeight: quantity > 0 ? FontWeight.bold : FontWeight.normal),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Add one',
                                  icon: const Icon(Icons.add_circle_outline),
                                  onPressed: () => _change(item, 1),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                // Sits under the menu rather than in the bottom bar: the waiter
                // is repeating back what the table just said, and a one-line
                // field wedged beside the total invites cut-off notes.
                if (categories.isNotEmpty)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Note for the kitchen',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: noteController,
                            maxLines: 3,
                            maxLength: 500,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'Allergies, no onion, less spicy…',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
      bottomNavigationBar: quantities.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$_lineCount item(s)', style: theme.textTheme.bodyMedium),
                          Text(
                            '₹${_total.toStringAsFixed(2)}',
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: submitting ? null : _submit,
                      icon: submitting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send),
                      label: Text(submitting ? 'Sending…' : 'Send to kitchen'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
