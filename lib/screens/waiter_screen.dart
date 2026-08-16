import 'package:flutter/material.dart';

import '../models/menu.dart';
import '../models/staff_order.dart';
import '../models/table_session.dart';
import '../services/api_client.dart';
import '../services/notifications.dart';
import 'live_orders.dart';
import 'new_order_screen.dart';

class WaiterScreen extends LiveOrdersScreen {
  const WaiterScreen({super.key, required super.session});

  @override
  State<WaiterScreen> createState() => _WaiterScreenState();
}

class _WaiterScreenState extends LiveOrdersState<WaiterScreen> {
  @override
  Set<String> get visibleStatuses => waiterStatuses;

  /// Every open visit, including tables that have not ordered yet.
  List<TableSession> sessions = const [];
  List<TableSession> _sessionsBefore = const [];

  @override
  Future<void> fetchExtras() async {
    final next = await client.fetchSessions();
    _sessionsBefore = sessions;
    sessions = next;
  }

  @override
  void onPolled(List<StaffOrder> previous, List<StaffOrder> next) {
    final before = {for (final order in previous) order.id: order.status};
    for (final order in next) {
      // The waiter follows every kitchen stage, not just "ready", so they can
      // set expectations at the table.
      if (waiterAlertStatuses.contains(order.status) && before[order.id] != order.status) {
        Notifications.order(
          '${order.tableLabel} · ${order.status}',
          order.status == 'ready' ? 'Ready to serve: ${order.summary}' : order.summary,
          key: '${order.id}-${order.status}',
        );
      }
    }

    // Cash alerts come off the session, not its orders: a table can ask to
    // settle up without ever having an order the waiter screen lists.
    final cashBefore = {for (final session in _sessionsBefore.where((s) => s.awaitingCash)) session.id};
    for (final session in sessions.where((session) => session.awaitingCash)) {
      if (cashBefore.contains(session.id)) continue;
      Notifications.cash(
        'Collect cash · ${session.tableLabel}',
        'This table asked to settle their bill in cash.',
        key: 'cash-${session.id}',
      );
    }
  }

  Future<void> _confirmDelete(String sessionId, String tableLabel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete $tableLabel session?'),
        content: const Text('Delete this table\'s session? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(dialogContext).colorScheme.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await runAction(() => client.deleteSession(sessionId));
  }

  /// Taking money off a table's bill - a goodwill gesture, a manager's call.
  /// Pre-filled with whatever is already applied so the waiter adjusts rather
  /// than guesses, and an empty field clears it.
  Future<void> _applyDiscount(TableSession session) async {
    final controller = TextEditingController(
      text: session.hasDiscount ? session.discountAmount.toStringAsFixed(2) : '',
    );
    final entered = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Discount · ${session.tableLabel}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Comes off this table\'s bill total.'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixText: '₹ ',
                hintText: '0.00',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          if (session.hasDiscount)
            TextButton(onPressed: () => Navigator.of(dialogContext).pop('0'), child: const Text('Remove')),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (entered == null || !mounted) return;

    final amount = entered.isEmpty ? 0.0 : double.tryParse(entered);
    if (amount == null || amount < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid amount.')));
      return;
    }
    await runAction(() => client.setSessionDiscount(session.id, amount));
  }

  /// Ordering on a table's behalf, for a walk-in who never scanned the QR code.
  /// The order lands on the table's visit and is a normal order from there on.
  Future<void> _newOrder(String tableLabel) async {
    final placed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => NewOrderScreen(client: client, tableLabel: tableLabel)),
    );
    if (!mounted || !(placed ?? false)) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Order sent for $tableLabel.')));
    await poll();
  }

  /// Tables with an open visit are already listed; this reaches the rest of the
  /// floor plan, which is where a walk-in who never scanned is actually sitting.
  Future<void> _pickTable() async {
    List<RestaurantTable> tables;
    try {
      tables = await client.fetchTables();
    } on Object catch (failure) {
      if (!mounted) return;
      final message = failure is ApiException ? failure.message : 'Could not load tables.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    if (!mounted) return;
    final chosen = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: tables.isEmpty
            ? const Padding(padding: EdgeInsets.all(24), child: Text('No tables have been set up yet.'))
            : ListView(
                shrinkWrap: true,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'Order for which table?',
                      style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  ...tables.map(
                    (table) => ListTile(
                      leading: const Icon(Icons.table_restaurant_outlined),
                      title: Text(table.label),
                      subtitle: table.hasActiveSession ? const Text('Already ordering') : null,
                      onTap: () => Navigator.of(sheetContext).pop(table.label),
                    ),
                  ),
                ],
              ),
      ),
    );
    if (chosen != null) await _newOrder(chosen);
  }

  /// Table-level view of the floor. Every open session gets a row and its own
  /// delete action, so a seated table with nothing ordered can still be cleared.
  Widget? _tablesCard(BuildContext context) {
    if (sessions.isEmpty) return null;
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(
              'Tables · ${sessions.length} open',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          ...sessions.map((session) {
            final cash = session.awaitingCash;
            return ListTile(
              leading: Icon(
                cash ? Icons.payments_outlined : Icons.table_restaurant_outlined,
                color: cash ? theme.colorScheme.tertiary : null,
              ),
              title: Text(
                session.tableLabel,
                style: TextStyle(fontWeight: cash ? FontWeight.bold : FontWeight.normal),
              ),
              subtitle: Text(
                [
                  if (cash)
                    'Collect cash · ${session.orderSummary}'
                  else if (session.billRequested)
                    'Bill requested · ${session.orderSummary}'
                  else
                    session.orderSummary,
                  if (session.hasDiscount) '− ₹${session.discountAmount.toStringAsFixed(2)} discount',
                ].join(' · '),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: session.hasDiscount ? 'Edit discount' : 'Add discount',
                    icon: Icon(
                      Icons.percent,
                      color: session.hasDiscount ? theme.colorScheme.primary : null,
                    ),
                    onPressed: () => _applyDiscount(session),
                  ),
                  IconButton(
                    tooltip: 'New order',
                    icon: const Icon(Icons.add_shopping_cart_outlined),
                    onPressed: () => _newOrder(session.tableLabel),
                  ),
                  IconButton(
                    tooltip: 'Delete session',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _confirmDelete(session.id, session.tableLabel),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Waiter'),
      actions: [
        IconButton(tooltip: 'New order', onPressed: _pickTable, icon: const Icon(Icons.add_shopping_cart_outlined)),
        IconButton(tooltip: 'Refresh', onPressed: poll, icon: const Icon(Icons.refresh)),
      ],
    ),
    body: buildBody(
      context,
      (order) => OrderCard(
        order: order,
        trailing: IconButton(
          tooltip: 'Delete session',
          icon: const Icon(Icons.delete_outline),
          onPressed: order.sessionId.isEmpty ? null : () => _confirmDelete(order.sessionId, order.tableLabel),
        ),
        actions: [
          if (order.status == 'ready')
            FilledButton(
              onPressed: () => runAction(() => client.updateOrderStatus(order.id, 'served')),
              child: const Text('Mark Served'),
            )
          else if (order.status == 'served')
            const Text('Served')
          else
            const Text('With the kitchen'),
        ],
      ),
      header: _tablesCard(context),
    ),
  );
}
