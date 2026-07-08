import 'package:flutter/material.dart';
import '../neumorphic_theme.dart';

class FeatureCardData {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  const FeatureCardData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

class FeatureCard extends StatelessWidget {
  final FeatureCardData data;
  final VoidCallback onTap;
  final double width;

  const FeatureCard({
    super.key,
    required this.data,
    required this.onTap,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: NeumorphicContainer(
          radius: 20,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: neumorphicShadows(
                    lightShadow: Colors.white,
                    darkShadow: cs.primary.withOpacity(0.85),
                    blur: 10,
                    offset: 4,
                    opacityDark: 0.12,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(data.icon, color: Colors.white, size: 18),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(data.title,
                  style: TextStyle(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
              const SizedBox(height: 6),
              Text(data.subtitle,
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 12,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
