# 🎬 Media Stack (Jellyfin + *arr + qBittorrent + NAS)

This stack downloads media locally, processes it with Sonarr and Radarr, and stores final files on a NAS for Jellyfin to stream.

---

# 🧠 Architecture

qBittorrent (downloads to local SSD)
        ↓
Sonarr / Radarr (organize + rename + move)
        ↓
NAS Storage (/mnt/nas)
        ↓
Jellyfin (streams from NAS)

---

# 📦 Requirements

- Linux server (Ubuntu recommended)
- Docker + Docker Compose installed
- NAS mounted at:
  /mnt/nas

NAS folder structure:
  /mnt/nas
    ├── movies
    └── tv

---

# 🛠️ Step 1 — Mount NAS

sudo mkdir -p /mnt/nas

sudo mount -t cifs //NAS_IP/Media /mnt/nas \
  -o username=USER,password=PASS,uid=1000,gid=1000

(Optional) Add to /etc/fstab for auto-mount.

---

# 🚀 Step 2 — Start the stack

docker compose up -d

docker ps

---

# ⚙️ Step 3 — Configure Applications

qBittorrent:
- Download path: /downloads
- Categories:
  - sonarr → TV
  - radarr → Movies

Sonarr:
- Root folder: /tv
- Enable Completed Download Handling
- Optional: Remove Completed Downloads

Radarr:
- Root folder: /movies

Jellyfin:
- Movies: /media/movies
- TV: /media/tv

---

# 🔁 Full Workflow

1. Downloads go to:
   /home/jackson/media/downloads

2. Sonarr/Radarr process files

3. Files move to NAS:
   /mnt/nas/movies
   /mnt/nas/tv

4. Jellyfin streams from NAS

---

# 🧯 Troubleshooting

Check NAS:
ls /mnt/nas

Fix permissions:
sudo chown -R 1000:1000 /mnt/nas

Ensure paths match:
- /downloads
- /tv
- /movies

---

# 🚀 Result

- Fast downloads (local SSD)
- Automated organization
- Centralized storage (NAS)
- Jellyfin streaming from NAS
