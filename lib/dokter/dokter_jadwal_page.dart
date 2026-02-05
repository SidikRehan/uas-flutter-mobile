import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DokterJadwalPage extends StatelessWidget {
  const DokterJadwalPage({super.key});

  // --- HELPER FORMAT HARI ---
  String _formatHari(dynamic rawData) {
    if (rawData is! List) return rawData?.toString() ?? "-";
    List<String> hari = List<String>.from(rawData);
    if (hari.isEmpty) return "-";

    // Urutan hari untuk sorting
    const urutan = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];

    // Sort hari berdasarkan urutan
    hari.sort((a, b) {
      int idxA = urutan.indexOf(a);
      int idxB = urutan.indexOf(b);
      // Handle jika ada hari yg tidak standar, taruh di belakang
      if (idxA == -1) idxA = 99;
      if (idxB == -1) idxB = 99;
      return idxA.compareTo(idxB);
    });

    // Cek range (Contoh: Senin - Rabu)
    if (hari.length > 2) {
      bool isConsecutive = true;
      for (int i = 0; i < hari.length - 1; i++) {
        int idxCurrent = urutan.indexOf(hari[i]);
        int idxNext = urutan.indexOf(hari[i + 1]);
        if (idxNext != idxCurrent + 1) {
          isConsecutive = false;
          break;
        }
      }
      if (isConsecutive) return "${hari.first} - ${hari.last}";
    }

    return hari.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    User? currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Jadwal Praktik"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<QuerySnapshot>(
        // Kita cari data dokter di collection 'doctors' yang uid-nya sama dengan yang login
        future: FirebaseFirestore.instance
            .collection('doctors')
            .where('uid', isEqualTo: currentUser?.uid)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Data jadwal tidak ditemukan."));
          }

          // Ambil data pertama (karena 1 dokter = 1 profil)
          var data = snapshot.data!.docs.first.data() as Map<String, dynamic>;

          // --- PARSE DATA JADWAL (SUPPORT FORMAT LAMA & BARU) ---
          String displayHari = "-";
          if (data['hari_kerja'] != null) {
            displayHari = _formatHari(data['hari_kerja']);
          } else {
            displayHari = data['Hari'] ?? "-";
          }

          String displayJam = "-";
          if (data['jam_buka'] != null && data['jam_tutup'] != null) {
            displayJam = "${data['jam_buka']} - ${data['jam_tutup']}";
          } else {
            displayJam = data['Jam'] ?? "-";
          }

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Jadwal Praktik Anda",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF03045E),
                  ),
                ),
                const SizedBox(height: 16),

                // KARTU JADWAL EXCLUSIVE
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4361EE), Color(0xFF4CC9F0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4361EE).withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Dekorasi lingkaran
                      Positioned(
                        top: -20,
                        right: -20,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -40,
                        left: 10,
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.access_time_filled_rounded,
                              size: 50,
                              color: Colors.white,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              data['Nama'] ?? "Dokter",
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            Container(
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                "Spesialis ${data['Poli'] ?? "-"}",
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Divider(
                                color: Colors.white30,
                                thickness: 1,
                              ),
                            ),

                            // Detail Jadwal
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildInfoColumn(
                                  "HARI",
                                  displayHari, // USE UPDATED VAR
                                  Icons.calendar_today_rounded,
                                ),
                                Container(
                                  width: 1,
                                  height: 40,
                                  color: Colors.white30,
                                ),
                                _buildInfoColumn(
                                  "JAM",
                                  displayJam, // USE UPDATED VAR
                                  Icons.schedule_rounded,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),
                Center(
                  child: Text(
                    "Pastikan hadir tepat waktu\nuntuk pelayanan terbaik.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value, IconData icon) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.white70),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ],
    );
  }
}
