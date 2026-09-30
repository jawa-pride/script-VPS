<div align="center">

```
 ██████╗██╗  ██╗ █████╗ ██████╗ ██████╗
██╔════╝██║  ██║██╔══██╗██╔══██╗██╔══██╗
██║     ███████║███████║██████╔╝██████╔╝
██║     ██╔══██║██╔══██║██╔══██╗██╔══██╗
╚██████╗██║  ██║██║  ██║██║  ██║██║  ██║
 ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝
```

# CHARR//TOOLKIT

**Satu script. Satu menu. Semua kebutuhan ops server Ubuntu kamu.**

*SysAdmin × NetEng × Security — dalam satu file Bash.*

![version](https://img.shields.io/badge/version-1.3.0-00e676?style=for-the-badge)
![shell](https://img.shields.io/badge/shell-Bash-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white)
![platform](https://img.shields.io/badge/Ubuntu%20%2F%20Debian-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)
![dependencies](https://img.shields.io/badge/dependencies-zero%20(installs%20on%20demand)-blue?style=for-the-badge)
![author](https://img.shields.io/badge/by-@c.for.charr-black?style=for-the-badge)

</div>

---

## ⚡ Apa ini?

**CHARR//TOOLKIT** adalah suite operasional server berbasis terminal untuk **Ubuntu Server**. Daripada hafalin puluhan command (`ufw`, `fail2ban-client`, `nft`, `certbot`, `journalctl`, `mysql`, dst.), semuanya dibungkus dalam **satu menu interaktif** yang rapi, berwarna, dan punya banyak pengaman supaya kamu nggak ke-lock atau salah hapus.

Cocok buat:

- 🖥️ **VPS kecil** (1 vCPU / <1 GB RAM) yang sering kehabisan memori
- 🌐 **Kamu yang mau hosting web** (Nginx + PHP + MariaDB + SSL) tanpa ribet
- 🛡️ **Server yang sering di-scan / diserang** dan butuh lapisan hardening praktis
- 🧰 **Sysadmin pemula sampai menengah** yang butuh dashboard + diagnosa cepat

> 💡 **Catatan penting:** CHARR//TOOLKIT **bukan pengganti** pengetahuan sysadmin, tools monitoring profesional, atau strategi backup. Dia adalah **asisten yang mempercepat dan mengamankan pekerjaan rutin** — bukan tombol ajaib. Tetap pahami apa yang kamu jalankan.

---

## ✨ Fitur Utama

| Kategori | Modul | Isi |
|---|---|---|
| 📊 **MONITOR** | Daily Briefing, System Fetch, Health Check, Live Monitor | Ringkasan harian sekali klik, neofetch versi sendiri, cek CPU/RAM/disk/inode/service/update/NTP/zombie, dashboard realtime (CPU, RAM, disk, traffic, top proses, koneksi) |
| 🗂️ **MANAGE** | Storage & Apps, Cleaner, Service Manager, Network Toolkit, Package Manager | Deteksi app/folder terbesar, pembersih 11 jenis sampah (apt, journal, log, snap, docker, cache), kontrol service, tes konektivitas/port/DNS/traceroute/LAN sweep |
| 🏗️ **BUILD** | VPS Setup Center, Database Manager | Baseline wizard, DNS Center (+BIND9), **LEMP 1 klik**, site Nginx (static/PHP/reverse proxy), SSL Let's Encrypt, PHP tuner; MariaDB: buat DB+user, backup/restore, cron backup, health & tuning |
| 🔐 **SECURE & FIX** | Security Center, Smart Doctor, Log Explorer | Audit keamanan, firewall UFW (wizard + peta eksposur), fail2ban, SSH hardening, auto-update; **auto-diagnosa + auto-fix**; analisis log pintar + live tail berwarna |
| 🧱 **HARDEN** | Swap & Memory, **Shield** | swapfile + zram + tuning kernel + Low-RAM tuner; anti-DDoS/scan berlapis (lihat di bawah) |
| ☢️ **DANGER** | Factory Reset | Reset level paket dengan proteksi SSH/boot/network & backup daftar paket |

---

## 🛡️ Shield — Hardening Berlapis (1 Klik)

Menu **Shield → FORTRESS** memasang lima lapisan sekaligus:

```
 ┌──────────────────────────────────────────────────────────┐
 │ 1  nftables     buang paket cacat (NULL/XMAS/FIN), deteksi │
 │                 port-scan → blacklist otomatis, rate-limit │
 │                 + connlimit per IP, SSH anti brute-flood   │
 │ 2  sysctl       SYN cookies, conntrack ketat, rp_filter    │
 │ 3  nginx L7     limit req/conn, anti-slowloris, blok UA    │
 │                 scanner (sqlmap, nikto, nmap, dst.)        │
 │ 4  fail2ban     nginx-limit-req, botsearch, recidive       │
 │ 5  SSH Lane     whitelist admin, MaxStartups, prioritas    │
 │                 CPU/IO sesi SSH, limit web/db, earlyoom    │
 └──────────────────────────────────────────────────────────┘
```

**Opsional / lanjutan:**

- 🌩️ **Cloudflare-only mode** — port 80/443 hanya menerima IP Cloudflare
- 🚇 **Cloudflare Tunnel** — nol port web terbuka di firewall
- 🧬 **WAF ModSecurity + OWASP CRS**
- 🧱 **AppArmor untuk Nginx** — mulai dari *complain mode* dulu
- 🔗 **Tailscale** — jalur SSH privat yang nggak lewat internet publik
- 📡 **Attack Radar** — dashboard live: conntrack, SYN_RECV, top sumber koneksi, rule yang lagi nge-drop paket
- 🚨 **Emergency Stop** — matikan nginx + (opsional) lockdown SSH dalam sekali pilih

---

## 🧯 Dirancang Anti Ke-Lock & Anti Salah Pencet

Server pernah down dan nggak bisa diakses itu menyakitkan. Makanya banyak pengaman bawaan:

- ✅ **SSH guard** — sebelum enable UFW, port SSH dipastikan sudah di-allow
- ✅ **Validasi sebelum reload** — `nginx -t`, `sshd -t`, `named-checkconf`, `php-fpm -t`; kalau gagal → **rollback otomatis**
- ✅ **Dead-man switch** — SSH Lockdown otomatis dibatalkan dalam **120 detik** kalau kamu nggak konfirmasi
- ✅ **Konfirmasi bertingkat** — aksi berbahaya minta kamu **mengetik frasa** (contoh: `RESET hostname`, `HAPUS DATA`, `RESTORE`)
- ✅ **Paket terlindungi** di Factory Reset — kernel, boot, SSH, netplan, apt/dpkg, sudo, ufw tidak disentuh
- ✅ **Input tervalidasi** — nama DB, domain, IP, port, password disaring regex
- ✅ **Semua aksi tercatat** di `/var/log/charr-toolkit.log`

---

## 🚀 Instalasi

```bash
# 1. Clone repo
git clone https://github.com/<username>/<nama-repo>.git
cd <nama-repo>

# 2. Jalankan (otomatis minta sudo kalau belum root)
sudo bash charr.sh
```

Mau dipanggil dari mana saja? Pilih menu **`[16] Install 'charr'`**, lalu cukup ketik:

```bash
sudo charr
```

**Tanpa animasi intro:**

```bash
sudo bash charr.sh --no-anim
```

### Persyaratan

| Item | Keterangan |
|---|---|
| OS | Ubuntu Server (berbasis Debian: `apt`, `systemd`) |
| Akses | `root` / `sudo` |
| Shell | Bash 4+ |
| Paket tambahan | Diinstall **otomatis saat dibutuhkan** (nginx, ufw, fail2ban, nftables, certbot, dll.) |

---

## 🎮 Mode CLI (tanpa menu)

```bash
sudo charr <perintah>
```

| Perintah | Fungsi |
|---|---|
| `daily` | Briefing harian |
| `fetch` | Info sistem ala neofetch |
| `health` | Health check |
| `monitor` | Live monitor |
| `clean` | Cleaner |
| `audit` | Security audit |
| `security` | Security Center |
| `firewall` / `fw` | Firewall Manager (UFW) |
| `setup` | VPS Setup Center |
| `lemp` | Install Nginx + PHP + MariaDB |
| `db` | Database Manager |
| `doctor` | Smart Doctor (scan + auto-fix) |
| `logs` | Log Explorer |
| `swap` | Swap & Memory |
| `shield` | Shield anti-DDoS / scan |
| `shield-reload` | Apply ulang ruleset Shield |
| `install` | Pasang sebagai command `charr` |

---

## 🩺 Smart Doctor

Bukan sekadar scan — dia **menjelaskan kenapa** sesuatu rusak dan menawarkan perbaikan:

```
 [CRIT] nginx gagal konek ke upstream/PHP-FPM (12 error/48 jam)
        ↳ php-fpm mati atau fastcgi_pass/proxy_pass salah
        ⚙ auto-fix tersedia

 HEALTH SCORE  ████████████████░░░░░░░░░░░░░░  64%  (1 critical, 3 warning)
```

Mendeteksi: disk/inode penuh, OOM-killer, service gagal, config Nginx error, socket PHP-FPM hilang, SSL hampir kedaluwarsa, MariaDB korup, UFW memblokir SSH, indikasi brute-force, dan banyak lagi.

---

## 📁 Lokasi File Penting

| Path | Isi |
|---|---|
| `/var/log/charr-toolkit.log` | Log semua aksi toolkit |
| `/etc/charr/` | Config Shield, whitelist IP, daftar IP Cloudflare |
| `/var/backups/charr-db/` | Backup database (`.sql.gz`) |
| `/root/charr-reset-<waktu>/` | Backup daftar paket sebelum Factory Reset |

---

## ⚠️ Baca Sebelum Dipakai

**Yang harus kamu tahu dengan jujur:**

- 🌊 **Serangan volumetrik (banjir bandwidth) tidak bisa dihentikan dari dalam server.** Paket sudah menyumbat jalur sebelum sampai ke mesinmu. Untuk itu gunakan proxy/upstream seperti Cloudflare (tersedia mode CF-only & Tunnel di Shield).
- 🧬 **WAF bisa memblokir request yang sah** (upload besar, API tidak lazim). Pantau log 1–2 hari setelah aktif.
- 🧱 **AppArmor** sengaja mulai dari *complain mode*. Pindah ke *enforce* hanya setelah log bersih.
- 🔒 **Lockdown SSH** membuatmu tergantung pada IP whitelist. Selalu siapkan **akses konsol dari panel VPS** sebagai cadangan.
- ☢️ **Factory Reset** menghapus paket dan (level 3) data. **Tidak bisa di-undo.** Backup dulu.
- 🌐 **LAN Sweep** hanya untuk jaringan **milikmu sendiri**.

**Disclaimer:** Dipakai dengan risiko sendiri. Uji di server non-produksi atau snapshot dulu. Penulis tidak bertanggung jawab atas kerugian akibat penggunaan yang salah.

---

## 🤝 Kontribusi

Ada bug, ide fitur, atau perbaikan? Silakan:

1. Fork repo ini
2. Buat branch: `git checkout -b fitur/nama-fitur`
3. Commit: `git commit -m "feat: deskripsi singkat"`
4. Push & buka **Pull Request**

Laporan bug sangat dibantu kalau menyertakan versi Ubuntu, versi CHARR//TOOLKIT (terlihat di banner), dan potongan `/var/log/charr-toolkit.log`.

---

## 📜 Lisensi

Tentukan lisensi sebelum publish (misalnya **MIT**) dan tambahkan file `LICENSE` di root repo.

---

<div align="center">

### 🛡️ Jaga Server Kamu

Server itu seperti rumah: kunci pintunya, pantau sekelilingnya, dan jangan pernah menganggap "pasti aman".
Alat ini membantu — **tapi kewaspadaan tetap ada di tanganmu.**

Jaga servermu dari orang-orang yang tidak bertanggung jawab.
Update rutin, backup teratur, dan jangan pernah bagikan kredensialmu.

**Stay safe. Stay sharp. 🔐**

*— [@c.for.charr](https://github.com/)*

</div>
