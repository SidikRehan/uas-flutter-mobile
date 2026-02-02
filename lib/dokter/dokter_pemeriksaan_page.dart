import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Pastikan sudah run: flutter pub add intl
import 'package:flutter/services.dart'; // Untuk LengthLimitingTextInputFormatter

class DokterPemeriksaanPage extends StatefulWidget {
  final String bookingId;
  final Map<String, dynamic> dataPasien; 

  const DokterPemeriksaanPage({super.key, required this.bookingId, required this.dataPasien});

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
        _biayaOpsController.text = '30000';   // Operasional Tetap
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                  const Text("Riwayat Rekam Medis", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const Divider(thickness: 2),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('bookings')
                      .where('id_pasien', isEqualTo: widget.dataPasien['id_pasien'])
                      .where('status', isEqualTo: 'Selesai') 
                      // .orderBy(...) <--- Dihapus sementara agar tidak butuh Index
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    var docs = snapshot.data!.docs;
                    
                    if (docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history_edu, size: 60, color: Colors.grey[300]),
                            const SizedBox(height: 10),
                            const Text("Belum ada riwayat kunjungan."),
                            const SizedBox(height: 5),
                            Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(color: Colors.green[100], borderRadius: BorderRadius.circular(5)),
                                child: const Text("PASIEN BARU", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12))
                            )
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        var data = docs[index].data() as Map<String, dynamic>;
                        if (docs[index].id == widget.bookingId) return const SizedBox();
                        
                        String tglIndo = _formatTanggalIndo(data['tanggal_booking'].toString().substring(0, 10));
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            title: Text(tglIndo, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text("Diagnosa: ${data['hasil_medis']}\nObat: ${data['resep_obat']}"),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mohon lengkapi Diagnosa dan Resep.")));
      return;
    }

    // B. Validasi Biaya (Hanya Non-BPJS)
    if (!isBPJS) {
      int jasaDokter = int.tryParse(_jasaDokterController.text) ?? 0;
      if (jasaDokter < 30000) {
        _showErrorDialog("Biaya Terlalu Rendah", "Minimal Jasa Dokter adalah Rp 30.000");
        return;
      }
      if (jasaDokter > 100000) {
        _showErrorDialog("Biaya Terlalu Tinggi", "Maksimal Jasa Dokter adalah Rp 100.000");
        return;
      }
    }

    // C. Simpan ke Firestore
    try {
      await FirebaseFirestore.instance.collection('bookings').doc(widget.bookingId).update({
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pemeriksaan Selesai!"), backgroundColor: Colors.green));
        Navigator.pop(context); // Kembali ke Dashboard
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  void _showErrorDialog(String title, String msg) {
    showDialog(
      context: context, 
      builder: (c) => AlertDialog(
        title: Text(title, style: const TextStyle(color: Colors.red)),
        content: Text(msg),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("Perbaiki"))],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    var pasien = widget.dataPasien;
    
    // Cek error validasi live (untuk warna merah di textfield)
    int jasaVal = int.tryParse(_jasaDokterController.text) ?? 0;
    bool jasaError = !isBPJS && (jasaVal > 100000);

    return Scaffold(
      appBar: AppBar(title: const Text("Pemeriksaan Pasien")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KARTU INFO PASIEN
            Card(
              color: isBPJS ? Colors.green[50] : Colors.blue[50],
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isBPJS ? Colors.green : Colors.blue,
                  child: const Icon(Icons.person, color: Colors.white),
                ),
                title: Text(pasien['nama_pasien'], style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(isBPJS ? "PASIEN BPJS (GRATIS)" : "PASIEN UMUM (BAYAR)"),
              ),
            ),
            const SizedBox(height: 10),
            
            // TOMBOL RIWAYAT
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _lihatRiwayatKunjungan,
                icon: const Icon(Icons.history),
                label: const Text("LIHAT RIWAYAT MEDIS"),
              ),
            ),
            
            const SizedBox(height: 20),
            const Text("Formulir Medis", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),

            TextField(
              controller: _diagnosaController,
              decoration: const InputDecoration(labelText: "Diagnosa Penyakit", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _resepController,
              decoration: const InputDecoration(labelText: "Resep Obat", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _catatanController,
              decoration: const InputDecoration(labelText: "Catatan (Opsional)", border: OutlineInputBorder()),
            ),

            const SizedBox(height: 20),
            const Divider(thickness: 2),
            const Text("Rincian Biaya", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),

            // --- INPUT JASA DOKTER ---
            TextField(
              controller: _jasaDokterController,
              keyboardType: TextInputType.number,
              readOnly: isBPJS, 
              // LIMITER: Max 6 digit (999.999) agar tidak error Overflow
              inputFormatters: [
                LengthLimitingTextInputFormatter(6), 
                FilteringTextInputFormatter.digitsOnly
              ],
              decoration: InputDecoration(
                labelText: "Jasa Dokter (Min 30rb - Max 100rb)", 
                border: const OutlineInputBorder(), 
                prefixText: "Rp ",
                // Error text muncul realtime jika > 100rb
                errorText: jasaError ? "Maksimal 100rb!" : null,
              ),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _biayaAdminController,
                    readOnly: true, 
                    decoration: const InputDecoration(labelText: "Biaya Admin", border: OutlineInputBorder(), prefixText: "Rp ", filled: true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _biayaOpsController,
                    readOnly: true,
                    decoration: const InputDecoration(labelText: "Operasional", border: OutlineInputBorder(), prefixText: "Rp ", filled: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _totalBiayaController,
              readOnly: true, 
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 18),
              decoration: const InputDecoration(labelText: "TOTAL AKHIR", border: OutlineInputBorder(), prefixText: "Rp "),
            ),
            
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _simpanPemeriksaan,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                child: const Text("SIMPAN & SELESAI"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}