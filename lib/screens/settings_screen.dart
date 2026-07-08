import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../components/info_card.dart';
import '../components/confirmation_dialog.dart';

class SettingsContent extends StatelessWidget {
  const SettingsContent({super.key});

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Konfirmasi Keluar',
      content: 'Apakah Anda yakin ingin keluar dari akun ini?',
      confirmLabel: 'Keluar',
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
            InfoCard(
              leading: const Icon(Icons.info_outline_rounded, size: 36),
              title: 'Smart Brankas',
              subtitle: 'Versi $appVersion${email != null ? ' • $email' : ''}',
            ),
            const SizedBox(height: 16),
            InfoCard(
              leading: const Icon(Icons.logout_rounded),
              title: 'Keluar',
              subtitle: 'Keluar dari akun saat ini',
              onTap: () => _confirmLogout(context),
            ),
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
