import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
// 1. TAMBAH IMPORT INI (WAJIB ADA)
import 'package:intl/date_symbol_data_local.dart';

import 'auth/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- BAGIAN KONEKSI FIREBASE (User Anda) ---
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyCIASyD8HejXiBLEUQC2DMY2_Ux4xGke0o",
        authDomain: "rs-app-belajar.firebaseapp.com",
        projectId: "rs-app-belajar",
        storageBucket: "rs-app-belajar.firebasestorage.app",
        messagingSenderId: "824513239332",
        appId: "1:824513239332:web:b371353c76cd7fa914fbb1",
      ),
    );
  } else {
    // Untuk Android (otomatis baca google-services.json)
    await Firebase.initializeApp();
  }

  // 2. TAMBAHKAN KODE INI (SOLUSI ERROR MERAH)
  // Ini menyiapkan format tanggal Indonesia ('id_ID') sebelum aplikasi jalan
  await initializeDateFormatting('id_ID', null);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Rumah Sakit App',
      // --- TEMA MODERN ("KECE") ---
      theme: ThemeData(
        useMaterial3: true,
        fontFamily:
            'Poppins', // Opsional: Pastikan font sudah didaftarkan di pubspec.yaml jika ingin dipakai
        // 1. Skema Warna (Medical Blue & Soft Cyan)
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0077B6), // Deep Blue
          primary: const Color(0xFF0077B6),
          secondary: const Color(0xFF00B4D8), // Cyan Blue
          surface: const Color(0xFFF8F9FA), // White Grey (Modern Background)
          error: const Color(0xFFEF233C),
        ),

        // 2. AppBar Modern (Flat & Clean)
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: Colors
              .transparent, // Transparan agar menyatu dengan background body
          elevation: 0,
          scrolledUnderElevation: 2, // Bayangan halus saat dicroll
          titleTextStyle: TextStyle(
            color: Color(0xFF023E8A),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
          iconTheme: IconThemeData(color: Color(0xFF023E8A)),
        ),

        // 3. Card Modern (Rounded & Soft Shadow)
        cardTheme: const CardThemeData(
          elevation: 4,
          color: Colors.white,
          surfaceTintColor: Colors.white, // Material 3 fix
          margin: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),

        // 4. Input Modern (Filled & Rounded)
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF0077B6), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),

        // 5. Button Modern (Tinggi & Rounded)
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0077B6),
            foregroundColor: Colors.white,
            elevation: 3,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
      home: const LoginPage(),
    );
  }
}
