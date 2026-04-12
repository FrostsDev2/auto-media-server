# 🎬 MEDIA STACK

**Jellyfin + *arr + qBittorrent + NAS** 🚀

This stack downloads media locally, processes it with Sonarr and Radarr, and stores final files on a NAS for Jellyfin to stream.

---

## 📦 WHAT EACH SERVICE DOES

🎥 Jellyfin - Media server that streams movies and TV shows from your NAS to any device - 

🧲 qBittorrent - Downloads torrents to a fast local SSD first
🔍 Prowlarr - Manages torrent indexers and provides search results to Sonarr/Radarr
📺 Sonarr - Automatically finds, downloads, renames, and moves TV shows to NAS
🎬 Radarr - Automatically finds, downloads, renames, and moves movies to NAS
📝 Jellyseerr - Request system for movies/TV shows -> sends to Sonarr/Radarr
🏠 Homepage - Dashboard providing one place to access all services
🐳 Portainer - Docker management UI for controlling containers
🔒 Gluetun (VPN) - Routes torrent traffic through VPN for privacy (used by qBittorrent & Prowlarr)
👀 Watchtower - Automatically updates Docker containers

---

## 🔄 HOW IT ALL WORKS TOGETHER

📝 Jellyseerr (requests)
        ↓
📺 Sonarr / 🎬 Radarr (management)
        ↓
🔍 Prowlarr (search indexers)
        ↓
🧲 qBittorrent (downloads via 🔒 VPN)
        ↓
💾 Local SSD (temporary storage)
        ↓
🗄️ NAS /mnt/nas (final storage)
        ↓
🎥 Jellyfin (streams media)

---

## 📁 STORAGE STRUCTURE

🗄️ NAS (/mnt/nas)
├── 🎬 movies
└── 📺 tv

---

## ⚙️ SETUP INSTRUCTIONS

### 📋 Requirements

🐧 Linux server (Ubuntu recommended)
🐳 Docker + Docker Compose installed
🔌 NAS mounted at /mnt/nas

### 1️⃣ Mount NAS

sudo mkdir -p /mnt/nas
sudo mount -t cifs //NAS_IP/Media /mnt/nas -o username=USER,password=PASS,uid=1000,gid=1000

💡 Optional: Add to /etc/fstab for auto-mount on boot.

### 2️⃣ Start Stack

docker compose up -d
docker ps

### 3️⃣ Configure Applications

🧲 qBittorrent - Download path: /downloads, Categories: sonarr -> TV, radarr -> Movies
📺 Sonarr - Root folder: /tv, Enable Completed Download Handling
🎬 Radarr - Root folder: /movies
🎥 Jellyfin - Movies: /media/movies, TV Shows: /media/tv

---

## 🔁 FULL WORKFLOW

1️⃣ Downloads go to: /home/jackson/media/downloads
2️⃣ Sonarr/Radarr process: Auto-rename & organize
3️⃣ Files move to NAS: /mnt/nas/movies & /mnt/nas/tv
4️⃣ Jellyfin streams: Reads directly from NAS

---

## 🧯 TROUBLESHOOTING

❌ Jellyfin missing files -> ls /mnt/nas
🔒 Permission issues -> sudo chown -R 1000:1000 /mnt/nas
⚠️ Import failures -> Ensure paths match exactly: /downloads /tv /movies

---

## 🎯 RESULT

⚡ Fast downloads - Local SSD speed
🤖 Automated organization - Set it and forget it
💾 Centralized storage - All media on NAS
📺 Clean streaming - Jellyfin serves everything

---

## 🎉 YOU'RE ALL SET!

Enjoy your fully automated media stack! 🍿
