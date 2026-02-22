import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/home_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyDs6GZBnrx6PgLV8pVRnsvrL8O-herrrsM",
        authDomain: "freshkeep-db.firebaseapp.com",
        projectId: "freshkeep-db",
        storageBucket: "freshkeep-db.firebasestorage.app",
        messagingSenderId: "770138586262",
        appId: "1:770138586262:web:19a42593ecfbc7342996b7",
        measurementId: "G-B7FP7TL4JG",
      ),
    );
  } else {
    await Firebase.initializeApp();
  }
  // Load environment variables (API Key)
  await dotenv.load();
  runApp(const FreshKeepApp());
}

class FreshKeepApp extends StatelessWidget {
  const FreshKeepApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FreshKeep',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // --- BỘ MÀU FRESHPICK ---
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32), // Xanh lá đậm
          primary: const Color(0xFF2E7D32),
          secondary: const Color(0xFFFF8F00), // Cam nhấn
          surface: const Color(0xFFF1F8E9), // Nền xanh nhạt dịu mắt
          error: const Color(0xFFD32F2F),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF1F8E9),
        fontFamily: 'PT Sans', // Giữ font của bạn
        
        // --- ĐÃ XÓA cardTheme ĐỂ TRÁNH LỖI TYPE MISMATCH ---
        
        // Style cho Nút bấm mới
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}