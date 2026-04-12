# 🎬 MEDIA STACK (JELLYFIN + ARR + QBITTORRENT + NAS)

This stack downloads media locally, processes it with Sonarr and Radarr, and stores final files on a NAS for Jellyfin to stream.

============================================================

WHAT EACH SERVICE DOES

JELLYFIN
Media server that streams movies and TV shows from your NAS to any device.

QBITTORRENT
Downloads torrents. Files are downloaded to a fast local SSD first.

PROWLARR
Manages torrent indexers and provides search results to Sonarr and Radarr.

SONARR
Automatically manages TV shows:
- finds episodes
- downloads them via qBittorrent
- renames files
- moves them to NAS TV folder

RADARR
Automatically manages movies:
- finds movies
- downloads them
- renames and organizes them
- moves them to NAS movies folder

JELLYSEERR
Request system for movies and TV shows.
Requests are sent to Sonarr (TV) and Radarr (movies).

HOMEPAGE
Dashboard that provides one place to access all services.

PORTAINER
Docker management UI for controlling containers.

GLUETUN (VPN)
Routes torrent traffic through a VPN for privacy and security.
Used by qBittorrent and Prowlarr.

WATCHTOWER
Automatically updates Docker containers to keep the system up to date.

============================================================

HOW IT ALL WORKS TOGETHER

Jellyseerr (requests)
        ↓
Sonarr / Radarr (management)
        ↓
Prowlarr (search indexers)
        ↓
Qbittorrent (downloads via VPN)
        ↓
Local SSD (temporary storage)
        ↓
NAS (/mnt/nas) (final storage)
        ↓
Jellyfin (streams media)

============================================================

STORAGE STRUCTURE

NAS:
/mnt/nas
├── movies
└── tv

============================================================

SETUP INSTRUCTIONS

MEDIA STACK OVERVIEW

This stack downloads media locally, processes it with Sonarr and Radarr, and stores final files on a NAS for Jellyfin to stream.

------------------------------------------------------------

ARCHITECTURE

Qbittorrent (downloads to local SSD)
        ↓
Sonarr / Radarr (organize + move)
        ↓
NAS Storage (/mnt/nas)
        ↓
Jellyfin (streams from NAS)

------------------------------------------------------------

REQUIREMENTS

- Linux server (Ubuntu recommended)
- Docker and Docker Compose installed
- NAS mounted at /mnt/nas

NAS folder structure:
  /mnt/nas
    movies
    tv

------------------------------------------------------------

STEP 1 - MOUNT NAS

sudo mkdir -p /mnt/nas

sudo mount -t cifs //NAS_IP/Media /mnt/nas
  -o username=USER,password=PASS,uid=1000,gid=1000

(Optional) Add to /etc/fstab for auto-mount.

------------------------------------------------------------

STEP 2 - START STACK

docker compose up -d

docker ps

------------------------------------------------------------

STEP 3 - CONFIGURE APPLICATIONS

QBITTORRENT
- Download path: /downloads
- Categories:
  sonarr -> TV
  radarr -> Movies

SONARR
- Root folder: /tv
- Enable Completed Download Handling
- Optional: Remove Completed Downloads

RADARR
- Root folder: /movies

JELLYFIN
- Movies: /media/movies
- TV: /media/tv

------------------------------------------------------------

FULL WORKFLOW

1. Downloads go to:
   /home/jackson/media/downloads

2. Sonarr/Radarr process files

3. Files move to NAS:
   /mnt/nas/movies
   /mnt/nas/tv

4. Jellyfin streams from NAS

------------------------------------------------------------

TROUBLESHOOTING

Check NAS:
ls /mnt/nas

Fix permissions:
sudo chown -R 1000:1000 /mnt/nas

Ensure paths match exactly:
- /downloads
- /tv
- /movies

------------------------------------------------------------

RESULT

- Fast downloads (local SSD)
- Automated organization
- Centralized storage (NAS)
- Jellyfin streaming from NAS
