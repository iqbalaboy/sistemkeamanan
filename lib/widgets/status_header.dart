import 'package:flutter/material.dart';
import '../neumorphic_theme.dart';

/// StatusHeader: separate widget that shows simple vault status (open/locked)
/// and optional last-updated timestamp. Designed to be placed under the welcome box.
class StatusHeader extends StatelessWidget {
  final bool isOpen;
  final String? lastUpdated;
  final VoidCallback? onTap;

  const StatusHeader({
    super.key,
    required this.isOpen,
    this.lastUpdated,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Updated: green when open, red when locked
    final statusColor = isOpen ? Colors.greenAccent.shade400 : Colors.redAccent;
    final statusText = isOpen ? 'Brankas Terbuka' : 'Brankas Terkunci';
    final statusIcon = isOpen ? Icons.lock_open_rounded : Icons.lock_rounded;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: NeumorphicContainer(
        radius: 14,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Colored status badge
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(statusIcon, color: statusColor, size: 22),
            ),

            const SizedBox(width: 12),

            // Texts
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(statusText,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      )),
                  if (lastUpdated != null) ...[
                    const SizedBox(height: 6),
                    Text('Terakhir: $lastUpdated',
                        style: TextStyle(
                          color: cs.onSurface.withOpacity(0.75),
                          fontSize: 12,
                        )),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}