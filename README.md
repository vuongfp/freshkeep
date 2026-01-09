# freshkeep

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
flutter build apk --dart-define=GOOGLE_AI_API_KEY=YOUR_REAL_API_KEY

Ví dụ cụ thể:
```bash
flutter clean
flutter pub get
flutter build apk --dart-define=GOOGLE_AI_API_KEY=

Khi cài đặt file APK này lên điện thoại, ứng dụng sẽ tự động có API Key và có thể gọi Gemini ngay lập tức mà không cần màn hình nhập key.