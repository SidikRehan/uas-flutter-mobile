import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
// PENTING: Tambahkan ini untuk format tanggal Indonesia
import 'package:intl/date_symbol_data_local.dart';

class PasienJadwalPage extends StatefulWidget {
  const PasienJadwalPage({super.key});

  @override
  State<PasienJadwalPage> createState() => _PasienJadwalPageState();
}

class _PasienJadwalPageState extends State<PasienJadwalPage> {
  final User? user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    // Inisialisasi format tanggal Indonesia
    initializeDateFormatting('id_ID', null);
  }

  // --- RUMUS HITUNG ESTIMASI (DENGAN TANGGAL) ---
  String _hitungEstimasi(String? jamPraktek, dynamic noAntrian) {
    if (jamPraktek == null || noAntrian == null) return "-";
    if (noAntrian.toString().length < 3) return "-";

    try {
      // 1. Ambil Jam Buka Dokter (Contoh: "08:00")
      String jamMulaiStr = jamPraktek.contains('-')
          ? jamPraktek.split('-')[0].trim()
          : jamPraktek.trim();
      List<String> parts = jamMulaiStr.split(':');
      int startHour = int.parse(parts[0]);
      int startMinute = int.parse(parts[1]);

      // 2. Ambil Urutan Antrian (A-004 -> 4)
      int urutan = int.parse(noAntrian.toString().split('-').last);

      // 3. LOGIKA DURASI PER PASIEN (Bisa Anda Ganti Angkanya)
      int durasiPerPasien =
          20; // <--- GANTI ANGKA INI JIKA MAU 15 ATAU 30 MENIT

      int tambahanMenit = (urutan - 1) * durasiPerPasien;

      // 4. Kalkulasi Waktu
      DateTime now = DateTime.now();
      // Kita asumsikan jadwalnya adalah HARI INI jam sekian
      DateTime jadwalMulai = DateTime(
        now.year,
        now.month,
        now.day,
        startHour,
        startMinute,
      );

      // Tambahkan estimasi antrian
      DateTime estimasiWaktu = jadwalMulai.add(
        Duration(minutes: tambahanMenit),
      );

      // 5. Format Output: "Selasa, 10 Feb • 08:20"
      return DateFormat('EEEE, d MMM • HH:mm', 'id_ID').format(estimasiWaktu);
    } catch (e) {
      return "-";
    }
  }

  Color _getStatusColor(String status) {
    if (status == 'Menunggu Konfirmasi') return Colors.orange;
    if (status == 'Disetujui') return Colors.green;
    if (status == 'Selesai') return Colors.blue;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Antrian & Estimasi"),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .where('uid_pasien', isEqualTo: user?.uid)
            // .orderBy('created_at', descending: true) // HAPUS INI BIAR GAK PERLU INDEX
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          var docs = snapshot.data!.docs;

          // SORTING MANUAL CLIENT-SIDE
          docs.sort((a, b) {
            var dataA = a.data() as Map<String, dynamic>;
            var dataB = b.data() as Map<String, dynamic>;
            // Bandingkan created_at (descending)
            Timestamp tA = dataA['created_at'] ?? Timestamp.now();
            Timestamp tB = dataB['created_at'] ?? Timestamp.now();
            return tB.compareTo(tA);
          });

          if (docs.isEmpty) {
            return const Center(child: Text("Belum ada antrian."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              String status = data['status'] ?? 'Menunggu';
              String dokterId = data['dokter_uid'];

              return Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      // HEADER
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_month,
                            color: Colors.blue,
                            size: 30,
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['nama_dokter'] ?? 'Dokter',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  "Poli ${data['poli']}",
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          Chip(
                            label: Text(
                              status,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                            backgroundColor: _getStatusColor(status),
                          ),
                        ],
                      ),
                      const Divider(height: 25, thickness: 1),

                      // TAMPILAN ESTIMASI
                      if (status == 'Disetujui')
                        FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('doctors')
                              .doc(dokterId)
                              .get(),
                          builder: (context, snapshotDoc) {
                            String estimasiLengkap = "...";

                            if (snapshotDoc.hasData &&
                                snapshotDoc.data!.exists) {
                              var docData =
                                  snapshotDoc.data!.data()
                                      as Map<String, dynamic>;
                              String jamBuka =
                                  docData['jam_buka'] ??
                                  docData['Jam'] ??
                                  "08:00";

                              estimasiLengkap = _hitungEstimasi(
                                jamBuka,
                                data['nomor_antrian'],
                              );
                            }

                            return Column(
                              children: [
                                // BARIS 1: NO ANTRIAN
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Column(
                                      children: [
                                        const Text(
                                          "NOMOR ANTRIAN",
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey,
                                            letterSpacing: 1.5,
                                          ),
                                        ),
                                        Text(
                                          data['nomor_antrian'] ?? '-',
                                          style: const TextStyle(
                                            fontSize: 48,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 15),

                                // BARIS 2: KOTAK ESTIMASI WAKTU LENGKAP
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.orange[50],
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.orange.withOpacity(0.5),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.timer_outlined,
                                            size: 16,
                                            color: Colors.deepOrange,
                                          ),
                                          SizedBox(width: 5),
                                          Text(
                                            "ESTIMASI DIPANGGIL",
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.deepOrange,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 5),
                                      // TAMPILAN HARI, TANGGAL & JAM
                                      Text(
                                        estimasiLengkap,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 2),
                                      const Text(
                                        "(Harap datang 15 menit sebelumnya)",
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        )
                      else if (status == 'Menunggu Konfirmasi')
                        const Text(
                          "Menunggu persetujuan Admin...",
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.grey,
                          ),
                        )
                      else
                        const Text(
                          "Pemeriksaan Selesai",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                    ],
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
