import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Import halaman Dashboard masing-masing
import '../home_page.dart';        // Halaman Pasien
import '../admin/admin_home_page.dart'; // Halaman Admin (Buat sendiri ya dashboard adminnya)
import '../dokter/dokter_dashboard.dart'; // Halaman Dokter (Lihat Langkah 3)

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  void _login() async {
    setState(() => _isLoading = true);
    try {
      // 1. Login ke Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 2. Cek Role di Database Firestore
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (userDoc.exists) {
        String role = userDoc['role'] ?? 'pasien'; // Default pasien kalau gak ada role

        if (mounted) {
          // 3. Arahkan sesuai Role
          if (role == 'admin') {
             // Navigator ke Admin Home
             Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const AdminHomePage())); // Sesuaikan nama class Admin kamu
          } else if (role == 'dokter') {
             // Navigator ke Dokter Dashboard
             Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const DokterDashboard()));
          } else {
             // Navigator ke Pasien Home
             Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const HomePage()));
          }
        }
      } else {
        throw "Data user tidak ditemukan di database.";
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal Login: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Login RS Sehat", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),
            TextField(controller: _emailController, decoration: const InputDecoration(labelText: "Email", border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(labelText: "Password", border: OutlineInputBorder())),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _login,
                child: _isLoading ? const CircularProgressIndicator() : const Text("MASUK"),
              ),
            ),
            // Tambahkan tombol Register Pasien di bawah jika perlu
          ],
        ),
      ),
    );
  }
}