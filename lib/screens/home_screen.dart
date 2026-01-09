import 'dart:io';
import 'package:flutter/foundation.dart'; // Để kiểm tra kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Để dùng Clipboard
import 'package:image_picker/image_picker.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fl_chart/fl_chart.dart'; // Import biểu đồ
import '../utils/image_utils.dart'; 
import '../services/ai_service.dart';
import '../services/pantry_service.dart';
import '../services/food_expiry_defaults_service.dart';
import '../models/pantry_item.dart';
import '../models/saved_receipt.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AiService _aiService = AiService();
  final PantryService _pantryService = PantryService();
  final FoodExpiryDefaultsService _foodExpiryService = FoodExpiryDefaultsService();
  final ImagePicker _picker = ImagePicker();
  
  XFile? _image;
  bool _isLoading = false;
  Map<String, dynamic>? _freshnessResult;
  String? _error;

  // --- STATE QUẢN LÝ GIAO DIỆN ---
  String _searchText = ""; // Từ khóa tìm kiếm
  bool _isVietnamese = true; // Mặc định là Tiếng Việt
  bool _showStats = false; // Trạng thái hiển thị biểu đồ

  // --- FILTER STATE ---
  String _selectedCategory = 'all';
  bool _showExpiringSoonOnly = false;

  // --- TỪ ĐIỂN ĐA NGÔN NGỮ ---
  final Map<String, Map<String, String>> _dict = {
    'app_title': {'en': 'FreshKeep v0.1', 'vn': 'FreshKeep v0.1'},
    'search_hint': {'en': 'Search items...', 'vn': 'Tìm kiếm món ăn...'},
    'stats_title': {'en': 'Pantry Statistics', 'vn': 'Thống kê Tủ lạnh'},
    'add_manual': {'en': 'Add Manual', 'vn': 'Thêm thủ công'},
    'check_freshness': {'en': 'Check Freshness', 'vn': 'Kiểm tra độ tươi'},
    'scan_receipt': {'en': 'Scan Receipt', 'vn': 'Quét hóa đơn'},
    'receipts_title': {'en': 'Recent Receipts', 'vn': 'Hóa đơn gần đây'},
    'pantry_title': {'en': 'Your Pantry', 'vn': 'Tủ lạnh của bạn'},
    'history_title': {'en': 'History', 'vn': 'Lịch sử'},
    'filter_expiring': {'en': 'Expiring Soon (≤ 2 days)', 'vn': 'Sắp hết hạn (≤ 2 ngày)'},
    'empty_pantry': {'en': 'Pantry is empty.', 'vn': 'Tủ lạnh trống.'},
    'no_match': {'en': 'No items match filter.', 'vn': 'Không tìm thấy món nào.'},
    'empty_receipts': {'en': 'No saved receipts.', 'vn': 'Chưa có hóa đơn nào.'},
    'empty_history': {'en': 'No history.', 'vn': 'Chưa có lịch sử.'},
    'items': {'en': 'items', 'vn': 'món'},
    'days': {'en': 'days', 'vn': 'ngày'},
    'add_success': {'en': 'Added to pantry!', 'vn': 'Đã thêm vào tủ lạnh!'},
    'update_success': {'en': 'Item updated!', 'vn': 'Đã cập nhật món!'},
    'export': {'en': 'Export Data', 'vn': 'Xuất dữ liệu'},
    'import': {'en': 'Import Data', 'vn': 'Nhập dữ liệu'},
    'copy': {'en': 'Copy', 'vn': 'Sao chép'},
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
    'status': {'en': 'Status', 'vn': 'Trạng thái'},
    'advice': {'en': 'Advice', 'vn': 'Lời khuyên'},
    'result': {'en': 'Result', 'vn': 'Kết quả'},
    'item': {'en': 'Item', 'vn': 'Món'},
    'left': {'en': 'left', 'vn': 'còn lại'},
    'edit': {'en': 'Edit', 'vn': 'Sửa'},
    'delete': {'en': 'Delete', 'vn': 'Xóa'},
    'no_data_stats': {'en': 'No data for stats', 'vn': 'Chưa có dữ liệu để thống kê'},
    'add_all': {'en': 'Add All', 'vn': 'Thêm tất cả'},
    'receipt_details': {'en': 'Receipt Details', 'vn': 'Chi tiết hóa đơn'},
    'import_success': {'en': 'Data imported successfully!', 'vn': 'Khôi phục dữ liệu thành công!'},
    'copied': {'en': 'Copied to clipboard!', 'vn': 'Đã sao chép vào bộ nhớ tạm!'},
    'json_data_title': {'en': 'JSON Data', 'vn': 'Mã JSON Dữ Liệu'},
    'import_title': {'en': 'Import Data', 'vn': 'Khôi phục Dữ Liệu'},
    'copy_instruction': {'en': 'Copy this code and save it somewhere safe:', 'vn': 'Sao chép mã này và lưu vào nơi an toàn:'},
    'paste_instruction': {'en': 'Paste JSON code here. Warning: Overwrites current data!', 'vn': 'Dán mã JSON vào đây. Cảnh báo: Dữ liệu hiện tại sẽ bị ghi đè!'},
    'import_now': {'en': 'Import Now', 'vn': 'Khôi phục ngay'},
    'camera': {'en': 'Camera', 'vn': 'Camera'},
    'gallery': {'en': 'Gallery', 'vn': 'Thư viện'},
    'backup_restore': {'en': 'Backup / Restore', 'vn': 'Sao lưu / Khôi phục'},
    'export_subtitle': {'en': 'Get JSON code to backup', 'vn': 'Lấy mã JSON để lưu trữ'},
    'import_subtitle': {'en': 'Paste JSON code to restore', 'vn': 'Dán mã JSON để khôi phục'},
  };

  // Helper dịch ngôn ngữ
  String _t(String key) => _dict[key]?[_isVietnamese ? 'vn' : 'en'] ?? key;

  // Danh mục hiển thị (Mặc định EN)
  final Map<String, String> _categoryDisplayNames = {
    'all': 'All',
    'meat': 'Meat',
    'seafood': 'Seafood',
    'vegetable': 'Vegetable',
    'fruit': 'Fruit',
    'dairy': 'Dairy',
    'other': 'Other',
  };
  
  // Mapping danh mục sang Tiếng Việt
  final Map<String, String> _categoryVN = {
    'all': 'Tất cả',
    'meat': 'Thịt',
    'seafood': 'Hải sản',
    'vegetable': 'Rau',
    'fruit': 'Trái cây',
    'dairy': 'Sữa/Trứng',
    'other': 'Khác',
  };

  // Hàm lấy tên danh mục theo ngôn ngữ
  String _getCategoryName(String key) {
    if (_isVietnamese) return _categoryVN[key] ?? key;
    return _categoryDisplayNames[key] ?? key;
  }

  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _quantityController;
  late TextEditingController _unitController;
  late TextEditingController _notesController;
  late TextEditingController _searchController;
  DateTime _selectedExpiryDate = DateTime.now().add(const Duration(days: 7));

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _quantityController = TextEditingController(text: '1');
    _unitController = TextEditingController(text: 'piece');
    _notesController = TextEditingController();
    _searchController = TextEditingController();
    
    // Khởi tạo Local Storage (rất quan trọng)
    _pantryService.init();
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

  int _safeParseInt(dynamic value, {int defaultValue = 1}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  Future<String> _generateImageHash(XFile file) async {
    final bytes = await file.readAsBytes();
    return computeImageHash(bytes);
  }

  // --- UI CHÍNH ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5DC),
      appBar: AppBar(
        title: Text(_t('app_title'), style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF8FBC8F),
        foregroundColor: Colors.white,
        actions: [
          // Nút chuyển ngữ EN/VN
          TextButton(
            onPressed: () => setState(() => _isVietnamese = !_isVietnamese),
            child: Text(
              _isVietnamese ? 'EN' : 'VN',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          // Nút bật/tắt biểu đồ
          IconButton(
            icon: const Icon(Icons.pie_chart),
            tooltip: _t('stats_title'),
            onPressed: () => setState(() => _showStats = !_showStats),
          ),
          // Nút Backup/Restore
          IconButton(
            icon: const Icon(Icons.settings_backup_restore), 
            tooltip: _t('backup_restore'),
            onPressed: _showBackupOptions,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Image Preview
            _buildImagePreview(),
            const SizedBox(height: 20),
            
            // 2. Action Buttons
            _buildActionButtons(),
            const SizedBox(height: 32),

            // Loading & Error
            if (_isLoading) const Center(child: SpinKitFadingCircle(color: Color(0xFF8FBC8F))),
            if (_error != null) 
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),

            // 3. AI Results
            if (_freshnessResult != null) _buildFreshnessCard(),
            
            // 4. THỐNG KÊ (Biểu đồ tròn)
            if (_showStats) ...[
              const SizedBox(height: 20),
              Text(_t('stats_title'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF8FBC8F))),
              const SizedBox(height: 16),
              _buildStatsChart(),
              const SizedBox(height: 20),
            ],

            const SizedBox(height: 20),
            
            // 5. TÌM KIẾM
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onChanged: (value) => setState(() => _searchText = value),
            ),
            const SizedBox(height: 20),

            // 6. DANH SÁCH PANTRY
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_t('pantry_title'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF8FBC8F))),
                // Chỉ hiện chip lọc khi có điều kiện lọc
                if (_selectedCategory != 'all' || _showExpiringSoonOnly || _searchText.isNotEmpty)
                   Chip(label: Text(_t('filtering'), style: const TextStyle(color: Colors.orange, fontSize: 10))),
              ],
            ),
            _buildFilters(),
            _buildPantryList(),

            const SizedBox(height: 40),

            // 7. HÓA ĐƠN
            Text(_t('receipts_title'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF8FBC8F))),
            _buildSavedReceiptsList(),

            const SizedBox(height: 40),

            // 8. LỊCH SỬ
            Text(_t('history_title'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF8FBC8F))),
            _buildFreshnessHistory(),
          ],
        ),
      ),
    );
  }

  // --- CÁC WIDGET CON & LOGIC ---

  Widget _buildImagePreview() {
    return Container(
      height: 250, 
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF8FBC8F), width: 3),
      ),
      child: _image != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(21),
              child: kIsWeb 
                ? Image.network(_image!.path, fit: BoxFit.cover) 
                : Image.file(File(_image!.path), fit: BoxFit.cover),
            )
          : const Center(child: Icon(Icons.add_a_photo, size: 60, color: Color(0xFF8FBC8F))),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Row(children: [
          Expanded(child: _buildInputButton(Icons.camera_alt, _t('camera'), ImageSource.camera)),
          const SizedBox(width: 20),
          Expanded(child: _buildInputButton(Icons.photo_library, _t('gallery'), ImageSource.gallery)),
        ]),
        const SizedBox(height: 12),
        
        if (_image != null)
          Row(children: [
            Expanded(child: _buildActionButton(_t('check_freshness'), _checkFreshness)),
            const SizedBox(width: 12),
            Expanded(child: _buildActionButton(_t('scan_receipt'), _scanReceipt)),
          ]),
        
        if (_image == null)
          ElevatedButton.icon(
            onPressed: _showAddPantryDialog,
            icon: const Icon(Icons.add),
            label: Text(_t('add_manual')),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8FBC8F), 
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 45)
            ),
          ),
      ],
    );
  }

  // BIỂU ĐỒ TRÒN (Pie Chart)
  Widget _buildStatsChart() {
    return StreamBuilder<List<PantryItem>>(
      stream: _pantryService.getPantryItems(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return SizedBox(height: 50, child: Center(child: Text(_t('no_data_stats'))));
        }

        final items = snapshot.data!;
        Map<String, int> counts = {};
        
        // Đếm số lượng theo loại
        for (var item in items) {
          String type = (item.type ?? 'other').toLowerCase();
          counts[type] = (counts[type] ?? 0) + 1;
        }

        // Tạo dữ liệu biểu đồ
        List<PieChartSectionData> sections = [];
        final List<Color> colors = [
          Colors.redAccent, Colors.blueAccent, Colors.green, 
          Colors.orange, Colors.purple, Colors.brown, Colors.grey
        ];
        
        int i = 0;
        counts.forEach((key, value) {
          final categoryName = _getCategoryName(key);
          sections.add(PieChartSectionData(
            color: colors[i % colors.length],
            value: value.toDouble(),
            title: '$categoryName\n$value',
            radius: 60,
            titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
          ));
          i++;
        });

        return Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
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
          title: Text(_t('filter_expiring'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
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
                  selectedColor: const Color(0xFF8FBC8F),
                  labelStyle: TextStyle(color: _selectedCategory == key ? Colors.white : Colors.black),
                  onSelected: (sel) => setState(() => _selectedCategory = sel ? key : 'all'),
                ),
              );
            }).toList(),
          ),
        )
      ],
    );
  }

  Widget _buildPantryList() {
    return StreamBuilder<List<PantryItem>>(
      stream: _pantryService.getPantryItems(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text(_t('empty_pantry')));
        }

        // --- FILTER LOGIC (Category + Expiring + Search) ---
        final filteredItems = snapshot.data!.where((item) {
          // 1. Filter Category
          final itemType = (item.type ?? 'other').trim().toLowerCase();
          if (_selectedCategory != 'all' && itemType != _selectedCategory) {
            return false;
          }
          // 2. Filter Expiring
          if (_showExpiringSoonOnly && !item.isExpiringSoon && !item.isExpired) {
            return false;
          }
          // 3. Filter Search Text
          if (_searchText.isNotEmpty) {
            if (!item.name.toLowerCase().contains(_searchText.toLowerCase())) {
              return false;
            }
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
            Color color = Colors.green;
            if (item.isExpired) {
              color = Colors.red;
            } else if (item.isExpiringSoon) {
              color = Colors.orange;
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(Icons.eco, color: color, size: 30),
                title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${item.quantity} ${item.unit} • ${item.daysUntilExpiry} ${_t('days')} ${_t('left')}'),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) => v == 'delete' ? _pantryService.deleteItem(item.id) : _showEditPantryDialog(item),
                  itemBuilder: (context) => [
                    PopupMenuItem(value: 'edit', child: Text(_t('edit'))),
                    PopupMenuItem(value: 'delete', child: Text(_t('delete'), style: const TextStyle(color: Colors.red))),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInputButton(IconData icon, String label, ImageSource source) {
    return ElevatedButton(
      onPressed: () => _pickImage(source),
      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
      child: Column(children: [Icon(icon), Text(label, style: const TextStyle(fontSize: 12))]),
    );
  }

  Widget _buildActionButton(String label, VoidCallback? onPressed) {
    return ElevatedButton(
      onPressed: _isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE9967A), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
      child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _buildFreshnessCard() {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_t('result')}: ${_freshnessResult!['status']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('${_t('item')}: ${_freshnessResult!['name']}'),
            Text('${_t('expiry_label')}: ${_freshnessResult!['days_left']} ${_t('days')}'),
            const Divider(),
            Text('${_freshnessResult!['advice']}'),
          ],
        ),
      ),
    );
  }

  // --- BACKUP / RESTORE LOGIC ---
  void _showBackupOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.upload_file, color: Color(0xFF8FBC8F)),
            title: Text(_t('export')),
            subtitle: Text(_t('export_subtitle')),
            onTap: () async {
              Navigator.pop(context);
              final json = await _pantryService.exportData();
              if (mounted) _showExportDialog(json);
            },
          ),
          ListTile(
            leading: const Icon(Icons.download, color: Colors.blue),
            title: Text(_t('import')),
            subtitle: Text(_t('import_subtitle')),
            onTap: () {
              Navigator.pop(context);
              _showImportDialog();
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showExportDialog(String json) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('json_data_title')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_t('copy_instruction')),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.grey[200],
                child: SelectableText(json, style: const TextStyle(fontFamily: 'monospace', fontSize: 10)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(_t('close'))),
          ElevatedButton.icon(
            icon: const Icon(Icons.copy),
            label: Text(_t('copy')),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: json));
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('copied'))));
              }
            },
          ),
        ],
      ),
    );
  }

  void _showImportDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('import_title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_t('paste_instruction')),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              maxLines: 5,
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '{"pantry": ...}'),
              style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(_t('cancel'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              try {
                if (controller.text.isEmpty) return;
                await _pantryService.importData(controller.text);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('import_success'))));
                }
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: Text(_t('import_now')),
          ),
        ],
      ),
    );
  }

  // --- CÁC DANH SÁCH KHÁC ---

  Widget _buildSavedReceiptsList() {
    return StreamBuilder<List<SavedReceipt>>(
      stream: _pantryService.getSavedReceipts(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) return Center(child: Text(_t('empty_receipts')));
        return Column(
          children: snapshot.data!.map((receipt) {
            return Card(
              child: ListTile(
                leading: const Icon(Icons.receipt),
                title: Text(receipt.displayText),
                trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _pantryService.deleteSavedReceipt(receipt.id)),
                onTap: () => _showReceiptItemsDialog(receipt.items),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildFreshnessHistory() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _pantryService.getFreshnessHistory(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) return Center(child: Text(_t('empty_history')));
        return Column(
          children: snapshot.data!.map((data) {
            return Card(
              child: ListTile(
                title: Text(data['name'] ?? 'Unknown'),
                subtitle: Text('${_t('status')}: ${data['status']}'),
                trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _pantryService.deleteHistoryEntry(data['id'])),
                onTap: () => _moveHistoryToPantry(data),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // --- LOGIC HÀM (Pick Image, Check, Scan, Add...) ---

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
      setState(() => _error = 'Lỗi: $e');
    }
  }

  Future<void> _checkFreshness() async {
    if (_image == null) return;
    setState(() { _isLoading = true; _error = null; _freshnessResult = null; });

    try {
      final imageHash = await _generateImageHash(_image!);
      final cachedResult = await _pantryService.findFreshnessByImageHash(imageHash);

      if (cachedResult != null) {
        setState(() => _freshnessResult = cachedResult);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚡ Loaded from cache'), backgroundColor: Colors.blue));
      } else {
        final result = await _aiService.checkFreshness(_image!);
        setState(() => _freshnessResult = result);
        if (result['name'] != 'Error') {
          await _pantryService.addFreshnessHistory(result, imageHash: imageHash);
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
    setState(() { _isLoading = true; _error = null; });

    try {
      final imageHash = await _generateImageHash(_image!);
      final cachedReceipt = await _pantryService.findReceiptByImageHash(imageHash);

      if (cachedReceipt != null) {
        if (mounted) _showReceiptItemsDialog(cachedReceipt.items);
      } else {
        final result = await _aiService.scanReceipt(_image!);
        if (result.isNotEmpty && mounted) {
          await _pantryService.saveScannedReceipt(result, imageName: _image!.name, imageHash: imageHash);
          _showReceiptItemsDialog(result);
        }
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _moveHistoryToPantry(Map<String, dynamic> data) async {
    await _pantryService.createPantryItem(
      name: data['name'],
      quantity: 1,
      expiryDate: DateTime.now().add(Duration(days: data['days_left'] ?? 0)),
      unit: 'piece',
      notes: '${_t('history_title')}: ${data['advice']}',
    );
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('add_success'))));
  }

  // --- DIALOGS (Add, Edit, Receipt) ---

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
                    TextField(controller: _nameController, decoration: InputDecoration(labelText: _t('name_label'))),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: _quantityController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: _t('qty_label')))),
                        const SizedBox(width: 12),
                        SizedBox(width: 100, child: TextField(controller: _unitController, decoration: InputDecoration(labelText: _t('unit_label')))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: _selectedExpiryDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (pickedDate != null) setDialogState(() => _selectedExpiryDate = pickedDate);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('${_t('expiry_label')}: ${_selectedExpiryDate.toString().split(' ')[0]}'), const Icon(Icons.calendar_today)]),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: _notesController, decoration: InputDecoration(labelText: _t('notes_label')), maxLines: 2),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text(_t('cancel'))),
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
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('add_success'))));
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

  void _showReceiptItemsDialog(List<Map<String, dynamic>> items) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('receipt_details')),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                title: Text(item['name']),
                subtitle: Text('${item['quantity']} ${item['unit']}'),
                onTap: () => _showEditItemDialog(item),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(_t('close'))),
          ElevatedButton(
            onPressed: () async {
              int count = 0;
              for (final item in items) {
                final days = _safeParseInt(item['suggested_days']);
                final type = item['type'] ?? 'other';
                await _pantryService.createPantryItem(
                  name: item['name'],
                  quantity: _safeParseInt(item['quantity']),
                  expiryDate: DateTime.now().add(Duration(days: days)),
                  unit: item['unit'] ?? 'piece',
                  type: type,
                );
                await _foodExpiryService.setExpiryDays(type, days);
                count++;
              }
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_t('add_all')} $count ${_t('items')}')));
              }
            },
            child: Text(_t('add_all')),
          )
        ],
      ),
    );
  }

  void _showEditItemDialog(Map<String, dynamic> item) {
    final nameC = TextEditingController(text: item['name']);
    final qtyC = TextEditingController(text: '${item['quantity'] ?? 1}');
    final unitC = TextEditingController(text: item['unit'] ?? 'piece');
    final daysC = TextEditingController(text: '${item['suggested_days'] ?? 5}');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('edit')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameC, decoration: InputDecoration(labelText: _t('name_label'))),
            TextField(controller: qtyC, decoration: InputDecoration(labelText: _t('qty_label'))),
            TextField(controller: unitC, decoration: InputDecoration(labelText: _t('unit_label'))),
            TextField(controller: daysC, decoration: InputDecoration(labelText: _t('expiry_label'))),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              final type = item['type'] ?? 'other';
              final days = int.tryParse(daysC.text) ?? 5;
              await _pantryService.createPantryItem(
                name: nameC.text,
                quantity: int.tryParse(qtyC.text) ?? 1,
                unit: unitC.text,
                expiryDate: DateTime.now().add(Duration(days: days)),
                type: type,
              );
              await _foodExpiryService.setExpiryDays(type, days);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('add_success'))));
              }
            },
            child: Text(_t('add')),
          )
        ],
      ),
    );
  }

  void _showEditPantryDialog(PantryItem item) {
    final nameC = TextEditingController(text: item.name);
    final qtyC = TextEditingController(text: '${item.quantity}');
    final unitC = TextEditingController(text: item.unit);
    final notesC = TextEditingController(text: item.notes);
    DateTime selectedDate = item.expiryDate;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSt) => AlertDialog(
          title: Text(_t('edit')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameC, decoration: InputDecoration(labelText: _t('name_label'))),
              TextField(controller: qtyC, decoration: InputDecoration(labelText: _t('qty_label'))),
              TextField(controller: unitC, decoration: InputDecoration(labelText: _t('unit_label'))),
              TextField(controller: notesC, decoration: InputDecoration(labelText: _t('notes_label'))),
              ElevatedButton(
                onPressed: () async {
                  final d = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime.now(), lastDate: DateTime(2030));
                  if (d != null) setSt(() => selectedDate = d);
                },
                child: Text('${_t('expiry_label')}: ${selectedDate.toString().split(' ')[0]}'),
              )
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
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('update_success'))));
                }
              },
              child: Text(_t('update')),
            )
          ],
        ),
      ),
    );
  }
}