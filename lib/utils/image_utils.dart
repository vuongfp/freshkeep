import 'package:crypto/crypto.dart';

/// Compute SHA256 hash of image bytes
String computeImageHash(List<int> imageBytes) {
  return sha256.convert(imageBytes).toString();
}