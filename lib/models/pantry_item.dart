class PantryItem {
  final String id;
  final String name;
  final int quantity;
  final DateTime expiryDate;
  final String unit;
  final String? notes;
  final DateTime createdAt;
  final String? type;

  PantryItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.expiryDate,
    this.unit = 'piece',
    this.notes,
    required this.createdAt,
    this.type = 'manual',
  });

  // Convert JSON -> Object
  factory PantryItem.fromJson(Map<String, dynamic> json) {
    return PantryItem(
      id: json['id'],
      name: json['name'] ?? 'Unknown',
      quantity: json['quantity'] ?? 1,
      // Parse DateTime from String format
      expiryDate: DateTime.tryParse(json['expiry_date'] ?? '') ?? DateTime.now().add(const Duration(days: 7)),
      unit: json['unit'] ?? 'piece',
      notes: json['notes'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      type: json['type'],
    );
  }

  // Convert Object -> JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'expiry_date': expiryDate.toIso8601String(), // Save as String
      'unit': unit,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'type': type,
    };
  }

  int get daysUntilExpiry => expiryDate.difference(DateTime.now()).inDays;
  bool get isExpired => daysUntilExpiry < 0;
  bool get isExpiringSoon => daysUntilExpiry >= 0 && daysUntilExpiry <= 2;
}