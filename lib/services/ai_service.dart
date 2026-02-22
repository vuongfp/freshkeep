import 'package:cloud_functions/cloud_functions.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'settings_service.dart';

class AiService {
  final _settings = SettingsService.instance;

  // Determine the active API key: custom (from settings) > server-side (Cloud Function)
  Future<String?> _getCustomApiKey() async {
    if (await _settings.hasCustomApiKey()) {
      return await _settings.getApiKey();
    }
    return null;
  }

  // --- CHECK FRESHNESS ---
  Future<Map<String, dynamic>> checkFreshness(XFile image) async {
    final imageBytes = await image.readAsBytes();
    final base64Image = base64Encode(imageBytes);
    final customKey = await _getCustomApiKey();

    if (customKey != null) {
      // Call Gemini directly with custom key
      return await _callGeminiDirect(
        imageBytes,
        base64Image,
        customKey,
        'freshness',
      );
    }

    // Fallback: Cloud Function (server-side key)
    final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
      'analyzeImage',
    );
    final result = await callable.call(<String, dynamic>{'image': base64Image});
    if (result.data is Map) {
      return Map<String, dynamic>.from(result.data as Map);
    }
    throw Exception(
      'Invalid response format from Cloud Function (analyzeImage)',
    );
  }

  // --- SCAN RECEIPT ---
  Future<List<Map<String, dynamic>>> scanReceipt(XFile image) async {
    final imageBytes = await image.readAsBytes();
    final base64Image = base64Encode(imageBytes);
    final customKey = await _getCustomApiKey();

    if (customKey != null) {
      final result = await _callGeminiDirect(
        imageBytes,
        base64Image,
        customKey,
        'receipt',
      );
      final items = result['items'];
      if (items is List) {
        return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    }

    // Fallback: Cloud Function (server-side key)
    final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
      'scanReceipt',
    );
    final result = await callable.call(<String, dynamic>{'image': base64Image});
    if (result.data is List) {
      return (result.data as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    throw Exception(
      'Invalid response format from Cloud Function (scanReceipt)',
    );
  }

  // --- DIRECT GEMINI CALL (with custom API key) ---
  Future<Map<String, dynamic>> _callGeminiDirect(
    Uint8List imageBytes,
    String base64Image,
    String apiKey,
    String mode,
  ) async {
    String mimeType = 'image/jpeg';
    if (base64Image.startsWith('iVBORw0KGgo'))
      mimeType = 'image/png';
    else if (base64Image.startsWith('UklGR'))
      mimeType = 'image/webp';

    final String prompt = mode == 'freshness'
        ? '''Analyze this food image. Return ONLY a JSON object (no markdown):
{"name_en":"string","name_vn":"string","status":"Fresh|Warning|Bad","days_left":int,"advice_en":"string","advice_vn":"string"}'''
        : '''OCR this receipt. Return ONLY a JSON array (no markdown):
[{"name_en":"string","name_vn":"string","quantity":int,"unit":"string","suggested_days":int,"type":"meat|seafood|vegetable|fruit|dairy|other"}]''';

    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey';

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt},
              {
                'inlineData': {'mimeType': mimeType, 'data': base64Image},
              },
            ],
          },
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Gemini API error ${response.statusCode}: ${response.body}',
      );
    }

    final data = jsonDecode(response.body);
    final text =
        data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
    final cleanText = text.replaceAll(RegExp(r'```json|```'), '').trim();

    if (mode == 'freshness') {
      final json = jsonDecode(cleanText);
      final j = json is List ? (json.isNotEmpty ? json[0] : {}) : json;
      return {
        'name': j['name_en'] ?? 'Unknown',
        'name_vn': j['name_vn'] ?? '',
        'status': j['status'] ?? 'Unknown',
        'days_left': j['days_left'] ?? 0,
        'advice_en': j['advice_en'] ?? 'No advice',
        'advice_vn': j['advice_vn'] ?? '',
      };
    } else {
      final parsed = jsonDecode(cleanText);
      final list = parsed is List ? parsed : [];
      return {'items': list};
    }
  }
}
