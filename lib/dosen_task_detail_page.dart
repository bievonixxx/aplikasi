import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class DosenTaskDetailPage extends StatelessWidget {
  final String tugasId;
  final Map<String, dynamic> tugas;
  const DosenTaskDetailPage({super.key, required this.tugasId, required this.tugas});

  @override
  Widget build(BuildContext context) {
    final deadline = tugas['deadline'] != null ? (tugas['deadline'] as Timestamp).toDate() : null;
    final mainContext = context;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Tugas (Dosen)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Hapus Tugas',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Konfirmasi Hapus'),
                  content: const Text('Yakin ingin menghapus tugas ini beserta semua pengumpulan?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus', style: TextStyle(color: Colors.red))),
                  ],
                ),
              );
              if (confirm == true) {
                // Hapus semua pengumpulan
                final pengumpulan = await FirebaseFirestore.instance
                  .collection('tugas')
                  .doc(tugasId)
                  .collection('pengumpulan')
                  .get();
                for (final doc in pengumpulan.docs) {
                  await doc.reference.delete();
                }
                // Hapus tugas
                await FirebaseFirestore.instance.collection('tugas').doc(tugasId).delete();
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tugas berhasil dihapus!')));
                }
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Detail Tugas', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Text('Judul:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(tugas['judul'] ?? '-', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Text('Deskripsi:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(tugas['deskripsi'] ?? '-'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Chip(label: Text('Deadline: ${deadline != null ? '${deadline.day}/${deadline.month}/${deadline.year} ${deadline.hour.toString().padLeft(2, '0')}:${deadline.minute.toString().padLeft(2, '0')}' : '-'}')),
                        const SizedBox(width: 8),
                        Chip(label: Text('Kategori: ${tugas['kategori'] ?? '-'}')),
                      ],
                    ),
                    const Divider(height: 32),
                    // File lampiran section
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('tugas')
                          .doc(tugasId)
                          .collection('attachments')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const SizedBox();
                        }
                        
                        final attachmentDoc = snapshot.data!.docs.first;
                        final files = List<Map<String, dynamic>>.from(attachmentDoc['files'] ?? []);
                        
                        if (files.isEmpty) return const SizedBox();
                        
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('File Lampiran:', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            ...(files.map((file) {
                              final link = file['link'] ?? '';
                              final fileType = file['type'] ?? 'unknown';
                              final previewUrl = file['previewUrl'] ?? '';
                              final downloadUrl = file['downloadUrl'] ?? '';
                              
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ListTile(
                                      leading: Icon(_getFileIcon(fileType)),
                                      title: Text('File dari Google Drive'),
                                      subtitle: Text(link),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (downloadUrl.isNotEmpty)
                                            IconButton(
                                              icon: const Icon(Icons.download),
                                              onPressed: () async {
                                                if (await canLaunchUrl(Uri.parse(downloadUrl))) {
                                                  await launchUrl(Uri.parse(downloadUrl), mode: LaunchMode.externalApplication);
                                                }
                                              },
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (fileType == 'pdf' && previewUrl.isNotEmpty)
                                      Container(
                                        margin: const EdgeInsets.all(8),
                                        child: ElevatedButton.icon(
                                          onPressed: () async {
                                            if (await canLaunchUrl(Uri.parse(downloadUrl))) {
                                              await launchUrl(Uri.parse(downloadUrl), mode: LaunchMode.externalApplication);
                                            }
                                          },
                                          icon: const Icon(Icons.download),
                                          label: const Text('Download PDF'),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }).toList()),
                            const Divider(height: 32),
                          ],
                        );
                      },
                    ),
                    const Text('Daftar Pengumpul:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 300,
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('tugas')
                            .doc(tugasId)
                            .collection('pengumpulan')
                            .orderBy('waktuKumpul', descending: false)
                            .snapshots(),
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
                                    Text('Belum ada mahasiswa yang mengumpulkan tugas.', style: TextStyle(color: Colors.grey[600]))
                                  ],
                                ),
                              ),
                            );
                          }
                          return ListView.builder(
                            itemCount: snapshot.data!.docs.length,
                            itemBuilder: (context, i) {
                              final data = snapshot.data!.docs[i].data() as Map<String, dynamic>;
                              final waktu = data['waktuKumpul'] != null ? (data['waktuKumpul'] as Timestamp).toDate() : null;
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  title: Text('${data['nama'] ?? '-'} (${data['nim'] ?? '-'})', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (waktu != null)
                                        Text('Waktu Kumpul: $waktu'),
                                      if (data['fileUrl'] != null)
                                        TextButton(
                                          onPressed: () async {
                                            final url = data['fileUrl'];
                                            if (await canLaunchUrl(Uri.parse(url))) {
                                              await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                                            } else {
                                              ScaffoldMessenger.of(mainContext).showSnackBar(const SnackBar(content: Text('Tidak bisa membuka link!')));
                                            }
                                          },
                                          child: const Text('Lihat File'),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getFileIcon(String fileType) {
    switch (fileType) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'document':
        return Icons.description;
      case 'presentation':
        return Icons.slideshow;
      case 'image':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }
} 