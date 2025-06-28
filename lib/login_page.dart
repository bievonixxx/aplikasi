import 'package:flutter/material.dart';
import 'register_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_page.dart';
import 'dosen_home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _nimController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _isDosen = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login Mahasiswa/Dosen')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Selamat Datang', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _nimController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'NIM',
                        prefixIcon: Icon(Icons.badge),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Checkbox(
                          value: !_isDosen,
                          onChanged: (val) {
                            setState(() {
                              _isDosen = false;
                            });
                          },
                        ),
                        const Text('Mahasiswa'),
                        Checkbox(
                          value: _isDosen,
                          onChanged: (val) {
                            setState(() {
                              _isDosen = true;
                            });
                          },
                        ),
                        const Text('Dosen'),
                      ],
                    ),
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Login'),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const RegisterPage()),
                        );
                      },
                      child: const Text('Belum punya akun? Registrasi'),
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

  void _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final nim = _nimController.text.trim();
    if (nim.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'NIM harus diisi';
      });
      return;
    }
    if (_isDosen) {
      if (nim == '10122090') {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const DosenHomePage(),
            ),
          );
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'NIM dosen salah!';
        });
      }
      setState(() {
        _isLoading = false;
      });
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('mahasiswa').doc(nim).get();
      if (doc.exists) {
        final data = doc.data()!;
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => HomePage(
                nama: data['nama'] ?? '',
                nim: data['nim'] ?? '',
                jurusan: data['jurusan'] ?? '',
              ),
            ),
          );
        }
      } else {
        setState(() {
          _errorMessage = 'NIM tidak ditemukan';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Terjadi kesalahan. Coba lagi.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
} 