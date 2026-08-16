/// The customer-facing menu, straight from `/api/menu?restaurant=`. The waiter
/// app orders from exactly the same payload the QR site does, so a walk-in
/// ordered at the table can never be offered something the site would not.
class MenuItem {
  const MenuItem({required this.id, required this.name, required this.price});

  factory MenuItem.fromJson(Map<String, dynamic> json) => MenuItem(
    id: json['id'] as String,
    name: json['name'] as String? ?? 'Item',
    price: (json['price'] as num?)?.toDouble() ?? 0,
  );

  final String id;
  final String name;
  final double price;
}

class MenuCategory {
  const MenuCategory({required this.id, required this.name, required this.items});

  factory MenuCategory.fromJson(Map<String, dynamic> json) => MenuCategory(
    id: json['id'] as String,
    name: json['name'] as String? ?? 'Menu',
    items: (json['items'] as List<dynamic>? ?? const []).map((raw) => MenuItem.fromJson(raw as Map<String, dynamic>)).toList(),
  );

  final String id;
  final String name;
  final List<MenuItem> items;
}

/// A table on the floor plan, from `/api/tables`. Unlike a session this exists
/// whether or not anyone is sitting there, which is what lets the waiter start
/// an order for a table nobody has scanned into yet.
class RestaurantTable {
  const RestaurantTable({required this.id, required this.label, required this.hasActiveSession});

  factory RestaurantTable.fromJson(Map<String, dynamic> json) => RestaurantTable(
    id: json['id'] as String,
    label: json['label'] as String? ?? 'Table',
    hasActiveSession: json['hasActiveSession'] as bool? ?? false,
  );

  final String id;
  final String label;
  final bool hasActiveSession;
}
