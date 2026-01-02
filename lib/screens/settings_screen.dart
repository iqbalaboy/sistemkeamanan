import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../neumorphic_theme.dart';

/// A settings content widget (no Scaffold) so it can be shown inside HomeScreen
/// while keeping the bottom navigation bar visible.
class SettingsContent extends StatelessWidget {
  const SettingsContent({super.key});

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Keluar'),
        content: const Text('Apakah Anda yakin ingin keluar dari akun ini?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Batal')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Keluar')),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseAuth.instance.signOut();
      if (!context.mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;
    const appVersion = '1.0.0';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // small header so it's clear we're in settings
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Icon(Icons.settings_rounded, color: cs.onSurface),
                  const SizedBox(width: 12),
                  Text('Pengaturan',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface)),
                ],
              ),
            ),

            const SizedBox(height: 8),

            NeumorphicContainer(
              radius: 14,
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Smart Brankas',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: cs.onSurface)),
                        const SizedBox(height: 4),
                        Text('Versi $appVersion',
                            style: TextStyle(color: cs.onSurfaceVariant)),
                        if (email != null) ...[
                          const SizedBox(height: 6),
                          Text('Login sebagai: $email',
                              style: TextStyle(
                                  color: cs.onSurfaceVariant, fontSize: 12)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            NeumorphicContainer(
              radius: 14,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: const Icon(Icons.logout_rounded),
                title: const Text('Keluar'),
                subtitle: const Text('Keluar dari akun saat ini'),
                onTap: () => _confirmLogout(context),
              ),
            ),

            const SizedBox(height: 12),

            // Footer small
            const Spacer(),
            Text('© 2025 Smart Brankas',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
