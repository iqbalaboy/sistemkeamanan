import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class FirebaseService {
  // Singleton setup
  FirebaseService._privateConstructor();
  static final FirebaseService instance = FirebaseService._privateConstructor();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final FirebaseDatabase _db;

  // Path dasar perangkat
  static const String deviceName = "smart_brankas";
  static final String basePath = "/devices/$deviceName";
  DatabaseReference get _deviceRef => _db.ref(basePath);

  Future<void> init() async {
    _db = FirebaseDatabase.instance;
    _db.setPersistenceEnabled(true);
  }

  // 🆕 Helper untuk membuat Firebase-safe timestamp
  String _getFirebaseSafeTimestamp() {
    final now = DateTime.now();
    // Format: YYYY-MM-DD_HH-mm-ss-SSS (mengganti : dengan - dan . dengan _)
    return '${now.year}-${_twoDigits(now.month)}-${_twoDigits(now.day)}_'
        '${_twoDigits(now.hour)}-${_twoDigits(now.minute)}-'
        '${_twoDigits(now.second)}-${now.millisecond}';
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  // 🆕 Helper untuk ISO timestamp (hanya untuk display)
  String _getIsoTimestamp() {
    return DateTime.now().toIso8601String();
  }

  // ---------------------------------------------------------------------------
  // 🔐 AUTH
  // ---------------------------------------------------------------------------

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  Future<UserCredential> createUser(String email, String password) =>
      _auth.createUserWithEmailAndPassword(email: email, password: password);

  Future<void> signOut() => _auth.signOut();

  // ---------------------------------------------------------------------------
  // 🔢 PIN HANDLER - ENHANCED WITH REAL-TIME SYNC
  // ---------------------------------------------------------------------------

  // Path khusus PIN (sama dengan ESP32)
  static final String pinPath = '$basePath/pin';
  DatabaseReference get _pinRef => _db.ref(pinPath);

  Future<String?> getPin() async {
    try {
      final snap = await _pinRef.get();
      if (snap.exists) {
        final pin = snap.value?.toString() ?? '';
        print('📥 Retrieved PIN from Firebase: $pin');
        return pin;
      }
      return null;
    } catch (e) {
      print('❌ Error getting PIN: $e');
      return null;
    }
  }

  Future<void> setPin(String newPin) async {
    try {
      final safeTimestamp = _getFirebaseSafeTimestamp();
      final isoTimestamp = _getIsoTimestamp();

      // Validasi PIN sebelum menyimpan
      if (newPin.length < 4 || newPin.length > 8) {
        throw Exception('PIN harus 4-8 digit');
      }

      if (!RegExp(r'^[0-9]+$').hasMatch(newPin)) {
        throw Exception('PIN hanya boleh mengandung angka');
      }

      // Update ke Firebase (akan trigger stream di ESP32)
      await _pinRef.set(newPin);

      // Juga update history dan status dengan SAFE timestamp
      await _deviceRef.update({
        'current_status': {
          'event': 'pin_changed',
          'time': isoTimestamp, // Untuk display
          'timestamp': safeTimestamp, // Untuk sorting
          'source': 'flutter_app',
        },
        'history/$safeTimestamp': {
          // ✅ SAFE path
          'action': 'pin_changed',
          'time': isoTimestamp,
          'timestamp': safeTimestamp,
          'source': 'flutter_app',
          'new_pin': newPin,
        },
        'pin_metadata': {
          'last_changed': isoTimestamp,
          'last_changed_safe': safeTimestamp,
          'changed_by': 'flutter_app',
        }
      });

      print('✅ PIN saved to Firebase: $newPin');
    } catch (e) {
      print('❌ Error setting PIN: $e');
      rethrow;
    }
  }

  // 🆕 REAL-TIME PIN STREAM (untuk sinkronisasi dari ESP32)
  Stream<String> getPinStream() {
    return _pinRef.onValue.map((event) {
      final pin = event.snapshot.value?.toString() ?? '';
      print('🔄 PIN Stream update: $pin');
      return pin;
    }).handleError((error) {
      print('❌ PIN Stream error: $error');
      return '';
    });
  }

  // ---------------------------------------------------------------------------
  // 📡 STREAMS (REALTIME LISTENERS)
  // ---------------------------------------------------------------------------

  // Status saat ini (realtime)
  Query currentStatusQuery() => _deviceRef.child('current_status');

  // Riwayat aktivitas (realtime)
  Query historyQuery() => _deviceRef.child('history');

  // 🆕 Stream untuk status brankas (terbuka/tertutup)
  Stream<Map<String, dynamic>> getBrankasStatusStream() {
    return _deviceRef.child('current_status').onValue.map((event) {
      final data = event.snapshot.value;
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return {};
    });
  }

  // ---------------------------------------------------------------------------
  // 🕒 HISTORY WRITER - DIPERBAIKI
  // ---------------------------------------------------------------------------

  Future<void> addHistory(String action,
      {Map<String, dynamic>? extraData}) async {
    final safeTimestamp = _getFirebaseSafeTimestamp();
    final isoTimestamp = _getIsoTimestamp();

    final historyData = {
      'action': action,
      'time': isoTimestamp,
      'timestamp': safeTimestamp,
      if (extraData != null) ...extraData,
    };

    await _deviceRef.update({
      'current_status': historyData,
      'history/$safeTimestamp': historyData, // ✅ SAFE path
    });
  }

  // ---------------------------------------------------------------------------
  // 🎥 MOTION / STREAM EVENT - DIPERBAIKI
  // ---------------------------------------------------------------------------

  Future<void> notifyMotion(String cameraStreamUrl) async {
    final safeTimestamp = _getFirebaseSafeTimestamp();
    final isoTimestamp = _getIsoTimestamp();

    await _deviceRef.update({
      'current_status': {
        'event': 'motion_detected',
        'time': isoTimestamp,
        'timestamp': safeTimestamp,
        'camera_stream': cameraStreamUrl,
      },
      'history/$safeTimestamp': {
        // ✅ SAFE path
        'action': 'motion_detected',
        'time': isoTimestamp,
        'timestamp': safeTimestamp,
        'camera_stream': cameraStreamUrl,
      },
    });
  }

  // ---------------------------------------------------------------------------
  // 🔓 BRANKAS CONTROL - DIPERBAIKI
  // ---------------------------------------------------------------------------

  Future<void> updateBrankasStatus(bool isOpen, {String? method}) async {
    final safeTimestamp = _getFirebaseSafeTimestamp();
    final isoTimestamp = _getIsoTimestamp();
    final event = isOpen ? 'brankas_opened' : 'brankas_closed';

    await _deviceRef.update({
      'current_status': {
        'event': event,
        'time': isoTimestamp,
        'timestamp': safeTimestamp,
        'method': method ?? 'unknown',
        'is_open': isOpen,
      },
      'history/$safeTimestamp': {
        // ✅ SAFE path
        'action': event,
        'time': isoTimestamp,
        'timestamp': safeTimestamp,
        'method': method ?? 'unknown',
        'is_open': isOpen,
      },
    });
  }

  // ---------------------------------------------------------------------------
  // 📊 GET HISTORY DATA - DIPERBAIKI
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getHistoryData({int limit = 20}) async {
    try {
      final snapshot = await _deviceRef
          .child('history')
          .orderByChild('timestamp') // ✅ Sort by safe timestamp
          .limitToLast(limit)
          .get();

      if (snapshot.exists) {
        final Map<dynamic, dynamic> historyMap = snapshot.value as Map;
        final List<Map<String, dynamic>> historyList = [];

        historyMap.forEach((key, value) {
          if (value is Map) {
            historyList.add({
              'id': key,
              ...Map<String, dynamic>.from(value),
            });
          }
        });

        // Urutkan dari yang terbaru berdasarkan timestamp
        historyList.sort((a, b) {
          final timeA = a['timestamp'] ?? '';
          final timeB = b['timestamp'] ?? '';
          return timeB.compareTo(timeA);
        });

        return historyList;
      }
      return [];
    } catch (e) {
      print('❌ Error getting history: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // 🧹 OPTIONAL CLEANUP
  // ---------------------------------------------------------------------------

  StreamSubscription? statusSub;
  StreamSubscription? historySub;
  StreamSubscription? pinSub;

  void disposeListeners() {
    statusSub?.cancel();
    historySub?.cancel();
    pinSub?.cancel();
  }

  void setupGlobalPinListener(void Function(String) onPinChanged) {
    pinSub = getPinStream().listen((newPin) {
      if (newPin.isNotEmpty) {
        onPinChanged(newPin);
      }
    }, onError: (error) {
      print('❌ Global PIN listener error: $error');
    });
  }
}
