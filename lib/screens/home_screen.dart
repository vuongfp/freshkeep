import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fl_chart/fl_chart.dart';
import '../utils/image_utils.dart';
import '../services/ai_service.dart';
import '../services/pantry_service.dart';
import '../services/food_expiry_defaults_service.dart';
import '../models/pantry_item.dart';
import '../models/saved_receipt.dart';
import '../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // --- AUTH ---
  final AuthService _authService = AuthService.instance;
  User? _user;
  bool _isGuest = false;
  Future<void> _clearPantry() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('confirm')),
        content: Text(_t('clear_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_t('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_t('clear_all')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _pantryService.clearPantry();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('clear_success'))),
        );
      }
    }
  }

  // State cho receipt filter
  DateTime? _receiptFilterFrom;
  DateTime? _receiptFilterTo;
  void _showReceiptsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSt) {
            return AlertDialog(
              title: Text(_t('receipts_title')),
              content: SizedBox(
                width: 350,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate:
                                    _receiptFilterFrom ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setSt(() => _receiptFilterFrom = picked);
                              }
                            },
                            child: Text(
                              _receiptFilterFrom == null
                                  ? _t('from_date')
                                  : _receiptFilterFrom!.toString().split(
                                        ' ',
                                      )[0],
                            ),
                          ),
                        ),
                        Expanded(
                          child: TextButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _receiptFilterTo ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setSt(() => _receiptFilterTo = picked);
                              }
                            },
                            child: Text(
                              _receiptFilterTo == null
                                  ? _t('to_date')
                                  : _receiptFilterTo!.toString().split(' ')[0],
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setSt(() {
                            _receiptFilterFrom = null;
                            _receiptFilterTo = null;
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    StreamBuilder<List<SavedReceipt>>(
                      stream: _pantryService.getSavedReceipts(),
                      builder: (context, snapshot) {
                        debugPrint(
                          '[ReceiptsDialog] StreamBuilder snapshot: hasData=${snapshot.hasData}, length=${snapshot.data?.length}',
                        );
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return Text(_t('no_receipts'));
                        }
                        var receipts = snapshot.data!;
                        if (_receiptFilterFrom != null) {
                          receipts = receipts
                              .where(
                                (r) => r.scannedAt.isAfter(
                                  _receiptFilterFrom!.subtract(
                                    const Duration(days: 1),
                                  ),
                                ),
                              )
                              .toList();
                        }
                        if (_receiptFilterTo != null) {
                          receipts = receipts
                              .where(
                                (r) => r.scannedAt.isBefore(
                                  _receiptFilterTo!.add(
                                    const Duration(days: 1),
                                  ),
                                ),
                              )
                              .toList();
                        }
                        receipts.sort(
                          (a, b) => b.scannedAt.compareTo(a.scannedAt),
                        );
                        return SizedBox(
                          height: 300,
                          child: ListView.builder(
                            itemCount: receipts.length,
                            itemBuilder: (context, idx) {
                              final r = receipts[idx];
                              return ListTile(
                                title: Text(
                                  '${r.items.length} ${_t("items")}',
                                ),
                                subtitle: Text(
                                  r.scannedAt.toString().split(' ')[0],
                                ),
                                trailing: r.imageName != null
                                    ? Text(r.imageName!)
                                    : null,
                                onTap: () {
                                  // Xem chi tiết hóa đơn nếu muốn
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text(
                                        _t('receipt_detail'),
                                      ),
                                      content: SizedBox(
                                        width: 350,
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${_t("date_label")}: ${r.scannedAt.toString().split(" ")[0]}',
                                            ),
                                            if (r.imageName != null)
                                              Text(
                                                '${_t("image_label")}: ${r.imageName}',
                                              ),
                                            const Divider(),
                                            ...r.items.map(
                                              (item) => Text(
                                                '- ${item['name'] ?? ''} (${item['quantity'] ?? ''} ${item['unit'] ?? ''})',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: Text(_t('close')),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(_isVietnamese ? 'Đóng' : 'Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Thêm nút mở dialog hóa đơn vào UI (ví dụ ở AppBar hoặc dưới nút Thêm thủ công)
  // --- SERVICES ---
  final AiService _aiService = AiService();
  final PantryService _pantryService = PantryService.instance;
  final FoodExpiryDefaultsService _foodExpiryService =
      FoodExpiryDefaultsService();
  final ImagePicker _picker = ImagePicker();

  // --- STATE ---
  XFile? _image;
  bool _isLoading = false;
  Map<String, dynamic>? _freshnessResult;
  String? _error;

  // State UI
  String _searchText = "";
  bool _isVietnamese = false;
  bool _showStats = false;
  String _selectedCategory = 'all';
  bool _showExpiringSoonOnly = false;

  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _quantityController;
  late TextEditingController _unitController;
  late TextEditingController _notesController;
  late TextEditingController _searchController;
  DateTime _selectedExpiryDate = DateTime.now().add(const Duration(days: 7));

  // --- TỪ ĐIỂN (Giữ nguyên của bạn) ---
  final Map<String, Map<String, String>> _dict = {
    'app_title': {'en': 'FreshKeep', 'vn': 'FreshKeep'},
    'search_hint': {'en': 'Search items...', 'vn': 'Tìm kiếm món ăn...'},
    'stats_title': {'en': 'Pantry Statistics', 'vn': 'Thống kê Tủ lạnh'},
    'add_manual': {'en': 'Add Manually', 'vn': 'Thêm thủ công'},
    'check_freshness': {'en': 'Check Freshness', 'vn': 'Kiểm tra độ tươi'},
    'scan_receipt': {'en': 'Scan Receipt', 'vn': 'Quét hóa đơn'},
    'pantry_title': {'en': 'Your Pantry', 'vn': 'Tủ lạnh của bạn'},
    'filter_expiring': {
      'en': 'Expiring Soon (≤ 2 days)',
      'vn': 'Sắp hết hạn (≤ 2 ngày)'
    },
    'empty_pantry': {'en': 'Pantry is empty.', 'vn': 'Tủ lạnh trống.'},
    'no_match': {
      'en': 'No items match filter.',
      'vn': 'Không tìm thấy món nào.'
    },
    'items': {'en': 'items', 'vn': 'món'},
    'days': {'en': 'days', 'vn': 'ngày'},
    'add_success': {'en': 'Added to pantry!', 'vn': 'Đã thêm vào tủ lạnh!'},
    'update_success': {'en': 'Item updated!', 'vn': 'Đã cập nhật món!'},
    'close': {'en': 'Close', 'vn': 'Đóng'},
    'cancel': {'en': 'Cancel', 'vn': 'Hủy'},
    'add': {'en': 'Add', 'vn': 'Thêm'},
    'update': {'en': 'Update', 'vn': 'Cập nhật'},
    'name_label': {'en': 'Item Name', 'vn': 'Tên món'},
    'qty_label': {'en': 'Quantity', 'vn': 'Số lượng'},
    'unit_label': {'en': 'Unit', 'vn': 'Đơn vị'},
    'notes_label': {'en': 'Notes', 'vn': 'Ghi chú'},
    'expiry_label': {'en': 'Expiry', 'vn': 'Hết hạn'},
    'filtering': {'en': 'Filtering', 'vn': 'Đang lọc'},
    'edit': {'en': 'Edit', 'vn': 'Sửa'},
    'delete': {'en': 'Delete', 'vn': 'Xóa'},
    'no_data_stats': {
      'en': 'No data for stats',
      'vn': 'Chưa có dữ liệu để thống kê'
    },
    'camera': {'en': 'Camera', 'vn': 'Camera'},
    'gallery': {'en': 'Gallery', 'vn': 'Thư viện'},
    'left': {'en': 'left', 'vn': 'còn lại'},
    // Auth
    'login': {'en': 'Login', 'vn': 'Đăng nhập'},
    'logout': {'en': 'Logout', 'vn': 'Đăng xuất'},
    'login_to_use': {'en': 'Login to use', 'vn': 'Đăng nhập để sử dụng'},
    'login_success': {'en': 'Login successful!', 'vn': 'Đăng nhập thành công!'},
    'logout_success': {'en': 'Logged out.', 'vn': 'Đã đăng xuất.'},
    'login_failed': {'en': 'Login failed: ', 'vn': 'Đăng nhập thất bại: '},
    // Receipts dialog
    'receipts_title': {'en': 'Scanned Receipts', 'vn': 'Các hóa đơn đã quét'},
    'no_receipts': {'en': 'No receipts yet.', 'vn': 'Chưa có hóa đơn nào.'},
    'view_receipts': {
      'en': 'View Scanned Receipts',
      'vn': 'Xem hóa đơn đã quét'
    },
    'receipt_detail': {'en': 'Receipt Details', 'vn': 'Chi tiết hóa đơn'},
    'date_label': {'en': 'Date', 'vn': 'Ngày'},
    'image_label': {'en': 'Image', 'vn': 'Ảnh'},
    'from_date': {'en': 'From', 'vn': 'Từ ngày'},
    'to_date': {'en': 'To', 'vn': 'Đến ngày'},
    // Pantry actions
    'clear_pantry': {'en': 'Clear Pantry', 'vn': 'Xóa tủ lạnh'},
    'clear_confirm': {
      'en': 'Are you sure you want to clear all pantry items?',
      'vn': 'Bạn có chắc muốn xóa toàn bộ tủ lạnh?'
    },
    'clear_success': {'en': 'Pantry cleared!', 'vn': 'Đã xóa toàn bộ tủ lạnh!'},
    'confirm': {'en': 'Confirm', 'vn': 'Xác nhận'},
    'clear_all': {'en': 'Clear all', 'vn': 'Xóa hết'},
    // Upload
    'tap_to_upload': {'en': 'Tap to upload image', 'vn': 'Chạm để tải ảnh lên'},
    // Expires
    'expires_in': {'en': 'Expires in: ', 'vn': 'Hạn dùng: '},
    // Settings
    'settings': {'en': 'Settings', 'vn': 'Cài đặt'},
    // Scan success
    'scan_success': {
      'en': 'Added {n} items to pantry!',
      'vn': 'Đã thêm {n} món vào tủ lạnh!'
    },
    // Error
    'error_prefix': {'en': 'Error: ', 'vn': 'Lỗi: '},
    'continue_as_guest': {'en': 'Continue as guest', 'vn': 'Tiếp tục với khách'},
    'guest_mode': {'en': 'Guest Mode', 'vn': 'Chế độ khách'},
  };

  String _t(String key) => _dict[key]?[_isVietnamese ? 'vn' : 'en'] ?? key;

  final Map<String, String> _categoryDisplayNames = {
    'all': 'All',
    'meat': 'Meat',
    'seafood': 'Seafood',
    'vegetable': 'Vegetable',
    'fruit': 'Fruit',
    'dairy': 'Dairy',
    'other': 'Other',
  };
  final Map<String, String> _categoryVN = {
    'all': 'Tất cả',
    'meat': 'Thịt',
    'seafood': 'Hải sản',
    'vegetable': 'Rau',
    'fruit': 'Trái cây',
    'dairy': 'Sữa/Trứng',
    'other': 'Khác',
  };
  String _getCategoryName(String key) => _isVietnamese
      ? (_categoryVN[key] ?? key)
      : (_categoryDisplayNames[key] ?? key);

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _quantityController = TextEditingController(text: '1');
    _unitController = TextEditingController(text: 'piece');
    _notesController = TextEditingController();
    _searchController = TextEditingController();
    // Default language: English. User can toggle to Vietnamese.
    _pantryService.init();
    // Listen to auth changes
    _authService.userChanges.listen((user) {
      setState(() {
        _user = user;
      });
    });
    _user = _authService.currentUser;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    _notesController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // --- LOGIC HÀM ---
  Future<String> _generateImageHash(XFile file) async {
    final bytes = await file.readAsBytes();
    return computeImageHash(bytes);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _image = pickedFile;
          _freshnessResult = null;
          _error = null;
        });
      }
    } catch (e) {
      setState(() => _error = '${_t("error_prefix")}$e');
    }
  }

  Future<void> _checkFreshness() async {
    if (_image == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
      _freshnessResult = null;
    });

    try {
      final imageHash = await _generateImageHash(_image!);
      final cachedResult = await _pantryService.findFreshnessByImageHash(
        imageHash,
      );

      if (cachedResult != null) {
        setState(() => _freshnessResult = cachedResult);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚡ Loaded from cache'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      } else {
        final result = await _aiService.checkFreshness(_image!);
        setState(() => _freshnessResult = result);
        if (result['name'] != 'Error') {
          await _pantryService.addFreshnessHistory(
            result,
            imageHash: imageHash,
          );
        }
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _scanReceipt() async {
    if (_image == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      debugPrint('[HomeScreen] Calling scanReceipt...');
      final result = await _aiService.scanReceipt(_image!);
      debugPrint('[HomeScreen] scanReceipt result: ${result.length} items');
      if (result.isNotEmpty && mounted) {
        // Lưu lại hóa đơn vừa scan
        await _pantryService.saveScannedReceipt(
          result,
          imageName: _image?.name,
          imageHash: await _generateImageHash(_image!),
        );
        // Convert each scanned item to PantryItem và add to pantry
        for (var item in result) {
          // Xác định type hợp lệ
          String type = (item['type'] ?? '').toString().toLowerCase();
          if (type == 'produce') type = 'vegetable';
          const validTypes = [
            'meat',
            'seafood',
            'vegetable',
            'fruit',
            'dairy',
            'other',
          ];
          if (!validTypes.contains(type)) {
            // Dựa vào unit hoặc name để đoán loại
            final unit = (item['unit'] ?? '').toString().toLowerCase();
            final name = (item['name'] ?? '').toString().toLowerCase();
            if (unit.contains('kg') || name.contains('thịt')) {
              type = 'meat';
            } else if (name.contains('cá') ||
                name.contains('tôm') ||
                name.contains('hải sản'))
              type = 'seafood';
            else if (name.contains('rau') ||
                name.contains('cải') ||
                name.contains('xà lách'))
              type = 'vegetable';
            else if (name.contains('chuối') ||
                name.contains('nho') ||
                name.contains('trái cây'))
              type = 'fruit';
            else if (name.contains('sữa') || name.contains('trứng'))
              type = 'dairy';
            else
              type = 'other';
          }
          final nameEn = (item['name'] ?? 'Unknown').toString();
          final itemNameVn = (item['name_vn'] ?? '').toString();
          await _pantryService.createPantryItem(
            name: nameEn,
            nameVn: itemNameVn.isNotEmpty ? itemNameVn : null,
            quantity: (item['quantity'] is int)
                ? item['quantity']
                : (item['quantity'] is double)
                    ? (item['quantity'] as double).round()
                    : 1,
            expiryDate: DateTime.now().add(
              Duration(days: item['suggested_days'] ?? 7),
            ),
            unit: item['unit'] ?? 'piece',
            notes: null,
            type: type,
          );
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
            _t('scan_success').replaceAll('{n}', '${result.length}'),
          )),
        );
      }
    } catch (e) {
      debugPrint('[HomeScreen] scanReceipt error: $e');
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- AUTH HANDLERS ---
  Future<void> _handleLogin() async {
    try {
      final user = await _authService.signInWithGoogle();
      if (user != null) {
        if (!mounted) return;
        setState(() => _user = user);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('login_success'))),
        );
      }
    } on PlatformException catch (e) {
      debugPrint('[Auth] signInWithGoogle error: $e');
      // If it's a keychain error, offer "Continue as Guest" to the user
      if (e.code == 'keychain_error') {
        final choice = await showDialog<String?>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(_t('login_failed')),
            content: Text('Google Sign-In failed due to a keychain error. Continue as guest?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, 'cancel'),
                child: Text(_t('cancel')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, 'retry'),
                child: Text('Retry'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, 'guest'),
                child: Text('Continue as Guest'),
              ),
            ],
          ),
        );

        if (!mounted) return;

        if (choice == 'guest') {
          try {
            final anon = await _authService.signInAnonymously();
            if (anon != null && mounted) {
              setState(() => _user = anon);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Signed in as guest')),
              );
            }
            return;
          } catch (e2) {
            debugPrint('[Auth] anonymous sign-in failed: $e2');
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${_t('login_failed')}$e2')),
            );
            return;
          }
        } else if (choice == 'retry') {
          // Try again
          return _handleLogin();
        } else {
          return; // canceled
        }
      }

      // Non-keychain errors: check if user signed in despite exception
      final currentUser = _authService.currentUser;
      if (currentUser != null) {
        if (!mounted) return;
        setState(() => _user = currentUser);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('login_success'))),
        );
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_t("login_failed")}$e')),
      );
    } catch (e) {
      debugPrint('[Auth] signInWithGoogle error: $e');
      final currentUser = _authService.currentUser;
      if (currentUser != null) {
        if (!mounted) return;
        setState(() => _user = currentUser);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('login_success'))),
        );
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_t("login_failed")}$e')),
      );
    }
  }
  
  Future<void> _handleGuestLogin() async {
    setState(() => _isLoading = true);
    try {
      final anon = await _authService.signInAnonymously();
      if (anon != null && mounted) {
        setState(() {
          _user = anon;
          _isGuest = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('guest_mode'))),
        );
      }
    } catch (e) {
      debugPrint('[Auth] Firebase guest sign-in failed, falling back to local mode: $e');
      if (mounted) {
        setState(() {
          _user = null;
          _isGuest = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_t('guest_mode')} (Offline)')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogout() async {
    await _authService.signOut();
    if (!mounted) return;
    setState(() {
      _user = null;
      _isGuest = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_t('logout_success'))),
    );
  }

  // --- UI CHÍNH (GIAO DIỆN MỚI) ---
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Icon(Icons.eco, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _t('app_title'),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _isVietnamese ? Icons.language : Icons.translate,
              color: theme.colorScheme.primary,
            ),
            onPressed: () => setState(() => _isVietnamese = !_isVietnamese),
          ),
          IconButton(
            icon: Icon(
              Icons.settings_outlined,
              color: theme.colorScheme.primary,
            ),
            tooltip: _t('settings'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SettingsScreen(isVietnamese: _isVietnamese),
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.pie_chart,
              color: _showStats
                  ? theme.colorScheme.secondary
                  : theme.colorScheme.primary,
            ),
            onPressed: () => setState(() => _showStats = !_showStats),
          ),
          _user == null && !_isGuest
              ? TextButton.icon(
                  onPressed: _handleLogin,
                  icon: const Icon(Icons.login, color: Colors.blue),
                  label: Text(
                    _isVietnamese ? 'Đăng nhập' : 'Login',
                    style: const TextStyle(color: Colors.blue),
                  ),
                )
              : PopupMenuButton<String>(
                  icon: CircleAvatar(
                    backgroundColor: Colors.grey[200],
                    backgroundImage: _user?.photoURL != null
                        ? NetworkImage(_user!.photoURL!)
                        : null,
                    child: _user?.photoURL == null
                        ? const Icon(Icons.person, color: Colors.black54)
                        : null,
                  ),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'logout',
                      child: Text(_t('logout')),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'logout') _handleLogout();
                  },
                ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. HERO IMAGE
            _buildNewImagePreview(theme),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showReceiptsDialog,
                    icon: const Icon(Icons.receipt_long),
                    label: Text(_t('view_receipts')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _clearPantry,
                    icon: const Icon(Icons.delete_forever),
                    label: Text(_t('clear_pantry')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 2. ACTION BUTTONS
            if (_user == null && !_isGuest) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: _handleLogin,
                        icon: const Icon(Icons.login),
                        label: Text(_t('login_to_use')),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton.icon(
                        onPressed: _handleGuestLogin,
                        icon: const Icon(Icons.person_outline),
                        label: Text(_t('continue_as_guest')),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              if (_image != null && !_isLoading)
                Row(
                  children: [
                    Expanded(
                      child: _buildNewActionButton(
                        context,
                        label: _t('check_freshness'),
                        icon: Icons.search,
                        color: theme.colorScheme.secondary,
                        onPressed: _checkFreshness,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildNewActionButton(
                        context,
                        label: _t('scan_receipt'),
                        icon: Icons.receipt_long,
                        color: theme.colorScheme.primary,
                        onPressed: _scanReceipt,
                      ),
                    ),
                  ],
                )
              else if (_isLoading)
                const Center(
                  child:
                      SpinKitThreeBounce(color: Color(0xFF2E7D32), size: 30.0),
                )
              else
                ElevatedButton.icon(
                  onPressed: _showAddPantryDialog,
                  icon: const Icon(Icons.add_circle_outline, size: 28),
                  label: Text(
                    _t('add_manual'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                ),
            ],
            const SizedBox(height: 24),

            // 3. RESULTS & ERROR
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_error!, style: TextStyle(color: Colors.red[800])),
              ),

            if (_freshnessResult != null)
              _buildNewResultCard(_freshnessResult!),

            // 4. STATS (Đã khôi phục logic)
            if (_showStats) ...[
              const SizedBox(height: 20),
              Text(
                _t('stats_title'),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E7D32),
                ),
              ),
              const SizedBox(height: 16),
              _buildStatsChart(),
            ],

            const SizedBox(height: 32),

            // 5. PANTRY LIST & FILTERS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _t('pantry_title'),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1B5E20),
                  ),
                ),
                if (_searchText.isNotEmpty || _selectedCategory != 'all')
                  const Icon(Icons.filter_list, color: Colors.orange),
              ],
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: _t('search_hint'),
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              onChanged: (value) => setState(() => _searchText = value),
            ),

            const SizedBox(height: 16),
            _buildFilters(), // Đã khôi phục
            const SizedBox(height: 16),
            _buildPantryListNewUI(), // Đã khôi phục
          ],
        ),
      ),
    );
  }

  // --- CÁC WIDGET PHỤ TRỢ (ĐÃ KHÔI PHỤC LOGIC CŨ) ---

  Widget _buildStatsChart() {
    return StreamBuilder<List<PantryItem>>(
      stream: _pantryService.getPantryItems(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return SizedBox(
            height: 50,
            child: Center(child: Text(_t('no_data_stats'))),
          );
        }
        final items = snapshot.data!;
        Map<String, int> counts = {};
        for (var item in items) {
          String type = (item.type ?? 'other').toLowerCase();
          counts[type] = (counts[type] ?? 0) + 1;
        }
        List<PieChartSectionData> sections = [];
        final List<Color> colors = [
          Colors.redAccent,
          Colors.blueAccent,
          Colors.green,
          Colors.orange,
          Colors.purple,
        ];
        int i = 0;
        counts.forEach((key, value) {
          sections.add(
            PieChartSectionData(
              color: colors[i % colors.length],
              value: value.toDouble(),
              title: '${_getCategoryName(key)}\n$value',
              radius: 60,
              titleStyle: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          );
          i++;
        });
        return Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 40,
              sectionsSpace: 2,
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          title: Text(
            _t('filter_expiring'),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          value: _showExpiringSoonOnly,
          activeTrackColor: Colors.redAccent,
          contentPadding: EdgeInsets.zero,
          onChanged: (val) => setState(() => _showExpiringSoonOnly = val),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _categoryDisplayNames.keys.map((key) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(_getCategoryName(key)),
                  selected: _selectedCategory == key,
                  selectedColor: const Color(0xFF2E7D32),
                  labelStyle: TextStyle(
                    color:
                        _selectedCategory == key ? Colors.white : Colors.black,
                  ),
                  onSelected: (sel) =>
                      setState(() => _selectedCategory = sel ? key : 'all'),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildPantryListNewUI() {
    return StreamBuilder<List<PantryItem>>(
      stream: _pantryService.getPantryItems(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 60,
                  color: Colors.grey[300],
                ),
                Text(
                  _t('empty_pantry'),
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        final filteredItems = snapshot.data!.where((item) {
          final itemType = (item.type ?? 'other').trim().toLowerCase();
          if (_selectedCategory != 'all' && itemType != _selectedCategory) {
            return false;
          }
          if (_showExpiringSoonOnly &&
              !item.isExpiringSoon &&
              !item.isExpired) {
            return false;
          }
          if (_searchText.isNotEmpty &&
              !item.name.toLowerCase().contains(_searchText.toLowerCase())) {
            return false;
          }
          return true;
        }).toList();

        if (filteredItems.isEmpty) return Center(child: Text(_t('no_match')));

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filteredItems.length,
          itemBuilder: (context, index) {
            final item = filteredItems[index];
            Color iconColor = Colors.green;
            if (item.isExpired) {
              iconColor = Colors.red;
            } else if (item.isExpiringSoon) iconColor = Colors.orange;

            return Dismissible(
              key: Key(item.id),
              direction: DismissDirection.endToStart,
              onDismissed: (_) => _pantryService.deleteItem(item.id),
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                color: Colors.red[100],
                child: const Icon(Icons.delete, color: Colors.red),
              ),
              child: Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFE8F5E9),
                    child: Icon(Icons.eco, color: iconColor),
                  ),
                  title: Text(
                    (_isVietnamese && (item.nameVn ?? '').isNotEmpty)
                        ? item.nameVn!
                        : item.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${item.quantity} ${item.unit} • ${item.daysUntilExpiry} ${_t('days')} ${_t('left')}',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) => v == 'delete'
                        ? _pantryService.deleteItem(item.id)
                        : _showEditPantryDialog(item),
                    itemBuilder: (context) => [
                      PopupMenuItem(value: 'edit', child: Text(_t('edit'))),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          _t('delete'),
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- DIALOGS (Đã khôi phục) ---
  Future<void> _showAddPantryDialog() async {
    _nameController.clear();
    _quantityController.text = '1';
    _unitController.text = 'piece';
    _notesController.clear();
    _selectedExpiryDate = DateTime.now().add(const Duration(days: 7));

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(_t('add_manual')),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(labelText: _t('name_label')),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _quantityController,
                            keyboardType: TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: _t('qty_label'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 100,
                          child: TextField(
                            controller: _unitController,
                            decoration: InputDecoration(
                              labelText: _t('unit_label'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: _selectedExpiryDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (pickedDate != null) {
                          setDialogState(
                            () => _selectedExpiryDate = pickedDate,
                          );
                        }
                      },
                      child: Text(
                        '${_t('expiry_label')}: ${_selectedExpiryDate.toString().split(' ')[0]}',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _notesController,
                      decoration: InputDecoration(labelText: _t('notes_label')),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(_t('cancel')),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (_nameController.text.isEmpty) return;
                    await _pantryService.createPantryItem(
                      name: _nameController.text.trim(),
                      quantity: int.tryParse(_quantityController.text) ?? 1,
                      expiryDate: _selectedExpiryDate,
                      unit: _unitController.text.trim(),
                      notes: _notesController.text.trim(),
                    );
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(_t('add_success'))),
                      );
                    }
                  },
                  child: Text(_t('add')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditPantryDialog(PantryItem item) {
    final nameC = TextEditingController(text: item.name);
    final qtyC = TextEditingController(text: '${item.quantity}');
    final unitC = TextEditingController(text: item.unit);
    final notesC = TextEditingController(text: item.notes);
    DateTime selectedDate = item.expiryDate;
    const validTypes = [
      'meat',
      'seafood',
      'vegetable',
      'fruit',
      'dairy',
      'other',
    ];
    String selectedType = validTypes.contains(item.type) ? item.type! : 'other';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSt) => AlertDialog(
          title: Text(_t('edit')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameC,
                decoration: InputDecoration(labelText: _t('name_label')),
              ),
              TextField(
                controller: qtyC,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: _t('qty_label')),
              ),
              TextField(
                controller: unitC,
                decoration: InputDecoration(labelText: _t('unit_label')),
              ),
              TextField(
                controller: notesC,
                decoration: InputDecoration(labelText: _t('notes_label')),
              ),
              DropdownButtonFormField<String>(
                initialValue: selectedType,
                decoration: InputDecoration(labelText: 'Type'),
                items: validTypes.map((type) {
                  switch (type) {
                    case 'meat':
                      return DropdownMenuItem(
                        value: 'meat',
                        child: Text(_isVietnamese ? 'Thịt' : 'Meat'),
                      );
                    case 'seafood':
                      return DropdownMenuItem(
                        value: 'seafood',
                        child: Text(_isVietnamese ? 'Hải sản' : 'Seafood'),
                      );
                    case 'vegetable':
                      return DropdownMenuItem(
                        value: 'vegetable',
                        child: Text(_isVietnamese ? 'Rau củ' : 'Vegetable'),
                      );
                    case 'fruit':
                      return DropdownMenuItem(
                        value: 'fruit',
                        child: Text(_isVietnamese ? 'Trái cây' : 'Fruit'),
                      );
                    case 'dairy':
                      return DropdownMenuItem(
                        value: 'dairy',
                        child: Text(_isVietnamese ? 'Sữa/Trứng' : 'Dairy'),
                      );
                    default:
                      return DropdownMenuItem(
                        value: 'other',
                        child: Text(_isVietnamese ? 'Khác' : 'Other'),
                      );
                  }
                }).toList(),
                onChanged: (val) => setSt(() => selectedType = val ?? 'other'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2030),
                  );
                  if (d != null) setSt(() => selectedDate = d);
                },
                child: Text(
                  '${_t('expiry_label')}: ${selectedDate.toString().split(' ')[0]}',
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                final newItem = PantryItem(
                  id: item.id,
                  name: nameC.text,
                  quantity: int.tryParse(qtyC.text) ?? 1,
                  expiryDate: selectedDate,
                  unit: unitC.text,
                  notes: notesC.text,
                  createdAt: item.createdAt,
                  type: item.type,
                );
                await _pantryService.updateItem(item.id, newItem);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(_t('update_success'))));
                }
              },
              child: Text(_t('update')),
            ),
          ],
        ),
      ),
    );
  }

  // --- UI COMPONENTS HELPERS ---
  Widget _buildNewImagePreview(ThemeData theme) {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: _image == null
            ? Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
                width: 2,
              )
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: _image != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  kIsWeb
                      ? Image.network(_image!.path, fit: BoxFit.cover)
                      : Image.file(File(_image!.path), fit: BoxFit.cover),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black54,
                      ),
                      onPressed: () => setState(() {
                        _image = null;
                        _freshnessResult = null;
                      }),
                    ),
                  ),
                ],
              )
            : InkWell(
                onTap: () => _showImageSourceModal(),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.cloud_upload_outlined,
                      size: 64,
                      color: theme.colorScheme.primary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _t('tap_to_upload'),
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  void _showImageSourceModal() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        height: 150,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildSourceOption(
              Icons.camera_alt,
              _t('camera'),
              ImageSource.camera,
            ),
            _buildSourceOption(
              Icons.photo_library,
              _t('gallery'),
              ImageSource.gallery,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceOption(IconData icon, String label, ImageSource source) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        _pickImage(source);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.green[100],
            child: Icon(icon, color: Colors.green[800], size: 30),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildNewActionButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        elevation: 4,
        shadowColor: color.withValues(alpha: 0.4),
      ),
    );
  }

  Widget _buildNewResultCard(Map<String, dynamic> data) {
    // status is ALWAYS English from API: Fresh / Warning / Bad
    final String statusEn = (data['status'] ?? 'Unknown').toString();
    final String statusVn = (data['status_vn'] ?? '').toString();
    final String displayStatus =
        _isVietnamese && statusVn.isNotEmpty ? statusVn : statusEn;

    Color statusColor = Colors.green;
    if (statusEn.toUpperCase().contains('BAD') ||
        statusEn.toUpperCase().contains('SPOILED')) {
      statusColor = Colors.red;
    } else if (statusEn.toUpperCase().contains('WARNING')) {
      statusColor = Colors.orange;
    }

    // Pick the right language for name
    final nameVn = (data['name_vn'] ?? '').toString();
    final displayName = _isVietnamese && nameVn.isNotEmpty
        ? nameVn
        : (data['name'] ?? 'Unknown').toString();

    // Pick the right language for advice
    final adviceVn = (data['advice_vn'] ?? '').toString();
    final adviceEn =
        (data['advice_en'] ?? data['advice'] ?? 'No advice').toString();
    final displayAdvice =
        _isVietnamese && adviceVn.isNotEmpty ? adviceVn : adviceEn;

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    displayStatus,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 30),
            Row(
              children: [
                const Icon(Icons.timer, color: Colors.grey, size: 20),
                const SizedBox(width: 8),
                Text(
                  _t('expires_in'),
                  style: TextStyle(color: Colors.grey[600]),
                ),
                Text(
                  "${data['days_left'] ?? '?'} ${_t('days')}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F8E9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.tips_and_updates,
                    color: Color(0xFFFF8F00),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      displayAdvice,
                      style: const TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Color(0xFF33691E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
