import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BookingPage extends StatefulWidget {
  final String? poliPilihan;

  const BookingPage({super.key, this.poliPilihan});

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {

  // --- FUNGSI 1: MENDAPATKAN NAMA HARI INI (INDONESIA) ---
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

  // --- FUNGSI 2: CEK APAKAH DOKTER BUKA? (LOGIKA UTAMA) ---
  bool _isDokterBuka(String jadwalHari, String jadwalJam) {
    // A. CEK HARI
    String hariIni = _getNamaHariIni();
    
    // Logika Sederhana: Cek apakah teks jadwal mengandung nama hari ini
    // Contoh: Jadwal "Senin - Jumat", Hari ini "Senin" -> TRUE
    // Catatan: Untuk range "Senin - Jumat", logic 'contains' hanya mendeteksi kata yang tertulis.
    // Agar aman, di Admin tulis jadwalnya lengkap misal: "Senin, Selasa, Rabu, Kamis, Jumat" atau pastikan logic ini cukup buat kamu.
    // Tapi untuk tugas kuliah, logic 'contains' atau pengecekan string sederhana biasanya sudah cukup.
    bool hariSesuai = jadwalHari.toLowerCase().contains(hariIni.toLowerCase());
    
    // B. CEK JAM (Hanya jika harinya sesuai)
    bool jamSesuai = false;
    if (hariSesuai) {
      try {
        // Format di Database diasumsikan: "08:00 - 15:00"
        // Kita ambil jam tutupnya (setelah tanda strip)
        List<String> splitJam = jadwalJam.split('-'); 
        if (splitJam.length > 1) {
          String jamTutupStr = splitJam[1].trim(); // Ambil "15:00"
          
          // Ubah "15:00" jadi Jam dan Menit angka
          int jamTutup = int.parse(jamTutupStr.split(':')[0]);
          int menitTutup = int.parse(jamTutupStr.split(':')[1]);

          // Bandingkan dengan Waktu Sekarang
          DateTime now = DateTime.now();
          DateTime waktuTutup = DateTime(now.year, now.month, now.day, jamTutup, menitTutup);
          
          // Jika waktu sekarang SEBELUM waktu tutup, berarti MASIH BUKA
          if (now.isBefore(waktuTutup)) {
            jamSesuai = true;
          }
        } else {
          // Kalau format jam salah/tidak ada strip, anggap buka saja biar gak error
          jamSesuai = true;
        }
      } catch (e) {
        // Kalau error parsing, anggap buka (fail-safe)
        jamSesuai = true;
      }
    }

    return hariSesuai && jamSesuai;
  }

  // --- FUNGSI HELPER AMBIL DATA AMAN ---
  String _getString(Map<String, dynamic> data, String key1, String key2) {
    return data[key1] ?? data[key2] ?? data[key1.toLowerCase()] ?? '-';
  }

  // --- FUNGSI SIMPAN ---
  void _simpanBooking(Map<String, dynamic> dokterData) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Anda harus login")));
      return;
    }

    String namaDokter = _getString(dokterData, 'Nama', 'nama');
    String poliDokter = _getString(dokterData, 'Poli', 'poli');
    String dokterUid = dokterData['uid'] ?? ''; 
    String fotoDokter = dokterData['foto_url'] ?? ''; 

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      var userData = userDoc.data() as Map<String, dynamic>?;

      String namaPasien = userData?['nama'] ?? 'Pasien';
      String nomorBpjs = userData?['nomor_bpjs'] ?? ''; 
      String jenisPasienOtomatis = (nomorBpjs.isNotEmpty && nomorBpjs != '-') ? 'BPJS' : 'Regular';

      await FirebaseFirestore.instance.collection('bookings').add({
        'id_pasien': user.uid,
        'nama_pasien': namaPasien,
        'nomor_bpjs': nomorBpjs,
        'nama_dokter': namaDokter,
        'dokter_uid': dokterUid, 
        'poli': poliDokter,
        'jenis_pasien': jenisPasienOtomatis,
        'status': 'Menunggu Konfirmasi',
        'tanggal_booking': DateTime.now().toString(),
        'created_at': FieldValue.serverTimestamp(),
        'hasil_medis': '', 
      });

      if (mounted) {
        Navigator.pop(context); // Tutup Loading
        Navigator.pop(context); // Tutup Dialog
        Navigator.pop(context); // Tutup BookingPage
        Navigator.pop(context); // Tutup PoliPage
        
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text("Booking Berhasil! ($jenisPasienOtomatis)"))
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal: $e")));
    }
  }

  // --- FUNGSI KONFIRMASI ---
  void _konfirmasiBooking(Map<String, dynamic> dokterData) {
    String namaDokter = _getString(dokterData, 'Nama', 'nama');
    String hari = _getString(dokterData, 'Hari', 'hari');
    String jam = _getString(dokterData, 'Jam', 'jam');
    String fotoUrl = dokterData['foto_url'] ?? ''; 
    
    String jadwal = "$hari ($jam)";

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Konfirmasi Booking"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.blue[100],
                backgroundImage: fotoUrl.isNotEmpty ? NetworkImage(fotoUrl) : null,
                child: fotoUrl.isEmpty ? const Icon(Icons.person, size: 40, color: Colors.blue) : null,
              ),
              const SizedBox(height: 15),
              const Text("Anda akan mendaftar ke:", style: TextStyle(fontSize: 12)),
              const SizedBox(height: 5),
              Text("Dr. $namaDokter", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18), textAlign: TextAlign.center),
              const SizedBox(height: 5),
              Text("Jadwal: $jadwal"),
              const Divider(height: 20),
              
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: Colors.blue.shade200)
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Status Pasien (BPJS/Regular) akan disesuaikan otomatis dengan Profil Anda.",
                        style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
            ElevatedButton(
              onPressed: () => _simpanBooking(dokterData),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
              child: const Text("Ya, Booking"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance.collection('doctors');
    if (widget.poliPilihan != null) {
      query = query.where('Poli', isEqualTo: widget.poliPilihan);
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.poliPilihan ?? "Pilih Dokter"), backgroundColor: Colors.blue, foregroundColor: Colors.white),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          var documents = snapshot.data!.docs;
          if (documents.isEmpty) {
            return Center(child: Text("Tidak ada dokter di ${widget.poliPilihan ?? 'sini'}."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: documents.length,
            itemBuilder: (context, index) {
              var data = documents[index].data() as Map<String, dynamic>;
              
              String namaTampil = _getString(data, 'Nama', 'nama');
              String hariTampil = _getString(data, 'Hari', 'hari');
              String jamTampil = _getString(data, 'Jam', 'jam');
              String fotoUrl = data['foto_url'] ?? ''; 

              // --- CEK STATUS BUKA/TUTUP ---
              bool isOpen = _isDokterBuka(hariTampil, jamTampil);

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 15),
                // Kalau Tutup, warnanya agak abu-abu
                color: isOpen ? Colors.white : Colors.grey[200],
                child: ListTile(
                  contentPadding: const EdgeInsets.all(10),
                  leading: Stack(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: isOpen ? Colors.blue[100] : Colors.grey,
                        backgroundImage: fotoUrl.isNotEmpty ? NetworkImage(fotoUrl) : null,
                        child: fotoUrl.isEmpty ? Icon(Icons.person, size: 30, color: isOpen ? Colors.blue : Colors.white) : null,
                      ),
                      // Badge Merah Kalau Tutup
                      if (!isOpen)
                        Positioned(
                          right: 0, bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                            child: const Icon(Icons.close, size: 15, color: Colors.white),
                          ),
                        )
                    ],
                  ),
                  title: Text(namaTampil, style: TextStyle(fontWeight: FontWeight.bold, color: isOpen ? Colors.black : Colors.grey)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("$hariTampil ($jamTampil)", style: TextStyle(color: isOpen ? Colors.black87 : Colors.grey)),
                      if (!isOpen)
                        const Text(
                          "TUTUP / JADWAL LEWAT", 
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 10)
                        ),
                    ],
                  ),
                  trailing: ElevatedButton(
                    // KUNCI TOMBOL JIKA TUTUP
                    onPressed: isOpen ? () => _konfirmasiBooking(data) : null,
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