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
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- 1. LOGIKA CEK JADWAL REAL-TIME ---
  bool _isDokterBuka(Map<String, dynamic> data) {
    try {
      DateTime now = DateTime.now();
      String hariIni = _getNamaHariIni(); 
      double jamSekarang = now.hour + (now.minute / 60.0);

      if (data['hari_kerja'] is List) {
        List<dynamic> hariKerja = data['hari_kerja'];
        if (!hariKerja.contains(hariIni)) return false; 

        TimeOfDay buka = _parseTime(data['jam_buka'] ?? "00:00");
        TimeOfDay tutup = _parseTime(data['jam_tutup'] ?? "23:59");
        
        double jamBuka = buka.hour + (buka.minute / 60.0);
        double jamTutup = tutup.hour + (tutup.minute / 60.0);

        return jamSekarang >= jamBuka && jamSekarang < jamTutup;
      } else if (data['Jam'] != null && data['Jam'].toString().contains('-')) {
         // Support Data Lama
         var parts = data['Jam'].toString().split('-');
         TimeOfDay buka = _parseTime(parts[0].trim());
         TimeOfDay tutup = _parseTime(parts[1].trim());
         double jamBuka = buka.hour + (buka.minute / 60.0);
         double jamTutup = tutup.hour + (tutup.minute / 60.0);
         return jamSekarang >= jamBuka && jamSekarang < jamTutup;
      }
      return true;
    } catch (e) {
      return true; 
    }
  }

  // --- 2. LOGIKA BOOKING (Sama seperti sebelumnya) ---
  void _cekDanProsesBooking(String dokterId, String namaDokter) async {
    User? user = _auth.currentUser;
    if (user == null) return;
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));

    try {
      var cekBooking = await FirebaseFirestore.instance
          .collection('bookings')
          .where('id_pasien', isEqualTo: user.uid)
          .where('status', whereIn: ['Menunggu Konfirmasi', 'Disetujui', 'Menunggu Pembayaran'])
          .get();

      if (mounted) Navigator.pop(context);

      if (cekBooking.docs.isNotEmpty) {
        var dataLama = cekBooking.docs.first.data();
        _showWarningDialog(dataLama['nama_dokter'] ?? 'Lain');
      } else {
        _showKonfirmasiBooking(dokterId, namaDokter);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  void _showWarningDialog(String dokterLama) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Gagal Booking", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Text("Anda masih memiliki antrian aktif dengan $dokterLama.\nSelesaikan dulu sebelum booking baru.", textAlign: TextAlign.center),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Mengerti"))],
      ),
    );
  }

  void _showKonfirmasiBooking(String dokterId, String namaDokter) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Konfirmasi"),
        content: Text("Mendaftar ke $namaDokter?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); _simpanBookingKeFirebase(dokterId, namaDokter); },
            child: const Text("Ya, Daftar"),
          ),
        ],
      ),
    );
  }

  void _simpanBookingKeFirebase(String dokterId, String namaDokter) async {
    User? user = _auth.currentUser;
    if (user == null) return;
    try {
      var userDoc = await FirebaseFirestore.instance.collection('pasiens').doc(user.uid).get();
      Map<String, dynamic> userData = userDoc.exists ? userDoc.data()! : {};
      
      if (!userDoc.exists) {
         var docUser = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
         userData = docUser.exists ? docUser.data()! : {};
      }
      
      String jenis = (userData['nomor_bpjs'] != null && userData['nomor_bpjs'].toString().length > 3) ? 'BPJS' : 'Regular';

      await FirebaseFirestore.instance.collection('bookings').add({
        'id_pasien': user.uid,
        'nama_pasien': userData['nama'] ?? 'Pasien',
        'nomor_bpjs': userData['nomor_bpjs'] ?? '-',
        'dokter_uid': dokterId,
        'nama_dokter': namaDokter,
        'poli': widget.namaPoli,
        'jenis_pasien': jenis,
        'status': 'Menunggu Konfirmasi',
        'tanggal_booking': DateTime.now().toString(),
        'created_at': FieldValue.serverTimestamp(),
        'biaya': '0', 'resep_obat': '-', 'nomor_antrian': null,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Berhasil Mendaftar!"), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal: $e")));
    }
  }

  // --- HELPER TIME ---
  TimeOfDay _parseTime(String timeStr) {
    try {
      List<String> parts = timeStr.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (e) { return const TimeOfDay(hour: 0, minute: 0); }
  }

  String _getNamaHariIni() {
    int weekday = DateTime.now().weekday;
    const hari = ["Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu", "Minggu"];
    return hari[weekday - 1];
  }

  // --- [FITUR BARU] HELPER FORMAT HARI PINTAR ---
  String _formatJadwalPintar(dynamic rawData) {
    if (rawData is! List) return rawData.toString(); // Kalau format lama, kembalikan string aslinya
    
    List<String> hari = List<String>.from(rawData);
    if (hari.isEmpty) return "-";

    // Urutan Hari Standar
    const urutan = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    
    // Urutkan hari berdasarkan urutan minggu (biar Senin selalu duluan)
    hari.sort((a, b) => urutan.indexOf(a).compareTo(urutan.indexOf(b)));

    // Cek apakah hari berurutan? (Contoh: Senin, Selasa, Rabu)
    bool berurutan = true;
    for (int i = 0; i < hari.length - 1; i++) {
      int indexSekarang = urutan.indexOf(hari[i]);
      int indexBerikut = urutan.indexOf(hari[i+1]);
      if (indexBerikut != indexSekarang + 1) {
        berurutan = false;
        break;
      }
    }

    // Jika Berurutan dan lebih dari 2 hari -> Pakai Strip "-"
    if (berurutan && hari.length > 2) {
      return "${hari.first} - ${hari.last}";
    } 
    // Jika cuma 2 hari atau acak (Senin, Kamis) -> Pakai Koma
    else {
      return hari.join(', ');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Dokter ${widget.namaPoli}")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('doctors')
            .where('Poli', isEqualTo: widget.namaPoli)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          var docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text("Belum ada dokter."));

          return ListView.builder(
            itemCount: docs.length,
            padding: const EdgeInsets.all(10),
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              bool isBuka = _isDokterBuka(data); 

              // --- GUNAKAN FORMATTER PINTAR DI SINI ---
              String jadwalHari = "";
              if (data['hari_kerja'] is List) {
                 jadwalHari = _formatJadwalPintar(data['hari_kerja']); // <--- INI PERUBAHANNYA
              } else {
                 jadwalHari = data['Hari'] ?? '-';
              }

              String jadwalJam = "";
              if (data['jam_buka'] != null) {
                jadwalJam = "${data['jam_buka']} - ${data['jam_tutup']}";
              } else {
                jadwalJam = data['Jam'] ?? '-';
              }

              return Card(
                color: isBuka ? Colors.white : Colors.grey[200],
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isBuka ? Colors.blue[100] : Colors.grey[300],
                    child: Icon(Icons.person, color: isBuka ? Colors.blue : Colors.grey),
                  ),
                  title: Text(data['Nama'] ?? 'Dokter', style: TextStyle(fontWeight: FontWeight.bold, color: isBuka ? Colors.black : Colors.grey)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("$jadwalHari ($jadwalJam)"),
                      if (!isBuka)
                        Container(
                          margin: const EdgeInsets.only(top: 5),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.red[100], borderRadius: BorderRadius.circular(4)),
                          child: const Text("SEDANG TUTUP (Diluar Jam Praktik)", style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  trailing: ElevatedButton(
                    onPressed: isBuka ? () => _cekDanProsesBooking(docs[index].id, data['Nama'] ?? 'Dokter') : null,
                    style: ElevatedButton.styleFrom(backgroundColor: isBuka ? Colors.blue : Colors.grey, foregroundColor: Colors.white),
                    child: Text(isBuka ? "Pilih" : "Tutup"),
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