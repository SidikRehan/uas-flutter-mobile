import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart'; 
import 'admin_poli_page.dart'; 

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _tabIndex = 0;
  
  bool isSuperAdmin = false;
  final User? currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() => _tabIndex = _tabController.index);
    });
    _cekLevelAdmin();
  }

  // --- LOGIKA "ADMIN SAKTI" (BACKDOOR) ---
  void _cekLevelAdmin() async {
    if (currentUser != null) {
      var doc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
      
      bool statusSuper = false;
      // GANTI EMAIL DI BAWAH INI DENGAN EMAIL ADMIN ANDA SENDIRI
      String emailSakti = "admin@rs.com"; // <-- UBAH EMAIL INI

      // 1. Cek Backdoor (Email Sakti)
      if (currentUser!.email == emailSakti) {
         statusSuper = true;
         // Auto-Fix Database
         if (!doc.exists || doc.data()?['level'] != 'super') {
            await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).set({
              'level': 'super',
              'role': 'admin',
              'email': emailSakti,
            }, SetOptions(merge: true));
         }
      } 
      // 2. Cek Database Normal
      else if (doc.exists && doc.data()?['level'] == 'super') {
        statusSuper = true;
      }

      if (mounted) setState(() => isSuperAdmin = statusSuper);
    }
  }

  // --- 1. FITUR TAMBAH PASIEN ---
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
                FirebaseApp secondaryApp = await Firebase.initializeApp(name: 'SecondaryApp', options: Firebase.app().options);
                UserCredential uc = await FirebaseAuth.instanceFor(app: secondaryApp).createUserWithEmailAndPassword(email: emailCtrl.text, password: passCtrl.text);
                
                String uid = uc.user!.uid;
                await FirebaseFirestore.instance.collection('users').doc(uid).set({
                  'uid': uid, 'nama': namaCtrl.text, 'email': emailCtrl.text, 'role': 'pasien', 
                  'nomor_bpjs': bpjsCtrl.text, 'created_at': FieldValue.serverTimestamp(),
                  'is_active': true, 
                });
                await FirebaseFirestore.instance.collection('pasiens').doc(uid).set({
                  'uid': uid, 'nama': namaCtrl.text, 'email': emailCtrl.text, 'nik': nikCtrl.text, 'nomor_bpjs': bpjsCtrl.text,
                });
                
                await secondaryApp.delete(); 
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

  // --- 2. FITUR TAMBAH DOKTER ---
  void _addDokter() {
    final namaCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    
    TimeOfDay jamBuka = const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay jamTutup = const TimeOfDay(hour: 16, minute: 0);
    List<String> hariTerpilih = [];
    String? selectedPoli; 
    final List<String> semuaHari = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            
            Future<void> pickTime(bool isBuka) async {
              final picked = await showTimePicker(context: context, initialTime: isBuka ? jamBuka : jamTutup);
              if (picked != null) setStateDialog(() => isBuka ? jamBuka = picked : jamTutup = picked);
            }
            String formatTime(TimeOfDay t) => '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}';

            return AlertDialog(
              title: const Text("Tambah Dokter Baru"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(controller: namaCtrl, decoration: const InputDecoration(labelText: "Nama Dokter (Gelar)")),
                    TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: "Email Login")),
                    TextField(controller: passCtrl, obscureText: true, decoration: const InputDecoration(labelText: "Password")),
                    const SizedBox(height: 15),
                    
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('polis').orderBy('nama_poli').snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Text("Loading Poli...");
                        return DropdownButtonFormField<String>(
                          value: selectedPoli,
                          decoration: const InputDecoration(labelText: "Pilih Poli Spesialis", border: OutlineInputBorder()),
                          items: snapshot.data!.docs.map<DropdownMenuItem<String>>((doc) {
                             var data = doc.data() as Map<String, dynamic>;
                             return DropdownMenuItem(value: data['nama_poli'].toString(), child: Text(data['nama_poli'].toString()));
                          }).toList(),
                          onChanged: (val) => setStateDialog(() => selectedPoli = val),
                        );
                      },
                    ),
                    const SizedBox(height: 15),
                    const Text("Jadwal Praktik:", style: TextStyle(fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                         Expanded(child: OutlinedButton(onPressed: () => pickTime(true), child: Text(formatTime(jamBuka)))),
                         const Padding(padding: EdgeInsets.symmetric(horizontal: 5), child: Text("-")),
                         Expanded(child: OutlinedButton(onPressed: () => pickTime(false), child: Text(formatTime(jamTutup)))),
                      ],
                    ),
                    Wrap(
                      spacing: 5,
                      children: semuaHari.map((hari) {
                        bool isSelected = hariTerpilih.contains(hari);
                        return FilterChip(
                          label: Text(hari),
                          selected: isSelected,
                          onSelected: (val) => setStateDialog(() => val ? hariTerpilih.add(hari) : hariTerpilih.remove(hari)),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
                ElevatedButton(
                  onPressed: () async {
                    if (emailCtrl.text.isEmpty || passCtrl.text.isEmpty || selectedPoli == null || hariTerpilih.isEmpty) {
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Data belum lengkap!")));
                       return;
                    }
                    try {
                      FirebaseApp secondaryApp = await Firebase.initializeApp(name: 'SecondaryApp', options: Firebase.app().options);
                      UserCredential uc = await FirebaseAuth.instanceFor(app: secondaryApp).createUserWithEmailAndPassword(email: emailCtrl.text, password: passCtrl.text);
                      String uid = uc.user!.uid;

                      await FirebaseFirestore.instance.collection('users').doc(uid).set({
                        'uid': uid, 'nama': namaCtrl.text, 'email': emailCtrl.text, 'role': 'dokter', 'created_at': FieldValue.serverTimestamp(),
                        'is_active': true, 
                      });
                      await FirebaseFirestore.instance.collection('doctors').doc(uid).set({
                        'uid': uid, 'nama': namaCtrl.text, 'Nama': namaCtrl.text,
                        'Poli': selectedPoli, 
                        'jam_buka': formatTime(jamBuka),
                        'jam_tutup': formatTime(jamTutup),
                        'hari_kerja': hariTerpilih,
                        'foto_url': '',
                        'is_active': true, 
                      });
                      
                      await secondaryApp.delete();
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

  // --- 3. FITUR EDIT USER ---
  void _editUser(Map<String, dynamic> data, String docId, String role) {
    final namaCtrl = TextEditingController(text: data['nama'] ?? data['Nama']);
    String? selectedPoli = role == 'dokter' ? data['Poli'] : null;
    
    // Status Aktif
    bool isActive = data['is_active'] ?? true;

    TimeOfDay jamBuka = const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay jamTutup = const TimeOfDay(hour: 16, minute: 0);
    List<String> hariTerpilih = [];
    final List<String> semuaHari = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];

    if (role == 'dokter') {
      try {
        if (data['jam_buka'] != null) {
          var p1 = data['jam_buka'].toString().split(':'); jamBuka = TimeOfDay(hour: int.parse(p1[0]), minute: int.parse(p1[1]));
          var p2 = data['jam_tutup'].toString().split(':'); jamTutup = TimeOfDay(hour: int.parse(p2[0]), minute: int.parse(p2[1]));
        }
        if (data['hari_kerja'] is List) hariTerpilih = List<String>.from(data['hari_kerja']);
      } catch (e) { print("Error parsing jadwal: $e"); }
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            
            Future<void> pickTime(bool isBuka) async {
              final picked = await showTimePicker(context: context, initialTime: isBuka ? jamBuka : jamTutup);
              if (picked != null) setStateDialog(() => isBuka ? jamBuka = picked : jamTutup = picked);
            }
            String formatTime(TimeOfDay t) => '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}';

            return AlertDialog(
              title: Text("Edit $role"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // SWITCH AKTIF
                    Container(
                      decoration: BoxDecoration(color: isActive ? Colors.green[50] : Colors.red[50], borderRadius: BorderRadius.circular(10)),
                      child: SwitchListTile(
                        title: Text(isActive ? "Status: AKTIF" : "Status: NON-AKTIF", style: TextStyle(fontWeight: FontWeight.bold, color: isActive ? Colors.green : Colors.red)),
                        subtitle: Text(isActive ? "User bisa login" : "User disembunyikan"),
                        value: isActive,
                        onChanged: (val) {
                          setStateDialog(() => isActive = val);
                        },
                      ),
                    ),
                    const SizedBox(height: 15),

                    TextField(controller: namaCtrl, decoration: const InputDecoration(labelText: "Nama Lengkap")),
                    const SizedBox(height: 15),
                    
                    if (role == 'dokter') ...[
                        const Text("Spesialisasi", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                        StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('polis').orderBy('nama_poli').snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox();
                          return DropdownButtonFormField<String>(
                            value: selectedPoli,
                            items: snapshot.data!.docs.map((doc) {
                               var pData = doc.data() as Map<String, dynamic>;
                               return DropdownMenuItem(value: pData['nama_poli'] as String, child: Text(pData['nama_poli']));
                            }).toList(),
                            onChanged: (val) => setStateDialog(() => selectedPoli = val),
                          );
                        },
                      ),
                      const SizedBox(height: 15),

                      if (isSuperAdmin) ...[
                        const Text("Atur Jadwal (Super Admin):", style: TextStyle(fontWeight: FontWeight.bold)),
                        Row(
                          children: [
                            Expanded(child: OutlinedButton(onPressed: () => pickTime(true), child: Text(formatTime(jamBuka)))),
                            const Padding(padding: EdgeInsets.symmetric(horizontal: 5), child: Text("-")),
                            Expanded(child: OutlinedButton(onPressed: () => pickTime(false), child: Text(formatTime(jamTutup)))),
                          ],
                        ),
                        Wrap(
                          spacing: 5,
                          children: semuaHari.map((hari) {
                            bool isSelected = hariTerpilih.contains(hari);
                            return FilterChip(
                              label: Text(hari), selected: isSelected,
                              onSelected: (val) => setStateDialog(() => val ? hariTerpilih.add(hari) : hariTerpilih.remove(hari)),
                            );
                          }).toList(),
                        ),
                      ] else ...[
                          Container(
                          width: double.infinity, padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                          child: const Column(
                            children: [
                              Icon(Icons.lock, color: Colors.grey),
                              Text("Jadwal Terkunci", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                            ],
                          ),
                        )
                      ]
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
                ElevatedButton(
                  onPressed: () async {
                    await FirebaseFirestore.instance.collection('users').doc(docId).update({
                      'nama': namaCtrl.text,
                      'is_active': isActive 
                    });
                    
                    if (role == 'dokter') {
                      Map<String, dynamic> updateData = {
                        'nama': namaCtrl.text, 'Nama': namaCtrl.text, 'Poli': selectedPoli,
                        'is_active': isActive 
                      };
                      if (isSuperAdmin) {
                        if (hariTerpilih.isEmpty) {
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pilih minimal 1 hari kerja!")));
                           return;
                        }
                        updateData['jam_buka'] = formatTime(jamBuka);
                        updateData['jam_tutup'] = formatTime(jamTutup);
                        updateData['hari_kerja'] = hariTerpilih;
                      }
                      await FirebaseFirestore.instance.collection('doctors').doc(docId).update(updateData);
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
  
  // --- HAPUS USER ---
  void _deleteUser(String docId, String role, String nama) {
     if (role == 'dokter' && !isSuperAdmin) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hanya Super Admin yang boleh menghapus Dokter!")));
        return;
     }
     showDialog(
       context: context,
       builder: (c) => AlertDialog(
         title: const Text("Konfirmasi Hapus"),
         content: Text("Hapus $role: $nama?"),
         actions: [
           TextButton(onPressed: () => Navigator.pop(c), child: const Text("Batal")),
           TextButton(onPressed: () {
              FirebaseFirestore.instance.collection('users').doc(docId).delete();
              if(role=='dokter') FirebaseFirestore.instance.collection('doctors').doc(docId).delete();
              if(role=='pasien') FirebaseFirestore.instance.collection('pasiens').doc(docId).delete();
              Navigator.pop(c);
           }, child: const Text("Hapus", style: TextStyle(color: Colors.red))),
         ],
       )
     );
  }

  // --- TAMBAH ADMIN (HANYA SUPER ADMIN) ---
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
                FirebaseApp secondaryApp = await Firebase.initializeApp(name: 'SecondaryApp', options: Firebase.app().options);
                UserCredential uc = await FirebaseAuth.instanceFor(app: secondaryApp).createUserWithEmailAndPassword(email: emailCtrl.text, password: passCtrl.text);
                
                String uid = uc.user!.uid;
                await FirebaseFirestore.instance.collection('users').doc(uid).set({
                  'nama': namaCtrl.text, 'email': emailCtrl.text,
                  'role': 'admin', 'level': 'regular', // Level Regular
                  'created_at': DateTime.now().toString(),
                });
                await secondaryApp.delete();
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
        // JUDUL DINAMIS + INDIKATOR
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Kelola Pengguna", style: TextStyle(fontSize: 18)),
            Text(
              isSuperAdmin ? "SUPER ADMIN (Full Akses)" : "Admin Staff (Terbatas)",
              style: TextStyle(
                fontSize: 12, 
                color: isSuperAdmin ? Colors.yellowAccent : Colors.white70, 
                fontWeight: FontWeight.bold
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue[800], foregroundColor: Colors.white,
        bottom: TabBar(controller: _tabController, indicatorColor: Colors.white, labelColor: Colors.white, unselectedLabelColor: Colors.white60, tabs: const [Tab(icon: Icon(Icons.people), text: "Pasien"), Tab(icon: Icon(Icons.medical_services), text: "Dokter"), Tab(icon: Icon(Icons.admin_panel_settings), text: "Admin")]),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_suggest), tooltip: "Kelola Poli",
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
        onPressed: () { 
          if (_tabIndex == 0) _addPasien(); 
          else if (_tabIndex == 1) _addDokter(); 
          else {
             if(isSuperAdmin) _addAdmin();
             else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hanya Super Admin!")));
          }
        },
        backgroundColor: _tabIndex == 0 ? Colors.green : (_tabIndex == 1 ? Colors.blue : (isSuperAdmin ? Colors.purple : Colors.grey)),
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
            String nama = data['nama'] ?? data['Nama'] ?? 'User';
            String sub = roleFilter=='dokter' ? (data['Poli'] ?? '-') : (data['email'] ?? '-');
            bool isActive = data['is_active'] ?? true;

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: isActive ? Colors.blue : Colors.grey, 
                child: Icon(roleFilter == 'dokter' ? Icons.medical_services : (roleFilter == 'admin' ? Icons.security : Icons.person), color: Colors.white)
              ),
              title: Text(nama, style: TextStyle(color: isActive ? Colors.black : Colors.grey)),
              subtitle: Text(isActive ? sub : "$sub (NON-AKTIF)"),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: const Icon(Icons.edit, color: Colors.orange), onPressed: () => _editUser(data, docs[index].id, roleFilter)),
                  if (roleFilter != 'admin' || isSuperAdmin) 
                    IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteUser(docs[index].id, roleFilter, nama)),
                ],
              ),
            );
          }
        );
      },
    );
  }
}