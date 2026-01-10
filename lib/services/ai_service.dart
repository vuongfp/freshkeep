import 'package:cloud_functions/cloud_functions.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';

class AiService {
  // Gọi Cloud Function analyzeImage
  Future<Map<String, dynamic>> checkFreshness(XFile image) async {
    final imageBytes = await image.readAsBytes();
    final base64Image = base64Encode(imageBytes);
    final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('analyzeImage');
    final result = await callable.call(<String, dynamic>{
      'image': base64Image,
    });
    if (result.data is Map) {
      return Map<String, dynamic>.from(result.data as Map);
    } else {
      throw Exception('Invalid response format from Cloud Function (analyzeImage)');
    }
  }

  // Gọi Cloud Function scanReceipt
  Future<List<Map<String, dynamic>>> scanReceipt(XFile image) async {
    final imageBytes = await image.readAsBytes();
    final base64Image = base64Encode(imageBytes);
    final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('scanReceipt');
    final result = await callable.call(<String, dynamic>{
      'image': base64Image,
    });
    if (result.data is List) {
      return (result.data as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } else {
      throw Exception('Invalid response format from Cloud Function (scanReceipt)');
    }
  }
}