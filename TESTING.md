# SPECTRA — Test setup for a Pixel 9 Pro + cochlear-implant user

This walks through getting SPECTRA running end-to-end for a real test session:
the Node backend on a laptop, the Flutter app on a Pixel 9 Pro, and the on-device
sound classifier wired up.

If you only want to read code, start with [INTEGRATION_GUIDE.md](INTEGRATION_GUIDE.md).

---

## 0. What you need

| Where      | Tool                                  | Why                                           |
|------------|---------------------------------------|-----------------------------------------------|
| Laptop     | Node.js 18+                           | Backend                                       |
| Laptop     | Flutter 3.10+ stable                  | Build + install the Android app               |
| Laptop     | Android SDK platform-tools (`adb`)    | Side-load the APK                             |
| Laptop     | JDK 17 (Microsoft / Temurin / Zulu)   | Android Gradle build needs JDK 17             |
| Pixel 9 Pro| USB cable + Developer Options enabled | `adb install` over USB                        |
| Both       | Same Wi-Fi network                    | The phone must reach the laptop's IP:3001     |

`flutter doctor` should be green for "Android toolchain" and "Connected device".

---

## 1. Backend on the laptop

```bash
cd backend
npm install         # one-time
npm run dev         # nodemon, restarts on save
```

Listens on `http://0.0.0.0:3001`. Confirm with:

```bash
curl http://localhost:3001/health
# → {"status":"healthy",...}
```

The default seeded user is `mkunchal@stevens.edu` / `demo123` — that's how we sign
in from the app. Change this before any real deployment (see `database.js:247`).

### Find the laptop's LAN IP

```bash
# macOS
ipconfig getifaddr en0

# Windows
ipconfig | findstr IPv4

# Linux
hostname -I | awk '{print $1}'
```

Use that address in the app's Server settings (next section).

---

## 2. Frontend — fetch the YAMNet model and build the APK

The on-device sound classifier expects two files in `frontend/assets/models/`:
`yamnet.tflite` and `yamnet_class_map.csv`. A setup script downloads both (they
are not committed because the model is ~4 MB).

```bash
cd frontend

# macOS / Linux
./scripts/setup_yamnet.sh

# Windows
pwsh ./scripts/setup_yamnet.ps1
```

Then:

```bash
flutter pub get

# Build a debug APK targeting the Pixel 9 Pro (arm64)
flutter build apk --debug --target-platform android-arm64

# Or compile + install while the phone is plugged in over USB:
flutter run --release    # release is much faster for the classifier
```

Bake the host into the build so the user doesn't have to type it on first launch:

```bash
flutter build apk --release \
  --dart-define BACKEND_HOST=192.168.1.42:3001
```

The APK lands in `frontend/build/app/outputs/flutter-apk/`.

---

## 3. Install on the Pixel 9 Pro

1. On the phone: **Settings → About phone → Build number** (tap 7 times) →
   Developer Options enabled.
2. **Developer Options → USB debugging: On**, **Wireless debugging: optional**.
3. Plug the Pixel into the laptop, accept the RSA fingerprint prompt.
4. From the laptop:

   ```bash
   adb install -r frontend/build/app/outputs/flutter-apk/app-release.apk
   ```

5. First launch: the app asks for **Microphone** permission. Grant it.
   The first time you tap *Listen* the app also asks for notification access on
   Android 13+; grant that too.

If `BACKEND_HOST` was not baked in, open **Profile → Backend Server** (or the
"Server: …" link at the bottom of the auth screen) and enter
`<laptop-ip>:3001`. Tap **Save & test connection** — you should see "Server
reachable".

---

## 4. Test scenarios

The cochlear-implant tester wears their device. Phone is unlocked, app is open.
On the **Home** tab, tap **Listen**.

| What to play              | Expected app reaction                                        |
|---------------------------|--------------------------------------------------------------|
| YouTube fire alarm        | Critical screen flash (red), 3 long buzzes, "🚨 Fire Alarm"  |
| Doorbell sample           | High-priority flash, 2 buzzes, "🔔 Doorbell"                 |
| Baby crying               | "👶 Baby Crying"                                             |
| Dog barking               | "🐕 Dog Bark"                                                |
| Phone ringtone            | "📱 Phone Ring"                                              |
| Smoke detector            | "🔥 Smoke Detector" (treated as critical)                    |

If the user has a partner / interpreter, hold a 30-second conversation on the
**Transcribe** tab to validate live captions. The text appears in real time and
restarts itself if Android's recognizer times out.

If a sound is misclassified, tap **Train AI → Was this right?** and supply the
correct label. The feedback hits `POST /api/iml/feedback`.

### Useful checks during the session

- **Backend logs** show every decision: `Alert broadcast to 1 clients (fire_alarm)`.
- **App logs** stream from `flutter logs` while the phone is plugged in.
- Latency: from sound onset to flash is ~1 s on a Pixel 9 Pro (Tensor G4 NPU).

---

## 5. Known limitations for this first test

| Limitation | Why | Mitigation |
|---|---|---|
| Foreground only — no continuous background listening | Android 14 typed FOREGROUND_SERVICE_MICROPHONE service not yet implemented | Keep the app open during the session |
| `name_called` never fires | YAMNet doesn't recognize specific names; this needs keyword spotting on top of speech-to-text | Future work |
| No auth tokens — `userId` is a query param | We did not finish JWT migration | Don't expose the backend over the public internet yet |
| Default password `demo123` is unsalted SHA-256 | Backend hash scheme | Fine for LAN test; rotate before any external deployment |
| HTTP only, no TLS | Local LAN | Keep it on Wi-Fi, never over cellular without a tunnel |
| iOS not validated | We only built the Android plumbing | Info.plist already has the usage descriptions ready |

---

## 6. Quick troubleshooting

| Symptom                                                | Fix                                                                 |
|--------------------------------------------------------|---------------------------------------------------------------------|
| App boots but stays on the auth screen with "Connection error" | Server settings host is wrong; phone and laptop on different Wi-Fi |
| `Listen` button errors with "model not found"          | `scripts/setup_yamnet.sh` was not run *before* `flutter build`     |
| Mic permission denied                                  | Phone Settings → Apps → HearClear → Permissions → Microphone        |
| Build fails with `compileSdk` mismatch                 | `cd frontend && flutter clean && flutter pub get` then rebuild      |
| `adb` cannot see Pixel                                 | Re-enable USB debugging; on the phone tap "Always trust this PC"    |
| WebSocket disconnects every few seconds                | Laptop went to sleep; disable sleep or use `caffeinate`             |
