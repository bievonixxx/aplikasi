import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_page.dart';
import 'dosen_task_detail_page.dart';

class DosenHomePage extends StatefulWidget {
  const DosenHomePage({super.key});

  @override
  State<DosenHomePage> createState() => _DosenHomePageState();
}

class _DosenHomePageState extends State<DosenHomePage> {
  final TextEditingController _judulController = TextEditingController();
  final TextEditingController _deskripsiController = TextEditingController();
  final TextEditingController _driveLinksController = TextEditingController();
  DateTime? _selectedDeadline;
  TimeOfDay? _selectedTime;
  final List<String> _kategoriList = [
    'Tugas', 'Quiz', 'UTS', 'UAS', 'Lainnya'
  ];
  String? _selectedKategori;
  bool _isLoading = false;

  List<String> _getDriveLinks() {
    final links = _driveLinksController.text.trim().split('\n');
    return links.where((link) => link.trim().isNotEmpty).toList();
  }

  String _extractFileId(String driveLink) {
    // Extract file ID from Google Drive link
    // Format: https://drive.google.com/file/d/{fileId}/view
    // Format: https://drive.google.com/open?id={fileId}
    // Format: https://docs.google.com/document/d/{fileId}/edit
    final regex = RegExp(r'/file/d/([a-zA-Z0-9_-]+)|[?&]id=([a-zA-Z0-9_-]+)|/document/d/([a-zA-Z0-9_-]+)|/presentation/d/([a-zA-Z0-9_-]+)');
    final match = regex.firstMatch(driveLink);
    if (match != null) {
      return match.group(1) ?? match.group(2) ?? match.group(3) ?? match.group(4) ?? '';
    }
    return '';
  }

  String _getFileType(String driveLink) {
    // Simple detection based on file extension in URL
    if (driveLink.toLowerCase().contains('.pdf')) return 'pdf';
    if (driveLink.toLowerCase().contains('.jpg') || driveLink.toLowerCase().contains('.jpeg') || driveLink.toLowerCase().contains('.png')) return 'image';
    if (driveLink.toLowerCase().contains('.doc') || driveLink.toLowerCase().contains('.docx') || driveLink.toLowerCase().contains('/document/')) return 'document';
    if (driveLink.toLowerCase().contains('.ppt') || driveLink.toLowerCase().contains('.pptx') || driveLink.toLowerCase().contains('/presentation/')) return 'presentation';
    return 'unknown';
  }

  String _generatePreviewUrl(String fileId, String fileType) {
    if (fileId.isEmpty) return '';
    
    switch (fileType) {
      case 'pdf':
        // Untuk PDF, gunakan direct download URL yang bisa di-preview
        return 'https://drive.google.com/uc?export=download&id=$fileId';
      case 'image':
        // Untuk gambar, gunakan direct URL
        return 'https://drive.google.com/uc?export=download&id=$fileId';
      case 'document':
        // Untuk dokumen, gunakan Google Docs viewer
        return 'https://docs.google.com/document/d/$fileId/preview';
      case 'presentation':
        // Untuk presentasi, gunakan Google Slides viewer
        return 'https://docs.google.com/presentation/d/$fileId/preview';
      default:
        // Fallback ke direct download URL
        return 'https://drive.google.com/uc?export=download&id=$fileId';
    }
  }

  String _generateDownloadUrl(String fileId) {
    if (fileId.isEmpty) return '';
    // Gunakan direct download URL yang lebih reliable
    return 'https://drive.google.com/uc?export=download&id=$fileId';
  }

  Future<void> _tambahTugas() async {
    final judul = _judulController.text.trim();
    final deskripsi = _deskripsiController.text.trim();
    final deadlineDate = _selectedDeadline;
    final deadlineTime = _selectedTime;
    final kategori = _selectedKategori;
    if (judul.isEmpty || deskripsi.isEmpty || deadlineDate == null || deadlineTime == null || kategori == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Semua field harus diisi!')),
      );
      return;
    }
    final deadline = DateTime(
      deadlineDate.year,
      deadlineDate.month,
      deadlineDate.day,
      deadlineTime.hour,
      deadlineTime.minute,
    );
    setState(() { _isLoading = true; });
    try {
      print('Creating tugas document...');
      // Buat dokumen tugas dulu
      final tugasRef = await FirebaseFirestore.instance.collection('tugas').add({
        'judul': judul,
        'deskripsi': deskripsi,
        'deadline': deadline,
        'kategori': kategori,
        'status': 'belum',
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      print('Tugas created with ID: ${tugasRef.id}');
      
      // Simpan Google Drive links jika ada
      final driveLinks = _getDriveLinks();
      if (driveLinks.isNotEmpty) {
        print('Saving ${driveLinks.length} Google Drive links...');
        
        final fileData = driveLinks.map((link) {
          final fileId = _extractFileId(link);
          final fileType = _getFileType(link);
          return {
            'link': link,
            'fileId': fileId,
            'type': fileType,
            'previewUrl': _generatePreviewUrl(fileId, fileType),
            'downloadUrl': _generateDownloadUrl(fileId),
          };
        }).toList();
        
        await FirebaseFirestore.instance
            .collection('tugas')
            .doc(tugasRef.id)
            .collection('attachments')
            .add({
          'files': fileData,
          'uploadedAt': FieldValue.serverTimestamp(),
        });
        print('Google Drive links saved successfully');
      }
      
      _judulController.clear();
      _deskripsiController.clear();
      _driveLinksController.clear();
      setState(() {
        _selectedDeadline = null;
        _selectedTime = null;
        _selectedKategori = null;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tugas berhasil ditambahkan!')),
        );
      }
    } catch (e) {
      print('Error in _tambahTugas: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menambah tugas: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Dosen'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginPage()),
                (route) => false,
              );
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tambah Tugas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
              const SizedBox(height: 8),
              // Statistik tugas dosen
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('tugas').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox();
                  final allTugas = snapshot.data!.docs;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _StatCard(
                          icon: Icons.assignment,
                          label: 'Total Tugas',
                          value: allTugas.length.toString(),
                          color: Colors.deepPurple,
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceVariant,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _judulController,
                        decoration: const InputDecoration(labelText: 'Judul'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _deskripsiController,
                        decoration: const InputDecoration(labelText: 'Deskripsi'),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedKategori,
                        items: _kategoriList.map((kat) => DropdownMenuItem(value: kat, child: Text(kat))).toList(),
                        onChanged: (val) => setState(() => _selectedKategori = val),
                        decoration: const InputDecoration(labelText: 'Kategori'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _driveLinksController,
                        decoration: const InputDecoration(
                          labelText: 'Google Drive Links (Soal, Gambar, dll)',
                          hintText: 'Paste link Google Drive di sini\nSatu link per baris\nContoh:\nhttps://drive.google.com/file/d/...\nhttps://drive.google.com/open?id=...',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 5,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) {
                                  setState(() { _selectedDeadline = picked; });
                                }
                              },
                              child: Text(_selectedDeadline == null
                                  ? 'Pilih Tanggal Deadline'
                                  : 'Tanggal: ${_selectedDeadline!.day}/${_selectedDeadline!.month}/${_selectedDeadline!.year}'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay.now(),
                                );
                                if (picked != null) {
                                  setState(() { _selectedTime = picked; });
                                }
                              },
                              child: Text(_selectedTime == null
                                  ? 'Pilih Jam Deadline'
                                  : 'Jam: ${_selectedTime!.format(context)}'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _tambahTugas,
                          child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Tambah Tugas'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 32),
              const Text('Daftar Tugas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
              const SizedBox(height: 12),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('tugas').orderBy('deadline').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 32.0),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text('Belum ada tugas.', style: TextStyle(color: Colors.grey[600]))
                          ],
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, i) {
                      final tugas = snapshot.data!.docs[i].data() as Map<String, dynamic>;
                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          title: Text(
                            tugas['judul'] ?? '-',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Deadline: ' + (tugas['deadline'] != null ? (tugas['deadline'] as Timestamp).toDate().toString().substring(0, 16) : '-')),
                              Text('Kategori: ${tugas['kategori'] ?? '-'}'),
                            ],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DosenTaskDetailPage(
                                  tugasId: snapshot.data!.docs[i].id,
                                  tugas: tugas,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    Key? key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 48, color: color),
        const SizedBox(height: 8),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(value, style: Theme.of(context).textTheme.headlineSmall),
      ],
    );
  }
} 