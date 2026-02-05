import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Pastikan sudah run: flutter pub add intl
import 'package:flutter/services.dart'; // Untuk LengthLimitingTextInputFormatter

class DokterPemeriksaanPage extends StatefulWidget {
  final String bookingId;
  final Map<String, dynamic> dataPasien;

  const DokterPemeriksaanPage({
    super.key,
    required this.bookingId,
    required this.dataPasien,
  });

  @override
  State<DokterPemeriksaanPage> createState() => _DokterPemeriksaanPageState();
}

class _DokterPemeriksaanPageState extends State<DokterPemeriksaanPage> {
  // Controller Form Medis
  final _diagnosaController = TextEditingController();
  final _resepController = TextEditingController();
  final _catatanController = TextEditingController();

  // Controller Biaya (Rincian)
  final _jasaDokterController = TextEditingController();
  final _biayaAdminController = TextEditingController();
  final _biayaOpsController = TextEditingController();
  final _totalBiayaController = TextEditingController();

  bool isBPJS = false;

  @override
  void initState() {
    super.initState();
    _cekStatusDanBiaya();
    // Listener: Hitung total otomatis setiap kali jasa dokter diubah
    _jasaDokterController.addListener(_hitungTotalOtomatis);
  }

  @override
  void dispose() {
    _jasaDokterController.removeListener(_hitungTotalOtomatis);
    _diagnosaController.dispose();
    _resepController.dispose();
    _catatanController.dispose();
    _jasaDokterController.dispose();
    _biayaAdminController.dispose();
    _biayaOpsController.dispose();
    _totalBiayaController.dispose();
    super.dispose();
  }

  // --- 1. LOGIKA STATUS PASIEN & BIAYA AWAL ---
  void _cekStatusDanBiaya() {
    String jenis = widget.dataPasien['jenis_pasien'] ?? 'Regular';

    setState(() {
      if (jenis == 'BPJS') {
        isBPJS = true;
        _jasaDokterController.text = '0';
        _biayaAdminController.text = '0';
        _biayaOpsController.text = '0';
        _totalBiayaController.text = '0';
      } else {
        isBPJS = false;
        // Default Biaya Non-BPJS
        _jasaDokterController.text = '50000'; // Jasa Dokter Default
        _biayaAdminController.text = '20000'; // Admin Tetap
        _biayaOpsController.text = '30000'; // Operasional Tetap
        _hitungTotalOtomatis(); // Hitung Total Awal
      }
    });
  }

  // --- 2. RUMUS TOTAL BIAYA ---
  void _hitungTotalOtomatis() {
    if (isBPJS) return;

    // Parsing aman (cegah error jika kosong)
    int jasaDokter = int.tryParse(_jasaDokterController.text) ?? 0;
    int admin = int.tryParse(_biayaAdminController.text) ?? 0;
    int ops = int.tryParse(_biayaOpsController.text) ?? 0;

    int total = jasaDokter + admin + ops;
    _totalBiayaController.text = total.toString();
  }

  // --- 3. HELPER FORMAT TANGGAL INDO ---
  String _formatTanggalIndo(String rawDate) {
    try {
      DateTime dt = DateTime.parse(rawDate);
      // Format: Senin, 2 Feb 2026
      return DateFormat('EEEE, d MMM yyyy', 'id_ID').format(dt);
    } catch (e) {
      return rawDate;
    }
  }

  // --- 4. POPUP RIWAYAT ---
  void _lihatRiwayatKunjungan() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Riwayat Rekam Medis",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(thickness: 2),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('bookings')
                      .where(
                        'id_pasien',
                        isEqualTo: widget.dataPasien['id_pasien'],
                      )
                      .where('status', isEqualTo: 'Selesai')
                      // .orderBy(...) <--- Dihapus sementara agar tidak butuh Index
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    var docs = snapshot.data!.docs;

                    if (docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history_edu,
                              size: 60,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 10),
                            const Text("Belum ada riwayat kunjungan."),
                            const SizedBox(height: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green[100],
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: const Text(
                                "PASIEN BARU",
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        var data = docs[index].data() as Map<String, dynamic>;
                        if (docs[index].id == widget.bookingId) {
                          return const SizedBox();
                        }

                        String tglIndo = _formatTanggalIndo(
                          data['tanggal_booking'].toString().substring(0, 10),
                        );
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            title: Text(
                              tglIndo,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              "Diagnosa: ${data['hasil_medis']}\nObat: ${data['resep_obat']}",
                            ),
                            trailing: Text(data['poli'] ?? '-'),
                            isThreeLine: true,
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
      },
    );
  }

  // --- 5. FUNGSI SIMPAN & VALIDASI ---
  void _simpanPemeriksaan() async {
    // A. Validasi Form Medis
    if (_diagnosaController.text.isEmpty || _resepController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Mohon lengkapi Diagnosa dan Resep.")),
      );
      return;
    }

    // B. Validasi Biaya (Hanya Non-BPJS)
    if (!isBPJS) {
      int jasaDokter = int.tryParse(_jasaDokterController.text) ?? 0;
      if (jasaDokter < 30000) {
        _showErrorDialog(
          "Biaya Terlalu Rendah",
          "Minimal Jasa Dokter adalah Rp 30.000",
        );
        return;
      }
      if (jasaDokter > 100000) {
        _showErrorDialog(
          "Biaya Terlalu Tinggi",
          "Maksimal Jasa Dokter adalah Rp 100.000",
        );
        return;
      }
    }

    // C. Simpan ke Firestore
    try {
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.bookingId)
          .update({
            'hasil_medis': _diagnosaController.text,
            'resep_obat': _resepController.text,
            'catatan_dokter': _catatanController.text,

            // Rincian Biaya
            'biaya_jasa_dokter': _jasaDokterController.text,
            'biaya_admin': _biayaAdminController.text,
            'biaya_ops': _biayaOpsController.text,
            'biaya': _totalBiayaController.text,

            'status': 'Menunggu Pembayaran',
            'selesai_pada': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Pemeriksaan Selesai!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // Kembali ke Dashboard
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  void _showErrorDialog(String title, String msg) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title, style: const TextStyle(color: Colors.red)),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("Perbaiki"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var pasien = widget.dataPasien;

    // Cek error validasi live (untuk warna merah di textfield)
    int jasaVal = int.tryParse(_jasaDokterController.text) ?? 0;
    bool jasaError = !isBPJS && (jasaVal > 100000);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Clean Background
      appBar: AppBar(
        title: const Text(
          "Pemeriksaan Pasien",
          style: TextStyle(
            color: Color(0xFF023E8A),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0077B6)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KARTU INFO PASIEN
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isBPJS
                    ? Colors.green[50]
                    : const Color(0xFF0077B6).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isBPJS
                      ? Colors.green.withValues(alpha: 0.3)
                      : const Color(0xFF0077B6).withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: isBPJS
                        ? Colors.green
                        : const Color(0xFF0077B6),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pasien['nama_pasien'],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: isBPJS
                                ? Colors.green[800]
                                : const Color(0xFF023E8A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isBPJS
                                ? "PASIEN BPJS DOMPET SEHAT (GRATIS)"
                                : "PASIEN UMUM (Wajib Bayar)",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isBPJS
                                  ? Colors.green
                                  : const Color(0xFF0077B6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // TOMBOL RIWAYAT
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _lihatRiwayatKunjungan,
                icon: Icon(Icons.history_edu_rounded, color: Colors.grey[700]),
                label: Text(
                  "LIHAT RIWAYAT MEDIS",
                  style: TextStyle(
                    color: Colors.grey[800],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey[300]!),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // SECTION: FORMULIR MEDIS
            const Text(
              "📝 Formulir Medis",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Color(0xFF03045E),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildModernTextField(
                    controller: _diagnosaController,
                    label: "Diagnosa Utama",
                    icon: Icons.medical_services_outlined,
                  ),
                  const SizedBox(height: 16),
                  _buildModernTextField(
                    controller: _resepController,
                    label: "Resep Obat",
                    icon: Icons.medication_outlined,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  _buildModernTextField(
                    controller: _catatanController,
                    label: "Catatan Tambahan (Opsional)",
                    icon: Icons.note_alt_outlined,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // SECTION: BIAYA
            Row(
              children: [
                const Text(
                  "💰 Rincian Biaya",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Color(0xFF03045E),
                  ),
                ),
                if (isBPJS)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      "GRATIS VIA BPJS",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // JASA DOKTER
                  TextField(
                    controller: _jasaDokterController,
                    keyboardType: TextInputType.number,
                    readOnly: isBPJS,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(6),
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: InputDecoration(
                      labelText: "Jasa Dokter",
                      hintText: "Min 30.000",
                      prefixIcon: const Icon(
                        Icons.attach_money_rounded,
                        color: Colors.blue,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixText: "Rp ",
                      errorText: jasaError ? "Maksimal 100rb!" : null,
                      filled: true,
                      fillColor: isBPJS ? Colors.grey[100] : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: _buildReadOnlyCost(
                          "Biaya Admin",
                          _biayaAdminController,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildReadOnlyCost(
                          "Opsional",
                          _biayaOpsController,
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(thickness: 1, height: 1),
                  ),
                  TextField(
                    controller: _totalBiayaController,
                    readOnly: true,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                      fontSize: 22,
                    ),
                    decoration: InputDecoration(
                      labelText: "TOTAL TAGIHAN",
                      labelStyle: TextStyle(
                        color: Colors.green[700],
                        fontWeight: FontWeight.bold,
                      ),
                      prefixIcon: const Icon(
                        Icons.payments_rounded,
                        color: Colors.green,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Colors.green,
                          width: 2,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Colors.green,
                          width: 2,
                        ),
                      ),
                      prefixText: "Rp ",
                      filled: true,
                      fillColor: Colors.green[50],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // TOMBOL SIMPAN
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _simpanPemeriksaan,
                icon: const Icon(Icons.save_rounded),
                label: const Text(
                  "SIMPAN HASIL & SELESAI",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0077B6),
                  foregroundColor: Colors.white,
                  elevation: 5,
                  shadowColor: const Color(0xFF0077B6).withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey[600]),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0077B6), width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }

  Widget _buildReadOnlyCost(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      readOnly: true,
      style: const TextStyle(color: Colors.grey),
      decoration: InputDecoration(
        labelText: label,
        prefixText: "Rp ",
        isDense: true,
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
