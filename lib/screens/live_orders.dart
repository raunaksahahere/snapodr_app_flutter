import 'dart:async';

import 'package:flutter/material.dart';

import '../models/staff_order.dart';
import '../services/api_client.dart';
import '../services/auth_store.dart';

const pollInterval = Duration(seconds: 4);

/// Base for the Kitchen and Waiter screens: both poll the same endpoint on the
/// same cadence and differ only in which statuses they show and what they
/// notify about.
abstract class LiveOrdersScreen extends StatefulWidget {
  const LiveOrdersScreen({super.key, required this.session});
  final StaffSession session;
}

abstract class LiveOrdersState<W extends LiveOrdersScreen> extends State<W> {
  late final ApiClient client = ApiClient(widget.session);

  /// Every order the restaurant has, unfiltered - the notification diffing and
  /// the table/session lookups need to see orders this screen does not list.
  List<StaffOrder> allOrders = const [];
  String? error;
  bool loading = true;
  Timer? _timer;
  bool _polling = false;

  /// Statuses this screen lists.
  Set<String> get visibleStatuses;

  /// Called after each successful poll so subclasses can raise notifications.
  /// Skipped for the very first poll, when everything would look "new".
  void onPolled(List<StaffOrder> previous, List<StaffOrder> next);

  List<StaffOrder> get orders => oldestFirst(allOrders, visibleStatuses);

  @override
  void initState() {
    super.initState();
    unawaited(poll());
    _timer = Timer.periodic(pollInterval, (_) => poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> poll() async {
    // A slow response must not let two polls overlap and double-notify.
    if (_polling) return;
    _polling = true;
    try {
      final next = await client.fetchOrders();
      final previous = allOrders;
      final first = loading;
      if (!mounted) return;
      setState(() {
        allOrders = next;
        error = null;
        loading = false;
      });
      if (!first) onPolled(previous, next);
    } on Object catch (failure) {
      if (mounted) {
        setState(() {
          error = failure is ApiException ? failure.message : 'Could not reach SnapOdr.';
          loading = false;
        });
      }
    } finally {
      _polling = false;
    }
  }

  Future<void> runAction(Future<void> Function() action) async {
    try {
      await action();
      await poll();
    } on Object catch (failure) {
      if (!mounted) return;
      final message = failure is ApiException ? failure.message : 'Something went wrong.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Widget buildBody(BuildContext context, Widget Function(StaffOrder order) card, {Widget? header}) {
    if (loading) return const Center(child: CircularProgressIndicator());
    final visible = orders;
    return RefreshIndicator(
      onRefresh: poll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          if (error != null)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(leading: const Icon(Icons.cloud_off), title: Text(error!)),
            ),
          ?header,
          if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 64),
              child: Center(child: Text('No live orders right now.')),
            ),
          ...visible.map(card),
        ],
      ),
    );
  }
}

/// Shared card chrome: table, age, status chip, items, then whatever actions
/// the screen wants underneath.
class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.order, required this.actions, this.trailing});

  final StaffOrder order;
  final List<Widget> actions;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(order.tableLabel, style: theme.textTheme.titleLarge)),
                Text(order.timeAgo, style: theme.textTheme.bodyMedium),
                ?trailing,
              ],
            ),
            const SizedBox(height: 2),
            Text('#${order.shortId}', style: theme.textTheme.bodySmall),
            const SizedBox(height: 10),
            ...order.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  children: [
                    Expanded(child: Text(item.name)),
                    Text('x${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Chip(
                  label: Text(order.status.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  visualDensity: VisualDensity.compact,
                ),
                const Spacer(),
                ...actions,
              ],
            ),
          ],
        ),
      ),
    );
  }
}
