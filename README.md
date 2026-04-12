# 🎬 MEDIA STACK

⚡ Jellyfin + *arr + qBittorrent + NAS ⚡

This stack downloads media locally, processes it with Sonarr & Radarr, and stores everything on a NAS for Jellyfin to stream anywhere.

---

📦 WHAT EACH SERVICE DOES

🎥 Jellyfin  
→ Media server that streams movies & TV shows from your NAS to any device

🧲 qBittorrent  
→ Downloads torrents to a fast local SSD first

🔍 Prowlarr  
→ Manages torrent indexers and sends search results to Sonarr & Radarr

📺 Sonarr  
→ Automatically finds, downloads, renames, and organizes TV shows

🎬 Radarr  
→ Automatically finds, downloads, renames, and organizes movies

📝 Jellyseerr  
→ Request system for movies & shows → sends directly to Sonarr/Radarr

🏠 Homepage  
→ Central dashboard for all your services

🐳 Portainer  
→ Docker management UI for controlling containers easily

🔒 Gluetun (VPN)  
→ Routes torrent traffic through VPN for privacy (qBittorrent + Prowlarr)

👀 Watchtower  
→ Automatically updates all Docker containers

---

🔄 HOW EVERYTHING WORKS

📝 Jellyseerr (Requests)
        ↓
📺 Sonarr / 🎬 Radarr (Management)
        ↓
🔍 Prowlarr (Search Indexers)
        ↓
🧲 qBittorrent (Downloads via VPN)
        ↓
💾 Local SSD (Temporary Storage)
        ↓
🗄️ NAS (/mnt/nas) (Permanent Storage)
        ↓
🎥 Jellyfin (Streams Everything)

---

📁 STORAGE STRUCTURE

🗄️ NAS (/mnt/nas)
├── 🎬 movies
└── 📺 tv

---
⚙️ SETUP INSTRUCTIONS

📋 Requirements:
🐧 Linux server (Ubuntu recommended)
🐳 Docker + Docker Compose installed
🔌 NAS mounted at /mnt/nas

---

1️⃣ MOUNT NAS

sudo mkdir -p /mnt/nas

sudo mount -t cifs //NAS_IP/Media /mnt/nas \
  -o username=USER,password=PASS,uid=1000,gid=1000

💡 Optional: Add to /etc/fstab for auto-mount on boot

---

2️⃣ START STACK

docker compose up -d

docker ps

---

3️⃣ CONFIGURE APPS

🧲 qBittorrent:
• Download path: /downloads
• Categories: sonarr → TV, radarr → Movies

📺 Sonarr:
• Root folder: /tv
• Enable Completed Download Handling

🎬 Radarr:
• Root folder: /movies

🎥 Jellyfin:
• Movies: /media/movies
• TV Shows: /media/tv

---

🔁 FULL WORKFLOW

1️⃣ Downloads → /home/jackson/media/downloads
2️⃣ Sonarr/Radarr → Auto rename & organize
3️⃣ Move to NAS → /mnt/nas/movies & /mnt/nas/tv
4️⃣ Jellyfin → Streams directly from NAS

---

🧯 TROUBLESHOOTING

❌ Missing files → ls /mnt/nas
🔒 Permissions → sudo chown -R 1000:1000 /mnt/nas
⚠️ Import issues → Check paths: /downloads /tv /movies

---

🎯 RESULT

⚡ Ultra-fast downloads (SSD speed)
🤖 Fully automated organization
💾 Centralized NAS storage
📺 Clean, seamless streaming via Jellyfin

---

🎉 YOU’RE ALL SET!

🍿 Sit back and enjoy your fully automated media server!
