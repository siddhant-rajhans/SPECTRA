# SPECTRA — Production Roadmap

What's left after Tier 1, ordered by what unlocks what. Tier 1 (real audio capture, on-device classification, configurable host, haptics, APK build) is already done — see [TESTING.md](TESTING.md) for the test playbook.

---

## Tier 2 — Security & data hygiene (deploy beyond LAN)

These are what stop you from putting the backend on a real server / public IP without being negligent.

| # | Item | Why it matters now | Rough effort |
|---|---|---|---|
| 1 | **JWT auth + auth middleware on every route** | Today every route trusts `?userId=default-user` from the query string. Anyone who hits the URL can read/write anyone's data. Until this lands, the backend can't leave LAN. | ~half a day |
| 2 | **bcrypt + salt on passwords** (replace unsalted SHA-256 in [`backend/server/database.js`](backend/server/database.js)) | The default `mkunchal@stevens.edu / demo123` hash + every user signup is trivially crackable from a DB dump. | 1–2 hours |
| 3 | **Persistent DB — better-sqlite3 or Postgres** | `sql.js` is an in-memory JS port, persisted to a single file on every change. A crash mid-write loses data; doesn't scale beyond one process. better-sqlite3 is a 30-min swap. | 1–3 hours |
| 4 | **HTTPS / TLS termination** (Caddy or Cloudflare Tunnel in front of the Node server) | The phone speaks plaintext HTTP today. Any cellular network or untrusted Wi-Fi can sniff or tamper with alerts/transcripts. | ~1 hour with Cloudflare Tunnel |
| 5 | **CORS allowlist + rate limit + input validation + no stack traces in prod** | Currently `origin: true` (wildcard), no rate limit, errors leak stack traces. Cheap hardening but real. | ~2 hours total |
| 6 | **`.env` config** for `JWT_SECRET`, `DATABASE_URL`, `CORS_ORIGIN`, `LOG_LEVEL` | Right now defaults are baked into source. Hard to deploy two environments. | ~30 min |
| 7 | **Release APK signing** with a real keystore (currently signed with the debug key — every fresh build invalidates updates and Play Store rejects) | Required if you ever want OTA updates or Play Store distribution; blocks anything past dev devices. | ~30 min |
| 8 | **Foreground service for continuous listening** (`flutter_foreground_task` + the `FOREGROUND_SERVICE_MICROPHONE` permission we already declared) | Right now the classifier stops when the user backgrounds the app or locks the phone. For real-world use this is the difference between "demo" and "always-on hearing aid companion." | ~half a day |
| 9 | **Crash reporting & basic observability** (Sentry for Flutter, Sentry/Logtail for Node) | Once a real user has it on their phone you need to know when it breaks. | 1–2 hours |
| 10 | **Privacy policy + audio data retention statement** | Captures + transcripts are recorded health-adjacent data. Even informally, the user testing should sign off on what's stored, where, and for how long. | not code — a doc + decision |

**If forced to pick three before the cochlear test goes anywhere beyond your living room:** #1 (JWT) + #4 (TLS) + #8 (foreground service).

---

## Tier 3 — Hearing-implant specific (research + iteration)

These are unbounded — where the project becomes a *medical assistive device* rather than an alerting app.

| # | Item | Status | Notes |
|---|---|---|---|
| 11 | **Direct streaming to the Cochlear Nucleus 7** via Android ASHA / LE Audio | Open question | Pixel 9 Pro supports LE Audio (Auracast). Cochlear's Nucleus 7 is MFi (iPhone) but Cochlear is rolling out Android via the Nucleus Smart App + ASHA. Worth one focused session researching whether we can stream alert tones / boost speech directly to the implant's processor instead of relying on the phone's speaker. |
| 12 | **Real IML retraining loop** | Backend `POST /api/iml/train` is entirely stubbed ([`imlService.js`](backend/server/services/imlService.js)) | Realistic v1: collect feedback samples, fine-tune YAMNet's last layer server-side on the user's confused classes (transfer learning), ship the personalized model back to the phone. Non-trivial — needs an actual ML pipeline, model registry, and on-device hot-swap. |
| 13 | **Keyword/name spotting** for `name_called` | Currently impossible — YAMNet has no notion of specific words | Run a Porcupine wake-word engine (or train your own on the user's name samples) in parallel with the classifier. The user records 3 samples of their name, we build a custom keyword model. Realistic but needs a different stack. |
| 14 | **Speaker diarization + better captions** | Today every line is labeled `You` because Android's recognizer doesn't separate speakers | Picovoice's Falcon or pyannote on a separate transcription server can split speakers — major UX win for restaurants/meetings. |
| 15 | **Calendar / location context** to power the existing `evaluateContext()` engine | Engine exists ([`contextEngine.js`](backend/server/services/contextEngine.js)), but `location` is hardcoded to `"home"` and calendar is hardcoded to `[]` | Wire up the phone's location + Google/Apple Calendar so context rules ("Don't fire doorbell during meetings") actually fire. |
| 16 | **Clinical validation of detection accuracy** for the 12 sound categories | Open | Before any tester relies on the fire-alarm detection to actually save them, we need numbers — false-negative rate under household noise, latency p99, etc. The IML pipeline can collect this passively but we need a benchmarking set. |
| 17 | **Internationalization** | Today everything is en-US | Cochlear users worldwide; even just supporting the speech recognizer's locale (it picks up system locale by default — already done) plus translating UI strings is a couple of days. |

**Killer feature argument:** #11 (direct streaming) is where this stops being "the user has to look at their phone" and starts being "the implant beeps when the doorbell rings." But it's also the riskiest because it depends on Cochlear's Android SDK availability, which is something we should research before committing.

---

## Recommended next session

Knock out Tier 2 #1 + #2 + #6 + #8 (auth + bcrypt + env config + foreground service) in one focused pass — that's the cluster that makes the app actually deployable and the listening actually useful. **Then** do the cochlear test. After that, the test will tell us whether to invest in Tier 3 #11 or #12 first.
