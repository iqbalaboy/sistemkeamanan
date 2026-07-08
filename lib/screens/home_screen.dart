import 'package:flutter/material.dart';
import 'live_stream_screen.dart';
import 'pin_screen.dart';
import 'settings_screen.dart';
import '../services/firebase_service.dart';
import 'package:intl/intl.dart';
import '../neumorphic_theme.dart';
import '../widgets/status_header.dart';
import '../components/welcome_header.dart';
import '../components/feature_card.dart';
import '../components/history_item.dart';
import '../components/empty_state.dart';
import '../components/bottom_nav.dart';

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

  final List<FeatureCardData> _features = const [
    FeatureCardData(
        id: 'pin', title: 'Ubah PIN', subtitle: '', icon: Icons.lock_rounded),
    FeatureCardData(
        id: 'history',
        title: 'Riwayat',
        subtitle: '',
        icon: Icons.history_rounded),
    FeatureCardData(
        id: 'livestream',
        title: 'Live Stream',
        subtitle: '',
        icon: Icons.videocam_rounded),
    FeatureCardData(
        id: 'status', title: 'Status', subtitle: '', icon: Icons.info_outline),
  ];

  @override
  void initState() {
    super.initState();
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

    service.historyQuery().onValue.listen((event) {
      final data = event.snapshot.value;
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
        : "http://192.168.234.170:80/stream";
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
                          ? const EmptyState(
                              icon: Icons.history_rounded,
                              message: 'Belum ada riwayat')
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
                                return HistoryItem(
                                  action: action.toString(),
                                  time: time,
                                  isSuccess: isSuccess,
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
      return t;
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
          const WelcomeHeader(),
          const SizedBox(height: 12),
          StatusHeader(isOpen: isOpen, lastUpdated: lastUpdated),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Fitur',
                style: TextStyle(
                    color: cs.onBackground.withOpacity(0.85),
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              final itemWidth = (constraints.maxWidth - 12) / 2;
              return SingleChildScrollView(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: List.generate(_features.length, (index) {
                    final f = _features[index];
                    return FeatureCard(
                      data: f,
                      width: itemWidth,
                      onTap: () => _onFeatureTap(f.id),
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 0,
        systemOverlayStyle: Theme.of(context).appBarTheme.systemOverlayStyle,
      ),
      body: Stack(
        children: [
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
          BottomNavBar(
            selectedIndex: _selectedIndex,
            onItemTapped: (i) => setState(() => _selectedIndex = i),
            onFabTap: _openStream,
          ),
        ],
      ),
    );
  }
}
