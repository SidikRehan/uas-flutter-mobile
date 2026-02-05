import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth/login_page.dart';
import 'pasien/pasien_pilih_dokter.dart';
import 'pasien/pasien_jadwal_page.dart';
// Import Halaman Notifikasi
import 'pasien/pasien_notifikasi_page.dart';

class PasienHomePage extends StatefulWidget {
  const PasienHomePage({super.key});

  @override
  State<PasienHomePage> createState() => _PasienHomePageState();
}

class _PasienHomePageState extends State<PasienHomePage> {
  int _selectedIndex = 0;
  User? user = FirebaseAuth.instance.currentUser;

  // Variabel Data Lengkap
  String namaUser = "Loading...";
  String emailUser = "";
  String nikUser = "-";
  String bpjsUser = "-";
  String tglLahirUser = "-";
  String umurUser = "-";
  String genderUser = "-"; // Tambah Variable Gender
  String jenisPasien = "Umum";

  @override
  void initState() {
    super.initState();
    _getLengkapDataUser();
  }

  // --- LOGIKA HITUNG UMUR ---
  String _hitungUmur(String tglLahir) {
    try {
      if (tglLahir == "-" || tglLahir.isEmpty) return "-";
      DateTime birthDate = DateTime.parse(tglLahir);
      DateTime today = DateTime.now();
      int age = today.year - birthDate.year;
      if (today.month < birthDate.month ||
          (today.month == birthDate.month && today.day < birthDate.day)) {
        age--;
      }
      return "$age Tahun";
    } catch (e) {
      return "-";
    }
  }

  // --- AMBIL DATA ---
  void _getLengkapDataUser() async {
    if (user != null) {
      setState(() => emailUser = user!.email ?? "-");

      try {
        var docPasien = await FirebaseFirestore.instance
            .collection('pasiens')
            .doc(user!.uid)
            .get();

        if (docPasien.exists) {
          var data = docPasien.data()!;
          setState(() {
            namaUser = data['nama'] ?? "Pasien";
            nikUser = data['nik'] ?? "-";
            bpjsUser = data['nomor_bpjs'] ?? "-";
            tglLahirUser = data['tanggal_lahir'] ?? "-";
            genderUser = data['jenis_kelamin'] ?? "-"; // Ambil Data Gender
            umurUser = _hitungUmur(tglLahirUser);

            if (bpjsUser != "-" && bpjsUser.isNotEmpty && bpjsUser.length > 3) {
              jenisPasien = "BPJS";
            } else {
              jenisPasien = "Umum";
            }
          });
        } else {
          var docUser = await FirebaseFirestore.instance
              .collection('users')
              .doc(user!.uid)
              .get();
          if (docUser.exists) {
            setState(() => namaUser = docUser.data()?['nama'] ?? "Pasien");
          }
        }
      } catch (e) {
        print("Gagal ambil data: $e");
      }
    }
  }

  // --- FITUR BARU: EDIT PROFIL SENDIRI ---
  void _editProfilSelf() {
    final tglCtrl = TextEditingController(
      text: tglLahirUser == "-" ? "" : tglLahirUser,
    );
    final bpjsCtrl = TextEditingController(
      text: bpjsUser == "-" ? "" : bpjsUser,
    );
    final nikCtrl = TextEditingController(text: nikUser == "-" ? "" : nikUser);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Lengkapi Profil"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: tglCtrl,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: "Tanggal Lahir",
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                onTap: () async {
                  DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime(2000),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    tglCtrl.text = picked.toString().split(' ')[0];
                  }
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nikCtrl,
                decoration: const InputDecoration(labelText: "NIK"),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: bpjsCtrl,
                decoration: const InputDecoration(
                  labelText: "No. BPJS (Opsional)",
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (tglCtrl.text.isEmpty) return;

              await FirebaseFirestore.instance
                  .collection('pasiens')
                  .doc(user!.uid)
                  .set({
                    'tanggal_lahir': tglCtrl.text,
                    'nomor_bpjs': bpjsCtrl.text,
                    'nik': nikCtrl.text,
                    'nama': namaUser,
                    'email': emailUser,
                    'uid': user!.uid,
                  }, SetOptions(merge: true));

              if (mounted) {
                Navigator.pop(context);
                _getLengkapDataUser();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Data Berhasil Disimpan!")),
                );
              }
            },
            child: const Text("Simpan"),
          ),
        ],
      ),
    );
  }

  // --- TAB 1: BERANDA MODERN ---
  Widget _buildHomeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. WELCOME SECTION (Modern & Clean)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[900]!, Colors.blue[600]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Selamat Datang, allow update 👋",
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        namaUser,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "$umurUser • $jenisPasien",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 35, color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // 2. SECTION LAYANAN
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Layanan Kami",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              TextButton(onPressed: () {}, child: const Text("Lihat Semua")),
            ],
          ),
          const SizedBox(height: 16),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('polis')
                .orderBy('nama_poli')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              var docs = snapshot.data!.docs;
              if (docs.isEmpty) return _buildEmptyState();

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.0, // Kotak Sempurna
                ),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  var data = docs[index].data() as Map<String, dynamic>;
                  return _buildPoliCard(data, context);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: const Column(
        children: [
          Icon(Icons.medical_services_outlined, size: 40, color: Colors.grey),
          SizedBox(height: 10),
          Text(
            "Belum ada layanan poli tersedia.",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildPoliCard(Map<String, dynamic> data, BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 2,
      shadowColor: Colors.blue.withValues(alpha: 0.1),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                PasienPilihDokter(namaPoli: data['nama_poli']),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.apartment_rounded,
                size: 32,
                color: Colors.blue[700],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              data['nama_poli'],
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "Tersedia",
              style: TextStyle(
                color: Colors.green,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- TAB 2: RIWAYAT / JADWAL ---
  Widget _buildRiwayatTab() {
    return const PasienJadwalPage();
  }

  // --- TAB 3: PROFIL ---
  Widget _buildProfilTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 50,
            backgroundColor: Colors.blue,
            child: Icon(Icons.person, size: 50, color: Colors.white),
          ),
          const SizedBox(height: 15),
          Text(
            namaUser,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Text(
            "$tglLahirUser ($umurUser)",
            style: const TextStyle(color: Colors.grey),
          ),

          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            decoration: BoxDecoration(
              color: jenisPasien == "BPJS" ? Colors.green : Colors.blue,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              "Pasien $jenisPasien",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _editProfilSelf,
            icon: const Icon(Icons.edit),
            label: const Text("Lengkapi Data & Tgl Lahir"),
          ),

          const SizedBox(height: 20),
          // 3. Card Modern (Rounded & Soft Shadow)
          Card(
            elevation: 4,
            shadowColor: Colors.black.withValues(
              alpha: 0.1,
            ), // Bayangan sangat halus
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: Colors.white,
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                children: [
                  _buildProfileItem(
                    Icons.wc,
                    "Jenis Kelamin",
                    genderUser,
                  ), // Tampilkan Gender
                  const Divider(),
                  _buildProfileItem(Icons.cake, "Umur", umurUser),
                  const Divider(),
                  _buildProfileItem(Icons.credit_card, "NIK", nikUser),
                  const Divider(),
                  _buildProfileItem(Icons.health_and_safety, "BPJS", bpjsUser),
                  const Divider(),
                  _buildProfileItem(Icons.email, "Email", emailUser),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.logout),
              label: const Text("Keluar"),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (c) => const LoginPage()),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue[800], size: 28),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _buildHomeTab(),
      _buildRiwayatTab(),
      _buildProfilTab(),
    ];

    return Scaffold(
      backgroundColor: Colors.grey[50],

      appBar: _selectedIndex == 1
          ? null
          : AppBar(
              title: Text(
                _selectedIndex == 0 ? "Halo, $namaUser" : "Profil Saya",
              ),
              backgroundColor: Colors.blue[800],
              foregroundColor: Colors.white,
              automaticallyImplyLeading: false,

              // --- BAGIAN INI YANG TADI HILANG ---
              // Tombol Lonceng Notifikasi
              actions: [
                if (_selectedIndex == 0)
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('notifications')
                        .where('user_id', isEqualTo: user?.uid)
                        .where('is_read', isEqualTo: false) // Cari notif baru
                        .snapshots(),
                    builder: (context, snapshot) {
                      bool adaNotif = false;
                      if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                        adaNotif = true;
                      }

                      return Stack(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.notifications),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (c) => const PasienNotifikasiPage(),
                                ),
                              );
                            },
                          ),
                          if (adaNotif)
                            Positioned(
                              right: 11,
                              top: 11,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 12,
                                  minHeight: 12,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                const SizedBox(width: 10),
              ],
              // -----------------------------------
            ),

      body: pages[_selectedIndex],

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: Colors.blue[800],
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Beranda"),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "Antrian"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profil"),
        ],
      ),
    );
  }
}
