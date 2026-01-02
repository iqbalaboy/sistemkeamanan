import 'package:flutter/material.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import '../neumorphic_theme.dart';

class LiveStreamScreen extends StatefulWidget {
  final String streamUrl;

  const LiveStreamScreen({super.key, required this.streamUrl});

  @override
  State<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends State<LiveStreamScreen> {
  bool _isReloading = false;

  void _reloadStream() {
    setState(() => _isReloading = true);
    Future.delayed(const Duration(milliseconds: 800), () {
      setState(() => _isReloading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Stream'),
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),

          // 🔵 Info Stream (neumorphic)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: NeumorphicContainer(
              radius: 16,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: ListTile(
                leading:
                    Icon(Icons.videocam_rounded, color: colorScheme.primary),
                title: const Text('Live Cam'),
                subtitle:
                    Text(widget.streamUrl, overflow: TextOverflow.ellipsis),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 🎥 Area Stream
          Expanded(
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: _isReloading
                    ? const CircularProgressIndicator()
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Mjpeg(
                          key: ValueKey(widget.streamUrl),
                          stream: widget.streamUrl,
                          isLive: true,
                          fit: BoxFit.contain,
                          loading: (context) =>
                              const CircularProgressIndicator(),
                          error: (context, error, stack) => Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline,
                                  color: colorScheme.error, size: 48),
                              const SizedBox(height: 12),
                              const Text(
                                'Gagal memuat stream',
                                style: TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 🧭 Navigasi Bawah
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Kembali'),
                ),
                const SizedBox(width: 16),
                FilledButton.icon(
                  onPressed: _reloadStream,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Segarkan'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
