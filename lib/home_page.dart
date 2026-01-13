import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth/login_page.dart'; 
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
  String jenisPasien = "Umum"; // Default

  @override
  void initState() {
    super.initState();
    _getLengkapDataUser();
  }

  // --- FUNGSI AMBIL DATA LENGKAP (FIXED) ---
  void _getLengkapDataUser() async {
    if (user != null) {
      setState(() {
        emailUser = user!.email ?? "-";
      });

      try {
        // Coba ambil dari koleksi 'pasiens' (Data lengkap ada disini)
        var docPasien = await FirebaseFirestore.instance.collection('pasiens').doc(user!.uid).get();
        
        if (docPasien.exists) {
          var data = docPasien.data()!;
          setState(() {
            namaUser = data['nama'] ?? "Pasien";
            nikUser = data['nik'] ?? "-";
            bpjsUser = data['nomor_bpjs'] ?? "-";
            
            // Logika cek jenis pasien
            if (bpjsUser != "-" && bpjsUser.isNotEmpty) {
              jenisPasien = "BPJS";
            } else {
              jenisPasien = "Umum";
            }
          });
        } else {
          // Fallback ke koleksi 'users' jika data di 'pasiens' hilang
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
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Jaga Kesehatan Anda!", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                SizedBox(height: 5),
                Text("Lakukan pemeriksaan rutin bersama dokter spesialis kami.", style: TextStyle(color: Colors.white70)),
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
              if (docs.isEmpty) {
                return const Center(child: Text("Belum ada layanan poli tersedia.", style: TextStyle(color: Colors.grey)));
              }

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  childAspectRatio: 1.1,
                ),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  var data = docs[index].data() as Map<String, dynamic>;
                  String namaPoli = data['nama_poli'] ?? 'Poli';

                  return InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => PasienPilihDokter(namaPoli: namaPoli)),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5, spreadRadius: 1)],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.blue[50], shape: BoxShape.circle),
                            child: Icon(Icons.medical_services, size: 28, color: Colors.blue[800]),
                          ),
                          const SizedBox(height: 10),
                          Text(namaPoli, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
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
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('id_pasien', isEqualTo: user?.uid)
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        var docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text("Belum ada riwayat pendaftaran."));

        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            String status = data['status'] ?? 'Menunggu';
            
            Color statusColor = Colors.grey;
            if (status == 'Disetujui') statusColor = Colors.blue;
            if (status == 'Selesai') statusColor = Colors.green;
            if (status == 'Menunggu Pembayaran') statusColor = Colors.orange;

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(backgroundColor: statusColor, child: const Icon(Icons.assignment, color: Colors.white)),
                title: Text(data['nama_dokter'] ?? 'Dokter', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("${data['poli']} - ${data['tanggal_booking'].toString().split(' ')[0]}"),
                    Container(
                      margin: const EdgeInsets.only(top: 5),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: statusColor.withOpacity(0.2), borderRadius: BorderRadius.circular(5)),
                      child: Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10)),
                    ),
                    if (status == 'Menunggu Pembayaran')
                      Text("Tagihan: Rp ${data['biaya']}", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }

  // --- TAB 3: PROFIL LENGKAP (UPDATE TERBARU) ---
  Widget _buildProfilTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Header Profil
          const CircleAvatar(radius: 50, backgroundColor: Colors.blue, child: Icon(Icons.person, size: 50, color: Colors.white)),
          const SizedBox(height: 15),
          Text(namaUser, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text(emailUser, style: const TextStyle(color: Colors.grey)),
          
          const SizedBox(height: 10),
          // Badge Jenis Pasien
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            decoration: BoxDecoration(
              color: jenisPasien == "BPJS" ? Colors.green : Colors.blue,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text("Pasien $jenisPasien", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),

          const SizedBox(height: 30),

          // Detail Data (Card)
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                children: [
                  _buildProfileItem(Icons.credit_card, "NIK (KTP)", nikUser),
                  const Divider(),
                  _buildProfileItem(Icons.health_and_safety, "Nomor BPJS", bpjsUser),
                  const Divider(),
                  _buildProfileItem(Icons.email, "Email Terdaftar", emailUser),
                ],
              ),
            ),
          ),

          const SizedBox(height: 30),
          
          // Tombol Keluar
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              icon: const Icon(Icons.logout),
              label: const Text("Keluar Aplikasi", style: TextStyle(fontSize: 16)),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (mounted) {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const LoginPage()));
                }
              },
            ),
          )
        ],
      ),
    );
  }

  // Helper Widget untuk Baris Profil
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
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
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
      appBar: AppBar(
        title: Text(_selectedIndex == 0 ? "Halo, $namaUser" : (_selectedIndex == 1 ? "Riwayat Antrian" : "Profil Saya")),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
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