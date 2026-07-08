import 'package:flutter/material.dart';
import '../neumorphic_theme.dart';

class HistoryItem extends StatelessWidget {
  final String action;
  final String time;
  final bool isSuccess;

  const HistoryItem({
    super.key,
    required this.action,
    required this.time,
    this.isSuccess = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = isSuccess ? Colors.green : Colors.red;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.background,
        borderRadius: BorderRadius.circular(14),
        boxShadow: neumorphicShadows(
          lightShadow: Colors.white,
          darkShadow: cs.primary.withOpacity(0.85),
          blur: 12,
          offset: 6,
        ),
      ),
      child: Row(
        children: [
          Icon(isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
              color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(action,
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: cs.onSurface)),
                const SizedBox(height: 4),
                Text(time,
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
              ],
            ),
          )
        ],
      ),
    );
  }
}
