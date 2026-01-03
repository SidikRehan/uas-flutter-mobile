import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth/login_page.dart'; // Import buat logout

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Variabel penampung data
  String _nama = "Loading...";
  String _email = "Loading...";
  String _nik = "-";
  String _role = "-";

  @override
  void initState() {
    super.initState();
    _ambilDataProfil();
  }

  // Fungsi Detektif: Mengambil data dari 2 tempat (Users & Pasiens)
  void _ambilDataProfil() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // 1. Ambil data dasar dari 'users' (Email & Role)
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      // 2. Ambil data detail dari 'pasiens' (NIK & Nama Lengkap)
      DocumentSnapshot pasienDoc = await FirebaseFirestore.instance
          .collection('pasiens')
          .doc(user.uid)
          .get();

      if (mounted) {
        setState(() {
          _email = userDoc['email'] ?? "-";
          _role = userDoc['role'] ?? "-";
          
          // Kalau ada data di koleksi pasiens, pakai itu. Kalau gak ada, pakai data users.
          if (pasienDoc.exists) {
            _nama = pasienDoc['nama'] ?? userDoc['nama'];
            _nik = pasienDoc['nik'] ?? "-";
          } else {
            _nama = userDoc['nama'] ?? "User";
          }
        });
      }
    } catch (e) {
      print("Gagal ambil data: $e");
    }
  }

  // Fungsi Logout
  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profil Saya"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // --- FOTO PROFIL (Avatar) ---
            const Center(
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Colors.blueAccent,
                child: Icon(Icons.person, size: 60, color: Colors.white),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _nama,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text(
              "Pasien RS Sehat Sentosa",
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 30),

            // --- KARTU INFORMASI ---
            _buildInfoCard(Icons.email, "Email", _email),
            _buildInfoCard(Icons.credit_card, "NIK (KTP)", _nik),
            _buildInfoCard(Icons.admin_panel_settings, "Status Akun", _role.toUpperCase()),

            const SizedBox(height: 40),

            // --- TOMBOL LOGOUT ---
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout),
                label: const Text("KELUAR / LOGOUT"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget kecil untuk bikin kartu biar kodingan rapi
  Widget _buildInfoCard(IconData icon, String judul, String isi) {
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(judul, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        subtitle: Text(isi, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
      ),
    );
  }
}