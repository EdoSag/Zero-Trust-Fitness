`legacy_vault.sqlite` is a real SQLCipher 4 database (made with SQLCipher
4.12 via Python `sqlcipher3`) in the schema Fitness versions before the core
used, keyed with the raw key `000102…1f` (`PRAGMA key = "x'…'"`) the way
`sqlcipher_flutter_libs` opened it. Workout and template rows are AES-256-GCM
encrypted under the same key, as `EncryptionService` wrote them. The third
workout row is deliberately not decryptable.
