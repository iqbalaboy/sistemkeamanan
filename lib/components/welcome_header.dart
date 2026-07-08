import 'package:flutter/material.dart';

class WelcomeHeader extends StatelessWidget {
  final String title;
  final String greeting;
  final String subtitle;
  final IconData icon;

  const WelcomeHeader({
    super.key,
    this.title = 'Smart Brankas',
    this.greeting = 'Selamat Datang!',
    this.subtitle = 'Kelola brankas Anda dengan mudah',
    this.icon = Icons.lock_outline_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.vpn_key_rounded,
                  color: cs.onPrimaryContainer, size: 18),
            ),
            const SizedBox(width: 10),
            Text(title,
                style: TextStyle(
                    color: cs.onBackground,
                    fontSize: 26,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 150),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4A6CF7), Color(0xFF3A57D8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.14),
                blurRadius: 16,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(greeting,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.98),
                            fontSize: 22,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Text(subtitle,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.95),
                            fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: Colors.white, size: 48),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
