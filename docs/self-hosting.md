# Self-hosting Zero-Trust Fitness (Docker + Nextcloud)

This guide provides a minimal self-hosting path where the server stores only encrypted blobs.

## 1) Docker Compose stack

```yaml
services:
  db:
    image: postgres:16
    restart: unless-stopped
    environment:
      POSTGRES_USER: ztf
      POSTGRES_PASSWORD: ztf
      POSTGRES_DB: ztf
    volumes:
      - db_data:/var/lib/postgresql/data

  supabase:
    image: supabase/postgres-meta:latest
    restart: unless-stopped
    environment:
      PG_META_DB_HOST: db
      PG_META_DB_NAME: ztf
      PG_META_DB_USER: ztf
      PG_META_DB_PASSWORD: ztf

  nextcloud:
    image: nextcloud:stable
    restart: unless-stopped
    ports:
      - "8080:80"
    volumes:
      - nextcloud_data:/var/www/html

volumes:
  db_data:
  nextcloud_data:
```

## 2) Required tables

Create the following columns for signed encrypted sync entries:
- `encrypted_vault.user_id`
- `encrypted_vault.data_blob`
- `encrypted_vault.signature`
- `encrypted_vault.public_key`
- `encrypted_vault.device_id`
- `encrypted_vault.updated_at`

## 3) Why this stays zero-knowledge

- The mobile app encrypts payloads with AES-256-GCM before upload.
- The app signs each blob with the user private key.
- Server operators can store or replicate blobs but cannot decrypt them.

## 4) Optional Nextcloud backup

Use WebDAV in Nextcloud as an additional blob target for encrypted exports.
