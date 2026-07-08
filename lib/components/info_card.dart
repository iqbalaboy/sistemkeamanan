import 'package:flutter/material.dart';
import '../neumorphic_theme.dart';

class InfoCard extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final double radius;

  const InfoCard({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.radius = 14,
  });

  @override
  Widget build(BuildContext context) {
    return NeumorphicContainer(
      radius: radius,
      padding: EdgeInsets.symmetric(
          horizontal: 12, vertical: onTap != null ? 4 : 14),
      child: ListTile(
        leading: leading,
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}
