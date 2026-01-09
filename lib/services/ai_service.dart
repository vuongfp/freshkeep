import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';

class AiService {
  GenerativeModel? _model;
  
  // Khởi tạo: Lấy API Key từ biến môi trường lúc build
  void initialize() {
    // Lấy key từ lệnh build: --dart-define=GOOGLE_AI_API_KEY=...
    const apiKey = String.fromEnvironment('GOOGLE_AI_API_KEY');
    
    if (apiKey.isNotEmpty) {
      _model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: apiKey,
      );
    } else {
      print("⚠️ CẢNH BÁO: Không tìm thấy API Key! Hãy build với --dart-define=GOOGLE_AI_API_KEY=...");
    }
  }

  // Kiểm tra xem đã có Key chưa
  bool get hasKey => _model != null;

  // Hàm Check Freshness
  Future<Map<String, dynamic>> checkFreshness(XFile image) async {
    if (_model == null) initialize(); 
    if (_model == null) return {"name": "Lỗi", "status": "Error", "days_left": 0, "advice": "Thiếu API Key (Build-time)!"};

    try {
      final imageBytes = await image.readAsBytes();
      final prompt = Content.text("Analyze produce. JSON only: name_en, name_vn, status (TƯƠI/HỎNG), days_left (int), advice_en, advice_vn.");
      final imagePart = Content.data('image/jpeg', imageBytes); 

      final response = await _model!.generateContent([prompt, imagePart]);
      final text = response.text;
      if (text == null) throw Exception('No response');

      final json = jsonDecode(text.replaceAll(RegExp(r'```json|```'), '').trim());

      return {
        "name": "${json['name_en']} (${json['name_vn']})",
        "status": json['status'], 
        "days_left": json['days_left'],
        "advice": "🇬🇧 ${json['advice_en']}\n🇻🇳 ${json['advice_vn']}"
      };
    } catch (e) {
      return {"name": "Lỗi", "status": "Unknown", "days_left": 0, "advice": "$e"};
    }
  }

  // Hàm Scan Receipt
  Future<List<Map<String, dynamic>>> scanReceipt(XFile image) async {
    if (_model == null) initialize();
    if (_model == null) return [];

    try {
      final imageBytes = await image.readAsBytes();
      final prompt = Content.text("""OCR receipt. JSON ARRAY: name_en, name_vn, quantity, unit, suggested_days (int), type. No markdown.""");
      final imagePart = Content.data('image/jpeg', imageBytes);

      final response = await _model!.generateContent([prompt, imagePart]);
      final text = response.text;
      if (text == null) throw Exception('No response');

      final List<dynamic> parsed = jsonDecode(text.replaceAll(RegExp(r'```json|```'), '').trim());
      
      return parsed.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        String name = map['name_en'] ?? 'Unknown';
        if (map['name_vn'] != null) name += " / ${map['name_vn']}";
        return {
          'name': name,
          'quantity': map['quantity'],
          'unit': map['unit'],
          'suggested_days': map['suggested_days'],
          'type': map['type'],
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }
}