import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminPoliPage extends StatefulWidget {
  const AdminPoliPage({super.key});

  @override
  State<AdminPoliPage> createState() => _AdminPoliPageState();
}

class _AdminPoliPageState extends State<AdminPoliPage> {
  final TextEditingController _poliCtrl = TextEditingController();

  // --- FUNGSI TAMBAH / EDIT POLI ---
  void _showFormPoli({String? docId, String? currentName}) {
    if (currentName != null) {
      _poliCtrl.text = currentName; // Isi teks kalau mau edit
    } else {
      _poliCtrl.clear(); // Bersihkan kalau tambah baru
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(docId == null ? "Tambah Poli Baru" : "Edit Nama Poli"),
        content: TextField(
          controller: _poliCtrl,
          decoration: const InputDecoration(labelText: "Nama Poli (Cth: Poli Jantung)"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(
            onPressed: () async {
              if (_poliCtrl.text.isEmpty) return;
              
              if (docId == null) {
                // TAMBAH BARU
                await FirebaseFirestore.instance.collection('polis').add({
                  'nama_poli': _poliCtrl.text,
                  'created_at': DateTime.now().toString(),
                });
              } else {
                // UPDATE
                await FirebaseFirestore.instance.collection('polis').doc(docId).update({
                  'nama_poli': _poliCtrl.text,
                });
              }
              
              if (mounted) Navigator.pop(context);
            },
            child: const Text("Simpan"),
          )
        ],
      ),
    );
  }

  // --- FUNGSI HAPUS POLI ---
  void _deletePoli(String docId, String namaPoli) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Poli"),
        content: Text("Yakin ingin menghapus $namaPoli?\n(Dokter yang sudah ada di poli ini tidak akan terhapus, tapi polinya akan hilang dari daftar pilihan)."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('polis').doc(docId).delete();
              if (mounted) Navigator.pop(context);
            },
            child: const Text("Hapus"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Kelola Data Poli"), backgroundColor: Colors.purple, foregroundColor: Colors.white),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('polis').orderBy('nama_poli').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          var docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text("Belum ada poli. Silakan tambah."));

          return ListView.separated(
            padding: const EdgeInsets.all(10),
            itemCount: docs.length,
            separatorBuilder: (c, i) => const Divider(),
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              String namaPoli = data['nama_poli'] ?? '-';

              return ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.purple, child: Icon(Icons.local_hospital, color: Colors.white)),
                title: Text(namaPoli, style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.edit, color: Colors.orange), onPressed: () => _showFormPoli(docId: docs[index].id, currentName: namaPoli)),
                    IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deletePoli(docs[index].id, namaPoli)),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showFormPoli(),
        backgroundColor: Colors.purple,
        child: const Icon(Icons.add),
      ),
    );
  }
}