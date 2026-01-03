import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddDoctorPage extends StatefulWidget {
  const AddDoctorPage({super.key});

  @override
  State<AddDoctorPage> createState() => _AddDoctorPageState();
}

class _AddDoctorPageState extends State<AddDoctorPage> {
  final _formKey = GlobalKey<FormState>();

  // Controller untuk Data Tampilan (Pasien Lihat Ini)
  final _namaController = TextEditingController();
  final _hariController = TextEditingController();
  final _jamController = TextEditingController();
  
  // Controller untuk Akun Login (Dokter Pakai Ini)
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _selectedPoli;
  final List<String> _daftarPoli = [
    'Poli Umum', 'Poli Gigi', 'Poli Anak', 
    'Poli Penyakit Dalam', 'Poli Mata', 'Poli Syaraf'
  ];

  bool _isLoading = false;

  void _simpanDokter() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // LANGKAH 1: Buat Akun Dokter di Firebase Auth
      // (PENTING: Setelah ini Admin akan ter-logout otomatis oleh Firebase)
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Ambil UID (ID Unik) dari akun baru tersebut
      String uidDokterBaru = userCredential.user!.uid;

      // LANGKAH 2: Simpan Data Pribadi & Role ke collection 'users'
      // Ini supaya Dokter bisa Login dan sistem tau dia itu 'dokter'
      await FirebaseFirestore.instance.collection('users').doc(uidDokterBaru).set({
        'nama': _namaController.text,
        'email': _emailController.text,
        'role': 'dokter', // KUNCI UTAMA: ROLE DOKTER
        'uid': uidDokterBaru,
      });

      // LANGKAH 3: Simpan Data Publik ke collection 'doctors'
      // Ini supaya Pasien bisa lihat nama dokter ini di menu 'Pilih Poli'
      await FirebaseFirestore.instance.collection('doctors').add({
        'uid': uidDokterBaru, // Kita simpan UID juga biar gampang dilacak
        'Nama': _namaController.text, // Huruf Besar (Sesuai booking page)
        'nama': _namaController.text, // Huruf Kecil (Cadangan)
        'Poli': _selectedPoli,
        'Hari': _hariController.text,
        'Jam': _jamController.text,
        'created_at': DateTime.now().toString(),
      });

      if (mounted) {
        // Tampilkan pesan sukses
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text("Sukses!"),
            content: const Text(
              "Akun Dokter berhasil dibuat & Data sudah masuk ke Poli.\n\n"
              "PENTING: Karena akun baru dibuat, sesi Admin berakhir.\n"
              "Silakan Admin login ulang."
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Tutup Dialog
                  Navigator.pop(context); // Keluar Halaman
                  // Kamu bisa tambahkan navigasi ke Login Page disini
                },
                child: const Text("OK, Mengerti"),
              )
            ],
          ),
        );
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal menambah dokter: $e")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Registrasi Dokter Baru")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Data Akun (Untuk Login Dokter)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
              const SizedBox(height: 10),
              
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: "Email Dokter", border: OutlineInputBorder(), prefixIcon: Icon(Icons.email)),
                validator: (val) => val!.isEmpty ? "Email wajib diisi" : null,
              ),
              const SizedBox(height: 10),
              
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: "Password Default", border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock)),
                validator: (val) => val!.length < 6 ? "Minimal 6 karakter" : null,
              ),

              const Divider(height: 40, thickness: 2),

              const Text("Data Publik (Untuk Dilihat Pasien)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
              const SizedBox(height: 10),

              TextFormField(
                controller: _namaController,
                decoration: const InputDecoration(labelText: "Nama Lengkap & Gelar", border: OutlineInputBorder(), hintText: "Contoh: dr. Budi Santoso, Sp.A"),
                validator: (val) => val!.isEmpty ? "Nama wajib diisi" : null,
              ),
              const SizedBox(height: 10),

              DropdownButtonFormField<String>(
                value: _selectedPoli,
                decoration: const InputDecoration(labelText: "Pilih Poli", border: OutlineInputBorder()),
                items: _daftarPoli.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _selectedPoli = v),
                validator: (v) => v == null ? "Poli wajib dipilih" : null,
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: _hariController,
                decoration: const InputDecoration(labelText: "Jadwal Hari", border: OutlineInputBorder(), hintText: "Senin - Kamis"),
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: _jamController,
                decoration: const InputDecoration(labelText: "Jadwal Jam", border: OutlineInputBorder(), hintText: "08:00 - 14:00"),
              ),
              
              const SizedBox(height: 30),
              
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _simpanDokter,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text("SIMPAN & BUAT AKUN"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}