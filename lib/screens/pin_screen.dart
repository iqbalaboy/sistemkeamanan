import 'dart:async';
import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../neumorphic_theme.dart';

class PinScreen extends StatefulWidget {
  const PinScreen({super.key});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  bool _loading = false;
  StreamSubscription<String>? _pinSubscription;

  @override
  void initState() {
    super.initState();
    _setupPinListener();
    // don't load or display raw PIN for security
  }

  @override
  void dispose() {
    _pinSubscription?.cancel();
    _oldCtrl.dispose();
    _newCtrl.dispose();
    super.dispose();
  }

  void _setupPinListener() {
    // Listen for PIN updates but DO NOT expose PIN value in UI or logs.
    _pinSubscription = FirebaseService.instance.getPinStream().listen((_) {
      if (!mounted) return;
      // Display a generic notification that PIN changed (no value)
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('PIN diperbarui dari perangkat'),
      ));
    }, onError: (error) {
      debugPrint('Error in PIN stream: $error');
    });
  }

  Future<void> _changePin() async {
    final oldPin = _oldCtrl.text.trim();
    final newPin = _newCtrl.text.trim();

    if (oldPin.isEmpty || newPin.isEmpty) {
      _show('Isi PIN lama & baru');
      return;
    }

    if (newPin.length < 4 || newPin.length > 8) {
      _show('PIN harus 4-8 digit angka');
      return;
    }

    if (!RegExp(r'^[0-9]+$').hasMatch(newPin)) {
      _show('PIN hanya boleh mengandung angka');
      return;
    }

    setState(() => _loading = true);

    try {
      // Use getPin() (existing service) to verify old PIN locally.
      final stored = await FirebaseService.instance.getPin();
      if (stored != null && stored.isNotEmpty && stored != oldPin) {
        _show('PIN lama salah');
        setState(() => _loading = false);
        return;
      }

      // setPin should handle secure storage (server-side hashing ideally)
      await FirebaseService.instance.setPin(newPin);

      if (!mounted) return;

      _show('PIN berhasil diubah!');

      _oldCtrl.clear();
      _newCtrl.clear();

      await Future.delayed(const Duration(milliseconds: 1200));

      Navigator.of(context).pop(true);
    } catch (e) {
      _show('Gagal menyimpan PIN');
      debugPrint('setPin error: $e');
      setState(() => _loading = false);
    }
  }

  void _show(String s) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(s),
      duration: const Duration(seconds: 3),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Ganti PIN'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 32),

              // Header card (neumorphic)
              NeumorphicContainer(
                radius: 20,
                padding:
                    const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
                child: Column(
                  children: [
                    Icon(Icons.password_rounded,
                        size: 90, color: colorScheme.primary),
                    const SizedBox(height: 16),
                    Text(
                      'Ubah PIN Brankas',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Input fields inside neumorphic container
              NeumorphicContainer(
                radius: 16,
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    TextField(
                      controller: _oldCtrl,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 8,
                      decoration: InputDecoration(
                        labelText: 'PIN Lama',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _newCtrl,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 8,
                      decoration: InputDecoration(
                        labelText: 'PIN Baru (4-8 digit angka)',
                        prefixIcon: const Icon(Icons.fingerprint_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        icon: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_rounded),
                        label: Text(_loading ? 'Menyimpan...' : 'Simpan PIN'),
                        onPressed: _loading ? null : _changePin,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              Text(
                'Perubahan PIN akan langsung tersinkronisasi dengan brankas.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
