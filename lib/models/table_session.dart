/// An open visit at a table, straight from `/api/sessions?restaurant=`.
///
/// Orders alone cannot describe the floor: a table that has been seated but has
/// not ordered yet produces no orders at all, so it never appears in the
/// order-derived list and staff have no way to clear it. This is the
/// table-level view that fills that gap.
class TableSession {
  const TableSession({
    required this.id,
    required this.tableLabel,
    required this.status,
    required this.paymentMethod,
    required this.orderCount,
    required this.discountAmount,
    required this.createdAt,
  });

  factory TableSession.fromJson(Map<String, dynamic> json) => TableSession(
    id: json['id'] as String,
    tableLabel: json['table'] as String? ?? 'Unknown table',
    status: json['status'] as String? ?? 'active',
    paymentMethod: json['paymentMethod'] as String?,
    orderCount: (json['orderCount'] as num?)?.toInt() ?? 0,
    discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0,
    createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
  );

  final String id;
  final String tableLabel;
  final String status;
  final String? paymentMethod;
  final int orderCount;

  /// Money already taken off this table's bill, so the waiter edits the current
  /// figure instead of overwriting it blind.
  final double discountAmount;
  final DateTime createdAt;

  /// Waiting to hand over cash at the counter rather than paying online.
  bool get awaitingCash => status == 'bill_requested' && paymentMethod == 'cash';

  /// Asked for the bill, however they intend to settle it.
  bool get billRequested => status == 'bill_requested';

  bool get hasDiscount => discountAmount > 0;

  String get orderSummary => switch (orderCount) {
    0 => 'No orders yet',
    1 => '1 order',
    _ => '$orderCount orders',
  };
}
