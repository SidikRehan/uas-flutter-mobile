import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth/login_page.dart'; // Pastikan import ini benar

class DokterProfilePage extends StatefulWidget {
  const DokterProfilePage({super.key});

  @override
  State<DokterProfilePage> createState() => _DokterProfilePageState();
}

class _DokterProfilePageState extends State<DokterProfilePage> {
  User? user = FirebaseAuth.instance.currentUser;
  String nama = "Loading...";
  String email = "";
  String poli = "-";
  String hari = "-";
  String jam = "-";

  @override
  void initState() {
    super.initState();
    _getDokterData();
  }

  void _getDokterData() async {
    if (user != null) {
      setState(() => email = user!.email ?? "-");
      
      try {
        var doc = await FirebaseFirestore.instance.collection('doctors').doc(user!.uid).get();
        if (doc.exists) {
          var data = doc.data()!;
          setState(() {
            nama = data['Nama'] ?? "Dokter";
            poli = data['Poli'] ?? "-";
            
            // Format Jadwal
            if (data['hari_kerja'] is List) {
               hari = (data['hari_kerja'] as List).join(', ');
            } else {
               hari = data['Hari'] ?? '-';
            }
            
            if (data['jam_buka'] != null) {
               jam = "${data['jam_buka']} - ${data['jam_tutup']}";
            } else {
               jam = data['Jam'] ?? '-';
            }
          });
        }
      } catch (e) {
        print("Error: $e");
      }
    }
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      // Kembali ke Halaman Login & Hapus semua history navigasi (agar tidak bisa back)
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (Route<dynamic> route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Profil Saya"), automaticallyImplyLeading: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Foto Profil
            const CircleAvatar(
              radius: 60,
              backgroundColor: Colors.blue,
              child: Icon(Icons.person, size: 60, color: Colors.white),
            ),
            const SizedBox(height: 20),
            
            // Nama & Poli
            Text(nama, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            Text("Spesialis $poli", style: const TextStyle(fontSize: 16, color: Colors.grey)),
            
            const SizedBox(height: 30),

            // Info Detail
            Card(
              child: Padding(
                padding: const EdgeInsets.all(15.0),
                child: Column(
                  children: [
                    _buildRow(Icons.email, "Email", email),
                    const Divider(),
                    _buildRow(Icons.calendar_today, "Hari Praktik", hari),
                    const Divider(),
                    _buildRow(Icons.access_time, "Jam Praktik", jam),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),

            // TOMBOL LOGOUT
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, // Merah tanda keluar
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _logout,
                icon: const Icon(Icons.logout),
                label: const Text("KELUAR APLIKASI", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              ],
            ),
          )
        ],
      ),
    );
  }
}