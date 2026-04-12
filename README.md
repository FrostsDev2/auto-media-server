# 🎬 Media Stack (Jellyfin + *arr + qBittorrent + NAS)

This stack downloads media locally, processes it with Sonarr/Radarr, then moves final files to a NAS for Jellyfin to stream.

---

# 🧠 Architecture


qBittorrent → Local SSD (downloads)
↓
Sonarr / Radarr (processing)
↓
NAS Storage (/mnt/nas)
↓
Jellyfin (streams from NAS)


---

# 📦 Requirements

- Linux server (Ubuntu recommended)
- Docker + Docker Compose
- NAS mounted at:

/mnt/nas


NAS structure:

/mnt/nas
├── movies
└── tv


---

# 🛠️ Step 1 — Mount NAS

bash
```
sudo mkdir -p /mnt/nas

sudo mount -t cifs //NAS_IP/Media /mnt/nas \
  -o username=USER,password=PASS,uid=1000,gid=1000
```

(Optional: add to /etc/fstab for auto-mount)

🚀 Step 2 — Start stack 
```
docker compose up -d
```
Check:
```
docker ps
```
⚙️ Step 3 — Configure apps
qBittorrent

Download path:

/downloads

Categories:

sonarr → TV
radarr → Movies
Sonarr

Root folder:

/tv

Enable:

Completed Download Handling ✔
Remove Completed ✔ (optional)
Radarr

Root folder:

/movies
Jellyfin

Libraries:

Movies:

/media/movies

TV:

/media/tv
🔁 Flow
Download → local SSD:
/home/jackson/media/downloads
Processed by Sonarr/Radarr
Moved to NAS:
/mnt/nas/movies
/mnt/nas/tv
Jellyfin reads from NAS
🧯 Troubleshooting

Jellyfin missing files:
```
ls /mnt/nas
```
Permission fix:
```
sudo chown -R 1000:1000 /mnt/nas
```
Sonarr/Radarr not importing:

Make sure paths match EXACTLY:
/downloads
/tv
/movies

---

If you want next upgrade, I can help you turn this into a **pro-level media server** with:

- :contentReference[oaicite:0]{index=0}
- :contentReference[oaicite:1]{index=1}
- :contentReference[oaicite:2]{index=2}
- :contentReference[oaicite:3]{index=3}
- :contentReference[oaicite:4]{index=4}

Just say 👍
