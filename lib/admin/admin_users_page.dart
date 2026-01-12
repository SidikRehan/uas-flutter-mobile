import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'admin_poli_page.dart'; // Pastikan import ini ada

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() => _tabIndex = _tabController.index);
    });
  }

  // --- FITUR TAMBAH PASIEN ---
  void _addPasien() {
    final namaCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final nikCtrl = TextEditingController();
    final bpjsCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Daftar Pasien Offline"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: namaCtrl, decoration: const InputDecoration(labelText: "Nama Pasien")),
              const SizedBox(height: 10),
              TextField(controller: nikCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "NIK (KTP)")),
              TextField(controller: bpjsCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Nomor BPJS (Opsional)")),
              const SizedBox(height: 15), const Divider(),
              TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: "Email Login")),
              TextField(controller: passCtrl, obscureText: true, decoration: const InputDecoration(labelText: "Password")),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(
            onPressed: () async {
              if (emailCtrl.text.isEmpty || passCtrl.text.isEmpty || namaCtrl.text.isEmpty) return;
              try {
                UserCredential uc = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: emailCtrl.text, password: passCtrl.text);
                await FirebaseFirestore.instance.collection('users').doc(uc.user!.uid).set({
                  'uid': uc.user!.uid, 'nama': namaCtrl.text, 'email': emailCtrl.text, 'role': 'pasien', 'nomor_bpjs': bpjsCtrl.text, 'created_at': DateTime.now().toString(),
                });
                await FirebaseFirestore.instance.collection('pasiens').doc(uc.user!.uid).set({
                  'uid': uc.user!.uid, 'nama': namaCtrl.text, 'email': emailCtrl.text, 'nik': nikCtrl.text, 'nomor_bpjs': bpjsCtrl.text,
                });
                if (mounted) Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
              }
            },
            child: const Text("Simpan"),
          ),
        ],
      ),
    );
  }

  // --- FITUR TAMBAH DOKTER (PERBAIKAN TIPE DATA) ---
  void _addDokter() {
    final namaCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final hariCtrl = TextEditingController();
    final jamCtrl = TextEditingController();
    String? selectedPoli; 

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Tambah Dokter Baru"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: namaCtrl, decoration: const InputDecoration(labelText: "Nama Dokter (Gelar)")),
                    TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: "Email Login")),
                    TextField(controller: passCtrl, obscureText: true, decoration: const InputDecoration(labelText: "Password")),
                    const SizedBox(height: 15),
                    
                    // --- DROPDOWN POLI (FIXED TYPE ERROR) ---
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('polis').orderBy('nama_poli').snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Text("Loading Poli...");
                        var listPoli = snapshot.data!.docs;
                        
                        return DropdownButtonFormField<String>(
                          value: selectedPoli,
                          decoration: const InputDecoration(labelText: "Pilih Poli Spesialis", border: OutlineInputBorder()),
                          // PERBAIKAN DI SINI: Menambahkan <DropdownMenuItem<String>>
                          items: listPoli.map<DropdownMenuItem<String>>((doc) {
                             var data = doc.data() as Map<String, dynamic>;
                             return DropdownMenuItem<String>(
                               value: data['nama_poli'].toString(), // Pastikan toString
                               child: Text(data['nama_poli'].toString())
                             );
                          }).toList(),
                          onChanged: (val) => setStateDialog(() => selectedPoli = val),
                        );
                      },
                    ),
                    // ----------------------------------------------

                    const SizedBox(height: 10),
                    TextField(controller: hariCtrl, decoration: const InputDecoration(labelText: "Hari (Cth: Senin - Rabu)")),
                    TextField(controller: jamCtrl, decoration: const InputDecoration(labelText: "Jam (Cth: 08:00 - 12:00)")),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
                ElevatedButton(
                  onPressed: () async {
                    if (emailCtrl.text.isEmpty || passCtrl.text.isEmpty || selectedPoli == null) return;
                    try {
                      UserCredential uc = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: emailCtrl.text, password: passCtrl.text);
                      String uid = uc.user!.uid;
                      await FirebaseFirestore.instance.collection('users').doc(uid).set({
                        'uid': uid, 'nama': namaCtrl.text, 'email': emailCtrl.text, 'role': 'dokter', 'created_at': DateTime.now().toString(),
                      });
                      await FirebaseFirestore.instance.collection('doctors').doc(uid).set({
                        'uid': uid, 'nama': namaCtrl.text, 'Nama': namaCtrl.text,
                        'Poli': selectedPoli, 'Hari': hariCtrl.text, 'Jam': jamCtrl.text, 'foto_url': '',
                      });
                      if (mounted) Navigator.pop(context);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                    }
                  },
                  child: const Text("Simpan"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- FITUR EDIT USER (PERBAIKAN TIPE DATA) ---
  void _editUser(Map<String, dynamic> data, String docId, String role) {
    final namaCtrl = TextEditingController(text: data['nama'] ?? data['Nama']);
    final hariCtrl = TextEditingController();
    final jamCtrl = TextEditingController();
    String? selectedPoli;

    if (role == 'dokter') {
      hariCtrl.text = data['Hari'] ?? '';
      jamCtrl.text = data['Jam'] ?? '';
      selectedPoli = data['Poli']; 
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text("Edit $role"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: namaCtrl, decoration: const InputDecoration(labelText: "Nama Lengkap")),
                    const SizedBox(height: 15),
                    
                    if (role == 'dokter') ...[
                       // DROPDOWN DINAMIS (FIXED TYPE ERROR)
                       StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('polis').orderBy('nama_poli').snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox();
                          var listPoli = snapshot.data!.docs;
                          
                          // Validasi selectedPoli
                          bool isValid = listPoli.any((doc) => doc['nama_poli'] == selectedPoli);
                          if (!isValid) selectedPoli = null;

                          return DropdownButtonFormField<String>(
                            value: selectedPoli,
                            decoration: const InputDecoration(labelText: "Poli Spesialis", border: OutlineInputBorder()),
                            // PERBAIKAN DI SINI JUGA
                            items: listPoli.map<DropdownMenuItem<String>>((doc) {
                               var pData = doc.data() as Map<String, dynamic>;
                               return DropdownMenuItem<String>(
                                 value: pData['nama_poli'].toString(), 
                                 child: Text(pData['nama_poli'].toString())
                               );
                            }).toList(),
                            onChanged: (val) => setStateDialog(() => selectedPoli = val),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(controller: hariCtrl, decoration: const InputDecoration(labelText: "Hari Praktik")),
                      TextField(controller: jamCtrl, decoration: const InputDecoration(labelText: "Jam Praktik")),
                    ],
                    const SizedBox(height: 20),
                     SizedBox(width: double.infinity, child: OutlinedButton.icon(icon: const Icon(Icons.lock_reset, color: Colors.red), label: const Text("Kirim Reset Password", style: TextStyle(color: Colors.red)), onPressed: () async { if(data['email'] != null) await FirebaseAuth.instance.sendPasswordResetEmail(email: data['email']); })),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
                ElevatedButton(
                  onPressed: () async {
                    await FirebaseFirestore.instance.collection('users').doc(docId).update({'nama': namaCtrl.text});
                    if (role == 'dokter') {
                      await FirebaseFirestore.instance.collection('doctors').doc(docId).update({
                        'nama': namaCtrl.text, 'Nama': namaCtrl.text, 'Poli': selectedPoli, 'Hari': hariCtrl.text, 'Jam': jamCtrl.text,
                      });
                    }
                    if (mounted) Navigator.pop(context);
                  },
                  child: const Text("Simpan"),
                ),
              ],
            );
          },
        );
      },
    );
  }
  
  void _deleteUser(String docId, String role, String nama) {
       FirebaseFirestore.instance.collection('users').doc(docId).delete();
       if(role=='dokter') FirebaseFirestore.instance.collection('doctors').doc(docId).delete();
       if(role=='pasien') FirebaseFirestore.instance.collection('pasiens').doc(docId).delete();
  }

  void _addAdmin() {
    TextEditingController emailCtrl = TextEditingController();
    TextEditingController passCtrl = TextEditingController();
    TextEditingController namaCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Tambah Admin Baru"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: namaCtrl, decoration: const InputDecoration(labelText: "Nama Admin")),
            TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: "Email")),
            TextField(controller: passCtrl, obscureText: true, decoration: const InputDecoration(labelText: "Password")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(
            onPressed: () async {
              if (emailCtrl.text.isEmpty || passCtrl.text.isEmpty) return;
              try {
                UserCredential uc = await FirebaseAuth.instance.createUserWithEmailAndPassword(
                  email: emailCtrl.text, password: passCtrl.text
                );
                await FirebaseFirestore.instance.collection('users').doc(uc.user!.uid).set({
                  'nama': namaCtrl.text, 'email': emailCtrl.text,
                  'role': 'admin', 'created_at': DateTime.now().toString(),
                });
                if (mounted) Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
              }
            },
            child: const Text("Simpan"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Kelola Pengguna"),
        backgroundColor: Colors.blue[800], foregroundColor: Colors.white,
        bottom: TabBar(controller: _tabController, indicatorColor: Colors.white, labelColor: Colors.white, unselectedLabelColor: Colors.white60, tabs: const [Tab(icon: Icon(Icons.people), text: "Pasien"), Tab(icon: Icon(Icons.medical_services), text: "Dokter"), Tab(icon: Icon(Icons.admin_panel_settings), text: "Admin")]),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_suggest),
            tooltip: "Kelola Poli",
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminPoliPage())),
          )
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUserList('pasien'),
          _buildUserList('dokter'),
          _buildUserList('admin'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () { if (_tabIndex == 0) _addPasien(); else if (_tabIndex == 1) _addDokter(); else _addAdmin(); },
        backgroundColor: _tabIndex == 0 ? Colors.green : (_tabIndex == 1 ? Colors.blue : Colors.purple),
        icon: Icon(_tabIndex == 0 ? Icons.person_add : (_tabIndex == 1 ? Icons.medical_services : Icons.security)),
        label: Text(_tabIndex == 0 ? "Tambah Pasien" : (_tabIndex == 1 ? "Tambah Dokter" : "Tambah Admin")),
      ),
    );
  }

  Widget _buildUserList(String roleFilter) {
    Query query = FirebaseFirestore.instance.collection('users').where('role', isEqualTo: roleFilter);
    if (roleFilter == 'dokter') query = FirebaseFirestore.instance.collection('doctors'); 

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        var docs = snapshot.data!.docs;
        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (c, i) => const Divider(),
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            return ListTile(
              leading: CircleAvatar(child: Icon(roleFilter == 'dokter' ? Icons.medical_services : Icons.person)),
              title: Text(data['nama'] ?? data['Nama'] ?? ''),
              subtitle: Text(roleFilter=='dokter' ? (data['Poli'] ?? '-') : (data['email'] ?? '-')),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: const Icon(Icons.edit, color: Colors.orange), onPressed: () => _editUser(data, docs[index].id, roleFilter)),
                  IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteUser(docs[index].id, roleFilter, data['nama'] ?? '')),
                ],
              ),
            );
          }
        );
      },
    );
  }
}