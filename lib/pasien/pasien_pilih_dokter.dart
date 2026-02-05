import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class PasienPilihDokter extends StatefulWidget {
  final String namaPoli;
  const PasienPilihDokter({super.key, required this.namaPoli});

  @override
  State<PasienPilihDokter> createState() => _PasienPilihDokterState();
}

class _PasienPilihDokterState extends State<PasienPilihDokter> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Konfigurasi Kuota Harian
  final int BATAS_KUOTA_HARIAN = 20;

  // --- 1. LOGIKA CEK STATUS BUKA/TUTUP (DIPERBAIKI) ---
  bool _isDokterSedangPraktek(Map<String, dynamic> data) {
    try {
      DateTime now = DateTime.now();
      String hariIni = _getNamaHariIni(now);
      // Konversi jam sekarang ke desimal (Contoh 20:30 jadi 20.5)
      double jamSekarang = now.hour + (now.minute / 60.0);

      // A. Cek Hari Kerja
      bool isHariMasuk = false;
      if (data['hari_kerja'] is List) {
        // Data Baru (List)
        List<dynamic> hariKerja = data['hari_kerja'];
        if (hariKerja.contains(hariIni)) isHariMasuk = true;
      } else {
        // Data Lama / Fallback (Asumsi buka tiap hari atau string)
        // Kita anggap True dulu, biar difilter oleh Jam
        isHariMasuk = true;
      }

      if (!isHariMasuk) return false; // Salah Hari -> Tutup

      // B. Cek Jam (Support Data Baru & Lama)
      double jamBuka = 0.0;
      double jamTutup = 0.0;

      if (data['jam_buka'] != null && data['jam_tutup'] != null) {
        // FORMAT BARU: Field terpisah
        TimeOfDay buka = _parseTime(data['jam_buka']);
        TimeOfDay tutup = _parseTime(data['jam_tutup']);
        jamBuka = buka.hour + (buka.minute / 60.0);
        jamTutup = tutup.hour + (tutup.minute / 60.0);
      } else if (data['Jam'] != null) {
        // FORMAT LAMA: String "08:00 - 15:00"
        var parts = data['Jam'].toString().split('-');
        if (parts.length == 2) {
          TimeOfDay buka = _parseTime(parts[0].trim());
          TimeOfDay tutup = _parseTime(parts[1].trim());
          jamBuka = buka.hour + (buka.minute / 60.0);
          jamTutup = tutup.hour + (tutup.minute / 60.0);
        }
      }

      // C. Bandingkan Jam
      // Jika jam data kosong/salah (0.0), kita return False (Tutup) biar aman
      if (jamBuka == 0.0 && jamTutup == 0.0) return false;

      // Logika Inti: Sekarang >= Buka DAN Sekarang < Tutup
      return jamSekarang >= jamBuka && jamSekarang < jamTutup;
    } catch (e) {
      // PENTING: Jika error membaca data, anggap TUTUP (Safety First)
      print("Error cek jadwal: $e");
      return false;
    }
  }

  // --- 2. LOGIKA UTAMA: CEK KUOTA & TENTUKAN TANGGAL ---
  void _prosesSmartBooking(
    String dokterId,
    String namaDokter,
    bool isSedangBuka,
  ) async {
    User? user = _auth.currentUser;
    if (user == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Cek Antrian Gantung
      var cekDouble = await FirebaseFirestore.instance
          .collection('bookings')
          .where('id_pasien', isEqualTo: user.uid)
          .where(
            'status',
            whereIn: [
              'Menunggu Konfirmasi',
              'Disetujui',
              'Menunggu Pembayaran',
            ],
          )
          .get();

      if (cekDouble.docs.isNotEmpty) {
        if (mounted) Navigator.pop(context);
        _showWarningDialog("Anda masih memiliki antrian aktif.");
        return;
      }

      DateTime now = DateTime.now();
      String tanggalHariIni = DateFormat('yyyy-MM-dd').format(now);

      // Default Logic
      DateTime tanggalJadwal;
      String pesanKonfirmasi;

      // LOGIKA PENENTUAN:
      if (isSedangBuka) {
        // Dokter BUKA, Cek Kuota dulu
        var cekKuota = await FirebaseFirestore.instance
            .collection('bookings')
            .where('dokter_uid', isEqualTo: dokterId)
            .where('tanggal_jadwal', isEqualTo: tanggalHariIni)
            .count()
            .get();

        int jumlahPasien = cekKuota.count ?? 0;

        if (jumlahPasien < BATAS_KUOTA_HARIAN) {
          // KASUS 1: BUKA & KUOTA ADA -> Masuk Hari Ini
          tanggalJadwal = now;
          pesanKonfirmasi =
              "Kuota Tersedia ($jumlahPasien/$BATAS_KUOTA_HARIAN). Anda akan masuk antrian HARI INI.";
        } else {
          // KASUS 2: BUKA TAPI PENUH -> Lempar Besok
          tanggalJadwal = now.add(const Duration(days: 1));
          pesanKonfirmasi =
              "Kuota Hari Ini PENUH. Anda dialihkan ke antrian BESOK.";
        }
      } else {
        // KASUS 3: TUTUP -> Lempar Besok
        tanggalJadwal = now.add(const Duration(days: 1));
        pesanKonfirmasi =
            "Dokter sedang tutup/diluar jam. Anda akan masuk antrian BESOK.";
      }

      if (mounted) Navigator.pop(context);

      _showKonfirmasiAkhir(
        dokterId,
        namaDokter,
        tanggalJadwal,
        pesanKonfirmasi,
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  void _showKonfirmasiAkhir(
    String dokterId,
    String namaDokter,
    DateTime jadwalFix,
    String pesan,
  ) {
    final keluhanCtrl = TextEditingController();
    String tglStr = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(jadwalFix);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Konfirmasi Jadwal"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: pesan.contains("PENUH") || pesan.contains("tutup")
                      ? Colors.orange[100]
                      : Colors.green[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  pesan,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Text(
                "Dokter: $namaDokter",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                "Jadwal: $tglStr",
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: keluhanCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: "Keluhan Utama",
                  hintText: "Contoh: Demam...",
                  border: OutlineInputBorder(),
                ),
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
            onPressed: () {
              if (keluhanCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Isi keluhan dulu!")),
                );
                return;
              }
              Navigator.pop(context);
              _simpanKeDatabase(
                dokterId,
                namaDokter,
                keluhanCtrl.text,
                jadwalFix,
              );
            },
            child: const Text("Ambil Antrian"),
          ),
        ],
      ),
    );
  }

  void _simpanKeDatabase(
    String dokterId,
    String namaDokter,
    String keluhan,
    DateTime jadwalFix,
  ) async {
    User? user = _auth.currentUser;
    if (user == null) return;

    String tanggalJadwalStr = DateFormat('yyyy-MM-dd').format(jadwalFix);

    try {
      var userDoc = await FirebaseFirestore.instance
          .collection('pasiens')
          .doc(user.uid)
          .get();
      Map<String, dynamic> userData = userDoc.exists ? userDoc.data()! : {};
      if (!userDoc.exists) {
        var docUser = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        userData = docUser.exists ? docUser.data()! : {};
      }
      String jenis =
          (userData['nomor_bpjs'] != null &&
              userData['nomor_bpjs'].toString().length > 3)
          ? 'BPJS'
          : 'Regular';

      await FirebaseFirestore.instance.collection('bookings').add({
        'id_pasien': user.uid,
        'nama_pasien': userData['nama'] ?? 'Pasien',
        'nomor_bpjs': userData['nomor_bpjs'] ?? '-',
        'keluhan': keluhan,
        'dokter_uid': dokterId,
        'nama_dokter': namaDokter,
        'poli': widget.namaPoli,
        'jenis_pasien': jenis,
        'status': 'Menunggu Konfirmasi',
        'created_at': FieldValue.serverTimestamp(),
        'tanggal_jadwal': tanggalJadwalStr,
        'biaya': '0',
        'resep_obat': '-',
        'nomor_antrian': null,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Berhasil! Cek menu Antrian."),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Gagal: $e")));
    }
  }

  void _showWarningDialog(String msg) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Info"),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("Oke"),
          ),
        ],
      ),
    );
  }

  TimeOfDay _parseTime(String timeStr) {
    try {
      // Bersihkan string dari spasi aneh
      String cleanTime = timeStr.trim();
      List<String> parts = cleanTime.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (e) {
      return const TimeOfDay(hour: 0, minute: 0);
    }
  }

  String _getNamaHariIni(DateTime date) {
    int weekday = date.weekday;
    const hari = [
      "Senin",
      "Selasa",
      "Rabu",
      "Kamis",
      "Jumat",
      "Sabtu",
      "Minggu",
    ];
    return hari[weekday - 1];
  }

  String _formatJadwalPintar(dynamic rawData) {
    if (rawData is! List) return rawData.toString();
    List<String> hari = List<String>.from(rawData);
    if (hari.isEmpty) return "-";
    const urutan = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    hari.sort((a, b) => urutan.indexOf(a).compareTo(urutan.indexOf(b)));
    return (hari.length > 2) ? "${hari.first} - ${hari.last}" : hari.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Pilih Dokter ${widget.namaPoli}")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('doctors')
            .where('Poli', isEqualTo: widget.namaPoli)
            .where('is_active', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          var docs = snapshot.data!.docs;
          if (docs.isEmpty)
            return const Center(child: Text("Belum ada dokter aktif."));

          return ListView.builder(
            itemCount: docs.length,
            padding: const EdgeInsets.all(10),
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;

              // CEK APAKAH DOKTER SEDANG PRAKTEK
              bool isBuka = _isDokterSedangPraktek(data);

              String jadwalHari = (data['hari_kerja'] is List)
                  ? _formatJadwalPintar(data['hari_kerja'])
                  : (data['Hari'] ?? '-');
              String jadwalJam = (data['jam_buka'] != null)
                  ? "${data['jam_buka']} - ${data['jam_tutup']}"
                  : (data['Jam'] ?? '-');

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.1),
                      blurRadius: 15,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _prosesSmartBooking(
                      docs[index].id,
                      data['Nama'] ?? 'Dokter',
                      isBuka,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  color: isBuka
                                      ? Colors.blue[50]
                                      : Colors.orange[50],
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.person,
                                  size: 35,
                                  color: isBuka ? Colors.blue : Colors.orange,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data['Nama'] ?? 'Dokter',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      widget.namaPoli,
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isBuka
                                            ? Colors.green[50]
                                            : Colors.red[50],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        isBuka ? "Sedang Praktek" : "Tutup",
                                        style: TextStyle(
                                          color: isBuka
                                              ? Colors.green[700]
                                              : Colors.red[700],
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Divider(),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Jadwal",
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 11,
                                    ),
                                  ),
                                  Text(
                                    jadwalHari,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    "Jam",
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 11,
                                    ),
                                  ),
                                  Text(
                                    jadwalJam,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => _prosesSmartBooking(
                                docs[index].id,
                                data['Nama'] ?? 'Dokter',
                                isBuka,
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isBuka
                                    ? const Color(0xFF0077B6)
                                    : Colors.grey,
                              ),
                              child: Text(
                                isBuka
                                    ? "Daftar Sekarang"
                                    : "Booking untuk Besok",
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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
