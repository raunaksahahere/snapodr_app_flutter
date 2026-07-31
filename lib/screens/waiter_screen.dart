import 'package:flutter/material.dart';

import '../models/staff_order.dart';
import '../models/table_session.dart';
import '../services/notifications.dart';
import 'live_orders.dart';

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
                cash
                    ? 'Collect cash · ${session.orderSummary}'
                    : session.billRequested
                    ? 'Bill requested · ${session.orderSummary}'
                    : session.orderSummary,
              ),
              trailing: IconButton(
                tooltip: 'Delete session',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _confirmDelete(session.id, session.tableLabel),
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
      actions: [IconButton(onPressed: poll, icon: const Icon(Icons.refresh))],
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
