import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 1. Buat bikin akun
import 'package:cloud_firestore/cloud_firestore.dart'; // 2. Buat simpan biodata

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _namaController = TextEditingController();
  final _nikController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Loading state (biar tombol muter-muter pas lagi proses)
  bool _isLoading = false;

  // Fungsi untuk Mendaftar
  Future<void> _registerUser() async {
    // 1. Cek dulu apakah kolom diisi semua?
    if (_namaController.text.isEmpty ||
        _nikController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Semua kolom wajib diisi!")),
      );
      return;
    }

    setState(() {
      _isLoading = true; // Mulai loading
    });

    try {
      // 2. Bikin Akun di Firebase Auth (Email & Password)
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Ambil ID Unik (UID) yang baru dibuat
      String uid = userCredential.user!.uid;

      // 3. Simpan Biodata Pasien ke Firestore Database
      // Kita simpan di koleksi 'users' (sesuai diagrammu)
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'nama': _namaController.text,
        'email': _emailController.text,
        'role': 'pasien', // PENTING: Menandai ini adalah Pasien
        'created_at': DateTime.now().toIso8601String(),
      });

      // Simpan data detail khusus pasien (NIK, dll) di koleksi 'pasiens'
      await FirebaseFirestore.instance.collection('pasiens').doc(uid).set({
        'uid': uid,
        'nik': _nikController.text,
        'nama': _namaController.text,
        'riwayat_alergi': '-', // Default dulu
      });

      // 4. Kalau berhasil, kasih tahu user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Registrasi Berhasil! Silahkan Login.")),
        );
        Navigator.pop(context); // Kembali ke halaman Login
      }
    } on FirebaseAuthException catch (e) {
      // KITA TAMPILKAN KODE ERROR ASLINYA DI SINI
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal: ${e.code}\n${e.message}"), // Munculkan kode asli
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5), // Tahan 5 detik biar terbaca
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() {
        _isLoading = false; // Stop loading
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Card(
            elevation: 5,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "DAFTAR PASIEN BARU",
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                  const SizedBox(height: 30),

                  TextField(
                    controller: _namaController,
                    decoration: InputDecoration(
                        labelText: "Nama Lengkap",
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10))),
                  ),
                  const SizedBox(height: 15),

                  TextField(
                    controller: _nikController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                        labelText: "NIK (KTP)",
                        prefixIcon: const Icon(Icons.credit_card),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10))),
                  ),
                  const SizedBox(height: 15),

                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                        labelText: "Email",
                        prefixIcon: const Icon(Icons.email),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10))),
                  ),
                  const SizedBox(height: 15),

                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                        labelText: "Password",
                        prefixIcon: const Icon(Icons.lock),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10))),
                  ),
                  const SizedBox(height: 30),

                  // --- TOMBOL DAFTAR (Dengan Loading) ---
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _registerUser, // Kalau loading, tombol mati
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("DAFTAR SEKARANG",
                              style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Sudah punya akun?"),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: const Text("Login disini"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}