# Contributing to Zero-Trust Fitness 🛡️

First off, thank you for considering contributing to Zero-Trust Fitness! It’s people like you who make privacy-first health tracking possible for everyone.

By contributing, you agree to abide by our code of conduct and maintain the security integrity of the platform.

---

## 🏗️ Our Core Philosophy
Before you write a single line of code, remember our **North Star**:
> **The Server Never Sees Plaintext.**
If your feature requires sending unencrypted biometric, GPS, or health data to a backend, it will not be merged. All processing must happen on the client (the device).

---

## 🚀 How Can I Contribute?

### 1. Reporting Bugs
* Check the [Issues](https://github.com/your-username/zero-trust-fitness/issues) tab to see if the bug has already been reported.
* If not, open a new issue. Include:
    * Your Device/OS version.
    * Steps to reproduce the bug.
    * Expected vs. Actual behavior.

### 2. Suggesting Features
* We love new ideas! Please open an issue labeled `enhancement` to discuss the logic before building it.
* **Security First:** Explain how your feature maintains the "Zero-Trust" model.

### 3. Pull Requests (PRs)
1. **Fork** the repo and create your branch from `main`.
2. **Naming:** Use descriptive branch names (e.g., `feat/heart-rate-chart` or `fix/encryption-leak`).
3. **Coding Standards:**
    * Follow the official [Flutter/Dart Style Guide](https://dart.dev/guides/language/effective-dart/style).
    * Comment your code, especially in the `security/` and `encryption/` folders.
4. **Tests:** If you add a new feature, please add corresponding unit or widget tests.
5. **Documentation:** Update the `README.md` or internal docs if your change alters the user flow.

---

## 🔐 Security Guidelines
This is a high-security project. Please follow these rules strictly:
* **No Third-Party Analytics:** Do not include Google Analytics, Firebase Analytics, or Mixpanel. We track *nothing* without explicit, granular user consent.
* **Dependency Management:** Be cautious with new packages. Every new dependency is a potential attack vector.
* **Sensitive Data:** Never log sensitive health data or encryption keys to the console (`print` or `log`).

---

## 🛠️ Development Setup
1.  **Clone the repo:** `git clone https://github.com/your-username/zero-trust-fitness.git`
2.  **Install dependencies:** `flutter pub get`
3.  **Run tests:** `flutter test`
4.  **Format code:** `flutter format .`

---

## 💬 Communication
Have questions?
* Reach out in the **#discussion** channel on the Nowa Discord server.
* Mention `@Edo` for architecture-level questions.
* Send your query to info@sagron.dev

---

## 📜 Recognition
All contributors will be featured in our `CONTRIBUTORS.md` file. Your help makes the world a more private place!

**Happy coding!**
