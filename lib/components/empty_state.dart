import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final double iconSize;

  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.iconSize = 64,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              size: iconSize, color: cs.onSurfaceVariant.withOpacity(0.3)),
          const SizedBox(height: 8),
          Text(message,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
        ],
      ),
    );
  }
}
