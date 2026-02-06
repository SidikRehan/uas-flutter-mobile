import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'login_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  // --- WARNA TEMA: MEDICAL BLUE ---
  final Color _hospitalColor = const Color(
    0xFF0077B6,
  ); // Biru Medis yang Tenang
  final Color _bgInput = const Color(0xFFF0F4F8); // Abu kebiruan sangat muda

  // CONTROLLER
  final _namaController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nikController = TextEditingController();
  final _bpjsController = TextEditingController();
  final _tglLahirController = TextEditingController();
  final _noHpController = TextEditingController();
  final _alamatController = TextEditingController();

  String? _selectedGender;
  bool _isLoading = false;
  bool _isObscure = true;

  // --- LOGIKA DATE PICKER ---
  Future<void> _selectDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(
            context,
          ).copyWith(colorScheme: ColorScheme.light(primary: _hospitalColor)),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _tglLahirController.text = picked.toString().split(' ')[0];
      });
    }
  }

  // --- LOGIKA REGISTER DENGAN TRANSACTION (AUTO ID) ---
  void _register() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        // 1. Buat Akun Auth dulu
        UserCredential uc = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: _emailController.text.trim(),
              password: _passwordController.text.trim(),
            );

        String uid = uc.user!.uid;

        // 2. Jalankan Transaksi Firestore (Safe Counter)
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          // A. Ambil Referensi Counter
          DocumentReference counterRef = FirebaseFirestore.instance
              .collection('counters')
              .doc('pasiens');
          DocumentSnapshot counterSnapshot = await transaction.get(counterRef);

          int nextId = 1;
          if (counterSnapshot.exists) {
            nextId =
                (counterSnapshot.data() as Map<String, dynamic>)['last_id'] + 1;
            transaction.update(counterRef, {'last_id': nextId});
          } else {
            transaction.set(counterRef, {'last_id': 1});
          }

          // B. Generate ID Format: PS-0001
          String customId = "PS-${nextId.toString().padLeft(4, '0')}";

          // C. Siapkan Data
          DocumentReference userRef = FirebaseFirestore.instance
              .collection('users')
              .doc(uid);
          DocumentReference pasienRef = FirebaseFirestore.instance
              .collection('pasiens')
              .doc(uid);

          transaction.set(userRef, {
            'uid': uid,
            'nama': _namaController.text.trim(),
            'email': _emailController.text.trim(),
            'role': 'pasien',
            'id_pasien': customId, // SIMPAN ID UNIK
            'created_at': FieldValue.serverTimestamp(),
            'is_active': true,
          });

          transaction.set(pasienRef, {
            'uid': uid,
            'nama': _namaController.text.trim(),
            'email': _emailController.text.trim(),
            'nik': _nikController.text.trim(),
            'nomor_bpjs': _bpjsController.text.trim(),
            'tanggal_lahir': _tglLahirController.text.trim(),
            'jenis_kelamin': _selectedGender,
            'no_hp': _noHpController.text.trim(),
            'alamat': _alamatController.text.trim(),
            'id_pasien': customId, // SIMPAN ID UNIK
            'created_at': FieldValue.serverTimestamp(),
          });
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Registrasi Berhasil! Silakan Login."),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (c) => const LoginPage()),
            (route) => false,
          );
        }
      } on FirebaseAuthException catch (e) {
        String msg = e.message ?? "Gagal Registrasi";
        if (e.code == 'email-already-in-use')
          msg = "Email ini sudah terdaftar.";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      } catch (e) {
        // Catch error lain (misal Firestore)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Pendaftaran Pasien",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _hospitalColor, // AppBar Biru
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER INFO
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD), // Biru sangat muda
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.verified_user_outlined, color: _hospitalColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Pastikan NIK sesuai KTP dan Nomor HP aktif.",
                        style: TextStyle(
                          color: _hospitalColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),

              // --- GROUP 1: DATA PRIBADI ---
              _buildSectionTitle("Data Pribadi", Icons.person_pin),
              _buildTextField(
                controller: _namaController,
                label: "Nama Lengkap (Sesuai KTP)",
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 15),

              // DROPDOWN GENDER
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _bgInput,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.transparent),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedGender,
                    hint: Row(
                      children: [
                        Icon(Icons.wc, color: _hospitalColor, size: 20),
                        const SizedBox(width: 10),
                        const Text("Pilih Jenis Kelamin"),
                      ],
                    ),
                    isExpanded: true,
                    icon: Icon(Icons.arrow_drop_down, color: _hospitalColor),
                    items: ['Laki-laki', 'Perempuan']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedGender = val),
                  ),
                ),
              ),
              const SizedBox(height: 15),

              // DATE PICKER
              _buildTextField(
                controller: _tglLahirController,
                label: "Tanggal Lahir",
                icon: Icons.calendar_today_outlined,
                readOnly: true,
                onTap: _selectDate,
              ),

              const SizedBox(height: 30),

              // --- GROUP 2: KONTAK & ALAMAT ---
              _buildSectionTitle("Kontak & Lokasi", Icons.location_on_outlined),

              // NOMOR HP
              _buildTextField(
                controller: _noHpController,
                label: "No. HP / WhatsApp",
                icon: Icons.phone_android_outlined,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(13),
                ],
                validator: (val) {
                  if (val == null || val.isEmpty) return "Wajib diisi";
                  if (val.length < 10) return "Nomor HP minimal 10 digit";
                  return null;
                },
              ),
              const SizedBox(height: 15),
              _buildTextField(
                controller: _alamatController,
                label: "Alamat Lengkap",
                icon: Icons.home_outlined,
                maxLines: 2,
              ),

              const SizedBox(height: 30),

              // --- GROUP 3: IDENTITAS ---
              _buildSectionTitle(
                "Rekam Medis & Identitas",
                Icons.assignment_ind_outlined,
              ),

              // NIK
              _buildTextField(
                controller: _nikController,
                label: "NIK (KTP)",
                icon: Icons.credit_card,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(16),
                ],
                validator: (val) {
                  if (val == null || val.isEmpty) return "NIK wajib diisi";
                  if (val.length != 16) return "NIK harus pas 16 digit";
                  return null;
                },
              ),
              const SizedBox(height: 15),

              _buildTextField(
                controller: _bpjsController,
                label: "Nomor BPJS (Opsional)",
                icon: Icons.health_and_safety_outlined,
                keyboardType: TextInputType.number,
                isRequired: false,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(13),
                ],
              ),

              const SizedBox(height: 30),

              // --- GROUP 4: AKUN LOGIN ---
              _buildSectionTitle("Keamanan Akun", Icons.lock_outline),
              _buildTextField(
                controller: _emailController,
                label: "Email Aktif",
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 15),
              // PASSWORD
              TextFormField(
                controller: _passwordController,
                obscureText: _isObscure,
                validator: (val) =>
                    val!.length < 6 ? "Password minimal 6 karakter" : null,
                decoration: InputDecoration(
                  labelText: "Buat Password",
                  prefixIcon: Icon(
                    Icons.vpn_key_outlined,
                    color: _hospitalColor,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isObscure ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey,
                    ),
                    onPressed: () => setState(() => _isObscure = !_isObscure),
                  ),
                  filled: true,
                  fillColor: _bgInput,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: _hospitalColor, width: 2),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // TOMBOL DAFTAR BIRU
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _hospitalColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 3,
                    shadowColor: _hospitalColor.withOpacity(0.5),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "DAFTAR SEKARANG",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET HELPER ---
  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 5),
      child: Row(
        children: [
          Icon(icon, size: 20, color: _hospitalColor),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey[800],
            ),
          ),
          Expanded(child: Divider(indent: 10, color: Colors.grey[300])),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    VoidCallback? onTap,
    int maxLines = 1,
    bool isRequired = true,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      onTap: onTap,
      maxLines: maxLines,
      inputFormatters: inputFormatters,
      validator:
          validator ??
          (val) => (isRequired && (val == null || val.isEmpty))
              ? "$label wajib diisi"
              : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _hospitalColor),
        filled: true,
        fillColor: _bgInput,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _hospitalColor, width: 2),
        ),
      ),
    );
  }
}
