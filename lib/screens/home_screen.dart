import 'package:flutter/material.dart';
import 'live_stream_screen.dart';
import 'pin_screen.dart';
import 'settings_screen.dart';
import '../services/firebase_service.dart';
import 'package:intl/intl.dart';
import '../neumorphic_theme.dart';
import '../widgets/status_header.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final service = FirebaseService.instance;
  Map currentStatus = {};
  List<Map> historyList = [];
  String cameraStream = "";
  int _selectedIndex = 0;

  // Four main feature cards tailored for Smart Brankas
  final List<_FeatureCardData> _features = const [
    _FeatureCardData(
        id: 'pin', title: 'Ubah PIN', subtitle: '', icon: Icons.lock_rounded),
    _FeatureCardData(
        id: 'history',
        title: 'Riwayat',
        subtitle: '',
        icon: Icons.history_rounded),
    _FeatureCardData(
        id: 'livestream',
        title: 'Live Stream',
        subtitle: '',
        icon: Icons.videocam_rounded),
    _FeatureCardData(
        id: 'status', title: 'Status', subtitle: '', icon: Icons.info_outline),
  ];

  @override
  void initState() {
    super.initState();

    // 🔴 Listener status brankas
    service.currentStatusQuery().onValue.listen((event) {
      final val = event.snapshot.value;
      if (val != null) {
        if (!mounted) return;
        setState(() {
          currentStatus = Map<String, dynamic>.from(val as Map);
          cameraStream =
              currentStatus['camera_stream']?.toString() ?? cameraStream;
        });
      } else {
        if (mounted) setState(() => currentStatus = {});
      }
    });

    // 🟢 Listener riwayat aktivitas
    service.historyQuery().onValue.listen((event) {
      final data = event.snapshot.value;
      debugPrint('🔥 History listener triggered: $data');

      if (!mounted) return;

      if (data == null) {
        setState(() => historyList = []);
        return;
      }

      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        final entries = map.entries.map((e) {
          if (e.value is Map) {
            final m = Map<String, dynamic>.from(e.value);
            m['__key'] = e.key;
            return m;
          } else {
            return {'action': e.value.toString(), '__key': e.key};
          }
        }).toList();
        entries.sort((a, b) => b['__key'].compareTo(a['__key']));
        setState(() => historyList = entries.cast<Map>());
      } else if (data is List) {
        final list = data
            .whereType<Map>()
            .toList()
            .reversed
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        setState(() => historyList = list);
      }
    });
  }

  bool _isVaultOpenFromStatus() {
    try {
      final raw = (currentStatus['event'] ??
              currentStatus['status'] ??
              currentStatus['state'] ??
              '')
          .toString()
          .toLowerCase();
      return raw.contains('open') ||
          raw.contains('buka') ||
          raw.contains('terbuka') ||
          raw.contains('unlock') ||
          raw.contains('unlocked');
    } catch (_) {
      return false;
    }
  }

  String? _lastUpdatedFromStatus() {
    final t = currentStatus['time'] ??
        currentStatus['updated_at'] ??
        currentStatus['timestamp'];
    if (t == null) return null;
    try {
      final s = t.toString();
      final dt = DateTime.parse(s);
      return DateFormat('yyyy-MM-dd HH:mm').format(dt);
    } catch (_) {
      // try numeric timestamp (seconds or ms)
      try {
        final n = int.parse(t.toString());
        DateTime dt;
        if (t.toString().length >= 13) {
          dt = DateTime.fromMillisecondsSinceEpoch(n);
        } else {
          dt = DateTime.fromMillisecondsSinceEpoch(n * 1000);
        }
        return DateFormat('yyyy-MM-dd HH:mm').format(dt);
      } catch (_) {
        return null;
      }
    }
  }

  void _openStream() {
    final url = cameraStream.isNotEmpty
        ? cameraStream
        : "http://192.168.23.172:80/stream";
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LiveStreamScreen(streamUrl: url)),
    );
  }

  void _openPinScreen() async {
    final changed = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => const PinScreen()));
    if (changed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN berhasil diperbarui')),
      );
    }
  }

  void _openHistorySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.3,
            maxChildSize: 0.92,
            builder: (_, controller) {
              return Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, -4))
                  ],
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 6,
                      decoration: BoxDecoration(
                          color: cs.onSurfaceVariant.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Riwayat Aktivitas',
                              style: TextStyle(
                                  color: cs.onSurface,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Tutup'),
                          )
                        ],
                      ),
                    ),
                    Expanded(
                      child: historyList.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.history_rounded,
                                      size: 64,
                                      color:
                                          cs.onSurfaceVariant.withOpacity(0.3)),
                                  const SizedBox(height: 8),
                                  Text('Belum ada riwayat',
                                      style: TextStyle(
                                          color: cs.onSurfaceVariant,
                                          fontSize: 14))
                                ],
                              ),
                            )
                          : ListView.builder(
                              controller: controller,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              itemCount: historyList.length,
                              itemBuilder: (context, i) {
                                final item = historyList[i];
                                final action =
                                    item['action'] ?? item['event'] ?? '';
                                final time = _formatTime(
                                    item['time'] ?? item['__key'] ?? '');
                                final isSuccess = action
                                    .toString()
                                    .toLowerCase()
                                    .contains('berhasil');
                                final color =
                                    isSuccess ? Colors.green : Colors.red;
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
                                      Icon(
                                          isSuccess
                                              ? Icons.check_circle_rounded
                                              : Icons.error_rounded,
                                          color: color),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(action.toString(),
                                                style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: cs.onSurface)),
                                            const SizedBox(height: 4),
                                            Text(time,
                                                style: TextStyle(
                                                    color: cs.onSurfaceVariant,
                                                    fontSize: 12)),
                                          ],
                                        ),
                                      )
                                    ],
                                  ),
                                );
                              },
                            ),
                    )
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showStatusDialog() {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Status Brankas',
                  style: TextStyle(
                      color: cs.onSurface, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Event',
                            style: TextStyle(
                                color: cs.onSurfaceVariant, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(currentStatus['event']?.toString() ?? '-',
                            style: TextStyle(
                                color: cs.onSurface,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Waktu',
                            style: TextStyle(
                                color: cs.onSurfaceVariant, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(_formatTime(currentStatus['time']?.toString()),
                            style: TextStyle(
                                color: cs.onSurface,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (currentStatus.isNotEmpty)
                Text(
                  'Camera: ${currentStatus['camera_stream'] ?? '-'}',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Tutup'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(String? t) {
    if (t == null) return '-';
    try {
      final dt = DateTime.parse(t);
      return DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
    } catch (_) {
      return t ?? '-';
    }
  }

  void _onFeatureTap(String id) {
    switch (id) {
      case 'pin':
        _openPinScreen();
        break;
      case 'history':
        _openHistorySheet();
        break;
      case 'livestream':
        _openStream();
        break;
      case 'status':
        _showStatusDialog();
        break;
      default:
        break;
    }
  }

  Widget _buildHomeBody(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isOpen = _isVaultOpenFromStatus();
    final lastUpdated = _lastUpdatedFromStatus();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 16),

          // Welcome (big) box
          const _LargeHeader(),

          const SizedBox(height: 12),

          // Separated status header placed under the welcome box
          StatusHeader(isOpen: isOpen, lastUpdated: lastUpdated),

          const SizedBox(height: 18),

          // Section header (Lihat Semua removed)
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Fitur',
                style: TextStyle(
                    color: cs.onBackground.withOpacity(0.85),
                    fontWeight: FontWeight.w600)),
          ),

          const SizedBox(height: 8),

          // 2x2 grid of feature cards
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              final itemWidth = (constraints.maxWidth - 12) / 2;
              return SingleChildScrollView(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: List.generate(_features.length, (index) {
                    final f = _features[index];
                    return GestureDetector(
                      onTap: () => _onFeatureTap(f.id),
                      child: SizedBox(
                        width: itemWidth,
                        child: NeumorphicContainer(
                          radius: 20,
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // small dark rounded square with icon (floating)
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
                                    child: Icon(f.icon,
                                        color: Colors.white, size: 18),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(f.title,
                                  style: TextStyle(
                                      color: cs.onSurface,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15)),
                              const SizedBox(height: 6),
                              Text(f.subtitle,
                                  style: TextStyle(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 12,
                                  )),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              );
            }),
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      // keep a minimal app bar area (transparent) so status bar icons are visible
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 0, // hide default toolbar area, header is in body now
        systemOverlayStyle: Theme.of(context).appBarTheme.systemOverlayStyle,
      ),
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  cs.background,
                  AppTheme.innerSurface.withOpacity(0.95),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: IndexedStack(
                    index: _selectedIndex == 1 ? 1 : 0,
                    children: [
                      _buildHomeBody(context),
                      const SettingsContent(),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom floating navbar with center FAB (unchanged)
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(35),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: Colors.white.withOpacity(0.8),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Nav items
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _NavItemCustom(
                          icon: Icons.home_outlined,
                          activeIcon: Icons.home_rounded,
                          label: 'Beranda',
                          selected: _selectedIndex == 0,
                          onTap: () => setState(() => _selectedIndex = 0),
                        ),
                        const SizedBox(width: 56),
                        _NavItemCustom(
                          icon: Icons.settings_outlined,
                          activeIcon: Icons.settings_rounded,
                          label: 'Pengaturan',
                          selected: _selectedIndex == 1,
                          onTap: () => setState(() => _selectedIndex = 1),
                        ),
                      ],
                    ),
                  ),

                  // Center FAB for Live Stream
                  Positioned(
                    top: -20,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: _openStream,
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                cs.primary,
                                cs.primary.withOpacity(0.8),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: cs.primary.withOpacity(0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.videocam_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Large header widget focused on layout (no clock)
/// This widget only renders the Welcome / Selamat Datang box.
class _LargeHeader extends StatelessWidget {
  const _LargeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title row
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
            Text('Smart Brankas',
                style: TextStyle(
                    color: cs.onBackground,
                    fontSize: 26,
                    fontWeight: FontWeight.bold)),
          ],
        ),

        const SizedBox(height: 12),

        // Welcome card
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 150),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF4A6CF7),
                const Color(0xFF3A57D8),
              ],
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
              // left: welcome text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Selamat Datang!',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.98),
                            fontSize: 22,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Text('Kelola brankas Anda dengan mudah',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.95),
                            fontSize: 12)),
                  ],
                ),
              ),

              // right: decorative icon box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.lock_outline_rounded,
                    color: Colors.white, size: 48),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Custom nav item that matches neumorphic style and app features
class _NavItemCustom extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItemCustom({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? activeIcon : icon,
              color:
                  selected ? cs.primary : cs.onSurfaceVariant.withOpacity(0.6),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? cs.primary
                    : cs.onSurfaceVariant.withOpacity(0.6),
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureCardData {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  const _FeatureCardData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}
