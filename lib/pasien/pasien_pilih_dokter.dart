import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PasienPilihDokter extends StatefulWidget {
  final String namaPoli; 

  const PasienPilihDokter({super.key, required this.namaPoli});

  @override
  State<PasienPilihDokter> createState() => _PasienPilihDokterState();
}

class _PasienPilihDokterState extends State<PasienPilihDokter> {
  User? currentUser = FirebaseAuth.instance.currentUser;

  // --- HELPER HARI ---
  String _getNamaHariIni() {
    int weekday = DateTime.now().weekday;
    switch (weekday) {
      case 1: return "Senin";
      case 2: return "Selasa";
      case 3: return "Rabu";
      case 4: return "Kamis";
      case 5: return "Jumat";
      case 6: return "Sabtu";
      case 7: return "Minggu";
      default: return "";
    }
  }

  // --- LOGIKA CEK BUKA/TUTUP ---
  bool _isDokterBuka(String jadwalHari, String jadwalJam) {
    // UNTUK TESTING: KITA BUAT SELALU BUKA (RETURN TRUE)
    // Agar mas bisa tes booking kapanpun tanpa terhalang hari.
    // Nanti kalau mau strict, hapus 'return true' di bawah ini.
    return true; 
    
    /* // Logika Asli (Aktifkan nanti jika sudah selesai testing):
    String hariIni = _getNamaHariIni();
    bool hariSesuai = jadwalHari.toLowerCase().contains(hariIni.toLowerCase());
    return hariSesuai;
    */
  }

  // --- FUNGSI PROSES BOOKING ---
  void _showBookingDialog(Map<String, dynamic> dokterData, String dokterId) async {
    // 1. Ambil Data Pasien dari Database
    String namaPasien = "Pasien";
    String nomorBpjs = "-";
    
    try {
      var docPasien = await FirebaseFirestore.instance.collection('pasiens').doc(currentUser!.uid).get();
      if (docPasien.exists) {
        namaPasien = docPasien.data()?['nama'] ?? "Pasien";
        nomorBpjs = docPasien.data()?['nomor_bpjs'] ?? "-";
      } else {
        // Fallback ke users jika data di pasiens belum ada
        var docUser = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
        namaPasien = docUser.data()?['nama'] ?? "Pasien";
      }
    } catch (e) {
      print("Error ambil data user: $e");
    }

    String jenisPasien = (nomorBpjs != "-" && nomorBpjs.isNotEmpty) ? "BPJS" : "Regular";

    if (!mounted) return;

    // 2. Tampilkan Dialog Konfirmasi
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Konfirmasi Booking"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Anda akan mendaftar ke:", style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 5),
            Text(dokterData['Nama'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text("Poli: ${widget.namaPoli}"),
            const Divider(),
            Text("Nama Pasien: $namaPasien"),
            Text("Jenis Pasien: $jenisPasien"),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.orange[50],
              child: const Text("Status awal booking adalah 'Menunggu Konfirmasi' admin.", style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.deepOrange)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(context); // Tutup dialog

              try {
                // 3. SIMPAN KE FIREBASE (COLLECTION 'bookings')
                await FirebaseFirestore.instance.collection('bookings').add({
                  'id_pasien': currentUser!.uid,
                  'nama_pasien': namaPasien,
                  'nomor_bpjs': nomorBpjs,
                  'dokter_uid': dokterId,
                  'nama_dokter': dokterData['Nama'],
                  'poli': widget.namaPoli,
                  'jenis_pasien': jenisPasien,
                  
                  // STATUS PENTING:
                  'status': 'Menunggu Konfirmasi', 
                  
                  'tanggal_booking': DateTime.now().toString(),
                  'created_at': FieldValue.serverTimestamp(),
                  'hasil_medis': '', // Kosong dulu
                  'biaya': '0',      // Kosong dulu
                });

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("Berhasil Booking! Cek menu Antrian."),
                    backgroundColor: Colors.green,
                  ));
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal: $e")));
              }
            },
            child: const Text("Ya, Booking"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Dokter ${widget.namaPoli}"),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('doctors')
            .where('Poli', isEqualTo: widget.namaPoli)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          var docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(child: Text("Belum ada dokter di ${widget.namaPoli}"));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              String docId = docs[index].id;
              
              String hari = data['Hari'] ?? '-';
              String jam = data['Jam'] ?? '-';
              
              // Cek Buka/Tutup (Sekarang di-set selalu True agar tombol nyala)
              bool isOpen = _isDokterBuka(hari, jam);

              return Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(data['Nama'] ?? 'Dokter', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("$hari ($jam)"),
                  trailing: ElevatedButton(
                    // JIKA ISOPEN TRUE -> JALANKAN DIALOG BOOKING
                    // JIKA FALSE -> NULL (TOMBOL MATI)
                    onPressed: isOpen ? () => _showBookingDialog(data, docId) : null,
                    
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isOpen ? Colors.blue : Colors.grey,
                      foregroundColor: Colors.white
                    ),
                    child: Text(isOpen ? "Pilih" : "Tutup"),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}