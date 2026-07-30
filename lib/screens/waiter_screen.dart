import 'package:flutter/material.dart';

import '../models/staff_order.dart';
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

    final cashBefore = _cashTables(previous);
    _cashTables(next).forEach((sessionId, table) {
      if (cashBefore.containsKey(sessionId)) return;
      Notifications.cash('Collect cash · $table', 'This table asked to settle their bill in cash.', key: 'cash-$sessionId');
    });
  }

  /// sessionId -> table label, for every table waiting to pay at the counter.
  Map<String, String> _cashTables(List<StaffOrder> orders) => {
    for (final order in orders.where((order) => order.awaitingCash)) order.sessionId: order.tableLabel,
  };

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

  @override
  Widget build(BuildContext context) {
    final cashTables = _cashTables(allOrders);
    return Scaffold(
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
        header: cashTables.isEmpty
            ? null
            : Card(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                margin: const EdgeInsets.only(bottom: 10),
                child: Column(
                  children: cashTables.entries
                      .map(
                        (entry) => ListTile(
                          leading: const Icon(Icons.payments_outlined),
                          title: Text('Collect cash · ${entry.value}'),
                          subtitle: const Text('Bill requested, paying at the counter.'),
                          trailing: IconButton(
                            tooltip: 'Delete session',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _confirmDelete(entry.key, entry.value),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
      ),
    );
  }
}
