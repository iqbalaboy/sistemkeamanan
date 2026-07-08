import 'dart:async';
import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../neumorphic_theme.dart';
import '../components/neumorphic_text_field.dart';
import '../components/loading_button.dart';

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
  }

  @override
  void dispose() {
    _pinSubscription?.cancel();
    _oldCtrl.dispose();
    _newCtrl.dispose();
    super.dispose();
  }

  void _setupPinListener() {
    _pinSubscription = FirebaseService.instance.getPinStream().listen((_) {
      if (!mounted) return;
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
      final stored = await FirebaseService.instance.getPin();
      if (stored != null && stored.isNotEmpty && stored != oldPin) {
        _show('PIN lama salah');
        setState(() => _loading = false);
        return;
      }

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
              NeumorphicContainer(
                radius: 20,
                padding:
                    const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
                child: Column(
                  children: [
                    Icon(Icons.password_rounded,
                        size: 90, color: colorScheme.primary),
                    const SizedBox(height: 16),
                    Text('Ubah PIN Brankas',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              NeumorphicContainer(
                radius: 16,
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    NeumorphicTextField(
                      controller: _oldCtrl,
                      labelText: 'PIN Lama',
                      prefixIcon: Icons.lock_outline_rounded,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 8,
                      borderRadius: 12,
                    ),
                    const SizedBox(height: 12),
                    NeumorphicTextField(
                      controller: _newCtrl,
                      labelText: 'PIN Baru (4-8 digit angka)',
                      prefixIcon: Icons.fingerprint_rounded,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 8,
                      borderRadius: 12,
                    ),
                    const SizedBox(height: 18),
                    LoadingButton(
                      loading: _loading,
                      onPressed: _changePin,
                      label: 'Simpan PIN',
                      loadingLabel: 'Menyimpan...',
                      icon: Icons.save_rounded,
                      height: 52,
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
