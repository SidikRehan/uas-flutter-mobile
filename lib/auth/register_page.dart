import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  
  // Controller
  final _namaController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nikController = TextEditingController();
  final _bpjsController = TextEditingController();
  final _tglLahirController = TextEditingController();
  final _noHpController = TextEditingController(); // BARU
  final _alamatController = TextEditingController(); // BARU
  
  String? _selectedGender; // BARU (Dropdown)

  bool _isLoading = false;

  Future<void> _selectDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _tglLahirController.text = picked.toString().split(' ')[0];
      });
    }
  }

  void _register() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        // 1. Buat Akun Auth
        UserCredential uc = await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim());

        String uid = uc.user!.uid;
        
        // 2. Simpan Data Dasar ke 'users'
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'uid': uid,
          'nama': _namaController.text.trim(),
          'email': _emailController.text.trim(),
          'role': 'pasien',
          'created_at': FieldValue.serverTimestamp(),
        });

        // 3. Simpan DATA LENGKAP ke 'pasiens'
        await FirebaseFirestore.instance.collection('pasiens').doc(uid).set({
          'uid': uid,
          'nama': _namaController.text.trim(),
          'email': _emailController.text.trim(),
          'nik': _nikController.text.trim(),
          'nomor_bpjs': _bpjsController.text.trim(),
          'tanggal_lahir': _tglLahirController.text.trim(),
          // FIELD BARU:
          'jenis_kelamin': _selectedGender,
          'no_hp': _noHpController.text.trim(),
          'alamat': _alamatController.text.trim(),
          'created_at': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Registrasi Berhasil! Silakan Login.")));
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage()));
        }
      } on FirebaseAuthException catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? "Gagal Registrasi")));
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Daftar Pasien Baru")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const Icon(Icons.assignment_ind, size: 60, color: Colors.blue),
              const SizedBox(height: 20),

              // NAMA
              TextFormField(
                controller: _namaController,
                decoration: const InputDecoration(labelText: "Nama Lengkap", border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
                validator: (val) => val!.isEmpty ? "Wajib diisi" : null,
              ),
              const SizedBox(height: 10),

              // JENIS KELAMIN (DROPDOWN)
              DropdownButtonFormField<String>(
                value: _selectedGender,
                decoration: const InputDecoration(labelText: "Jenis Kelamin", border: OutlineInputBorder(), prefixIcon: Icon(Icons.wc)),
                items: ['Laki-laki', 'Perempuan'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (val) => setState(() => _selectedGender = val),
                validator: (val) => val == null ? "Pilih jenis kelamin" : null,
              ),
              const SizedBox(height: 10),

              // TGL LAHIR
              TextFormField(
                controller: _tglLahirController,
                readOnly: true,
                onTap: _selectDate,
                decoration: const InputDecoration(labelText: "Tanggal Lahir", border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_today)),
                validator: (val) => val!.isEmpty ? "Wajib diisi" : null,
              ),
              const SizedBox(height: 10),

              // KONTAK & ALAMAT
              TextFormField(
                controller: _noHpController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: "No. HP / WhatsApp", border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone)),
                validator: (val) => val!.isEmpty ? "Wajib diisi" : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _alamatController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: "Alamat Lengkap", border: OutlineInputBorder(), prefixIcon: Icon(Icons.home)),
                validator: (val) => val!.isEmpty ? "Wajib diisi" : null,
              ),
              const SizedBox(height: 10),

              // IDENTITAS
              TextFormField(
                controller: _nikController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "NIK (KTP)", border: OutlineInputBorder(), prefixIcon: Icon(Icons.credit_card)),
                validator: (val) => val!.length != 16 ? "NIK harus 16 digit" : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _bpjsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Nomor BPJS (Opsional)", border: OutlineInputBorder(), prefixIcon: Icon(Icons.card_membership)),
              ),
              
              const Divider(height: 30),

              // AKUN LOGIN
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: "Email Login", border: OutlineInputBorder(), prefixIcon: Icon(Icons.email)),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: "Password", border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock)),
              ),
              
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("DAFTAR SEKARANG"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}