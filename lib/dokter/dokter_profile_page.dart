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
        var doc = await FirebaseFirestore.instance
            .collection('doctors')
            .doc(user!.uid)
            .get();
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
        // print("Error: $e");
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
      backgroundColor: const Color(0xFFF8F9FA), // Clean Background
      body: SingleChildScrollView(
        child: Column(
          children: [
            // HEADER GRADIENT
            Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 240,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0077B6), Color(0xFF00B4D8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(32),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -50,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const CircleAvatar(
                      radius: 60,
                      backgroundColor: Color(0xFF0077B6),
                      child: Icon(Icons.person, size: 60, color: Colors.white),
                    ),
                  ),
                ),
                Positioned(
                  top: 50,
                  right: 20,
                  child: IconButton(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout_rounded, color: Colors.white),
                    tooltip: "Keluar Aplikasi",
                  ),
                ),
              ],
            ),

            const SizedBox(height: 60),

            // NAMA & POLI
            Text(
              nama,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF03045E),
              ),
              textAlign: TextAlign.center,
            ),
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "Spesialis $poli",
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF0077B6),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 30),

            // INFO DETAIL CARD
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildRow(Icons.email_outlined, "Email", email),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(height: 1),
                    ),
                    _buildRow(
                      Icons.calendar_month_outlined,
                      "Hari Praktik",
                      hari,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(height: 1),
                    ),
                    _buildRow(Icons.access_time_rounded, "Jam Praktik", jam),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            // TOMBOL LOGOUT BIG
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.red,
                    elevation: 0,
                    side: BorderSide(color: Colors.red.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _logout,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text(
                    "KELUAR APLIKASI",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFF0077B6), size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF03045E),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
