#include <Arduino.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include <Keypad.h>
#include <ESP32Servo.h>
#include <UniversalTelegramBot.h>
#include <HTTPClient.h>
#include <vector>

// Firebase
#include <Firebase_ESP_Client.h>
#include "addons/TokenHelper.h"
#include "time.h"  // NTP

// ==================== CONFIG WIFI ====================
const char* WIFI_SSID = "SENYUMCINA";
const char* WIFI_PASS = "salamdulu";

// Telegram
const char* BOT_TOKEN = "8545375333:AAGzhIfPukw6dazpWbg-3AoxJUnRPFg4kjw";
const char* CHAT_ID   = "1673567582";

// ESP32-CAM
const char* camHost = "192.168.234.170";
const uint16_t camPort = 80;
const char* camStreamPath = "/stream";
const char* camSnapshotPath = "/capture";  // endpoint snapshot

// Firebase
const char* FIREBASE_API_KEY       = "AIzaSyDLKmfovVg_eTlMkumkI-F_od5A-8hbtF8";
const char* FIREBASE_DATABASE_URL  = "https://smartbrankas-9d384-default-rtdb.asia-southeast1.firebasedatabase.app";
const char* FIREBASE_USER_EMAIL    = "iqbalardiansyah326@gmail.com";
const char* FIREBASE_USER_PASSWORD = "password123";
// ===============================================================

// Device & DB path
const char* DEVICE_NAME = "smart_brankas";
String DATABASE_PATH = String("/devices/") + DEVICE_NAME;

// ===== Hardware setup =====
LiquidCrystal_I2C lcd(0x27, 16, 2);

// Keypad
const byte ROWS = 4;
const byte COLS = 4;
char keys[ROWS][COLS] = {
  {'1','2','3','A'},
  {'4','5','6','B'},
  {'7','8','9','C'},
  {'*','0','#','D'}
};
byte rowPins[ROWS] = {19, 18, 23, 5};
byte colPins[COLS] = {16, 4, 25, 26};
Keypad keypad = Keypad(makeKeymap(keys), rowPins, colPins, ROWS, COLS);

const int pirPin = 32;
const int buzzerPin = 27;
const int ledMerah = 12;
const int ledHijau = 13;

Servo brankasServo;
const int servoPin = 14;
const int SERVO_CLOSED_ANGLE = 0;
const int SERVO_OPEN_ANGLE  = 90;

// ===== App state =====
String pinInput = "";
String pinBenar = "111111"; // default
bool loginMode = false;
bool ubahPinMode = false;
bool menuUtama = false;
bool gerakanTerdeteksi = false;
bool brankasTerbuka = false;
unsigned long lastMotion = 0;
unsigned long motionStartTime = 0;
bool motionConfirmed = false;
int salahCounter = 0;
bool pinChangingFromStream = false; // Flag untuk mencegah loop

// ===== Firebase objects =====
FirebaseData fbdo;
FirebaseData fbdoStream; // Untuk stream PIN changes
FirebaseAuth fbAuth;
FirebaseConfig fbConfig;
bool firebaseReady = false;
bool streamSetupDone = false;

// ===== Telegram =====
WiFiClientSecure secureClient;
UniversalTelegramBot bot(BOT_TOKEN, secureClient);

// ===== Background tasks =====
volatile bool motionPending = false;
unsigned long lastNotifyTime = 0;
const unsigned long NOTIFY_COOLDOWN = 0UL;
const unsigned long MOTION_THRESHOLD = 1400UL; // ms
TaskHandle_t notifyTaskHandle = NULL;

// ===== Intruder photo control =====
unsigned long lastIntruderPhotoTime = 0;
const unsigned long INTRUDER_PHOTO_COOLDOWN = 10000UL; // 10 detik

// Buffer & callback untuk sendPhotoByBinary
static const uint8_t* tgPhotoBuf = nullptr;
static size_t tgPhotoLen = 0;
static size_t tgPhotoPos = 0;

bool tgMoreDataAvailable() {
  return tgPhotoPos < tgPhotoLen;
}
uint8_t tgGetNextByte() {
  if (tgPhotoPos < tgPhotoLen) return tgPhotoBuf[tgPhotoPos++];
  return 0;
}
uint8_t* tgGetNextBuffer(size_t* size) { // tidak dipakai
  if (size) *size = 0;
  return nullptr;
}
int tgOnRequestEnd() { // opsional
  return 0;
}

// ===== Forward declarations =====
void setupWiFi();
void setupTime();
void setupFirebase();
void setupPinStream();
String getFormattedTime();
void saveCurrentStatus(FirebaseJson &data);
void saveHistory(FirebaseJson &data, const String &action);
bool loadPinFromFirebase();
bool savePinToFirebase(const String &pin, const String &source);
bool isDigitsOnly(const String &s);

// Telegram notification functions
void sendTelegramNotification(const String &message);
void notifyMotionDetected();
void notifyBrankasOpened();
void notifyPinChanged(const String &source);
void notifyLockout();

bool captureAndSendIntruderPhoto();
bool fetchCameraJpeg(std::vector<uint8_t> &buffer);
bool sendTelegramPhoto(const std::vector<uint8_t> &buffer, const String &caption);

void notifyTask(void * parameter);
void streamCallback(FirebaseStream data);
void streamTimeoutCallback(bool timeout);

void tampilkanAwal();
void tampilkanMenuUtama();
void printMasked(const String &s);
void buzzerBeep(int duration_ms);
void bukaBrankas();
void tutupBrankas();
void handlePinEntry(char key);
void handleGantiPin(char key);

// ===== PIN Stream Callback (Firebase → ESP) =====
void streamCallback(FirebaseStream data) {
  Serial.println("\n========== FIREBASE STREAM CALLBACK ==========");
  Serial.printf("Stream path: %s\n", data.dataPath().c_str());
  Serial.printf("Event type: %s\n", data.eventType().c_str());
  
  // Hanya proses jika data berupa string (PIN)
  if (data.dataTypeEnum() == fb_esp_rtdb_data_type_string) {
    String newPin = data.stringData();
    Serial.printf("Received PIN from Firebase: '%s'\n", newPin.c_str());
    Serial.printf("Current PIN: '%s'\n", pinBenar.c_str());
    
    // Validasi PIN format
    if (isDigitsOnly(newPin) && newPin.length() >= 4 && newPin.length() <= 8) {
      if (newPin != pinBenar) {
        Serial.println("📱 PIN CHANGED FROM FLUTTER APP!");
        Serial.printf("   Old PIN: %s\n", pinBenar.c_str());
        Serial.printf("   New PIN: %s\n", newPin.c_str());
        
        // Set flag untuk mencegah loop saat update
        pinChangingFromStream = true;
        
        // Update PIN lokal
        pinBenar = newPin;
        
        // Tampilkan notifikasi di LCD jika tidak sedang digunakan
        if (!loginMode && !ubahPinMode && !brankasTerbuka && !menuUtama) {
          lcd.clear();
          lcd.print("PIN Diupdate!");
          lcd.setCursor(0, 1);
          lcd.print("dari Aplikasi");
          buzzerBeep(200);
          delay(2000);
          tampilkanAwal();
        }
        
        // Kirim notifikasi Telegram
        notifyPinChanged("app");
        
        // Reset flag
        pinChangingFromStream = false;
        
        Serial.println("✅ PIN synchronized from Flutter app");
      } else {
        Serial.println("ℹ️ PIN unchanged (same value)");
      }
    } else {
      Serial.printf("❌ Invalid PIN format: '%s' (length: %d)\n", newPin.c_str(), newPin.length());
    }
  } else {
    Serial.printf("⚠️ Unexpected data type: %d\n", data.dataTypeEnum());
  }
  
  Serial.println("==============================================\n");
}

void streamTimeoutCallback(bool timeout) {
  if (timeout) {
    Serial.println("⚠️ Firebase stream timeout, will reconnect automatically...");
  } else {
    Serial.println("✅ Firebase stream connected and listening for PIN changes");
  }
}

// ================= Implementation =================

void setup() {
  Serial.begin(115200);
  delay(50);
  
  Serial.println("\n\n========================================");
  Serial.println("   SMART BRANKAS - PIN SYNC SYSTEM");
  Serial.println("========================================\n");
  
  lcd.init();
  lcd.backlight();

  // servo
  brankasServo.attach(servoPin, 500, 2400);
  brankasServo.write(SERVO_CLOSED_ANGLE);
  delay(200);
  brankasTerbuka = false;

  // pins
  pinMode(pirPin, INPUT);
  pinMode(buzzerPin, OUTPUT);
  pinMode(ledMerah, OUTPUT);
  pinMode(ledHijau, OUTPUT);
  digitalWrite(buzzerPin, LOW);
  digitalWrite(ledMerah, LOW);
  digitalWrite(ledHijau, LOW);

  tampilkanAwal();

  // WiFi, time, Firebase
  setupWiFi();
  setupTime();
  setupFirebase();

  // Load PIN from Firebase
  if (firebaseReady) {
    if (!loadPinFromFirebase()) {
      Serial.println("⚠️ No valid PIN in Firebase; saving default PIN");
      savePinToFirebase(pinBenar, "system");
    }
    
    // Setup PIN stream untuk sinkronisasi real-time
    Serial.println("\n🔄 Setting up real-time PIN synchronization...");
    setupPinStream();
  } else {
    Serial.println("❌ Firebase not ready; will use local default PIN");
  }

  // Telegram TLS
  secureClient.setInsecure();
  Serial.println("✅ Telegram client configured");

  // Create background task
  xTaskCreatePinnedToCore(notifyTask, "notifyTask", 8192, NULL, 1, &notifyTaskHandle, 1);
  
  Serial.println("\n✅ System ready!");
  Serial.println("========================================\n");
}

// ---------------- WiFi / Time / Firebase ----------------
void setupWiFi() {
  Serial.printf("📡 Connecting to WiFi '%s'...\n", WIFI_SSID);
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 30) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  Serial.println();
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("✅ WiFi connected");
    Serial.print("   IP: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("❌ WiFi connection failed");
  }
}

void setupTime() {
  // GMT+7 (25200 detik offset), server NTP
  configTime(25200, 0, "pool.ntp.org", "time.nist.gov");
  Serial.println("⏰ NTP syncing...");

  struct tm timeinfo;
  int retry = 0;
  const int maxRetry = 20;

  while (!getLocalTime(&timeinfo) && retry < maxRetry) {
    Serial.print(".");
    delay(500);
    retry++;
  }
  Serial.println();

  if (retry == maxRetry) {
    Serial.println("❌ Failed to sync time via NTP");
  } else {
    char buf[32];
    strftime(buf, sizeof(buf), "%Y-%m-%d %H:%M:%S", &timeinfo);
    Serial.print("✅ Time synced: ");
    Serial.println(buf);
  }
}

String getFormattedTime() {
  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) return "Unknown";
  char buf[32];
  strftime(buf, sizeof(buf), "%Y-%m-%d %H:%M:%S", &timeinfo);
  return String(buf);
}

void setupFirebase() {
  Serial.println("🔥 Setting up Firebase...");
  Serial.print("Using DB URL: ");
  Serial.println(FIREBASE_DATABASE_URL);

  fbConfig.api_key       = FIREBASE_API_KEY;
  fbConfig.database_url  = FIREBASE_DATABASE_URL;
  fbAuth.user.email      = FIREBASE_USER_EMAIL;
  fbAuth.user.password   = FIREBASE_USER_PASSWORD;
  fbConfig.token_status_callback = tokenStatusCallback;

  Firebase.reconnectWiFi(true);
  fbdo.setResponseSize(4096);
  fbdoStream.setResponseSize(4096);
  Firebase.begin(&fbConfig, &fbAuth);

  int attempts = 0;
  while (!Firebase.ready() && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  Serial.println();

  firebaseReady = Firebase.ready();
  if (firebaseReady) {
    Serial.println("✅ Firebase Ready!");
  } else {
    Serial.println("❌ Firebase connection failed");
  }
}

void setupPinStream() {
  if (!firebaseReady) {
    Serial.println("❌ Cannot setup PIN stream - Firebase not ready");
    return;
  }
  
  String pinPath = DATABASE_PATH + "/pin";
  Serial.println("   Stream path: " + pinPath);
  
  if (!Firebase.RTDB.beginStream(&fbdoStream, pinPath.c_str())) {
    Serial.println("❌ Stream begin failed: " + fbdoStream.errorReason());
    streamSetupDone = false;
    return;
  }
  
  Firebase.RTDB.setStreamCallback(&fbdoStream, streamCallback, streamTimeoutCallback);
  streamSetupDone = true;
  Serial.println("✅ PIN stream setup complete - listening for changes from Flutter app");
}

void saveCurrentStatus(FirebaseJson &data) {
  if (!firebaseReady) return;
  String path = DATABASE_PATH + "/current_status";
  data.set("updatedAt", getFormattedTime());
  if (Firebase.RTDB.setJSON(&fbdo, path.c_str(), &data)) {
    Serial.println("✅ Firebase: status updated");
  } else {
    Serial.println("❌ Firebase: status update failed - " + fbdo.errorReason());
  }
}

void saveHistory(FirebaseJson &data, const String &action) {
  if (!firebaseReady) return;
  String timestamp = getFormattedTime();
  
  String safeTimestamp = timestamp;
  safeTimestamp.replace(":", "-");
  safeTimestamp.replace(" ", "_");
  
  String path = DATABASE_PATH + "/history/" + safeTimestamp;
  data.set("action", action);
  data.set("time", timestamp);
  if (Firebase.RTDB.setJSON(&fbdo, path.c_str(), &data)) {
    Serial.println("✅ Firebase: history saved - " + safeTimestamp);
  } else {
    Serial.println("❌ Firebase: history failed - " + fbdo.errorReason());
  }
}

// ---------------- PIN read/write on Firebase ----------------
bool isDigitsOnly(const String &s) {
  if (s.length() == 0) return false;
  for (unsigned int i = 0; i < s.length(); ++i) {
    if (!isDigit(s.charAt(i))) return false;
  }
  return true;
}

bool loadPinFromFirebase() {
  if (!firebaseReady) {
    Serial.println("❌ loadPinFromFirebase: firebase not ready");
    return false;
  }
  String path = DATABASE_PATH + "/pin";
  Serial.println("📥 Loading PIN from: " + path);
  if (Firebase.RTDB.getString(&fbdo, path.c_str())) {
    String val = fbdo.stringData();
    Serial.println("   Retrieved value: " + val);
    if (isDigitsOnly(val) && val.length() >= 4 && val.length() <= 8) {
      pinBenar = val;
      Serial.println("✅ PIN loaded: " + pinBenar);
      return true;
    } else {
      Serial.println("❌ Invalid PIN data in Firebase");
      return false;
    }
  } else {
    Serial.println("❌ Firebase getString failed: " + fbdo.errorReason());
    return false;
  }
}

bool savePinToFirebase(const String &pin, const String &source) {
  if (!firebaseReady) {
    Serial.println("❌ savePinToFirebase: firebase not ready");
    return false;
  }
  if (!isDigitsOnly(pin) || pin.length() < 4 || pin.length() > 8) {
    Serial.println("❌ savePinToFirebase: invalid pin format (must be 4-8 digits)");
    return false;
  }
  
  // Jangan save jika perubahan dari stream (mencegah loop)
  if (pinChangingFromStream) {
    Serial.println("ℹ️ Skip saving PIN (changed from stream, avoiding loop)");
    return true;
  }
  
  String path = DATABASE_PATH + "/pin";
  Serial.printf("📤 Saving PIN to Firebase: '%s' (source: %s)\n", pin.c_str(), source.c_str());
  
  if (Firebase.RTDB.setString(&fbdo, path.c_str(), pin)) {
    Serial.println("✅ PIN saved to Firebase successfully");
    
    // Simpan metadata perubahan PIN
    FirebaseJson metadata;
    metadata.set("last_changed", getFormattedTime());
    metadata.set("changed_by", source);
    String metaPath = DATABASE_PATH + "/pin_metadata";
    Firebase.RTDB.setJSON(&fbdo, metaPath.c_str(), &metadata);
    
    return true;
  } else {
    Serial.println("❌ Firebase setString failed: " + fbdo.errorReason());
    return false;
  }
}

// ---------------- Telegram Notification Functions ----------------
void sendTelegramNotification(const String &message) {
  if (strlen(BOT_TOKEN) > 5 && strlen(CHAT_ID) > 1) {
    Serial.println("📱 Sending Telegram notification...");
    if (bot.sendMessage(CHAT_ID, message, "")) {
      Serial.println("✅ Telegram sent successfully");
    } else {
      Serial.println("❌ Telegram send failed");
    }
  } else {
    Serial.println("⚠️ Telegram credentials not configured");
  }
}

void notifyMotionDetected() {
  String timestamp = getFormattedTime();
  
  String message = "🚨 *PERINGATAN GERAKAN TERDETEKSI* 🚨\n\n";
  message += "⏰ Waktu: " + timestamp + "\n";
  message += "📍 Lokasi: Smart Brankas\n";
  message += "👁️ Status: Gerakan mencurigakan terdeteksi!\n\n";
  message += "⚠️ Segera periksa keamanan brankas Anda!";

  sendTelegramNotification(message);

  if (firebaseReady) {
    FirebaseJson j;
    j.set("event", "motion_detected");
    j.set("time", timestamp);
    saveCurrentStatus(j);
    saveHistory(j, "motion_detected");
  }
}

void notifyBrankasOpened() {
  String timestamp = getFormattedTime();
  
  String message = "✅ *BRANKAS DIBUKA* ✅\n\n";
  message += "⏰ Waktu: " + timestamp + "\n";
  message += "📍 Lokasi: Smart Brankas\n";
  message += "🔓 Status: Brankas berhasil dibuka\n";
  message += "🔑 Akses: PIN valid\n\n";
  message += "ℹ️ Brankas dalam kondisi terbuka.";
  
  sendTelegramNotification(message);

  if (firebaseReady) {
    FirebaseJson j;
    j.set("event", "brankas_opened");
    j.set("time", timestamp);
    saveCurrentStatus(j);
    saveHistory(j, "brankas_opened");
  }
}

void notifyPinChanged(const String &source) {
  String timestamp = getFormattedTime();
  String sourceText = (source == "esp") ? "Keypad ESP32" : "Aplikasi Mobile";
  
  String message = "🔐 *PIN BRANKAS DIUBAH* 🔐\n\n";
  message += "⏰ Waktu: " + timestamp + "\n";
  message += "📍 Lokasi: Smart Brankas\n";
  message += "🔄 Sumber: " + sourceText + "\n";
  message += "✅ Status: PIN berhasil diubah\n\n";
  message += "⚠️ Jika bukan Anda yang mengubah PIN, segera periksa keamanan brankas!";
  
  sendTelegramNotification(message);

  if (firebaseReady) {
    FirebaseJson j;
    j.set("event", "pin_changed");
    j.set("time", timestamp);
    j.set("source", source);
    saveCurrentStatus(j);
    saveHistory(j, "pin_changed");
  }
}

void notifyLockout() {
  String timestamp = getFormattedTime();
  
  String message = "🔴 *PERINGATAN LOCKOUT!* 🔴\n\n";
  message += "⏰ Waktu: " + timestamp + "\n";
  message += "📍 Lokasi: Smart Brankas\n";
  message += "❌ Status: 3x PIN SALAH!\n";
  message += "🚫 Sistem: TERKUNCI SEMENTARA\n\n";
  message += "⚠️⚠️⚠️ PERINGATAN KEAMANAN! ⚠️⚠️⚠️\n";
  message += "Seseorang mencoba akses tidak sah!\n";
  message += "Segera periksa keamanan brankas Anda!";
  
  sendTelegramNotification(message);

  if (firebaseReady) {
    FirebaseJson j;
    j.set("event", "lockout");
    j.set("time", timestamp);
    j.set("failed_attempts", 3);
    saveCurrentStatus(j);
    saveHistory(j, "lockout");
  }
}

bool fetchCameraJpeg(std::vector<uint8_t> &buffer) {
  String url = String("http://") + camHost + ":" + String(camPort) + camSnapshotPath;
  HTTPClient http;
  http.setTimeout(8000);   // naikkan timeout
  http.useHTTP10(true);    // hindari chunked

  for (int attempt = 1; attempt <= 3; ++attempt) {
    Serial.printf("📸 Attempt %d: %s\n", attempt, url.c_str());
    if (!http.begin(url)) {
      Serial.println("❌ http.begin gagal");
      return false;
    }
    int httpCode = http.GET();
    if (httpCode == HTTP_CODE_OK) {
      WiFiClient *stream = http.getStreamPtr();
      int total = http.getSize();  // bisa -1 (unknown)
      buffer.clear();

      if (total > 0) {
        buffer.resize(total);
        size_t readLen = stream->readBytes(buffer.data(), total);
        buffer.resize(readLen);
      } else {
        // unknown length: baca sampai habis / timeout pendek
        unsigned long start = millis();
        while (http.connected() && (millis() - start < 3000)) {
          while (stream->available()) {
            buffer.push_back(stream->read());
            start = millis(); // reset timeout jika ada data
          }
          delay(10);
        }
      }

      http.end();
      if (buffer.empty()) {
        Serial.println("❌ Snapshot kosong (tidak ada data). Retrying...");
        delay(300);
        continue;
      }
      Serial.printf("✅ Snapshot OK, size = %u bytes\n", (unsigned int)buffer.size());
      return true;
    } else {
      Serial.printf("❌ Snapshot gagal, HTTP code: %d\n", httpCode);
      http.end();
      delay(300);
    }
  }
  return false;
}

bool sendTelegramPhoto(const std::vector<uint8_t> &buffer, const String &caption) {
  if (strlen(BOT_TOKEN) <= 5 || strlen(CHAT_ID) <= 1) {
    Serial.println("⚠️ Telegram credentials not set");
    return false;
  }
  Serial.println("📤 Mengirim foto ke Telegram...");

  // siapkan buffer & posisi
  tgPhotoBuf = buffer.data();
  tgPhotoLen = buffer.size();
  tgPhotoPos = 0;

  // kirim dengan callback
  String resp = bot.sendPhotoByBinary(
                  CHAT_ID,
                  "image/jpeg",
                  (int)tgPhotoLen,
                  tgMoreDataAvailable,
                  tgGetNextByte,
                  nullptr,          // getNextBuffer (tidak dipakai)
                  tgOnRequestEnd);  // endRequest callback

  bool ok = resp.length() > 0;
  if (ok) Serial.println("✅ Foto terkirim");
  else    Serial.println("❌ Kirim foto gagal");
  return ok;
}

bool captureAndSendIntruderPhoto() {
  unsigned long now = millis();
  if (now - lastIntruderPhotoTime < INTRUDER_PHOTO_COOLDOWN) {
    Serial.println("ℹ️ Skip foto intruder (cooldown)");
    return false;
  }
  std::vector<uint8_t> jpeg;
  if (!fetchCameraJpeg(jpeg)) return false;

  String caption = "🚨 Percobaan PIN salah!\nWaktu: " + getFormattedTime();
  bool sent = sendTelegramPhoto(jpeg, caption);
  if (sent) lastIntruderPhotoTime = now;
  return sent;
}

void notifyTask(void * parameter) {
  for (;;) {
    if (motionPending) {
      motionPending = false;
      // Langsung kirim notifikasi tanpa cek cooldown
      lastNotifyTime = millis();
      notifyMotionDetected();
    }
    vTaskDelay(pdMS_TO_TICKS(300));
  }
}

// ---------------- UI & control functions ----------------
void tampilkanAwal() {
  lcd.clear();
  lcd.print("Mendeteksi...");
  lcd.setCursor(0, 1);
  lcd.print("A: Menu");
  menuUtama = false;
  loginMode = false;
  ubahPinMode = false;
  pinInput = "";
}

void tampilkanMenuUtama() {
  lcd.clear();
  lcd.print("1.Masukkan PIN");
  lcd.setCursor(0, 1);
  lcd.print("2.Ganti PIN");
  menuUtama = true;
  loginMode = false;
  ubahPinMode = false;
  pinInput = "";
}

void printMasked(const String &s) {
  lcd.setCursor(0, 1);
  for (unsigned int i = 0; i < s.length(); i++) lcd.print("*");
  for (int i = s.length(); i < 16; i++) lcd.print(" ");
}

void buzzerBeep(int duration_ms) {
  if (duration_ms <= 0) return;
  digitalWrite(buzzerPin, HIGH);
  delay(duration_ms);
  digitalWrite(buzzerPin, LOW);
}

void bukaBrankas() {
  brankasServo.write(SERVO_OPEN_ANGLE);
  delay(700);
  brankasTerbuka = true;
  lcd.clear(); 
  lcd.print("Brankas Terbuka");
  lcd.setCursor(0,1); 
  lcd.print("Tekan D tutup");
  buzzerBeep(150);
  notifyBrankasOpened();
}

void tutupBrankas() {
  brankasServo.write(SERVO_CLOSED_ANGLE);
  delay(700);
  brankasTerbuka = false;
  lcd.clear(); 
  lcd.print("Brankas Tertutup");
  lcd.setCursor(0,1); 
  lcd.print("Kembali...");
  delay(800);
  tampilkanAwal();

  if (firebaseReady) {
    FirebaseJson j; 
    j.set("event","brankas_closed"); 
    j.set("time", getFormattedTime());
    saveCurrentStatus(j); 
    saveHistory(j,"brankas_closed");
  }
}

// ---------- PIN entry ----------
void handlePinEntry(char key) {
  if (!key) return;
  if (key == 'C') { pinInput = ""; tampilkanAwal(); return; }
  if (key == '#') {
    if (pinInput == pinBenar) {
      lcd.clear(); 
      lcd.print("Login Berhasil");
      buzzerBeep(150); 
      digitalWrite(ledHijau, HIGH); 
      delay(800); 
      digitalWrite(ledHijau, LOW);
      salahCounter = 0;
      bukaBrankas();
      loginMode = false;
    } else {
      salahCounter++;
      lcd.clear(); 
      lcd.print("PIN Salah!");
      buzzerBeep(500); 
      
      // Foto & kirim ke Telegram saat PIN salah
      captureAndSendIntruderPhoto();

      delay(800);
      if (salahCounter >= 3) {
        lcd.clear(); 
        lcd.print("TERKUNCI 3X SALAH");
        for (int i = 0; i < 11; i++) { 
          buzzerBeep(500); 
          delay(600); 
        }
        salahCounter = 0;
        notifyLockout();
      }
      tampilkanAwal();
    }
    pinInput = "";
    return;
  }
  if (key == 'B') { 
    if (pinInput.length() > 0) { 
      pinInput.remove(pinInput.length()-1); 
      printMasked(pinInput); 
    } 
    return; 
  }
  if (key == '*') { 
    pinInput=""; 
    lcd.setCursor(0,1); 
    lcd.print("                "); 
    return; 
  }
  if (pinInput.length() < 8) { 
    pinInput += key; 
    printMasked(pinInput); 
  }
}

// ---------- PIN change ----------
void handleGantiPin(char key) {
  static String newPin = "";
  static bool inputBaru = false;
  if (!key) return;
  if (key == 'C') { 
    tampilkanAwal(); 
    inputBaru=false; 
    pinInput=""; 
    ubahPinMode=false; 
    return; 
  }
  if (key == '#') {
    if (!inputBaru) {
      if (pinInput == pinBenar) { 
        lcd.clear(); 
        lcd.print("PIN Baru:"); 
        inputBaru=true; 
        pinInput=""; 
      } else { 
        lcd.clear(); 
        lcd.print("PIN Lama Salah"); 
        delay(1500); 
        tampilkanAwal(); 
        ubahPinMode=false; 
        inputBaru=false; 
      }
    } else {
      newPin = pinInput;
      if (newPin.length() >= 4 && newPin.length() <= 8 && isDigitsOnly(newPin)) {
        Serial.println("\n⌨️ PIN CHANGED FROM KEYPAD!");
        Serial.printf("   Old PIN: %s\n", pinBenar.c_str());
        Serial.printf("   New PIN: %s\n", newPin.c_str());
        
        bool saved = true;
        if (firebaseReady) {
          saved = savePinToFirebase(newPin, "esp"); // ESP → Firebase → Flutter
        }
        
        if (saved) {
          pinBenar = newPin;
          lcd.clear(); 
          lcd.print("PIN Disimpan"); 
          delay(1500);
          notifyPinChanged("esp");
          Serial.println("✅ PIN saved and will sync to Flutter app\n");
        } else {
          lcd.clear(); 
          lcd.print("Simpan Gagal"); 
          delay(1500);
          Serial.println("❌ PIN save failed\n");
        }
      } else {
        lcd.clear(); 
        lcd.print("PIN 4-8 digit"); 
        delay(1500);
      }
      tampilkanAwal(); 
      ubahPinMode=false; 
      inputBaru=false;
    }
    pinInput = "";
    return;
  }
  if (key == 'B') { 
    if (pinInput.length() > 0) { 
      pinInput.remove(pinInput.length()-1); 
      printMasked(pinInput); 
    } 
    return; 
  }
  if (key == '*') { 
    pinInput=""; 
    lcd.setCursor(0,1); 
    lcd.print("                "); 
    return; 
  }
  if (pinInput.length() < 8) { 
    pinInput += key; 
    printMasked(pinInput); 
  }
}

// ---------------- Main loop ----------------
void loop() {
  char key = keypad.getKey();
  int pirState = digitalRead(pirPin);

  if (key) buzzerBeep(70);

  if (brankasTerbuka && key == 'D') { 
    tutupBrankas(); 
    return; 
  }

  // Motion detection
  if (pirState == HIGH && !menuUtama && !loginMode && !ubahPinMode && !brankasTerbuka) {
    if (!gerakanTerdeteksi) {
      gerakanTerdeteksi = true;
      motionStartTime = millis();
      motionConfirmed = false;
      
      lcd.clear(); 
      lcd.print("Gerakan Terdeteksi"); 
      lcd.setCursor(0,1); 
      lcd.print("Memverifikasi...");
      digitalWrite(ledMerah, HIGH); 
      buzzerBeep(100);
      
      Serial.println("👀 Motion detected - verifying...");
    } else {
      unsigned long motionDuration = millis() - motionStartTime;
      
      if (motionDuration >= MOTION_THRESHOLD && !motionConfirmed) {
        motionConfirmed = true;
        lastMotion = millis();
        motionPending = true;
        
        lcd.setCursor(0,1); 
        lcd.print("A: Menu         ");
        
        Serial.println("✅ Motion confirmed - sending notification");
      }
    }
  } else if (pirState == LOW && !menuUtama && !loginMode && !ubahPinMode && !brankasTerbuka) {
    if (gerakanTerdeteksi) {
      unsigned long motionDuration = millis() - motionStartTime;
      
      if (!motionConfirmed) {
        Serial.printf("ℹ️ Motion too short (%lu ms) - ignored\n", motionDuration);
      }
      
      lcd.clear(); 
      lcd.print("Mendeteksi..."); 
      lcd.setCursor(0,1); 
      lcd.print("A: Menu");
      digitalWrite(ledMerah, LOW); 
      gerakanTerdeteksi = false;
      motionConfirmed = false;
    }
  }

  if (key == 'A' && !menuUtama && !loginMode && !ubahPinMode && !brankasTerbuka) 
    tampilkanMenuUtama();

  if (menuUtama) {
    if (key == '1') { 
      lcd.clear(); 
      lcd.print("Masukkan PIN"); 
      lcd.setCursor(0,1); 
      pinInput=""; 
      lcd.print("                "); 
      lcd.setCursor(0,1); 
      menuUtama=false; 
      loginMode=true; 
    } else if (key == '2') { 
      lcd.clear(); 
      lcd.print("PIN Lama:"); 
      lcd.setCursor(0,1); 
      pinInput=""; 
      lcd.print("                "); 
      lcd.setCursor(0,1); 
      menuUtama=false; 
      ubahPinMode=true; 
    } else if (key == 'C') 
      tampilkanAwal();
  } else if (loginMode) 
    handlePinEntry(key);
  else if (ubahPinMode)
    handleGantiPin(key);

  delay(10);
}