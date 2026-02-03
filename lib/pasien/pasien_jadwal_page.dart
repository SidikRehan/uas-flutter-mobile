import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // Pastikan sudah run: flutter pub add intl

class PasienJadwalPage extends StatefulWidget {
  const PasienJadwalPage({super.key});

  @override
  State<PasienJadwalPage> createState() => _PasienJadwalPageState();
}

class _PasienJadwalPageState extends State<PasienJadwalPage> {
  final User? user = FirebaseAuth.instance.currentUser;

  // --- RUMUS HITUNG ESTIMASI ---
  String _hitungEstimasi(String? jamPraktek, dynamic noAntrian) {
    // 1. Validasi Data Kosong/Salah
    if (jamPraktek == null || noAntrian == null) return "-";
    if (noAntrian.toString().length < 3) return "-"; // Format harus A-00X

    try {
      // 2. Ambil Jam Mulai (Contoh "08:00 - 12:00" -> Ambil "08:00")
      // Jika format jam di database cuma "08:00", kode ini tetap aman
      String jamMulaiStr = jamPraktek.split('-')[0].trim();
      List<String> parts = jamMulaiStr.split(':');
      int startHour = int.parse(parts[0]);
      int startMinute = int.parse(parts[1]);

      // 3. Ambil Angka Antrian (Contoh "A-005" -> Ambil 5)
      // Kita split berdasarkan '-' lalu ambil elemen terakhir
      int urutan = int.parse(noAntrian.toString().split('-').last);

      // 4. Hitung Tambahan Waktu (Estimasi 20 menit per pasien)
      // Pasien pertama (urutan 1) langsung masuk (0 menit tunggu)
      int tambahanMenit = (urutan - 1) * 20;

      // 5. Kalkulasi Waktu
      DateTime now = DateTime.now();
      DateTime jadwalMulai = DateTime(now.year, now.month, now.day, startHour, startMinute);
      DateTime estimasiWaktu = jadwalMulai.add(Duration(minutes: tambahanMenit));

      // 6. Format ke String "09:40"
      return DateFormat('HH:mm').format(estimasiWaktu);
    } catch (e) {
      return "-"; // Return strip jika gagal hitung
    }
  }

  // Helper Warna Status
  Color _getStatusColor(String status) {
    if (status == 'Menunggu Konfirmasi') return Colors.orange;
    if (status == 'Disetujui') return Colors.blue;
    if (status == 'Selesai') return Colors.green;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Jadwal & Antrian Saya"), 
        automaticallyImplyLeading: false, // Hilangkan tombol back jika ini halaman utama tab
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .where('id_pasien', isEqualTo: user?.uid)
            .orderBy('created_at', descending: true) // Yang terbaru paling atas
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          var docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 10),
                  const Text("Belum ada jadwal pemeriksaan.", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              String status = data['status'] ?? 'Menunggu';
              String dokterId = data['dokter_uid'];

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: Column(
                    children: [
                      // --- HEADER KARTU (Nama Dokter & Status) ---
                      Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: Colors.blue, 
                            child: Icon(Icons.medical_services, color: Colors.white)
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(data['nama_dokter'] ?? 'Dokter', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Text("Poli ${data['poli']}", style: const TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ),
                          // Label Status
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(color: _getStatusColor(status).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                            child: Text(status, style: TextStyle(color: _getStatusColor(status), fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ],
                      ),
                      const Divider(height: 25),

                      // --- LOGIKA TAMPILAN BERDASARKAN STATUS ---
                      
                      // KASUS 1: DISETUJUI (Tampilkan No Antrian & Estimasi)
                      if (status == 'Disetujui') 
                        FutureBuilder<DocumentSnapshot>(
                          // Ambil data dokter untuk tahu Jam Bukanya
                          future: FirebaseFirestore.instance.collection('doctors').doc(dokterId).get(),
                          builder: (context, snapshotDoc) {
                            String estimasiJam = "...";
                            
                            if (snapshotDoc.hasData && snapshotDoc.data!.exists) {
                              var docData = snapshotDoc.data!.data() as Map<String, dynamic>;
                              // Prioritaskan 'jam_buka', kalau kosong coba 'Jam', kalau kosong default 08:00
                              String jadwalStr = docData['jam_buka'] ?? docData['Jam'] ?? "08:00"; 
                              
                              // HITUNG ESTIMASI DISINI
                              estimasiJam = _hitungEstimasi(jadwalStr, data['nomor_antrian']);
                            }

                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Kolom Kiri: Nomor Antrian
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("Nomor Antrian", style: TextStyle(color: Colors.grey, fontSize: 12)),
                                    Text(data['nomor_antrian'] ?? '-', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blue)),
                                  ],
                                ),
                                // Kolom Kanan: Kotak Estimasi Waktu
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.orange[50], 
                                    borderRadius: BorderRadius.circular(10), 
                                    border: Border.all(color: Colors.orange.shade200)
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(Icons.access_time_filled, size: 14, color: Colors.orange),
                                          SizedBox(width: 5),
                                          Text("Estimasi Panggilan", style: TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                      const SizedBox(height: 5),
                                      // HASIL ESTIMASI
                                      Text("$estimasiJam WIB", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                                    ],
                                  ),
                                )
                              ],
                            );
                          }
                        )
                      
                      // KASUS 2: MENUNGGU (Belum dapat antrian)
                      else if (status == 'Menunggu Konfirmasi')
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                          child: const Text(
                            "Menunggu konfirmasi Admin.\nNomor antrian akan muncul setelah disetujui.", 
                            style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey, fontSize: 12), 
                            textAlign: TextAlign.center
                          ),
                        )
                      
                      // KASUS 3: SELESAI
                      else if (status == 'Selesai')
                         Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(8)),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle, color: Colors.green, size: 20),
                              SizedBox(width: 8),
                              Text("Pemeriksaan Selesai", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                            ],
                          ),
                        )
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