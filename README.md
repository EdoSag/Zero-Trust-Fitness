# 🛡️ Zero-Trust Fitness

**Your health data is human rights data. Own it. Encrypt it. Protect it.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](http://makeapullrequest.com)
[![Status: Alpha](https://img.shields.io/badge/Status-Alpha-orange.svg)]()

Zero-Trust Fitness is a privacy-first, open-source alternative to mainstream fitness platforms. Built on the principle of **Zero-Knowledge**, this app ensures that your heart rate, GPS coordinates, and biometric telemetry are encrypted on your device before they ever touch a server. 

Neither the developers nor the hosting providers can see your data. **You hold the keys.**

---

## ✨ Core Pillars

* **🔒 Zero-Trust Architecture:** No unencrypted data ever leaves your device.
* **🔑 User-Managed Keys:** Encryption keys are derived from your master passphrase via PBKDF2.
* **📱 Local-First:** Full functionality offline. Syncing to the cloud is an optional, encrypted backup.
* **🤝 Open Ecosystem:** Standardized JSON/GPX exports so you are never locked into the platform.

---

## 🛠️ Technical Specification

### The "Security Enclave" Stack
| Layer | Technology | Purpose |
| :--- | :--- | :--- |
| **Mobile Framework** | Flutter | Cross-platform access to HealthKit (iOS) & Health Connect (Android). |
| **Local Database** | SQLCipher | AES-256 encrypted SQLite database for on-device storage. |
| **Encryption Engine** | Rust (via Bridge) | High-performance, memory-safe cryptographic operations. |
| **Sync Backend** | Go / Supabase | A "dumb" storage vault for encrypted blobs. |

### Data Security Model
All sensitive records (Workouts, Vitals, GPS) follow this flow:
1.  **Capture:** Data pulled from device sensors.
2.  **Encrypt:** Client-side encryption using **AES-256-GCM**.
3.  **Store:** Saved to encrypted local DB.
4.  **Sync (Optional):** Encrypted blob sent to the server. The server sees only metadata (timestamp, user_id, encrypted_blob).

---

## 📈 Roadmap

### Phase 1: The Foundation (Current)
- [x] Initialize Repository and Project Structure.
- [x] Implement Secure Key Storage (Keychain/Keystore).
- [x] Build basic UI for manual activity logging.

### Phase 2: The Integration
- [x] Connect to **Apple HealthKit** and **Android Health Connect**.
- [x] Real-time GPS tracking for runs and cycles.
- [x] Privacy-focused data visualizations (Charts/Graphs).

### Phase 3: The Ghost Sync
- [x] Implement End-to-End Encrypted (E2EE) cloud backup.
- [ ] Multi-device sync using the user's private key.
- [ ] Self-hosting guide for Docker/Nextcloud.

---

## 🤝 Contributing

We are actively looking for contributors! Whether you are a security researcher, a mobile dev, or a UI designer, we need your help to build the future of private fitness.

1.  Check the [Issues](https://github.com/) tab for "Good First Issues."
2.  Join the discussion in our community Discord (as seen in the Dev Diary!).
3.  Read our `CONTRIBUTING.md` (Coming soon).

---

## 📜 License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

---

> *"The only person who should know your resting heart rate is you and your doctor—not an advertising algorithm."*
