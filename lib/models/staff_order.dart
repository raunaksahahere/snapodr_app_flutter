/// Statuses the kitchen works through. Anything past `ready` has left the
/// kitchen's hands; anything cancelled or completed is history.
const kitchenStatuses = {'pending', 'accepted', 'preparing', 'ready'};

/// The waiter also tracks orders that are plated and being carried out.
const waiterStatuses = {'pending', 'accepted', 'preparing', 'ready', 'served'};

/// Status changes the waiter wants to be told about as the kitchen progresses.
const waiterAlertStatuses = {'accepted', 'preparing', 'ready'};

class OrderLine {
  const OrderLine({required this.name, required this.quantity});

  factory OrderLine.fromJson(Map<String, dynamic> json) => OrderLine(
    name: (json['menuItem'] as Map<String, dynamic>?)?['name'] as String? ?? 'Item',
    quantity: (json['quantity'] as num?)?.toInt() ?? 1,
  );

  final String name;
  final int quantity;
}

class StaffOrder {
  const StaffOrder({
    required this.id,
    required this.status,
    required this.createdAt,
    required this.items,
    required this.tableLabel,
    required this.sessionId,
    required this.sessionStatus,
    required this.sessionPaymentMethod,
  });

  factory StaffOrder.fromJson(Map<String, dynamic> json) {
    final session = json['session'] as Map<String, dynamic>? ?? const {};
    final table = session['table'] as Map<String, dynamic>? ?? const {};
    return StaffOrder(
      id: json['id'] as String,
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      items: (json['items'] as List<dynamic>? ?? const []).map((raw) => OrderLine.fromJson(raw as Map<String, dynamic>)).toList(),
      tableLabel: table['label'] as String? ?? 'Unknown table',
      sessionId: session['id'] as String? ?? '',
      sessionStatus: session['status'] as String? ?? '',
      sessionPaymentMethod: session['paymentMethod'] as String?,
    );
  }

  final String id;
  final String status;
  final DateTime createdAt;
  final List<OrderLine> items;
  final String tableLabel;
  final String sessionId;
  final String sessionStatus;
  final String? sessionPaymentMethod;

  /// The table is waiting to hand over cash at the counter rather than paying
  /// through Cashfree.
  bool get awaitingCash => sessionStatus == 'bill_requested' && sessionPaymentMethod == 'cash';

  String get shortId => id.length <= 6 ? id : id.substring(id.length - 6);

  String get summary => items.map((item) => '${item.name} x${item.quantity}').join(', ');

  /// The next status this order can move to, or null when staff have nothing
  /// left to do with it here.
  String? get nextKitchenStatus => const {'pending': 'accepted', 'accepted': 'preparing', 'preparing': 'ready'}[status];

  String get timeAgo {
    final elapsed = DateTime.now().difference(createdAt);
    if (elapsed.inSeconds < 60) return 'just now';
    if (elapsed.inMinutes < 60) return '${elapsed.inMinutes} min ago';
    if (elapsed.inHours < 24) return '${elapsed.inHours} hr ago';
    return '${elapsed.inDays} d ago';
  }
}

/// Oldest first - the order that has been waiting longest sits at the top.
List<StaffOrder> oldestFirst(Iterable<StaffOrder> orders, Set<String> statuses) {
  final visible = orders.where((order) => statuses.contains(order.status)).toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  return visible;
}
