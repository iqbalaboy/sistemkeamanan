import 'package:flutter/material.dart';

class LoadingButton extends StatelessWidget {
  final bool loading;
  final VoidCallback? onPressed;
  final String label;
  final String? loadingLabel;
  final IconData? icon;
  final double height;
  final double width;
  final Color? backgroundColor;

  const LoadingButton({
    super.key,
    required this.loading,
    required this.onPressed,
    required this.label,
    this.loadingLabel,
    this.icon,
    this.height = 54,
    this.width = double.infinity,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      height: height,
      child: FilledButton.icon(
        style: backgroundColor != null
            ? FilledButton.styleFrom(backgroundColor: backgroundColor)
            : null,
        icon: loading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: backgroundColor != null ? Colors.white : cs.onPrimary,
                ),
              )
            : icon != null
                ? Icon(icon)
                : const SizedBox.shrink(),
        label: Text(loading ? (loadingLabel ?? label) : label),
        onPressed: loading ? null : onPressed,
      ),
    );
  }
}
