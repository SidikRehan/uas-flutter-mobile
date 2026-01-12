import 'dart:io'; 
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart'; 
import 'package:firebase_storage/firebase_storage.dart'; 
import 'auth/login_page.dart'; 

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _nama = "Loading...";
  String _email = "Loading...";
  String _nik = "-";
  String _role = "-";
  String _bpjs = "-";
  String _fotoUrl = ""; 

  @override
  void initState() {
    super.initState();
    _ambilDataProfil();
  }

  // --- FUNGSI AMBIL DATA (YANG SUDAH DIPERBAIKI) ---
  void _ambilDataProfil() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // 1. Ambil Dokumen dari Database
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      DocumentSnapshot pasienDoc = await FirebaseFirestore.instance.collection('pasiens').doc(user.uid).get();

      // 2. CEK APAKAH DATANYA ADA? (PENTING BIAR GAK LOADING TERUS)
      if (!userDoc.exists) {
        if (mounted) {
          setState(() {
            _nama = "Data Tidak Ditemukan";
            _email = user.email ?? "-";
            _role = "Akun Lama / Error";
          });
        }
        return;
      }

      // 3. Konversi Data agar Aman
      var userData = userDoc.data() as Map<String, dynamic>;

      if (mounted) {
        setState(() {
          _email = userData['email'] ?? "-";
          _role = userData['role'] ?? "-";
          _bpjs = userData['nomor_bpjs'] ?? "";
          _fotoUrl = userData['foto_url'] ?? ""; 

          // Cek Data Detail Pasien
          if (pasienDoc.exists) {
            var pasienData = pasienDoc.data() as Map<String, dynamic>;
            _nama = pasienData['nama'] ?? userData['nama'] ?? "User";
            _nik = pasienData['nik'] ?? "-";
          } else {
            // Kalau data pasien detail gak ada, pakai nama dari user akun
            _nama = userData['nama'] ?? "User";
          }
        });
      }
    } catch (e) {
      print("Error ambil profil: $e");
      if (mounted) {
        setState(() {
          _nama = "Error Koneksi";
        });
      }
    }
  }

  // --- FUNGSI GANTI FOTO ---
  Future<void> _gantiFoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);

    if (pickedFile != null) {
      User? user = FirebaseAuth.instance.currentUser;
      File file = File(pickedFile.path);

      try {
        // Tampilkan Loading indikator sederhana lewat SnackBar
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sedang mengupload foto...")));

        // 1. Upload ke Firebase Storage
        String path = 'foto_profil/${user!.uid}.jpg';
        TaskSnapshot snapshot = await FirebaseStorage.instance.ref().child(path).putFile(file);
        
        // 2. Ambil Link Download (URL)
        String downloadUrl = await snapshot.ref.getDownloadURL();

        // 3. Simpan URL ke Firestore
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'foto_url': downloadUrl,
        });

        // 4. Update Tampilan
        setState(() {
          _fotoUrl = downloadUrl;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Foto berhasil diupdate!")));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal upload: $e")));
        }
      }
    }
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context, 
        MaterialPageRoute(builder: (context) => const LoginPage()), 
        (route) => false
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isBpjs = _bpjs.isNotEmpty && _bpjs != "-";

    return Scaffold(
      appBar: AppBar(title: const Text("Profil Saya"), backgroundColor: Colors.blue, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // --- AVATAR DENGAN TOMBOL EDIT ---
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: _fotoUrl.isNotEmpty ? NetworkImage(_fotoUrl) : null,
                    child: _fotoUrl.isEmpty 
                      ? const Icon(Icons.person, size: 60, color: Colors.grey) 
                      : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: InkWell(
                      onTap: _gantiFoto, 
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      ),
                    ),
                  )
                ],
              ),
            ),
            
            const SizedBox(height: 15),
            Text(_nama, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            Text("Pasien RS Sehat Sentosa", style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 30),

            _buildInfoCard(Icons.email, "Email", _email),
            _buildInfoCard(Icons.credit_card, "NIK (KTP)", _nik),
            
            // Kartu BPJS
            Card(
              elevation: 2,
              color: isBpjs ? Colors.green[50] : Colors.blue[50],
              child: ListTile(
                leading: Icon(Icons.health_and_safety, color: isBpjs ? Colors.green : Colors.blue),
                title: Text(isBpjs ? "Pasien BPJS" : "Pasien Regular", style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(isBpjs ? "No: $_bpjs" : "Pembayaran Pribadi"),
              ),
            ),
            
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity, 
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _logout, 
                icon: const Icon(Icons.logout), 
                label: const Text("KELUAR"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String judul, String isi) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(judul, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        subtitle: Text(isi, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}