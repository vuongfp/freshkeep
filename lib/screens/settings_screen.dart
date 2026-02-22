import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  final bool isVietnamese;
  const SettingsScreen({super.key, required this.isVietnamese});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _keyController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _settings = SettingsService.instance;

  bool _hasKey = false;
  bool _obscure = true;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final has = await _settings.hasCustomApiKey();
    setState(() {
      _hasKey = has;
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);
    await _settings.saveApiKey(_keyController.text);
    _keyController.clear();
    setState(() {
      _hasKey = true;
      _isSaving = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isVietnamese
                ? '✅ Đã lưu API Key thành công!'
                : '✅ API Key saved successfully!',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _clear() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(widget.isVietnamese ? 'Xác nhận' : 'Confirm'),
        content: Text(
          widget.isVietnamese
              ? 'Xóa API Key tùy chỉnh? App sẽ dùng key mặc định từ server.'
              : 'Remove custom API Key? App will use the server default key.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(widget.isVietnamese ? 'Hủy' : 'Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              widget.isVietnamese ? 'Xóa' : 'Remove',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _settings.clearApiKey();
      setState(() => _hasKey = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isVietnamese
                  ? 'Đã xóa API Key tùy chỉnh'
                  : 'Custom API Key removed',
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool vn = widget.isVietnamese;
    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      appBar: AppBar(
        title: Text(vn ? 'Cài đặt' : 'Settings'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Section Header ---
                  _sectionHeader(
                    Icons.key,
                    vn ? 'Gemini API Key' : 'Gemini API Key',
                  ),
                  const SizedBox(height: 12),

                  // --- Current Status Card ---
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            _hasKey ? Icons.check_circle : Icons.info_outline,
                            color: _hasKey ? Colors.green : Colors.orange,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _hasKey
                                      ? (vn
                                            ? 'Đang dùng API Key tùy chỉnh'
                                            : 'Using custom API Key')
                                      : (vn
                                            ? 'Đang dùng API Key mặc định (server)'
                                            : 'Using default server API Key'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (_hasKey)
                                  Text(
                                    vn
                                        ? 'Key hiện tại: ••••••••••••••••••••'
                                        : 'Current key: ••••••••••••••••••••',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (_hasKey)
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              tooltip: vn ? 'Xóa key' : 'Remove key',
                              onPressed: _clear,
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // --- Update Key Form ---
                  Text(
                    _hasKey
                        ? (vn ? 'Thay đổi API Key:' : 'Update API Key:')
                        : (vn
                              ? 'Nhập API Key tùy chỉnh:'
                              : 'Enter custom API Key:'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Form(
                    key: _formKey,
                    child: TextFormField(
                      controller: _keyController,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        hintText: vn
                            ? 'Dán API Key vào đây...'
                            : 'Paste your API Key here...',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: const Icon(
                          Icons.vpn_key_outlined,
                          color: Color(0xFF2E7D32),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return vn
                              ? 'Vui lòng nhập API Key'
                              : 'Please enter an API Key';
                        }
                        if (v.trim().length < 20) {
                          return vn
                              ? 'API Key không hợp lệ (quá ngắn)'
                              : 'Invalid API Key (too short)';
                        }
                        return null;
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save),
                      label: Text(vn ? 'Lưu API Key' : 'Save API Key'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // --- Info Box ---
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Colors.blue,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            vn
                                ? 'API Key được lưu an toàn trên thiết bị. Bạn không thể xem lại key đã lưu vì lý do bảo mật. Lấy key tại: aistudio.google.com'
                                : 'API Key is stored securely on your device. For security reasons, you cannot view a saved key. Get your key at: aistudio.google.com',
                            style: TextStyle(
                              color: Colors.blue[800],
                              fontSize: 13,
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

  Widget _sectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF2E7D32), size: 22),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1B5E20),
          ),
        ),
      ],
    );
  }
}
