import 'package:flutter/material.dart';

import '../models/staff_order.dart';
import '../services/notifications.dart';
import 'live_orders.dart';

class KitchenScreen extends LiveOrdersScreen {
  const KitchenScreen({super.key, required super.session});

  @override
  State<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends LiveOrdersState<KitchenScreen> {
  @override
  Set<String> get visibleStatuses => kitchenStatuses;

  @override
  void onPolled(List<StaffOrder> previous, List<StaffOrder> next) {
    final known = previous.map((order) => order.id).toSet();
    for (final order in next.where((order) => kitchenStatuses.contains(order.status) && !known.contains(order.id))) {
      Notifications.order('New order · ${order.tableLabel}', order.summary, key: 'new-${order.id}');
    }
  }

  static const _labels = {'accepted': 'Accept', 'preparing': 'Start Preparing', 'ready': 'Mark Ready'};

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Kitchen'),
      actions: [IconButton(onPressed: poll, icon: const Icon(Icons.refresh))],
    ),
    body: buildBody(context, (order) {
      final next = order.nextKitchenStatus;
      return OrderCard(
        order: order,
        actions: [
          if (next != null)
            FilledButton(
              onPressed: () => runAction(() => client.updateOrderStatus(order.id, next)),
              child: Text(_labels[next]!),
            )
          else
            const Text('Waiting for the waiter'),
        ],
      );
    }),
  );
}
