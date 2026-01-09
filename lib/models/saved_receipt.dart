class SavedReceipt {
  final String id;
  final List<Map<String, dynamic>> items;
  final DateTime scannedAt;
  final String? imageName;
  final String? imageHash;

  SavedReceipt({
    required this.id,
    required this.items,
    required this.scannedAt,
    this.imageName,
    this.imageHash,
  });

  factory SavedReceipt.fromJson(Map<String, dynamic> json) {
    return SavedReceipt(
      id: json['id'],
      items: List<Map<String, dynamic>>.from(json['items'] ?? []),
      scannedAt: DateTime.tryParse(json['scanned_at'] ?? '') ?? DateTime.now(),
      imageName: json['image_name'],
      imageHash: json['image_hash'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'items': items,
      'scanned_at': scannedAt.toIso8601String(),
      'image_name': imageName,
      'image_hash': imageHash,
    };
  }

  String get displayText {
    final itemCount = items.length;
    final dateStr = scannedAt.toString().split(' ')[0];
    return '$itemCount items • $dateStr';
  }
}