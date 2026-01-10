import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart'; // Needed for debugPrint and kIsWeb
import 'package:path_provider/path_provider.dart';
import '../models/pantry_item.dart';
import '../models/saved_receipt.dart';

class PantryService {
      bool _initialized = false;
    Future<void> clearPantry() async {
      _pantryItems.clear();
      await _saveToFile();
      _broadcastAll();
    }
  static final PantryService _instance = PantryService._internal();
  static PantryService get instance => _instance;
  factory PantryService() => _instance;
  PantryService._internal();

  File? _file;
  final String _fileName = 'freshkeep_data.json';
  
  // In-memory data
  List<PantryItem> _pantryItems = [];
  List<SavedReceipt> _savedReceipts = [];
  List<Map<String, dynamic>> _freshnessHistory = [];
  
  // Expiry Defaults
  Map<String, int> _expiryDefaults = {
    'meat': 7,
    'seafood': 3,
    'vegetable': 3,
    'fruit': 5,
    'dairy': 7,
    'bread': 3,
    'other': 5,
  };

  // Stream Controllers
  final _pantryStreamController = StreamController<List<PantryItem>>.broadcast();
  final _receiptStreamController = StreamController<List<SavedReceipt>>.broadcast();
  final _historyStreamController = StreamController<List<Map<String, dynamic>>>.broadcast();

  // --- INIT & FILE IO ---

  Future<void> init() async {
    try {
      if (kIsWeb) {
        debugPrint("Web mode: Local file storage disabled.");
        _broadcastAll();
        return;
      }

      final directory = await getApplicationDocumentsDirectory();
      _file = File('${directory.path}/$_fileName');
      
      if (await _file!.exists()) {
        try {
          final content = await _file!.readAsString();
          final data = jsonDecode(content);

          if (data['pantry'] != null) {
            _pantryItems = (data['pantry'] as List)
                .map((e) => PantryItem.fromJson(e))
                .toList();
          }

          if (data['receipts'] != null) {
            _savedReceipts = (data['receipts'] as List)
                .map((e) => SavedReceipt.fromJson(e))
                .toList();
            debugPrint('[PantryService] Loaded receipts: \\${_savedReceipts.length}');
          }

          if (data['history'] != null) {
            _freshnessHistory = List<Map<String, dynamic>>.from(data['history']);
          }

          if (data['expiry_defaults'] != null) {
            _expiryDefaults = Map<String, int>.from(data['expiry_defaults']);
          }
        } catch (e) {
          debugPrint("Lỗi đọc file local: $e");
        }
      }
      
      _broadcastAll();
      _initialized = true;
    } catch (e) {
      debugPrint("Lỗi khởi tạo storage: $e");
    }
  }

  Future<void> _saveToFile() async {
    if (_file == null) {
      _broadcastAll(); // Update UI even if file save is skipped (Web)
      return; 
    }
    
    final data = {
      'pantry': _pantryItems.map((e) => e.toJson()).toList(),
      'receipts': _savedReceipts.map((e) => e.toJson()).toList(),
      'history': _freshnessHistory,
      'expiry_defaults': _expiryDefaults,
    };

    try {
      await _file!.writeAsString(jsonEncode(data));
    } catch (e) {
      debugPrint("Lỗi ghi file: $e");
    }
    _broadcastAll();
  }

  // --- EXPORT / IMPORT DATA ---

  Future<String> exportData() async {
    // Always export from memory to ensure latest state
    final data = {
      'pantry': _pantryItems.map((e) => e.toJson()).toList(),
      'receipts': _savedReceipts.map((e) => e.toJson()).toList(),
      'history': _freshnessHistory,
      'expiry_defaults': _expiryDefaults,
    };
    return jsonEncode(data);
  }

  Future<void> importData(String jsonString) async {
    try {
      final data = jsonDecode(jsonString);
      
      if (data is! Map) throw Exception("Invalid JSON data");

      if (data['pantry'] != null) {
        _pantryItems = (data['pantry'] as List).map((e) => PantryItem.fromJson(e)).toList();
      }
      if (data['receipts'] != null) {
        _savedReceipts = (data['receipts'] as List).map((e) => SavedReceipt.fromJson(e)).toList();
      }
      if (data['history'] != null) {
        _freshnessHistory = List<Map<String, dynamic>>.from(data['history']);
      }
      if (data['expiry_defaults'] != null) {
        _expiryDefaults = Map<String, int>.from(data['expiry_defaults']);
      }

      await _saveToFile();
      _broadcastAll();
    } catch (e) {
      throw Exception("Import failed: $e");
    }
  }

  void _broadcastAll() {
    _pantryItems.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
    _pantryStreamController.add(List.from(_pantryItems));

    _savedReceipts.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
    _receiptStreamController.add(List.from(_savedReceipts));

    _freshnessHistory.sort((a, b) {
      final tA = DateTime.tryParse(a['checked_at'] ?? '') ?? DateTime(2000);
      final tB = DateTime.tryParse(b['checked_at'] ?? '') ?? DateTime(2000);
      return tB.compareTo(tA);
    });
    _historyStreamController.add(List.from(_freshnessHistory));
  }

  // --- DEFAULTS OPERATIONS ---
  int getExpiryDefault(String type) => _expiryDefaults[type] ?? 5;

  Future<void> setExpiryDefault(String type, int days) async {
    _expiryDefaults[type] = days;
    await _saveToFile();
  }

  // --- PANTRY OPERATIONS ---
  Stream<List<PantryItem>> getPantryItems() {
    _ensureInitialized();
    return _pantryStreamController.stream;
  }

  Future<String> createPantryItem({
    required String name,
    required int quantity,
    required DateTime expiryDate,
    required String unit,
    String? notes,
    String type = 'manual',
  }) async {
    final newItem = PantryItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      quantity: quantity,
      expiryDate: expiryDate,
      unit: unit,
      notes: notes,
      createdAt: DateTime.now(),
      type: type,
    );

    _pantryItems.add(newItem);
    await _saveToFile();
    return newItem.id;
  }

  Future<void> deleteItem(String id) async {
    _pantryItems.removeWhere((item) => item.id == id);
    await _saveToFile();
    _broadcastAll();
  }

  Future<void> updateItem(String id, PantryItem updatedItem) async {
    final index = _pantryItems.indexWhere((item) => item.id == id);
    if (index != -1) {
      _pantryItems[index] = updatedItem;
      await _saveToFile();
    }
  }

  // --- HISTORY OPERATIONS ---
  Stream<List<Map<String, dynamic>>> getFreshnessHistory() => _historyStreamController.stream;

  Future<String> addFreshnessHistory(Map<String, dynamic> data, {String? imageHash}) async {
    final newEntry = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'name': data['name'] ?? 'Unknown',
      'status': data['status'] ?? 'Unknown',
      'days_left': data['days_left'] ?? 0,
      'advice': data['advice'] ?? '',
      'image_hash': imageHash,
      'checked_at': DateTime.now().toIso8601String(),
    };
    
    _freshnessHistory.add(newEntry);
    await _saveToFile();
    return newEntry['id'];
  }

  Future<void> deleteHistoryEntry(String id) async {
    _freshnessHistory.removeWhere((item) => item['id'] == id);
    await _saveToFile();
  }

  Future<Map<String, dynamic>?> findFreshnessByImageHash(String imageHash) async {
    try {
      final item = _freshnessHistory.firstWhere(
        (element) => element['image_hash'] == imageHash,
      );
      return {
        'name': item['name'],
        'status': item['status'],
        'days_left': item['days_left'],
        'advice': item['advice'],
        'from_cache': true,
      };
    } catch (e) {
      return null;
    }
  }

  // --- RECEIPT OPERATIONS ---
  Stream<List<SavedReceipt>> getSavedReceipts() => _receiptStreamController.stream;


  Future<String> saveScannedReceipt(
    List<Map<String, dynamic>> items, {
    String? imageName,
    String? imageHash,
  }) async {
    debugPrint('[PantryService] Saving scanned receipt with ${items.length} items, imageName=$imageName, imageHash=$imageHash');
    _ensureInitialized();
    final newReceipt = SavedReceipt(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      items: items,
      scannedAt: DateTime.now(),
      imageName: imageName,
      imageHash: imageHash,
    );

    _savedReceipts.add(newReceipt);
    debugPrint('[PantryService] Total receipts after save: ${_savedReceipts.length}');
    await _saveToFile();
    _broadcastAll();
    return newReceipt.id;
  }

  Future<void> deleteSavedReceipt(String id) async {
    _ensureInitialized();
    _savedReceipts.removeWhere((item) => item.id == id);
    await _saveToFile();
  }

  Future<SavedReceipt?> findReceiptByImageHash(String imageHash) async {
    _ensureInitialized();
    try {
      return _savedReceipts.firstWhere((element) => element.imageHash == imageHash);
    } catch (e) {
      return null;
    }
  }

  Future<SavedReceipt?> getSavedReceiptById(String id) async {
    try {
      return _savedReceipts.firstWhere((element) => element.id == id);
    } catch (e) {
      return null;
    }
    _ensureInitialized();
  }

  void _ensureInitialized() {
    if (!_initialized) {
      // ignore: deprecated_member_use
      init();
    }
  }
}