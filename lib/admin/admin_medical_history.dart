import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminMedicalHistory extends StatefulWidget {
  const AdminMedicalHistory({super.key});

  @override
  State<AdminMedicalHistory> createState() => _AdminMedicalHistoryState();
}

class _AdminMedicalHistoryState extends State<AdminMedicalHistory> {
  final TextEditingController _searchController = TextEditingController();
  String _keyword = "";
  late Stream<QuerySnapshot> _medicalHistoryStream;

  @override
  void initState() {
    super.initState();
    // KITA HAPUS orderBy DARI QUERY AGAR TIDAK BUTUH INDEX FIREBASE
    // Sorting akan dilakukan secara manual di Client-side (di bawah).
    _medicalHistoryStream = FirebaseFirestore.instance
        .collection('bookings')
        .where('status', isEqualTo: 'Selesai')
        .snapshots();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Helper Format Tanggal
  String _formatDate(String? dateStr) {
    if (dateStr == null) return "-";
    try {
      DateTime dt = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(dt);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          "Data Rekam Medis",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0077B6),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 1. SEARCH BAR
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Cari Nama Pasien / No BPJS...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (val) {
                setState(() {
                  _keyword = val.toLowerCase();
                });
              },
            ),
          ),

          // 2. LIST DATA
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _medicalHistoryStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Terjadi Kesalahan:\n${snapshot.error}",
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Cek konsol debug untuk link pembuatan Index.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var docs = snapshot.data!.docs;

                // Client-side Filtering (Search)
                var filteredDocs = docs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  String nama = (data['nama_pasien'] ?? '')
                      .toString()
                      .toLowerCase();
                  String bpjs = (data['nomor_bpjs'] ?? '')
                      .toString()
                      .toLowerCase();
                  return nama.contains(_keyword) || bpjs.contains(_keyword);
                }).toList();

                // SORTING MANUAL (CLIENT SIDE)
                // Ini solusi bypass agar tidak perlu menunggu Index Firebase dibuat
                filteredDocs.sort((a, b) {
                  var dataA = a.data() as Map<String, dynamic>;
                  var dataB = b.data() as Map<String, dynamic>;
                  String tglA = (dataA['tanggal_booking'] ?? '').toString();
                  String tglB = (dataB['tanggal_booking'] ?? '').toString();
                  return tglB.compareTo(tglA); // Descending (Terbaru di atas)
                });

                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.folder_off_outlined,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Tidak ada data rekam medis.",
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    var data =
                        filteredDocs[index].data() as Map<String, dynamic>;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ExpansionTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        collapsedShape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        backgroundColor: Colors.white,
                        collapsedBackgroundColor: Colors.white,
                        leading: CircleAvatar(
                          backgroundColor: const Color(
                            0xFF00B4D8,
                          ).withOpacity(0.1),
                          child: const Icon(
                            Icons.history_edu,
                            color: Color(0xFF0077B6),
                          ),
                        ),
                        title: Text(
                          data['nama_pasien'] ?? 'Pasien',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Text(
                          "${_formatDate(data['tanggal_booking'])} • ${data['poli']}",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                        children: [
                          Container(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            width: double.infinity,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Divider(),
                                _buildInfoRow("Dokter", data['nama_dokter']),
                                _buildInfoRow("Diagnosa", data['hasil_medis']),
                                _buildInfoRow("Resep Obat", data['resep_obat']),
                                _buildInfoRow(
                                  "Catatan",
                                  data['catatan_dokter'],
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    "No. Antrian: ${data['nomor_antrian'] ?? '-'}",
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Text(": "),
          Expanded(
            child: Text(
              value ?? "-",
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
