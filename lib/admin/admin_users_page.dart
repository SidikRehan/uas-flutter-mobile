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
  // --- FITUR EDIT USER & JADWAL DOKTER (UPGRADE) ---
  void _editUser(Map<String, dynamic> data, String docId, String role) {
    final namaCtrl = TextEditingController(text: data['nama'] ?? data['Nama']);
    String? selectedPoli = role == 'dokter' ? data['Poli'] : null;
    
    // Variabel Jadwal (Default Kosong)
    TimeOfDay jamBuka = const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay jamTutup = const TimeOfDay(hour: 16, minute: 0);
    List<String> hariTerpilih = [];

    // --- LOGIKA LOAD DATA LAMA (MIGRASI OTOMATIS) ---
    if (role == 'dokter') {
      try {
        // 1. Load Jam
        if (data['jam_buka'] != null) {
          // Format Baru (08:00)
          var parts = data['jam_buka'].toString().split(':');
          jamBuka = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
          
          var parts2 = data['jam_tutup'].toString().split(':');
          jamTutup = TimeOfDay(hour: int.parse(parts2[0]), minute: int.parse(parts2[1]));
        } else if (data['Jam'] != null) {
          // Format Lama (08:00 - 16:00) -> Kita coba ambil angkanya saja
          // Fallback: Biarkan default 08:00 - 16:00 jika format lama susah diparsing
        }

        // 2. Load Hari
        if (data['hari_kerja'] is List) {
          hariTerpilih = List<String>.from(data['hari_kerja']);
        } else if (data['Hari'] != null) {
          // Jika masih format string "Senin - Rabu", biarkan kosong (user set ulang)
        }
      } catch (e) {
        print("Error parsing jadwal lama: $e");
      }
    }

    final List<String> semuaHari = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            
            // Helper Pilih Jam
            Future<void> pickTime(bool isBuka) async {
              final picked = await showTimePicker(
                context: context,
                initialTime: isBuka ? jamBuka : jamTutup,
              );
              if (picked != null) {
                setStateDialog(() {
                  if (isBuka) jamBuka = picked; else jamTutup = picked;
                });
              }
            }

            // Helper Format Jam ke String (08:00)
            String formatTime(TimeOfDay t) {
              return '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}';
            }

            return AlertDialog(
              title: Text("Edit $role"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(controller: namaCtrl, decoration: const InputDecoration(labelText: "Nama Lengkap")),
                    const SizedBox(height: 15),
                    
                    // --- KHUSUS DOKTER: EDIT JADWAL ---
                    if (role == 'dokter') ...[
                        const Text("Spesialis & Jadwal", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                        const SizedBox(height: 10),
                        
                        // 1. Edit Poli
                        StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('polis').orderBy('nama_poli').snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox();
                          return DropdownButtonFormField<String>(
                            value: selectedPoli,
                            decoration: const InputDecoration(labelText: "Poli", border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5)),
                            items: snapshot.data!.docs.map((doc) {
                               var pData = doc.data() as Map<String, dynamic>;
                               return DropdownMenuItem(value: pData['nama_poli'] as String, child: Text(pData['nama_poli']));
                            }).toList(),
                            onChanged: (val) => setStateDialog(() => selectedPoli = val),
                          );
                        },
                      ),
                      const SizedBox(height: 15),

                      // 2. Edit Jam
                      const Text("Jam Praktik:", style: TextStyle(fontSize: 12)),
                      Row(
                        children: [
                          Expanded(child: OutlinedButton(onPressed: () => pickTime(true), child: Text(formatTime(jamBuka)))),
                          const Padding(padding: EdgeInsets.symmetric(horizontal: 5), child: Text("-")),
                          Expanded(child: OutlinedButton(onPressed: () => pickTime(false), child: Text(formatTime(jamTutup)))),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // 3. Edit Hari (Chips)
                      const Text("Hari Praktik:", style: TextStyle(fontSize: 12)),
                      Wrap(
                        spacing: 5,
                        children: semuaHari.map((hari) {
                          bool isSelected = hariTerpilih.contains(hari);
                          return FilterChip(
                            label: Text(hari, style: TextStyle(fontSize: 10, color: isSelected ? Colors.white : Colors.black)),
                            selected: isSelected,
                            selectedColor: Colors.blue,
                            checkmarkColor: Colors.white,
                            onSelected: (bool selected) {
                              setStateDialog(() {
                                if (selected) {
                                  hariTerpilih.add(hari);
                                } else {
                                  hariTerpilih.remove(hari);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
                ElevatedButton(
                  onPressed: () async {
                    // Validasi Sederhana
                    if (role == 'dokter' && hariTerpilih.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pilih minimal 1 hari kerja!")));
                      return;
                    }

                    // Update Users Collection (Nama saja)
                    await FirebaseFirestore.instance.collection('users').doc(docId).update({'nama': namaCtrl.text});
                    
                    // Update Doctors Collection (Lengkap dengan Jadwal Baru)
                    if (role == 'dokter') {
                      await FirebaseFirestore.instance.collection('doctors').doc(docId).update({
                        'nama': namaCtrl.text, 
                        'Nama': namaCtrl.text, 
                        'Poli': selectedPoli,
                        
                        // UPDATE KE FORMAT BARU (REAL-TIME SUPPORT)
                        'jam_buka': formatTime(jamBuka),
                        'jam_tutup': formatTime(jamTutup),
                        'hari_kerja': hariTerpilih,
                      });
                    }
                    if (mounted) Navigator.pop(context);
                  },
                  child: const Text("Simpan Perubahan"),
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