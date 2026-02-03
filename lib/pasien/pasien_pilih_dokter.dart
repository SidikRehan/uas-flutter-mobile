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

  // --- 2. LOGIKA BOOKING (Input Keluhan & Cek Double Booking) ---
  void _cekDanProsesBooking(String dokterId, String namaDokter) async {
    User? user = _auth.currentUser;
    if (user == null) return;
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));

    try {
      // Cek apakah ada bookingan aktif?
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
        // Tampilkan Popup Input Keluhan
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

  // DIALOG KONFIRMASI + INPUT KELUHAN
  void _showKonfirmasiBooking(String dokterId, String namaDokter) {
    final keluhanCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Formulir Pendaftaran"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Dokter: $namaDokter", style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            const Text("Keluhan Utama:", style: TextStyle(fontSize: 12, color: Colors.grey)),
            TextField(
              controller: keluhanCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: "Contoh: Demam tinggi sudah 3 hari, pusing...",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(
            onPressed: () {
              if (keluhanCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Isi keluhan dulu!")));
                return;
              }
              Navigator.pop(context); 
              _simpanBookingKeFirebase(dokterId, namaDokter, keluhanCtrl.text); // Kirim Keluhan
            },
            child: const Text("Daftar Antrian"),
          ),
        ],
      ),
    );
  }

  void _simpanBookingKeFirebase(String dokterId, String namaDokter, String keluhan) async {
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
        // DATA BARU:
        'keluhan': keluhan, 
        'jenis_kelamin': userData['jenis_kelamin'] ?? '-',
        'umur': _hitungUmur(userData['tanggal_lahir'] ?? '-'),
        'alamat': userData['alamat'] ?? '-',
        // ---------
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

  // --- HELPER FUNCTIONS ---
  String _hitungUmur(String tgl) {
    if (tgl == '-' || tgl.isEmpty) return '-';
    try {
      int age = DateTime.now().year - DateTime.parse(tgl).year;
      return "$age Thn";
    } catch (e) { return '-'; }
  }

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

  String _formatJadwalPintar(dynamic rawData) {
    if (rawData is! List) return rawData.toString();
    List<String> hari = List<String>.from(rawData);
    if (hari.isEmpty) return "-";

    const urutan = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    hari.sort((a, b) => urutan.indexOf(a).compareTo(urutan.indexOf(b)));

    bool berurutan = true;
    for (int i = 0; i < hari.length - 1; i++) {
      if (urutan.indexOf(hari[i+1]) != urutan.indexOf(hari[i]) + 1) {
        berurutan = false;
        break;
      }
    }

    if (berurutan && hari.length > 2) {
      return "${hari.first} - ${hari.last}";
    } else {
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
            .where('is_active', isEqualTo: true) // <--- HANYA DOKTER AKTIF YG MUNCUL
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          var docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text("Belum ada dokter aktif."));

          return ListView.builder(
            itemCount: docs.length,
            padding: const EdgeInsets.all(10),
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              bool isBuka = _isDokterBuka(data); 

              String jadwalHari = (data['hari_kerja'] is List) ? _formatJadwalPintar(data['hari_kerja']) : (data['Hari'] ?? '-');
              String jadwalJam = (data['jam_buka'] != null) ? "${data['jam_buka']} - ${data['jam_tutup']}" : (data['Jam'] ?? '-');

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