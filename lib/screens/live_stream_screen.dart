import 'package:flutter/material.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import '../components/info_card.dart';

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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: InfoCard(
              leading: Icon(Icons.videocam_rounded, color: colorScheme.primary),
              title: 'Live Cam',
              subtitle: widget.streamUrl,
              radius: 16,
            ),
          ),
          const SizedBox(height: 16),
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
