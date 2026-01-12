import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class DokterProfilePage extends StatefulWidget {
  const DokterProfilePage({super.key});

  @override
  State<DokterProfilePage> createState() => _DokterProfilePageState();
}

class _DokterProfilePageState extends State<DokterProfilePage> {
  final _namaCtrl = TextEditingController();
  final _poliCtrl = TextEditingController();
  final _hariCtrl = TextEditingController();
  final _jamCtrl = TextEditingController();
  
  String _fotoUrl = "";
  String _docId = ""; 
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _ambilDataDokter();
  }

  void _ambilDataDokter() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    var snapshot = await FirebaseFirestore.instance
        .collection('doctors')
        .where('uid', isEqualTo: user.uid)
        .get();

    if (snapshot.docs.isNotEmpty) {
      var doc = snapshot.docs.first;
      var data = doc.data();
      if (mounted) {
        setState(() {
          _docId = doc.id;
          _namaCtrl.text = data['Nama'] ?? data['nama'] ?? "";
          _poliCtrl.text = data['Poli'] ?? data['poli'] ?? "";
          _hariCtrl.text = data['Hari'] ?? data['hari'] ?? "";
          _jamCtrl.text = data['Jam'] ?? data['jam'] ?? "";
          _fotoUrl = data['foto_url'] ?? ""; 
          _isLoading = false;
        });
      }
    }
  }

  // --- LOGIKA SIMPAN (HANYA NAMA) ---
  void _simpanData() async {
    if (_docId.isEmpty) return;
    
    // Update ke database 'doctors'
    // KITA HAPUS UPDATE POLI, HARI, JAM DARI SINI
    await FirebaseFirestore.instance.collection('doctors').doc(_docId).update({
      'Nama': _namaCtrl.text, // Cuma Nama yang boleh diubah
    });

    // Update juga di 'users' biar sinkron namanya
    User? user = FirebaseAuth.instance.currentUser;
    await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
      'nama': _namaCtrl.text,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Nama & Gelar berhasil diperbarui!")));
    }
  }

  Future<void> _gantiFoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);

    if (pickedFile != null && _docId.isNotEmpty) {
      File file = File(pickedFile.path);
      try {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mengupload foto...")));
        
        String path = 'foto_dokter/$_docId.jpg';
        TaskSnapshot snapshot = await FirebaseStorage.instance.ref().child(path).putFile(file);
        String downloadUrl = await snapshot.ref.getDownloadURL();

        await FirebaseFirestore.instance.collection('doctors').doc(_docId).update({
          'foto_url': downloadUrl,
        });

        setState(() {
          _fotoUrl = downloadUrl;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Foto Profil Berhasil Diganti!")));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Profil Dokter"), backgroundColor: Colors.teal, foregroundColor: Colors.white),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // FOTO DOKTER
                GestureDetector(
                  onTap: _gantiFoto,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.teal[100],
                        backgroundImage: _fotoUrl.isNotEmpty ? NetworkImage(_fotoUrl) : null,
                        child: _fotoUrl.isEmpty 
                          ? const Icon(Icons.person, size: 60, color: Colors.teal) 
                          : null,
                      ),
                      Positioned(
                        bottom: 0, 
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(color: Colors.teal, shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Text("Ketuk foto untuk mengganti", style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 30),

                // FORMULIR
                // 1. NAMA (Boleh Edit)
                _buildInput("Nama & Gelar", _namaCtrl, Icons.person, isEditable: true),
                
                const Divider(height: 30),
                const Text("Informasi Praktik (Hubungi Admin untuk ubah)", style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic)),
                const SizedBox(height: 10),

                // 2. POLI, HARI, JAM (Tidak Boleh Edit / Read Only)
                _buildInput("Poli Spesialis", _poliCtrl, Icons.local_hospital, isEditable: false),
                Row(
                  children: [
                    Expanded(child: _buildInput("Hari Praktik", _hariCtrl, Icons.calendar_today, isEditable: false)),
                    const SizedBox(width: 15),
                    Expanded(child: _buildInput("Jam Praktik", _jamCtrl, Icons.access_time, isEditable: false)),
                  ],
                ),
                
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _simpanData,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                    child: const Text("SIMPAN PERUBAHAN"),
                  ),
                )
              ],
            ),
          ),
    );
  }

  // Widget Input Pintar (Bisa dikunci)
  Widget _buildInput(String label, TextEditingController ctrl, IconData icon, {required bool isEditable}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: ctrl,
        readOnly: !isEditable, // Kalau tidak editable, jadikan ReadOnly
        enabled: isEditable,   // Matikan interaksi kalau tidak editable
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: isEditable ? Colors.teal : Colors.grey),
          border: const OutlineInputBorder(),
          // Beri warna latar abu-abu jika dikunci (disabled)
          filled: !isEditable,
          fillColor: Colors.grey[200], 
        ),
      ),
    );
  }
}