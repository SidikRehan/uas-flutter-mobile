import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth/login_page.dart'; 
import 'pasien/pasien_pilih_dokter.dart'; 

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
      if (today.month < birthDate.month || (today.month == birthDate.month && today.day < birthDate.day)) {
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
        var docPasien = await FirebaseFirestore.instance.collection('pasiens').doc(user!.uid).get();
        
        if (docPasien.exists) {
          var data = docPasien.data()!;
          setState(() {
            namaUser = data['nama'] ?? "Pasien";
            nikUser = data['nik'] ?? "-";
            bpjsUser = data['nomor_bpjs'] ?? "-";
            tglLahirUser = data['tanggal_lahir'] ?? "-";
            umurUser = _hitungUmur(tglLahirUser); 
            
            if (bpjsUser != "-" && bpjsUser.isNotEmpty && bpjsUser.length > 3) {
              jenisPasien = "BPJS";
            } else {
              jenisPasien = "Umum";
            }
          });
        } else {
          var docUser = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
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
    final tglCtrl = TextEditingController(text: tglLahirUser == "-" ? "" : tglLahirUser);
    final bpjsCtrl = TextEditingController(text: bpjsUser == "-" ? "" : bpjsUser);
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
                decoration: const InputDecoration(labelText: "Tanggal Lahir", suffixIcon: Icon(Icons.calendar_today)),
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
              TextField(controller: nikCtrl, decoration: const InputDecoration(labelText: "NIK"), keyboardType: TextInputType.number),
              const SizedBox(height: 10),
              TextField(controller: bpjsCtrl, decoration: const InputDecoration(labelText: "No. BPJS (Opsional)"), keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(
            onPressed: () async {
              if (tglCtrl.text.isEmpty) return;
              
              await FirebaseFirestore.instance.collection('pasiens').doc(user!.uid).set({
                'tanggal_lahir': tglCtrl.text,
                'nomor_bpjs': bpjsCtrl.text,
                'nik': nikCtrl.text,
                'nama': namaUser, // Pertahankan nama lama
                'email': emailUser,
                'uid': user!.uid,
              }, SetOptions(merge: true)); // Merge agar data lain tidak hilang

              if (mounted) {
                Navigator.pop(context);
                _getLengkapDataUser(); // Refresh Tampilan
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Data Berhasil Disimpan!")));
              }
            },
            child: const Text("Simpan"),
          )
        ],
      ),
    );
  }

  // --- TAB 1: BERANDA ---
  Widget _buildHomeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Colors.blue, Colors.cyan]),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Jaga Kesehatan Anda!", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 5),
                Text("Halo, $namaUser ($umurUser)", style: const TextStyle(color: Colors.white70)), 
              ],
            ),
          ),
          const SizedBox(height: 25),
          const Text("Layanan Poli", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('polis').orderBy('nama_poli').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              var docs = snapshot.data!.docs;
              if (docs.isEmpty) return const Center(child: Text("Belum ada layanan poli.", style: TextStyle(color: Colors.grey)));

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 1.1,
                ),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  var data = docs[index].data() as Map<String, dynamic>;
                  return InkWell(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PasienPilihDokter(namaPoli: data['nama_poli']))),
                    child: Container(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5)]),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.blue[50], shape: BoxShape.circle), child: Icon(Icons.medical_services, size: 28, color: Colors.blue[800])),
                          const SizedBox(height: 10),
                          Text(data['nama_poli'], textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // --- TAB 2: RIWAYAT ---
  Widget _buildRiwayatTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('bookings').where('id_pasien', isEqualTo: user?.uid).orderBy('created_at', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        var docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text("Belum ada riwayat."));

        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            String status = data['status'] ?? 'Menunggu';
            Color statusColor = status == 'Disetujui' ? Colors.green : (status == 'Selesai' ? Colors.blue : (status == 'Ditolak' ? Colors.red : Colors.orange));
            
            return Card(
              margin: const EdgeInsets.only(bottom: 15),
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(backgroundColor: statusColor.withOpacity(0.2), child: Icon(Icons.medical_services, color: statusColor)),
                        const SizedBox(width: 15),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(data['nama_dokter'] ?? 'Dokter', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(data['poli'] ?? 'Poli', style: const TextStyle(color: Colors.grey)),
                        ])),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(20)), child: Text(status, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                      ],
                    ),
                    const Divider(height: 25),
                    if (status == 'Disetujui' || status == 'Selesai') ...[
                      const Text("NOMOR ANTRIAN ANDA", style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(data['nomor_antrian'] ?? 'A-???', style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: statusColor)),
                    ] else ...[
                       const Text("Sedang Menunggu...", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                    ]
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- TAB 3: PROFIL ---
  Widget _buildProfilTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Header Profil
          const CircleAvatar(radius: 50, backgroundColor: Colors.blue, child: Icon(Icons.person, size: 50, color: Colors.white)),
          const SizedBox(height: 15),
          Text(namaUser, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text("$tglLahirUser ($umurUser)", style: const TextStyle(color: Colors.grey)), 
          
          const SizedBox(height: 10),
          Container(padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5), decoration: BoxDecoration(color: jenisPasien == "BPJS" ? Colors.green : Colors.blue, borderRadius: BorderRadius.circular(20)), child: Text("Pasien $jenisPasien", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          
          const SizedBox(height: 20),
          
          // TOMBOL EDIT (BARU)
          OutlinedButton.icon(
            onPressed: _editProfilSelf, // <--- Panggil fungsi edit
            icon: const Icon(Icons.edit),
            label: const Text("Lengkapi Data & Tgl Lahir"),
          ),

          const SizedBox(height: 20),

          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                children: [
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
          SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), icon: const Icon(Icons.logout), label: const Text("Keluar"), onPressed: () async { await FirebaseAuth.instance.signOut(); if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const LoginPage())); })),
        ],
      ),
    );
  }

  Widget _buildProfileItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(children: [Icon(icon, color: Colors.blue[800], size: 28), const SizedBox(width: 15), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)), Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500))]))]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [_buildHomeTab(), _buildRiwayatTab(), _buildProfilTab()];
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: Text(_selectedIndex == 0 ? "Halo, $namaUser" : (_selectedIndex == 1 ? "Riwayat" : "Profil")), backgroundColor: Colors.blue[800], foregroundColor: Colors.white, automaticallyImplyLeading: false),
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(currentIndex: _selectedIndex, onTap: (index) => setState(() => _selectedIndex = index), selectedItemColor: Colors.blue[800], unselectedItemColor: Colors.grey, items: const [BottomNavigationBarItem(icon: Icon(Icons.home), label: "Beranda"), BottomNavigationBarItem(icon: Icon(Icons.history), label: "Antrian"), BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profil")]),
    );
  }
}