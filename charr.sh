#!/usr/bin/env bash
# ╔════════════════════════════════════════════════════════════════╗
# ║  CHARR//TOOLKIT — Ubuntu Server Ops Suite                      ║
# ║  Author : @c.for.charr                                         ║
# ║  Usage  : sudo bash charr.sh [--no-anim] [command]             ║
# ╚════════════════════════════════════════════════════════════════╝
set -o pipefail
VERSION="1.3.0"
AUTHOR="@c.for.charr"
LOG="/var/log/charr-toolkit.log"
ANIM=1

[[ $EUID -eq 0 ]] || exec sudo -E bash "$0" "$@"
[[ -t 1 ]] || ANIM=0

# ───────────────────────── colors & helpers ─────────────────────────
R=$'\e[31m'; G=$'\e[32m'; Y=$'\e[33m'; B=$'\e[34m'; M=$'\e[35m'; C=$'\e[36m'
W=$'\e[97m'; D=$'\e[90m'; BD=$'\e[1m'; N=$'\e[0m'
trap 'tput cnorm 2>/dev/null; printf "%s" "$N"' EXIT
trap 'tput cnorm 2>/dev/null; echo; exit 130' INT

log()  { printf '%s %s\n' "$(date '+%F %T')" "$*" >>"$LOG" 2>/dev/null; }
ok()   { printf " ${G}[ ✔ ]${N} %s\n" "$*"; }
warn() { printf " ${Y}[ ! ]${N} %s\n" "$*"; }
err()  { printf " ${R}[ ✘ ]${N} %s\n" "$*"; }
info() { printf " ${C}[ i ]${N} %s\n" "$*"; }
rep()  { local s="" i; for ((i=0;i<${2:-0};i++)); do s+="$1"; done; printf '%s' "$s"; }
need() { command -v "$1" >/dev/null 2>&1; }
pause(){ echo; read -rp "  ${D}[Enter] lanjut...${N} " _; }
confirm(){ local a; read -rp "  ${Y}$1 [y/N]:${N} " a; [[ $a =~ ^[Yy]$ ]]; }
hum()  { numfmt --to=iec --suffix=B "${1:-0}" 2>/dev/null || echo "${1:-0}B"; }
used() { df -B1 --output=used / | tail -1 | tr -d ' '; }
sz()   { du -sb "$@" 2>/dev/null | awk '{s+=$1} END{print s+0}'; }

section() {
  local t="$1" pad=$((54-${#1}))
  printf "\n${BD}${C}┏━[ ${W}%s${C} ]%s${N}\n" "$t" "$(rep '━' $pad)"
}

bar() { # pct width
  local p=${1%.*} w=${2:-24} f e col
  p=${p:-0}; ((p<0)) && p=0; ((p>100)) && p=100
  f=$((p*w/100)); e=$((w-f))
  if ((p>=85)); then col=$R; elif ((p>=60)); then col=$Y; else col=$G; fi
  printf '%s%s%s%s%s %3d%%' "$col" "$(rep '█' $f)" "$D" "$(rep '░' $e)" "$N" "$p"
}

# ───────────────────────── animations ─────────────────────────
type_out() { local s="$1" d="${2:-0.008}" i; for ((i=0;i<${#s};i++)); do printf '%s' "${s:$i:1}"; sleep "$d"; done; echo; }

matrix() {
  local dur="${1:-2}" cols lines i r c end=$((SECONDS+dur))
  local set='0123456789ABCDEF@#$%&*<>/\|{}[]=+:;'
  cols=$(tput cols); lines=$(tput lines); tput civis; clear
  while ((SECONDS < end)); do
    for i in {1..70}; do
      r=$((RANDOM%lines+1)); c=$((RANDOM%cols+1))
      printf '\e[%d;%dH\e[32m%s' "$r" "$c" "${set:RANDOM%${#set}:1}"
      printf '\e[%d;%dH\e[97m%s' "$((r%lines+1))" "$c" "${set:RANDOM%${#set}:1}"
    done
    sleep 0.03
  done
  printf '\e[0m'; tput cnorm; clear
}

progress() { # msg
  local n=32 i
  for ((i=0;i<=n;i++)); do
    printf "\r ${C}%-26s${N} [${G}%s${D}%s${N}] %3d%%" "$1" "$(rep '#' $i)" "$(rep '.' $((n-i)))" $((i*100/n))
    sleep 0.02
  done; echo
}

boot_seq() {
  local s steps=("Initializing CHARR kernel hooks" "Probing hardware bus" "Mounting telemetry channels"
    "Loading network stack" "Spawning watchdog daemons" "Handshaking with systemd" "Arming security modules")
  for s in "${steps[@]}"; do
    printf " ${D}[${N}${G}  OK  ${N}${D}]${N} "; type_out "$s ..." 0.012; sleep 0.04
  done
  echo; progress "Decrypting workspace"
  sleep 0.3
}

intro() { ((ANIM)) || return 0; matrix 2; boot_seq; }

banner() {
  clear
  printf "${G}${BD}"
  cat <<'EOF'
 ██████╗██╗  ██╗ █████╗ ██████╗ ██████╗
██╔════╝██║  ██║██╔══██╗██╔══██╗██╔══██╗
██║     ███████║███████║██████╔╝██████╔╝
██║     ██╔══██║██╔══██║██╔══██╗██╔══██╗
╚██████╗██║  ██║██║  ██║██║  ██║██║  ██║
 ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝
EOF
  printf "${N}${D}  ┌─ ${W}SERVER OPS SUITE${D} • SysAdmin × NetEng × Sec ─ v%s ─ ${C}%s${D} ─┐${N}\n" "$VERSION" "$AUTHOR"
}

# ───────────────────────── info collectors ─────────────────────────
os_name()  { . /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-Linux}"; }
cpu_model(){ lscpu 2>/dev/null | awk -F: '/Model name/{gsub(/^ +/,"",$2);print $2;exit}'; }
mem_pct()  { free | awk '/Mem:/{printf "%d",$3*100/$2}'; }
prim_ip()  { ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1);exit}}'; }
prim_if()  { ip route show default 2>/dev/null | awk '{print $5; exit}'; }
cpu_sample(){ awk '/^cpu /{b=$2+$3+$4+$7+$8+$9; print b, b+$5+$6}' /proc/stat; }

status_bar() {
  printf "${D}  host:${N}%s ${D}ip:${N}%s ${D}up:${N}%s ${D}load:${N}%s ${D}mem:${N}%s%%\n" \
    "$(hostname)" "$(prim_ip)" "$(uptime -p | sed 's/up //')" "$(cut -d' ' -f1 /proc/loadavg)" "$(mem_pct)"
}

sysfetch() {
  local L0='┌──────────────────┐' L1='│ ● ● ●            │' L2='├──────────────────┤'
  local L3='│ > charr@srv      │' L4='│ > sudo ./hack    │' L5='│ > _              │' L6='└──────────────────┘'
  local blank; blank=$(printf '%20s' '')
  local logo=("" "$L0" "$L1" "$L2" "$L3" "$L4" "$L5" "$L6")
  local u="${SUDO_USER:-${USER:-$(id -un)}}" pk sn sv fl
  pk=$(dpkg-query -f '.\n' -W 2>/dev/null | wc -l)
  sn=$(snap list 2>/dev/null | tail -n +2 | wc -l)
  sv=$(systemctl list-units --type=service --state=running --no-legend 2>/dev/null | wc -l)
  fl=$(systemctl --failed --no-legend 2>/dev/null | wc -l)
  kv() { printf '%s%-9s%s %s' "$C" "$1" "$N" "$2"; }
  local info=(
    "${BD}${G}${u}${N}@${BD}${G}$(hostname)${N}"
    "${D}$(rep '─' 34)${N}"
    "$(kv OS "$(os_name)")"
    "$(kv Kernel "$(uname -r)")"
    "$(kv Uptime "$(uptime -p | sed 's/up //')")"
    "$(kv Packages "$pk (dpkg), $sn (snap)")"
    "$(kv Shell "${SHELL##*/}")"
    "$(kv CPU "$(cpu_model) ($(nproc))")"
    "$(kv Memory "$(free -m | awk '/Mem:/{printf "%d / %d MiB (%d%%)",$3,$2,$3*100/$2}')")"
    "$(kv Disk "$(df -h / | awk 'NR==2{printf "%s / %s (%s)",$3,$2,$5}')")"
    "$(kv IP "$(prim_ip) via $(prim_if)")"
    "$(kv Services "$sv running, ${fl} failed")"
    "$(kv Author "${AUTHOR}")"
  )
  echo
  local i n=${#info[@]}
  for ((i=0;i<n;i++)); do
    printf "  ${G}%s${N}  %s\n" "${logo[$i]:-$blank}" "${info[$i]}"
  done
  printf "\n  %s" "$blank"
  for c in 40 41 42 43 44 45 46 47; do printf '\e[%dm   ' "$c"; done; printf '%s\n' "$N"
}

# ───────────────────────── health ─────────────────────────
health() {
  section "SYSTEM HEALTH"
  local l1 l5 l15 cores upd fl z
  read -r l1 l5 l15 _ </proc/loadavg; cores=$(nproc)
  printf "  %-10s %s %s %s ${D}(%s core)${N}\n" "Load" "$l1" "$l5" "$l15" "$cores"
  awk -v l="$l1" -v c="$cores" 'BEGIN{exit !(l>c)}' && warn "load 1m > jumlah core" || ok "load normal"
  printf "  %-10s %s\n" "RAM" "$(bar "$(mem_pct)" 28)"
  printf "  %-10s %s\n" "Swap" "$(bar "$(free | awk '/Swap:/{if($2>0)printf "%d",$3*100/$2; else print 0}')" 28)"
  echo "  ${D}── disk ──${N}"
  df -P -x tmpfs -x devtmpfs -x squashfs -x overlay -x efivarfs 2>/dev/null | awk 'NR>1{gsub("%","",$5);print $6,$5}' |
    while read -r m p; do printf "  %-18s %s\n" "$m" "$(bar "$p" 24)"; done
  printf "  %-10s %s\n" "Inode /" "$(bar "$(df -i / | awk 'NR==2{gsub("%","",$5);print $5+0}')" 28)"
  echo "  ${D}── services & system ──${N}"
  fl=$(systemctl --failed --no-legend --plain 2>/dev/null | awk '{print $1}')
  if [[ -z $fl ]]; then ok "gak ada service failed"; else err "service failed:"; echo "$fl" | sed 's/^/        /'; fi
  upd=$(apt list --upgradable 2>/dev/null | grep -c 'upgradable')
  ((upd>0)) && warn "$upd paket bisa di-upgrade" || ok "paket up-to-date"
  [[ -f /var/run/reboot-required ]] && warn "REBOOT dibutuhkan (kernel/lib update)" || ok "gak perlu reboot"
  [[ $(timedatectl show -p NTPSynchronized --value 2>/dev/null) == yes ]] && ok "waktu sinkron NTP" || warn "NTP belum sinkron"
  z=$(ps -eo stat | grep -c '^Z')
  ((z>0)) && warn "$z proses zombie" || ok "gak ada zombie"
  if need ufw; then ufw status 2>/dev/null | head -1 | grep -q active && ok "firewall UFW aktif" || warn "UFW nonaktif"; else warn "ufw belum terinstall"; fi
}

daily() {
  banner; sysfetch; health
  section "TOP FOLDER /var"
  du -xh --max-depth=1 /var 2>/dev/null | sort -rh | head -6 | sed 's/^/  /'
  section "LOGIN TERAKHIR"
  last -n 5 -a 2>/dev/null | head -5 | sed 's/^/  /'
  local f; f=$( { journalctl -u ssh -u sshd --since '24 hours ago' --no-pager 2>/dev/null; } | grep -c 'Failed password')
  ((f>0)) && warn "$f percobaan login SSH gagal (24 jam)" || ok "gak ada login SSH gagal (24 jam)"
}

# ───────────────────────── live monitor ─────────────────────────
monitor_live() {
  local iface pb pt cb ct cp rx tx nrx ntx t0 dt rxr txr k dp line
  iface=$(prim_if); iface=${iface:-lo}
  read -r pb pt <<<"$(cpu_sample)"
  rx=$(<"/sys/class/net/$iface/statistics/rx_bytes"); tx=$(<"/sys/class/net/$iface/statistics/tx_bytes")
  t0=${EPOCHREALTIME/./}
  tput civis; clear
  while true; do
    sleep 0.01
    read -r cb ct <<<"$(cpu_sample)"
    cp=$(( ct>pt ? 100*(cb-pb)/(ct-pt) : 0 )); pb=$cb; pt=$ct
    nrx=$(<"/sys/class/net/$iface/statistics/rx_bytes"); ntx=$(<"/sys/class/net/$iface/statistics/tx_bytes")
    dt=$(( ${EPOCHREALTIME/./} - t0 )); ((dt<1)) && dt=1; t0=${EPOCHREALTIME/./}
    rxr=$(( (nrx-rx)*1000000/dt )); txr=$(( (ntx-tx)*1000000/dt )); rx=$nrx; tx=$ntx
    dp=$(df -P / | awk 'NR==2{gsub("%","",$5);print $5}')
    printf '\e[H'
    printf "${BD}${G}CHARR//MONITOR${N} ${D}%s • %s • [q] keluar${N}\e[K\n" "$(hostname)" "$(date '+%F %T')"
    printf "${D}$(rep '─' 70)${N}\e[K\n"
    printf " CPU   %s ${D}load %s${N}\e[K\n" "$(bar "$cp" 34)" "$(cut -d' ' -f1-3 /proc/loadavg)"
    printf " RAM   %s ${D}%s${N}\e[K\n" "$(bar "$(mem_pct)" 34)" "$(free -h | awk '/Mem:/{print $3"/"$2}')"
    printf " DISK  %s ${D}/${N}\e[K\n" "$(bar "$dp" 34)"
    printf " NET   ${C}↓ %s${N}  ${M}↑ %s${N}  ${D}[%s]${N}\e[K\n" "$(hum $rxr)/s" "$(hum $txr)/s" "$iface"
    printf "${D}$(rep '─' 70)${N}\e[K\n"
    printf " ${BD}TOP PROSES (CPU)${N}\e[K\n"
    while read -r line; do printf "  %s\e[K\n" "$line"; done < <(ps -eo pid,user:10,comm:18,%cpu,%mem --sort=-%cpu | head -8)
    printf "${D}$(rep '─' 70)${N}\e[K\n"
    printf " ${BD}KONEKSI${N} ${D}estab:${N}%s ${D}listen:${N}%s ${D}procs:${N}%s\e[K\n" \
      "$(ss -tn state established 2>/dev/null | tail -n +2 | wc -l)" "$(ss -tln 2>/dev/null | tail -n +2 | wc -l)" "$(ps -e --no-headers | wc -l)"
    printf '\e[J'
    read -rsn1 -t 2 k && [[ $k == q || $k == Q ]] && break
  done
  tput cnorm; clear
}

# ───────────────────────── storage & apps ─────────────────────────
inventory() {
  section "APT — INSTALL MANUAL"
  printf "  total: %s paket manual, %s total\n" "$(apt-mark showmanual | wc -l)" "$(dpkg-query -f '.\n' -W | wc -l)"
  apt-mark showmanual | paste -sd' ' | fold -s -w 96 | sed 's/^/  /'
  section "SNAP"
  need snap && snap list 2>/dev/null | sed 's/^/  /' || echo "  (snap gak ada)"
  section "DOCKER"
  if need docker; then docker ps -a --format '  {{.Names}}\t{{.Image}}\t{{.Status}}' 2>/dev/null; docker system df 2>/dev/null | sed 's/^/  /'; else echo "  (docker gak ada)"; fi
  section "/opt  &  /usr/local/bin"
  ls -1 /opt /usr/local/bin 2>/dev/null | sed 's/^/  /'
  section "SERVICE AKTIF"
  systemctl list-units --type=service --state=running --no-legend --plain | awk '{print "  "$1}'
  section "PORT LISTEN → PROSES"
  ss -tulpn 2>/dev/null | awk 'NR>1{printf "  %-5s %-26s %s\n",$1,$5,$7}'
}

storage_menu() {
  while true; do
    section "STORAGE & APP EXPLORER"
    cat <<EOF
  ${G}[1]${N} Ringkasan disk (df)          ${G}[5]${N} Ukuran app terinstall (top 25)
  ${G}[2]${N} Top folder di path           ${G}[6]${N} Deteksi SEMUA app/service/folder
  ${G}[3]${N} Top file terbesar di path    ${G}[7]${N} Ukuran home tiap user
  ${G}[4]${N} Ukuran /var/log & cache      ${G}[0]${N} Balik
EOF
    local c p; read -rp "  ${C}»${N} " c
    case $c in
      1) df -hT -x tmpfs -x devtmpfs -x squashfs -x overlay | sed 's/^/  /'; pause;;
      2) read -rp "  path [/]: " p; p=${p:-/}; info "scan $p (tunggu...)"
         du -xh --max-depth=1 "$p" 2>/dev/null | sort -rh | head -16 | sed 's/^/  /'; pause;;
      3) read -rp "  path [/]: " p; p=${p:-/}; info "scan $p (tunggu...)"
         find "$p" -xdev -type f -printf '%s\t%p\n' 2>/dev/null | sort -rn | head -15 |
           while IFS=$'\t' read -r s f; do printf "  %9s  %s\n" "$(hum "$s")" "$f"; done; pause;;
      4) du -sh /var/log /var/cache /var/lib/apt /var/lib/snapd /var/lib/docker /var/crash /tmp 2>/dev/null | sed 's/^/  /'
         journalctl --disk-usage 2>/dev/null | sed 's/^/  /'; pause;;
      5) dpkg-query -Wf '${Installed-Size}\t${Package}\n' | sort -rn | head -25 |
           awk '{printf "  %9.1f MB  %s\n",$1/1024,$2}'; pause;;
      6) inventory; pause;;
      7) du -sh /root /home/* 2>/dev/null | sort -rh | sed 's/^/  /'; pause;;
      0) return;;
    esac
  done
}

# ───────────────────────── cleaner ─────────────────────────
c_apt()     { apt-get clean; apt-get -y autoclean; }
c_orphan()  { DEBIAN_FRONTEND=noninteractive apt-get -y autoremove --purge; }
c_rc()      { dpkg -l | awk '/^rc/{print $2}' | xargs -r dpkg --purge; }
c_journal() { journalctl --rotate; journalctl --vacuum-time=7d --vacuum-size=200M; }
c_logs()    { find /var/log -type f \( -name '*.gz' -o -name '*.[0-9]' -o -name '*.old' \) -delete; }
c_tmp()     { find /tmp -mindepth 1 -mtime +3 -delete 2>/dev/null; find /var/tmp -mindepth 1 -mtime +7 -delete 2>/dev/null; }
c_ucache()  { local h; for h in /root /home/*; do rm -rf "$h/.cache/"* "$h/.local/share/Trash/"* 2>/dev/null; done; }
c_snap()    { need snap || return 0; snap list --all | awk '/disabled/{print $1,$3}' | while read -r n r; do snap remove "$n" --revision="$r"; done; }
c_docker()  { need docker || return 0; docker system prune -f; }
c_pipnpm()  { need pip && pip cache purge; need pip3 && pip3 cache purge; need npm && npm cache clean --force; return 0; }
c_crash()   { rm -rf /var/crash/* 2>/dev/null; }

CLEAN_TASKS=(
  "APT cache (clean + autoclean)|c_apt"
  "Paket orphan (autoremove --purge, termasuk kernel lama)|c_orphan"
  "Sisa config paket terhapus (rc)|c_rc"
  "Journal systemd (>7 hari / >200M)|c_journal"
  "Log lama terkompres (*.gz, *.1)|c_logs"
  "Temp file lama (/tmp, /var/tmp)|c_tmp"
  "Cache & trash user (~/.cache)|c_ucache"
  "Snap revision lama (disabled)|c_snap"
  "Docker dangling (prune)|c_docker"
  "Cache pip / npm|c_pipnpm"
  "Crash report (/var/crash)|c_crash"
)

run_clean() { # label func
  local b a; b=$(used); log "clean: $1"
  "$2" >>"$LOG" 2>&1; a=$(used)
  ok "$1  ${D}(+$(hum $((b>a ? b-a : 0))) bebas)${N}"
}

cleaner_scan() {
  section "SCAN — YANG BISA DIBERSIHIN"
  local j l
  j=$(journalctl --disk-usage 2>/dev/null | grep -oE '[0-9.]+[KMGT]' | head -1)
  l=$(find /var/log -type f \( -name '*.gz' -o -name '*.[0-9]' -o -name '*.old' \) -printf '%s\n' 2>/dev/null | awk '{s+=$1}END{print s+0}')
  printf "  %-24s %10s\n" "APT cache"      "$(hum "$(sz /var/cache/apt)")"
  printf "  %-24s %10s\n" "Journal"        "${j:-0}"
  printf "  %-24s %10s\n" "Log lama"       "$(hum "$l")"
  printf "  %-24s %10s\n" "/tmp + /var/tmp" "$(hum "$(sz /tmp /var/tmp)")"
  printf "  %-24s %10s\n" "User cache"     "$(hum "$(sz /root/.cache /home/*/.cache)")"
  printf "  %-24s %10s\n" "Paket orphan"   "$(apt-get -s autoremove 2>/dev/null | grep -c '^Remv') paket"
  printf "  %-24s %10s\n" "Config sisa (rc)" "$(dpkg -l | grep -c '^rc') paket"
}

cleaner_menu() {
  while true; do
    cleaner_scan
    section "CLEANER"
    local i t
    for i in "${!CLEAN_TASKS[@]}"; do
      t=${CLEAN_TASKS[$i]%%|*}; printf "  ${G}[%2d]${N} %s\n" $((i+1)) "$t"
    done
    printf "  ${Y}[ A]${N} ${BD}BERSIHIN SEMUA${N}     ${G}[ 0]${N} Balik\n"
    local c; read -rp "  ${C}»${N} " c
    case $c in
      0) return;;
      [Aa]) if confirm "Jalanin semua task pembersihan?"; then
              local b a; b=$(used)
              for t in "${CLEAN_TASKS[@]}"; do run_clean "${t%%|*}" "${t##*|}"; done
              a=$(used); echo; ok "${BD}TOTAL bebas: $(hum $((b>a ? b-a : 0)))${N}"
            fi; pause;;
      ''|*[!0-9]*) ;;
      *) if ((c>=1 && c<=${#CLEAN_TASKS[@]})); then
           t=${CLEAN_TASKS[$((c-1))]}; run_clean "${t%%|*}" "${t##*|}"; pause
         fi;;
    esac
  done
}

# ───────────────────────── service manager ─────────────────────────
SVC=""
pick_service() {
  local kw n i; local -a M
  read -rp "  keyword service (mis. ssh, nginx, docker): " kw
  mapfile -t M < <(systemctl list-unit-files --type=service --no-legend --plain | awk '{print $1}' | grep -i -- "$kw" | head -20)
  ((${#M[@]})) || { err "gak ketemu"; return 1; }
  for i in "${!M[@]}"; do printf "  %2d) %-38s ${D}[%s]${N}\n" $((i+1)) "${M[$i]}" "$(systemctl is-active "${M[$i]}" 2>/dev/null)"; done
  read -rp "  pilih nomor: " n
  [[ $n =~ ^[0-9]+$ ]] && ((n>=1 && n<=${#M[@]})) || { err "invalid"; return 1; }
  SVC="${M[$((n-1))]}"
}

service_menu() {
  while true; do
    section "SERVICE MANAGER"
    cat <<EOF
  ${G}[1]${N} List service jalan           ${G}[5]${N} Restart service
  ${G}[2]${N} List service failed          ${G}[6]${N} Enable / Disable (boot)
  ${G}[3]${N} Status service               ${G}[7]${N} Log service (50 baris)
  ${G}[4]${N} Start / Stop service         ${G}[0]${N} Balik
EOF
    local c a; read -rp "  ${C}»${N} " c
    case $c in
      1) systemctl list-units --type=service --state=running --no-legend --plain | awk '{printf "  %-40s %s\n",$1,$4" "$5" "$6" "$7}'; pause;;
      2) systemctl --failed --plain | sed 's/^/  /'; pause;;
      3) pick_service && systemctl status "$SVC" --no-pager | sed 's/^/  /'; pause;;
      4) pick_service && { read -rp "  [s]tart / s[t]op: " a
           case $a in s) systemctl start "$SVC" && ok "$SVC started";; t) systemctl stop "$SVC" && ok "$SVC stopped";; esac; log "svc $a $SVC"; }; pause;;
      5) pick_service && systemctl restart "$SVC" && ok "$SVC restarted" && log "svc restart $SVC"; pause;;
      6) pick_service && { read -rp "  [e]nable / [d]isable: " a
           case $a in e) systemctl enable "$SVC";; d) systemctl disable "$SVC";; esac; log "svc $a $SVC"; }; pause;;
      7) pick_service && journalctl -u "$SVC" -n 50 --no-pager | sed 's/^/  /'; pause;;
      0) return;;
    esac
  done
}

# ───────────────────────── network toolkit ─────────────────────────
lan_sweep() {
  local cidr base i
  cidr=$(ip -4 -o addr show scope global | awk '{print $4; exit}'); base=${cidr%.*}
  [[ -n $base ]] || { err "gak nemu IP lokal"; return; }
  info "ping sweep ${base}.0/24 — pakai di jaringan sendiri aja"
  for i in $(seq 1 254); do ( ping -c1 -W1 "$base.$i" >/dev/null 2>&1 && echo "$base.$i" ) & done | sort -t. -k4 -n | sed 's/^/  UP  /'
  wait; echo; ip neigh show | grep -v FAILED | sed 's/^/  /'
}

net_menu() {
  while true; do
    section "NETWORK TOOLKIT"
    cat <<EOF
  ${G}[1]${N} Interface / IP / route / DNS   ${G}[7]${N} Traceroute / MTR
  ${G}[2]${N} Tes konektivitas (GW,IP,DNS)   ${G}[8]${N} DNS lookup
  ${G}[3]${N} Port listening + proses        ${G}[9]${N} Firewall (ufw/nft)
  ${G}[4]${N} Koneksi aktif & top IP remote  ${G}[10]${N} LAN sweep (host hidup)
  ${G}[5]${N} Traffic per interface          ${G}[11]${N} Install net-tools pack
  ${G}[6]${N} Cek port remote (TCP)          ${G}[0]${N} Balik
EOF
    local c h p gw; read -rp "  ${C}»${N} " c
    case $c in
      1) ip -br a | sed 's/^/  /'; echo; ip route | sed 's/^/  /'; echo
         resolvectl status 2>/dev/null | grep -E 'Link|DNS Server|Current DNS' | sed 's/^/  /' || cat /etc/resolv.conf; pause;;
      2) gw=$(ip route show default | awk '{print $3; exit}')
         for h in "$gw" 1.1.1.1 8.8.8.8; do [[ -n $h ]] || continue
           ping -c2 -W2 "$h" >/dev/null 2>&1 && ok "ping $h" || err "ping $h"; done
         getent hosts google.com >/dev/null && ok "DNS resolve google.com" || err "DNS gagal"
         need curl && { curl -s -o /dev/null -m 5 -w '  HTTP google: %{http_code} (%{time_total}s)\n' https://www.google.com || err "HTTPS gagal"; }
         need curl && info "IP publik: $(curl -s -m 5 https://ifconfig.me || echo n/a)"; pause;;
      3) ss -tulpn | awk 'NR>1{printf "  %-5s %-28s %s\n",$1,$5,$7}'; pause;;
      4) echo "  ${D}ringkasan state:${N}"; ss -tan | awk 'NR>1{c[$1]++} END{for(k in c) printf "  %-12s %d\n",k,c[k]}'
         echo; echo "  ${D}top IP remote (ESTAB):${N}"
         ss -tn state established | awk 'NR>1{split($4,a,":"); print a[1]}' | sort | uniq -c | sort -rn | head -10 | sed 's/^/  /'; pause;;
      5) for h in $(ls /sys/class/net); do printf "  %-12s RX %-10s TX %-10s\n" "$h" \
           "$(hum "$(<"/sys/class/net/$h/statistics/rx_bytes")")" "$(hum "$(<"/sys/class/net/$h/statistics/tx_bytes")")"; done; pause;;
      6) read -rp "  host: " h; read -rp "  port: " p
         timeout 3 bash -c "</dev/tcp/$h/$p" 2>/dev/null && ok "$h:$p OPEN" || err "$h:$p closed/filtered"; pause;;
      7) read -rp "  target: " h
         if need mtr; then mtr -rwc 5 "$h"; elif need traceroute; then traceroute "$h"; else warn "install dulu (opsi 11)"; fi; pause;;
      8) read -rp "  domain: " h
         if need dig; then dig +short "$h" A "$h" AAAA "$h" MX | sed 's/^/  /'; else getent ahosts "$h" | sed 's/^/  /'; fi; pause;;
      9) need ufw && ufw status verbose | sed 's/^/  /'; need nft && nft list ruleset 2>/dev/null | head -40 | sed 's/^/  /'; pause;;
      10) lan_sweep; pause;;
      11) apt-get update -qq && apt-get install -y net-tools dnsutils mtr-tiny traceroute nmap iftop nload tcpdump curl; pause;;
      0) return;;
    esac
  done
}

# ───────────────────────── security audit ─────────────────────────
audit() {
  section "SECURITY AUDIT"
  local v f
  if need sshd; then
    v=$(sshd -T 2>/dev/null | awk '/^permitrootlogin /{print $2}')
    [[ $v == no ]] && ok "SSH root login: no" || warn "SSH PermitRootLogin = ${v:-?} (saran: no)"
    v=$(sshd -T 2>/dev/null | awk '/^passwordauthentication /{print $2}')
    [[ $v == no ]] && ok "SSH password auth: off (key-only)" || warn "SSH password auth: ${v:-?} (saran: key-only)"
    info "SSH port: $(sshd -T 2>/dev/null | awk '/^port /{print $2}' | paste -sd,)"
  else warn "openssh-server gak terdeteksi"; fi
  need ufw && { ufw status | head -1 | grep -q active && ok "UFW aktif" || warn "UFW belum aktif"; } || warn "UFW belum ada"
  need fail2ban-client && ok "fail2ban terinstall" || warn "fail2ban belum ada"
  dpkg -s unattended-upgrades >/dev/null 2>&1 && ok "unattended-upgrades ada" || warn "auto security update belum aktif"
  v=$(awk -F: '$3==0{print $1}' /etc/passwd | paste -sd' ')
  [[ $v == root ]] && ok "UID 0 cuma root" || err "UID 0: $v"
  v=$(awk -F: '($2==""){print $1}' /etc/shadow 2>/dev/null | paste -sd' ')
  [[ -z $v ]] && ok "gak ada user tanpa password" || err "password kosong: $v"
  info "SUID binaries: $(find / -xdev -perm -4000 -type f 2>/dev/null | wc -l)"
  echo "  ${D}── port terbuka ke publik (0.0.0.0 / ::) ──${N}"
  ss -tuln | awk 'NR>1 && ($5 ~ /^(0\.0\.0\.0|\*|\[::\]):/){print "  "$1" "$5}' | sort -u
  echo "  ${D}── top IP gagal login SSH (24 jam) ──${N}"
  f=$( { journalctl -u ssh -u sshd --since '24 hours ago' --no-pager 2>/dev/null; grep -h 'Failed password' /var/log/auth.log 2>/dev/null; } |
       grep 'Failed password' | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' | sort | uniq -c | sort -rn | head -5)
  [[ -n $f ]] && echo "$f" | sed 's/^/  /' || ok "bersih"
  echo "  ${D}── login terakhir ──${N}"; last -n 5 -a 2>/dev/null | head -5 | sed 's/^/  /'
}

# ───────────────────────── package manager ─────────────────────────
pkg_menu() {
  while true; do
    section "PACKAGE MANAGER"
    cat <<EOF
  ${G}[1]${N} Update + Upgrade penuh       ${G}[5]${N} Fix broken (dpkg/apt -f)
  ${G}[2]${N} Cari paket                   ${G}[6]${N} Daftar paket manual
  ${G}[3]${N} Install paket                ${G}[0]${N} Balik
  ${G}[4]${N} Hapus paket (purge)
EOF
    local c p; read -rp "  ${C}»${N} " c
    case $c in
      1) apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y full-upgrade; log "full-upgrade"; pause;;
      2) read -rp "  keyword: " p; apt-cache search "$p" | head -25 | sed 's/^/  /'; pause;;
      3) read -rp "  paket: " p; apt-get install -y $p; log "install $p"; pause;;
      4) read -rp "  paket: " p; apt-get purge -y $p && apt-get -y autoremove --purge; log "purge $p"; pause;;
      5) dpkg --configure -a; apt-get -f install -y; pause;;
      6) apt-mark showmanual | paste -sd' ' | fold -s -w 96 | sed 's/^/  /'; pause;;
      0) return;;
    esac
  done
}

# ───────────────────────── FACTORY RESET ─────────────────────────
# Paket yang DILINDUNGI (biar SSH, network, boot, apt tetap hidup)
PROTECT_RE='^(ubuntu-.*|openssh-.*|ssh|netplan\.io|libnetplan.*|systemd.*|linux-.*|grub.*|shim.*|efibootmgr|cloud-.*|sudo|apt|apt-.*|dpkg|network-manager|networkd-dispatcher|ufw|iptables|nftables|initramfs-tools.*|lvm2|mdadm|open-iscsi|multipath-tools|snapd|ca-certificates|curl|wget|gawk|mawk|procps|psmisc|iproute2|iputils-ping|isc-dhcp-client|less|lsof|nano|vim-tiny|cron|rsyslog|logrotate|kmod|udev|open-vm-tools|qemu-guest-agent|python3|python3-minimal|unattended-upgrades|needrestart|bash-completion|tzdata|locales|console-setup|keyboard-configuration)$'

installed_pkgs() { dpkg-query -W -f='${db:Status-Abbrev} ${Package}\n' 2>/dev/null | awk '$1 ~ /^ii/{print $2}'; }

restore_marks() { # $1 = file manual.before
  installed_pkgs | xargs -r apt-mark auto >/dev/null 2>&1
  xargs -a "$1" -r apt-mark manual >/dev/null 2>&1
}

wipe_dotfiles() {
  local h f
  for h in /root /home/*; do [[ -d $h ]] || continue
    for f in "$h"/.[!.]*; do [[ -e $f ]] || continue
      case "$(basename "$f")" in .ssh|.bashrc|.profile|.bash_logout|.hushlogin|.sudo_as_admin_successful) continue;; esac
      rm -rf -- "$f"
    done
  done
}

wipe_snaps() {
  need snap || return 0
  local p s
  for p in 1 2 3; do
    for s in $(snap list 2>/dev/null | awk 'NR>1{print $1}' | grep -Ev '^(core|core[0-9]+|snapd|bare|gtk-common-themes|gnome-.*|mesa-.*)$'); do
      snap remove --purge "$s" >>"$LOG" 2>&1
    done
  done
}

factory_reset() {
  banner
  section "☢  FACTORY RESET — VERSI LINUX (level paket)"
  cat <<EOF
  ${R}${BD}PERINGATAN:${N} ini ngehapus paket & (opsional) data. ${BD}Gak bisa di-undo.${N}
  ${G}Dilindungi otomatis:${N} kernel, boot, SSH, netplan/network, apt/dpkg, sudo, ufw, snapd, cloud-init.
  Server tetap bisa di-SSH & boot; sisanya balik ke base ubuntu-server.
  Backup daftar paket otomatis ke ${C}/root/charr-reset-<waktu>/${N}

  ${Y}Level 1${N}  Purge semua paket di luar base  (+ sisa config rc, apt cache)
  ${Y}Level 2${N}  Level 1 + snap app, /opt, /usr/local/*, dotfiles user (kecuali .ssh/.bashrc/.profile), /var/lib/docker
  ${R}Level 3${N}  Level 2 + DATA: /home/*/(non-hidden), /var/www, /srv   ${R}(bahaya)${N}
EOF
  [[ -n ${SSH_CONNECTION:-} ]] && info "kamu lagi konek via SSH — sesi tetap aman, SSH & network dilindungi"
  local lvl; read -rp "  level [1/2/3, x=batal]: " lvl
  [[ $lvl =~ ^[123]$ ]] || { info "dibatalin"; return; }

  local ts dir prot plan
  ts=$(date +%Y%m%d-%H%M%S); dir="/root/charr-reset-$ts"; plan="$dir/plan-purge.txt"; mkdir -p "$dir"
  apt-mark showmanual >"$dir/manual.before"; dpkg --get-selections >"$dir/selections.before"
  log "FACTORY RESET start level=$lvl dir=$dir"

  info "hitung rencana (apt simulate)..."
  prot=$(dpkg-query -W -f='${Package}\t${Priority}\t${Essential}\n' 2>/dev/null | awk -F'\t' '$2=="required"||$2=="important"||$3=="yes"{print $1}')
  { installed_pkgs | grep -E "$PROTECT_RE"; echo "$prot"; } | sort -u | grep -v '^$' | xargs -r apt-mark manual >/dev/null 2>&1
  installed_pkgs | grep -Ev "$PROTECT_RE" | grep -Fxv -f <(echo "$prot") | xargs -r apt-mark auto >/dev/null 2>&1
  apt-get -s autoremove --purge 2>/dev/null | awk '/^Purg /{print $2}' >"$plan"

  if grep -Eqx 'openssh-server|netplan\.io|sudo|systemd|apt|dpkg|ubuntu-server|ubuntu-minimal' "$plan"; then
    err "rencana nyentuh paket kritikal — ABORT demi keamanan"; restore_marks "$dir/manual.before"; return
  fi
  local cnt; cnt=$(wc -l <"$plan")
  echo; printf "  ${BD}%s paket${N} bakal di-purge. Preview:\n" "$cnt"
  head -60 "$plan" | paste -sd' ' | fold -s -w 92 | sed 's/^/  /'
  ((cnt>60)) && echo "  ${D}... daftar lengkap: $plan${N}"
  ((lvl>=2)) && echo "  + snap app, /opt, /usr/local/*, dotfiles user, /var/lib/docker akan dihapus"
  ((lvl>=3)) && echo "  ${R}+ DATA /home/*, /var/www, /srv akan DIHAPUS${N}"

  local phrase="RESET $(hostname)" a
  echo; read -rp "  ketik ${BD}${phrase}${N} buat lanjut: " a
  [[ $a == "$phrase" ]] || { warn "gak cocok — dibatalin, tanda paket dipulihin"; restore_marks "$dir/manual.before"; return; }
  if ((lvl==3)); then read -rp "  LEVEL 3: ketik ${R}HAPUS DATA${N}: " a; [[ $a == "HAPUS DATA" ]] || { warn "dibatalin"; restore_marks "$dir/manual.before"; return; }; fi

  local i; for i in 10 9 8 7 6 5 4 3 2 1; do printf "\r  ${R}${BD}EKSEKUSI dalam %2ds — Ctrl+C buat batal${N}" "$i"; sleep 1; done; echo
  local b; b=$(used)

  printf "  ${C}[1]${N} purge paket...\n"
  DEBIAN_FRONTEND=noninteractive apt-get -y autoremove --purge 2>&1 | tee -a "$LOG" | tail -n 3 | sed 's/^/      /'
  DEBIAN_FRONTEND=noninteractive apt-get -y autoremove --purge >>"$LOG" 2>&1
  c_rc >>"$LOG" 2>&1
  if ((lvl>=2)); then
    printf "  ${C}[2]${N} snap, /opt, /usr/local, dotfiles, docker...\n"
    wipe_snaps
    rm -rf /opt/* /usr/local/bin/* /usr/local/sbin/* /usr/local/lib/* /usr/local/share/* /var/lib/docker 2>/dev/null
    wipe_dotfiles
  fi
  if ((lvl>=3)); then
    printf "  ${C}[3]${N} hapus data user/web...\n"
    local h; for h in /home/*; do find "$h" -mindepth 1 -maxdepth 1 ! -name '.*' -exec rm -rf -- {} + 2>/dev/null; done
    find /var/www /srv -mindepth 1 -maxdepth 1 -exec rm -rf -- {} + 2>/dev/null
  fi
  printf "  ${C}[F]${N} finishing (cache, log, journal)...\n"
  c_apt >>"$LOG" 2>&1; c_journal >>"$LOG" 2>&1; c_logs >>"$LOG" 2>&1; c_tmp >>"$LOG" 2>&1
  local a2; a2=$(used); log "FACTORY RESET done level=$lvl"
  echo; ok "${BD}SELESAI.${N} bebas ±$(hum $((b>a2 ? b-a2 : 0))). Backup daftar paket: $dir"
  info "reinstall paket lama: xargs -a $dir/manual.before apt-get install -y"
  confirm "Reboot sekarang?" && systemctl reboot
}

# ═══════════════════════════════════════════════════════════════════
#  v1.1 MODULES — helpers
# ═══════════════════════════════════════════════════════════════════
aptg() { DEBIAN_FRONTEND=noninteractive apt-get -y -o DPkg::Lock::Timeout=180 -o Dpkg::Options::=--force-confold "$@"; }
apti() { aptg install "$@"; }

run() { # label cmd...   (spinner + log, tampil ✔/✘)
  local label="$1" pid rc i=0 sp='/-\|'; shift
  ( "$@" >>"$LOG" 2>&1 ) & pid=$!
  tput civis 2>/dev/null
  while kill -0 "$pid" 2>/dev/null; do
    printf "\r ${C}[ %s ]${N} %s" "${sp:$((i++%4)):1}" "$label"; sleep 0.1
  done
  wait "$pid"; rc=$?
  tput cnorm 2>/dev/null; printf '\r\e[K'
  if ((rc==0)); then ok "$label"; else err "$label ${D}(rc=$rc — detail: $LOG)${N}"; fi
  return $rc
}

ask() { read -rp "  $1 ${D}[${2:-}]${N}: " REPLY; REPLY=${REPLY:-${2:-}}; }
RE_NAME='^[A-Za-z0-9_]+$'
RE_DOMAIN='^([A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?\.)+[A-Za-z]{2,}$'
RE_PW='^[A-Za-z0-9@%+=_.,:/-]+$'
RE_IP='^[0-9a-fA-F:./]+$'
RE_DNS='^[0-9a-fA-F:. ]+$'
valid_name()   { [[ $1 =~ $RE_NAME ]]; }
valid_domain() { [[ $1 =~ $RE_DOMAIN ]]; }
svc_active()   { systemctl is-active --quiet "$1" 2>/dev/null; }
genpw()        { tr -dc 'A-Za-z0-9' </dev/urandom | head -c "${1:-20}"; }
pubip()        { curl -s -m 5 https://ifconfig.me 2>/dev/null || curl -s -m 5 https://api.ipify.org 2>/dev/null; }
colorize()     { sed -E "s/(error|fail(ed|ure)?|fatal|crit(ical)?|emerg|denied|refused|corrupt)/${R}\1${N}/Ig; s/(warn(ing)?|timeout|timed out)/${Y}\1${N}/Ig"; }
colorize_fw()  { sed -E "s/ALLOW/${G}ALLOW${N}/; s/DENY/${R}DENY${N}/; s/REJECT/${R}REJECT${N}/; s/LIMIT/${Y}LIMIT${N}/"; }

dom_points_here() { # domain → 0 kalau A record == IP publik server
  local d="$1" pip ips
  pip=$(pubip); [[ -n $pip ]] || return 2
  if need dig; then ips=$(dig +short A "$d" @1.1.1.1 2>/dev/null | grep -E '^[0-9.]+$')
  else ips=$(getent ahostsv4 "$d" 2>/dev/null | awk '{print $1}' | sort -u); fi
  grep -qx "$pip" <<<"$ips"
}

php_ver() {
  dpkg-query -W -f='${db:Status-Abbrev} ${Package}\n' 'php*-fpm' 2>/dev/null | awk '$1 ~ /^ii/{print $2}' |
    sed -E 's/^php([0-9.]+)-fpm$/\1/' | grep -E '^[0-9.]+$' | sort -V | tail -1
}
php_sock() { local v; v=$(php_ver); [[ -S /run/php/php${v}-fpm.sock ]] && echo "/run/php/php${v}-fpm.sock" || ls /run/php/php*-fpm.sock 2>/dev/null | head -1; }

live_tail() { # cmd... (Ctrl+C cuma stop tail)
  trap ':' INT
  ( trap - INT; "$@" 2>&1 | colorize )
  trap 'tput cnorm 2>/dev/null; echo; exit 130' INT
}

# ═══════════════════════════════════════════════════════════════════
#  FIREWALL (UFW)
# ═══════════════════════════════════════════════════════════════════
fw_ensure() { need ufw && return 0; warn "ufw belum terinstall"; confirm "Install ufw sekarang?" || return 1; run "install ufw" apti ufw; need ufw; }
fw_active() { ufw status 2>/dev/null | head -1 | grep -q 'Status: active'; }
ssh_ports() { { sshd -T 2>/dev/null | awk '/^port /{print $2}'; ss -tlnpH 2>/dev/null | awk '/"sshd"/{n=split($4,a,":"); print a[n]}'; } | sort -un; }

fw_allowed_ports() { # semua port yang di-allow (termasuk hasil expand app profile)
  ufw status 2>/dev/null | awk '/ALLOW|LIMIT/' | sed -E 's/ \(v6\)//; s/[[:space:]]{2,}/|/g' | cut -d'|' -f1 | sort -u |
  while IFS= read -r t; do
    [[ -z $t ]] && continue
    [[ $t =~ ^[0-9] ]] || t=$(ufw app info "$t" 2>/dev/null | awk '/^Port/{f=1;next} f&&NF{print}' | tr -d ' ' | paste -sd,)
    t=${t//\/tcp/}; t=${t//\/udp/}
    IFS=, read -ra P <<<"$t"
    for x in "${P[@]}"; do
      if [[ $x =~ ^([0-9]+):([0-9]+)$ ]]; then seq "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"; else echo "$x"; fi
    done
  done | sort -un
}

fw_ssh_guard() { # jangan sampai ke-lock
  local p good=1 ap; mapfile -t ap < <(fw_allowed_ports)
  for p in $(ssh_ports); do
    printf '%s\n' "${ap[@]}" | grep -qx "$p" && continue
    warn "port SSH $p BELUM di-allow"
    if confirm "Allow SSH $p/tcp sekarang (anti lock-out)?"; then ufw limit "$p/tcp" comment 'SSH (charr)' >/dev/null; else good=0; fi
  done
  ((good))
}

fw_dashboard() {
  section "FIREWALL // STATUS"
  if fw_active; then ok "UFW ${G}${BD}AKTIF${N}"; else warn "UFW ${R}${BD}NONAKTIF${N} — semua port terbuka"; fi
  ufw status verbose 2>/dev/null | grep -E '^(Default|Logging)' | sed 's/^/  /'
  echo; ufw status numbered 2>/dev/null | colorize_fw | sed 's/^/  /'
}

APPS=()
fw_apps() {
  section "FIREWALL // APP PROFILE TERSEDIA"
  local -a A; mapfile -t A < <(ufw app list 2>/dev/null | tail -n +2 | sed 's/^ *//' | grep -v '^$')
  ((${#A[@]})) || { warn "belum ada app profile (install nginx/openssh/dll dulu)"; return 1; }
  local i; for i in "${!A[@]}"; do
    printf "  ${G}%2d)${N} %-24s ${D}%s${N}\n" $((i+1)) "${A[$i]}" "$(ufw app info "${A[$i]}" 2>/dev/null | awk '/^Port/{f=1;next} f&&NF{gsub(/ /,"");print;exit}')"
  done
  APPS=("${A[@]}")
}

fw_allowed_view() {
  section "FIREWALL // APP & PORT YANG DIIZINKAN"
  fw_active || warn "UFW nonaktif — sebenarnya semua port terbuka"
  ufw status 2>/dev/null | awk '/ALLOW|LIMIT/' | colorize_fw | sed 's/^/  /'
  echo "  ${D}── diblokir (DENY/REJECT) ──${N}"
  ufw status 2>/dev/null | awk '/DENY|REJECT/' | colorize_fw | sed 's/^/  /'
}

fw_exposure() {
  section "FIREWALL // PETA EKSPOSUR (port listen vs rule)"
  local act=0 proto st rq sq laddr peer proc port addr pname verdict; local -a AP
  fw_active && act=1; mapfile -t AP < <(fw_allowed_ports)
  printf "  ${D}%-5s %-7s %-22s %-16s %s${N}\n" PROTO PORT ADDR PROSES STATUS
  while read -r proto st rq sq laddr peer proc; do
    port=${laddr##*:}; addr=${laddr%:*}
    pname=$(sed -nE 's/.*\(\("([^"]+)".*/\1/p' <<<"$proc")
    if [[ $addr == 127.* || $addr == "[::1]" || $addr == "::1" ]]; then verdict="${G}lokal saja (aman)${N}"
    elif ((!act)); then verdict="${R}TERBUKA — ufw off${N}"
    elif printf '%s\n' "${AP[@]}" | grep -qx "$port"; then verdict="${Y}diizinkan firewall${N}"
    else verdict="${G}diblok default-deny${N}"; fi
    printf "  %-5s %-7s %-22s %-16s %s\n" "$proto" "$port" "$addr" "${pname:--}" "$verdict"
  done < <(ss -tulnpH 2>/dev/null | sort -k5)
  echo "  ${D}(cek berdasar rule UFW; rule berbasis source-IP dianggap 'diizinkan')${N}"
}

fw_rule_wizard() {
  local act t n p proto src cmt target; local -a args=()
  echo "  aksi: ${G}1${N}=allow  ${R}2${N}=deny  ${Y}3${N}=limit (anti brute-force)"
  read -rp "  pilih [1]: " act
  case ${act:-1} in 1) act=allow;; 2) act=deny;; 3) act=limit;; *) err "invalid"; return;; esac
  echo "  target: ${G}1${N}=app profile  ${G}2${N}=port"
  read -rp "  pilih [2]: " t
  if [[ ${t:-2} == 1 ]]; then
    fw_apps || return; read -rp "  nomor app: " n
    [[ $n =~ ^[0-9]+$ ]] && ((n>=1 && n<=${#APPS[@]})) || { err "invalid"; return; }
    target="${APPS[$((n-1))]}"
    read -rp "  dari IP/CIDR (kosong = semua): " src
    [[ -z $src || $src =~ $RE_IP ]] || { err "IP invalid"; return; }
    if [[ -n $src ]]; then args=("$act" from "$src" to any app "$target"); else args=("$act" "$target"); fi
  else
    read -rp "  port (mis. 8080 atau 8000:8010): " p
    [[ $p =~ ^[0-9]+(:[0-9]+)?$ ]] || { err "port invalid"; return; }
    read -rp "  proto tcp/udp/any [tcp]: " proto; proto=${proto:-tcp}
    [[ $proto =~ ^(tcp|udp|any)$ ]] || { err "proto invalid"; return; }
    read -rp "  dari IP/CIDR (kosong = semua): " src
    [[ -z $src || $src =~ $RE_IP ]] || { err "IP invalid"; return; }
    if [[ -n $src ]]; then args=("$act" from "$src" to any port "$p"); [[ $proto != any ]] && args+=(proto "$proto")
    else if [[ $proto == any ]]; then args=("$act" "$p"); else args=("$act" "$p/$proto"); fi; fi
  fi
  read -rp "  komentar (opsional): " cmt
  [[ -n $cmt ]] && args+=(comment "$cmt")
  info "ufw ${args[*]}"; ufw "${args[@]}" && log "ufw ${args[*]}"
}

fw_delete_rule() {
  ufw status numbered | colorize_fw | sed 's/^/  /'
  local n; read -rp "  nomor rule yang dihapus: " n
  [[ $n =~ ^[0-9]+$ ]] || { err "invalid"; return; }
  confirm "Hapus rule #$n?" && ufw --force delete "$n" && log "ufw delete $n"
}

fw_block_ip() {
  local ip; read -rp "  IP/CIDR yang diblok: " ip
  [[ $ip =~ $RE_IP ]] || { err "IP invalid"; return; }
  ufw insert 1 deny from "$ip" >/dev/null 2>&1 || ufw deny from "$ip"
  ok "diblok: $ip"; log "ufw block $ip"
}

fw_blocklog() {
  section "FIREWALL // TOP IP YANG DIBLOK"
  if [[ ! -s /var/log/ufw.log ]]; then warn "belum ada /var/log/ufw.log — aktifkan: ufw logging low"; return; fi
  grep 'UFW BLOCK' /var/log/ufw.log | grep -oE 'SRC=[0-9a-f.:]+' | cut -d= -f2 | sort | uniq -c | sort -rn | head -10 | sed 's/^/  /'
  echo "  ${D}── port tujuan paling sering ──${N}"
  grep 'UFW BLOCK' /var/log/ufw.log | grep -oE 'DPT=[0-9]+' | cut -d= -f2 | sort | uniq -c | sort -rn | head -8 | sed 's/^/  /'
}

fw_presets() {
  echo "  ${G}1${N} SSH (limit)   ${G}2${N} HTTP 80   ${G}3${N} HTTPS 443   ${G}4${N} Web 80+443   ${G}5${N} DNS 53   ${G}6${N} MariaDB 3306 dari 1 IP"
  local c ip p; read -rp "  pilih: " c
  case $c in
    1) for p in $(ssh_ports); do ufw limit "$p/tcp" comment 'SSH (charr)'; done;;
    2) ufw allow 80/tcp comment 'HTTP';;
    3) ufw allow 443/tcp comment 'HTTPS';;
    4) ufw allow 80/tcp comment 'HTTP'; ufw allow 443/tcp comment 'HTTPS';;
    5) ufw allow 53 comment 'DNS';;
    6) read -rp "  IP sumber: " ip; [[ $ip =~ $RE_IP ]] || { err "IP invalid"; return; }
       ufw allow from "$ip" to any port 3306 proto tcp comment 'MariaDB remote';;
  esac
}

fw_wizard() {
  section "FIREWALL // SETUP WIZARD"
  fw_ensure || return
  local sp p; sp=$(ssh_ports | paste -sd' '); sp=${sp:-22}
  info "port SSH terdeteksi: ${BD}$sp${N} (di-allow dulu biar gak ke-lock)"
  confirm "Set baseline: deny incoming, allow outgoing?" || return
  ufw default deny incoming >/dev/null; ufw default allow outgoing >/dev/null
  for p in $sp; do ufw limit "$p/tcp" comment 'SSH (charr)' >/dev/null; done
  ok "baseline + SSH rate-limit"
  confirm "Buka web (80 & 443)?" && { ufw allow 80/tcp comment 'HTTP' >/dev/null; ufw allow 443/tcp comment 'HTTPS' >/dev/null; ok "web dibuka"; }
  confirm "Buka DNS (53) — kalau mau jadi DNS server?" && { ufw allow 53 comment 'DNS' >/dev/null; ok "DNS dibuka"; }
  ufw logging low >/dev/null
  if confirm "Aktifkan firewall SEKARANG?"; then ufw --force enable >/dev/null && ok "UFW aktif"; log "ufw wizard enable"; fi
  fw_dashboard
}

fw_toggle() {
  echo "  ${G}1${N}=enable  ${Y}2${N}=disable  ${R}3${N}=reset (hapus semua rule)  ${G}4${N}=logging"
  local c a; read -rp "  pilih: " c
  case $c in
    1) fw_ssh_guard && { ufw --force enable && ok "UFW aktif"; } || warn "dibatalin — SSH belum aman di-allow";;
    2) confirm "Matiin firewall?" && ufw disable;;
    3) read -rp "  ketik ${R}RESET FW${N}: " a; [[ $a == "RESET FW" ]] && { ufw --force reset; warn "semua rule terhapus & UFW nonaktif — jalankan Wizard"; };;
    4) read -rp "  level [off/low/medium/high]: " a; ufw logging "$a";;
  esac
}

fw_menu() {
  fw_ensure || return
  while true; do
    fw_dashboard
    section "FIREWALL MANAGER"
    cat <<EOF
  ${G}[1]${N} Setup Wizard (baseline aman)      ${G}[7]${N} Block IP
  ${G}[2]${N} Lihat app profile (ufw app list)  ${G}[8]${N} Peta eksposur (listen vs rule)
  ${G}[3]${N} Lihat app/port yang diizinkan     ${G}[9]${N} Log blokir (top IP)
  ${G}[4]${N} Tambah rule (allow/deny/limit)    ${G}[10]${N} Enable / Disable / Reset
  ${G}[5]${N} Quick presets                     ${G}[0]${N} Balik
  ${G}[6]${N} Hapus rule
EOF
    local c; read -rp "  ${C}»${N} " c
    case $c in
      1) fw_wizard; pause;;
      2) fw_apps; pause;;
      3) fw_allowed_view; pause;;
      4) fw_rule_wizard; pause;;
      5) fw_presets; pause;;
      6) fw_delete_rule; pause;;
      7) fw_block_ip; pause;;
      8) fw_exposure; pause;;
      9) fw_blocklog; pause;;
      10) fw_toggle; pause;;
      0) return;;
    esac
  done
}

# ═══════════════════════════════════════════════════════════════════
#  SECURITY CENTER: fail2ban, ssh hardening, auto-update
# ═══════════════════════════════════════════════════════════════════
f2b_setup() {
  section "FAIL2BAN"
  need fail2ban-client || { confirm "Install fail2ban?" && run "install fail2ban" apti fail2ban || return; }
  local mr bt ft sp
  ask "maxretry (gagal login sebelum ban)" 5; mr=$REPLY
  ask "bantime (mis. 1h, 1d)" 1h; bt=$REPLY
  ask "findtime (jendela hitung)" 10m; ft=$REPLY
  [[ $mr =~ ^[0-9]+$ && $bt =~ ^[0-9]+[smhdw]?$ && $ft =~ ^[0-9]+[smhdw]?$ ]] || { err "input invalid"; return; }
  sp=$(ssh_ports | paste -sd,); sp=${sp:-ssh}
  cat >/etc/fail2ban/jail.d/charr.local <<EOF
[DEFAULT]
bantime  = $bt
findtime = $ft
maxretry = $mr
backend  = systemd

[sshd]
enabled = true
port    = $sp
EOF
  systemctl enable --now fail2ban >/dev/null 2>&1; systemctl restart fail2ban
  sleep 1; fail2ban-client status sshd 2>/dev/null | sed 's/^/  /' || warn "jail sshd belum aktif — cek: journalctl -u fail2ban"
  log "fail2ban setup mr=$mr bt=$bt ft=$ft"
}

f2b_menu() {
  while true; do
    section "FAIL2BAN MANAGER"
    echo "  ${G}[1]${N} Setup/ubah jail SSH   ${G}[2]${N} Status & IP diban   ${G}[3]${N} Unban IP   ${G}[4]${N} Ban IP   ${G}[0]${N} Balik"
    local c ip; read -rp "  ${C}»${N} " c
    case $c in
      1) f2b_setup; pause;;
      2) need fail2ban-client && fail2ban-client status sshd | sed 's/^/  /' || warn "fail2ban belum ada"; pause;;
      3) read -rp "  IP: " ip; [[ $ip =~ $RE_IP ]] && fail2ban-client set sshd unbanip "$ip"; pause;;
      4) read -rp "  IP: " ip; [[ $ip =~ $RE_IP ]] && fail2ban-client set sshd banip "$ip"; pause;;
      0) return;;
    esac
  done
}

ssh_harden() {
  section "SSH HARDENING WIZARD"
  need sshd || { err "openssh-server gak ada"; return; }
  local keys nr f=/etc/ssh/sshd_config.d/00-charr.conf; local -a L=()
  keys=$(find /root/.ssh /home/*/.ssh -name authorized_keys -size +0 2>/dev/null | head -3)
  nr=$(find /home/*/.ssh -name authorized_keys -size +0 2>/dev/null | wc -l)
  [[ -n $keys ]] && ok "authorized_keys ditemukan" || warn "GAK ada authorized_keys — password auth tidak akan dimatiin (anti lock-out)"
  warn "sebelum lanjut: pastikan bisa login pakai KEY dari terminal lain"
  confirm "Lanjut?" || return
  if ((nr>0)); then confirm "Larang root login (PermitRootLogin no)?" && L+=("PermitRootLogin no")
  else confirm "Root hanya boleh pakai key (prohibit-password)?" && L+=("PermitRootLogin prohibit-password"); fi
  [[ -n $keys ]] && confirm "Matiin login pakai password (key-only)?" && L+=("PasswordAuthentication no" "KbdInteractiveAuthentication no")
  confirm "Batasi MaxAuthTries 3 + LoginGraceTime 30 + X11 off?" && L+=("MaxAuthTries 3" "LoginGraceTime 30" "X11Forwarding no")
  ((${#L[@]})) || { info "gak ada perubahan"; return; }
  mkdir -p /etc/ssh/sshd_config.d; [[ -f $f ]] && cp "$f" "$f.bak"
  printf '# dibuat CHARR//TOOLKIT %s\n' "$(date '+%F %T')" >"$f"; printf '%s\n' "${L[@]}" >>"$f"
  if sshd -t 2>/tmp/charr-sshd.err; then
    systemctl reload ssh 2>/dev/null || systemctl reload sshd 2>/dev/null
    ok "config valid & di-reload"; sshd -T | grep -Ei '^(permitrootlogin|passwordauthentication|maxauthtries) ' | sed 's/^/  /'
    warn "JANGAN tutup sesi ini — tes login baru dulu di terminal lain"; log "ssh harden: ${L[*]}"
  else
    err "config invalid — rollback"; cat /tmp/charr-sshd.err | sed 's/^/  /'
    [[ -f $f.bak ]] && mv "$f.bak" "$f" || rm -f "$f"
  fi
}

auto_updates() {
  need unattended-upgrade || run "install unattended-upgrades" apti unattended-upgrades || return
  cat >/etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
  ok "security auto-update aktif"; log "auto updates on"
}

security_menu() {
  while true; do
    section "SECURITY CENTER"
    cat <<EOF
  ${G}[1]${N} Security Audit (scan)          ${G}[4]${N} SSH Hardening Wizard
  ${G}[2]${N} ${BD}Firewall Manager (UFW)${N}         ${G}[5]${N} Auto security updates
  ${G}[3]${N} Fail2ban (anti brute-force)    ${G}[0]${N} Balik
EOF
    local c; read -rp "  ${C}»${N} " c
    case $c in
      1) audit; pause;;
      2) fw_menu;;
      3) f2b_menu;;
      4) ssh_harden; pause;;
      5) auto_updates; pause;;
      0) return;;
    esac
  done
}

# ═══════════════════════════════════════════════════════════════════
#  DNS
# ═══════════════════════════════════════════════════════════════════
dns_resolver() {
  section "DNS // SET RESOLVER SERVER"
  svc_active systemd-resolved || { err "systemd-resolved gak aktif — resolver diatur via netplan/resolv.conf"; return; }
  echo "  ${G}1${N} Cloudflare (1.1.1.1)  ${G}2${N} Google (8.8.8.8)  ${G}3${N} Quad9 (9.9.9.9)  ${G}4${N} Custom"
  local c dns fb dot; read -rp "  pilih [1]: " c
  case ${c:-1} in
    1) dns="1.1.1.1 1.0.0.1"; fb="8.8.8.8 9.9.9.9";;
    2) dns="8.8.8.8 8.8.4.4"; fb="1.1.1.1 9.9.9.9";;
    3) dns="9.9.9.9 149.112.112.112"; fb="1.1.1.1 8.8.8.8";;
    4) read -rp "  DNS (pisah spasi): " dns; [[ $dns =~ $RE_DNS ]] || { err "invalid"; return; }; fb="1.1.1.1";;
    *) return;;
  esac
  confirm "Aktifkan DNS-over-TLS (opportunistic)?" && dot=opportunistic || dot=no
  mkdir -p /etc/systemd/resolved.conf.d
  cat >/etc/systemd/resolved.conf.d/charr.conf <<EOF
[Resolve]
DNS=$dns
FallbackDNS=$fb
DNSOverTLS=$dot
DNSSEC=allow-downgrade
Cache=yes
EOF
  systemctl restart systemd-resolved; resolvectl flush-caches 2>/dev/null
  sleep 1; getent hosts cloudflare.com >/dev/null && ok "resolve OK" || err "resolve gagal — cek netplan (DNS per-link bisa override)"
  resolvectl status 2>/dev/null | grep -E 'Current DNS|DNS Servers|Link' | head -8 | sed 's/^/  /'
  log "dns resolver $dns dot=$dot"
}

dns_check_domain() {
  section "DNS // DOMAIN CHECKER"
  need dig || { confirm "Install dnsutils (dig)?" && run "install dnsutils" apti dnsutils || return; }
  local d r pip; read -rp "  domain: " d; valid_domain "$d" || { err "domain invalid"; return; }
  pip=$(pubip); info "IP publik server: ${BD}${pip:-?}${N}"
  local t; for t in A AAAA NS MX TXT CNAME; do
    printf "  ${C}%-6s${N} %s\n" "$t" "$(dig +short "$t" "$d" @1.1.1.1 2>/dev/null | paste -sd' ' | cut -c1-110)"
  done
  echo "  ${D}── propagasi A record per resolver ──${N}"
  for r in 1.1.1.1 8.8.8.8 9.9.9.9 208.67.222.222; do
    printf "  %-16s %s\n" "$r" "$(dig +short A "$d" @"$r" +time=3 +tries=1 2>/dev/null | paste -sd' ')"
  done
  if dom_points_here "$d"; then ok "$d → ${BD}nunjuk ke server ini${N}"; else warn "$d belum nunjuk ke $pip (SSL Let's Encrypt bakal gagal)"; fi
}

dns_bench() {
  section "DNS // BENCHMARK LATENCY"
  need dig || { warn "butuh dig (menu Check Domain → install dnsutils)"; return; }
  local r q ms; printf "  ${D}%-16s %s${N}\n" RESOLVER "google.com | cloudflare.com | wikipedia.org"
  for r in 1.1.1.1 8.8.8.8 9.9.9.9 208.67.222.222; do
    printf "  %-16s" "$r"
    for q in google.com cloudflare.com wikipedia.org; do
      ms=$(dig @"$r" "$q" +time=3 +tries=1 2>/dev/null | awk '/Query time/{print $4}'); printf " %5sms" "${ms:-—}"
    done; echo
  done
}

dns_bind_setup() {
  section "DNS // BIND9 AUTHORITATIVE + ZONE"
  need named || run "install bind9" apti bind9 bind9-utils dnsutils || return
  local dom ip f z=/etc/bind/zones
  read -rp "  domain (example.com): " dom; valid_domain "$dom" || { err "domain invalid"; return; }
  ask "IP server (A record)" "$(prim_ip)"; ip=$REPLY; [[ $ip =~ ^[0-9.]+$ ]] || { err "IP invalid"; return; }
  mkdir -p "$z"; f="$z/db.$dom"
  [[ -f $f ]] && { confirm "zone $dom sudah ada, timpa?" || return; }
  cat >"$f" <<EOF
\$TTL 3600
@   IN SOA ns1.$dom. admin.$dom. ( $(date +%s) 3600 900 1209600 300 )
@       IN NS   ns1.$dom.
ns1     IN A    $ip
@       IN A    $ip
www     IN CNAME $dom.
EOF
  named-checkzone "$dom" "$f" >/dev/null || { err "zone error"; named-checkzone "$dom" "$f"; return; }
  grep -q "zone \"$dom\"" /etc/bind/named.conf.local 2>/dev/null ||
    printf 'zone "%s" { type master; file "%s"; };\n' "$dom" "$f" >>/etc/bind/named.conf.local
  named-checkconf || { err "named.conf error"; return; }
  systemctl enable named >/dev/null 2>&1; systemctl restart named 2>/dev/null || systemctl restart bind9
  fw_active && ufw allow 53 comment 'DNS' >/dev/null && ok "ufw: port 53 dibuka"
  sleep 1; local a; a=$(dig +short @127.0.0.1 "$dom" A 2>/dev/null)
  [[ -n $a ]] && ok "zone $dom aktif → $a" || err "zone belum menjawab — cek: journalctl -u named"
  info "di registrar: set nameserver ke ns1.$dom (glue record → $ip)"; log "bind zone $dom"
}

dns_add_record() {
  section "DNS // TAMBAH RECORD"
  local -a Z; mapfile -t Z < <(ls /etc/bind/zones/db.* 2>/dev/null)
  ((${#Z[@]})) || { warn "belum ada zone — buat dulu (BIND9 setup)"; return; }
  local i n f type name val pri; for i in "${!Z[@]}"; do printf "  ${G}%d)${N} %s\n" $((i+1)) "${Z[$i]##*/db.}"; done
  read -rp "  pilih zone: " n; [[ $n =~ ^[0-9]+$ ]] && ((n>=1 && n<=${#Z[@]})) || return
  f=${Z[$((n-1))]}; local dom=${f##*/db.}
  read -rp "  tipe (A/AAAA/CNAME/MX/TXT): " type; type=${type^^}
  read -rp "  nama (mis. www, api, @): " name; [[ $name =~ ^[A-Za-z0-9@._*-]+$ ]] || { err "nama invalid"; return; }
  read -rp "  value: " val; [[ -n $val && $val != *\"* ]] || { err "value invalid"; return; }
  cp "$f" "$f.bak"
  case $type in
    A|AAAA) printf '%-8s IN %-5s %s\n' "$name" "$type" "$val" >>"$f";;
    CNAME)  [[ $val == *. ]] || val="$val."; printf '%-8s IN CNAME %s\n' "$name" "$val" >>"$f";;
    MX)     read -rp "  prioritas [10]: " pri; pri=${pri:-10}; [[ $val == *. ]] || val="$val."; printf '%-8s IN MX %s %s\n' "$name" "$pri" "$val" >>"$f";;
    TXT)    printf '%-8s IN TXT "%s"\n' "$name" "$val" >>"$f";;
    *) err "tipe gak didukung"; return;;
  esac
  sed -i -E "0,/\( *[0-9]+/ s//( $(date +%s)/" "$f"
  if named-checkzone "$dom" "$f" >/dev/null; then rndc reload >/dev/null 2>&1 || systemctl reload named; ok "record ditambah & zone di-reload"; log "dns add $type $name $val ($dom)"
  else err "zone invalid — rollback"; mv "$f.bak" "$f"; fi
}

dns_menu() {
  while true; do
    section "DNS CENTER"
    cat <<EOF
  ${G}[1]${N} Set resolver server (Cloudflare/Google/Quad9 + DoT)
  ${G}[2]${N} Domain checker (record + propagasi + nunjuk ke server ini?)
  ${G}[3]${N} Benchmark latency resolver
  ${G}[4]${N} BIND9 — jadi DNS server + buat zone domain
  ${G}[5]${N} Tambah record ke zone BIND9
  ${G}[6]${N} Flush cache & status resolver     ${G}[0]${N} Balik
EOF
    local c; read -rp "  ${C}»${N} " c
    case $c in
      1) dns_resolver; pause;;
      2) dns_check_domain; pause;;
      3) dns_bench; pause;;
      4) dns_bind_setup; pause;;
      5) dns_add_record; pause;;
      6) resolvectl flush-caches 2>/dev/null && ok "cache di-flush"; resolvectl statistics 2>/dev/null | head -12 | sed 's/^/  /'; pause;;
      0) return;;
    esac
  done
}

# ═══════════════════════════════════════════════════════════════════
#  WEB SERVER / NGINX / SSL / LEMP
# ═══════════════════════════════════════════════════════════════════
NGX_HEAD='server {
    listen 80;
    listen [::]:80;
    server_name @SN@;
    access_log /var/log/nginx/@DOM@.access.log;
    error_log  /var/log/nginx/@DOM@.error.log;
'
NGX_STATIC='    root @ROOT@;
    index index.html index.htm;
    location / { try_files $uri $uri/ =404; }
    location ~ /\.(?!well-known) { deny all; }
}'
NGX_PHP='    root @ROOT@;
    index index.php index.html;
    location / { try_files $uri $uri/ /index.php?$query_string; }
    location ~ \.php$ { include snippets/fastcgi-php.conf; fastcgi_pass unix:@SOCK@; }
    location ~ /\.(?!well-known) { deny all; }
}'
NGX_PROXY='    location / {
        proxy_pass http://127.0.0.1:@PORT@;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}'

nginx_install() { need nginx && return 0; run "install nginx" apti nginx || return 1; systemctl enable --now nginx >/dev/null 2>&1; }

nginx_reload_safe() {
  local t; t=$(nginx -t 2>&1) && { systemctl reload nginx && ok "nginx di-reload"; return 0; }
  err "nginx -t GAGAL:"; echo "$t" | sed 's/^/    /'; return 1
}

web_probe() { # url
  curl -sS -o /dev/null -m 10 -L -w "  HTTP %{http_code} • dns %{time_namelookup}s • connect %{time_connect}s • tls %{time_appconnect}s • ttfb %{time_starttransfer}s • total %{time_total}s • ip %{remote_ip}\n" "$1" 2>&1 | sed 's/^curl: /  /'
}

site_create() {
  section "WEB // BUAT SITE NGINX"
  nginx_install || return
  local dom kind root port sock conf tpl sn
  read -rp "  domain (mis. app.example.com): " dom; valid_domain "$dom" || { err "domain invalid"; return; }
  echo "  tipe: ${G}1${N}=static  ${G}2${N}=PHP (FPM)  ${G}3${N}=reverse proxy (Node/Python/dll)"
  read -rp "  pilih [1]: " kind; kind=${kind:-1}
  conf=/etc/nginx/sites-available/$dom
  [[ -e $conf ]] && { confirm "config $dom sudah ada, timpa?" || return; }
  sn="$dom"; [[ ${dom//[^.]/} == . ]] && sn="$dom www.$dom"
  root=/var/www/$dom
  case $kind in
    1|2) mkdir -p "$root"
         if ! compgen -G "$root/index.*" >/dev/null; then
           if [[ $kind == 1 ]]; then printf '<!doctype html><title>%s</title><h1 style="font-family:monospace">%s — online ✔</h1><p>CHARR//TOOLKIT</p>\n' "$dom" "$dom" >"$root/index.html"
           else printf '<?php echo "<h1 style=\\"font-family:monospace\\">%s — PHP ".PHP_VERSION." ✔</h1>";\n' "$dom" >"$root/index.php"; fi
         fi
         chown -R www-data:www-data "$root"
         if [[ $kind == 2 ]]; then
           sock=$(php_sock); [[ -n $sock ]] || { err "php-fpm belum ada — jalankan LEMP Stack dulu"; return; }
           tpl="$NGX_HEAD$NGX_PHP"
         else tpl="$NGX_HEAD$NGX_STATIC"; fi;;
    3) ask "port aplikasi lokal" 3000; port=$REPLY; [[ $port =~ ^[0-9]+$ ]] || { err "port invalid"; return; }
       tpl="$NGX_HEAD$NGX_PROXY";;
    *) return;;
  esac
  tpl=${tpl//@SN@/$sn}; tpl=${tpl//@DOM@/$dom}; tpl=${tpl//@ROOT@/$root}; tpl=${tpl//@SOCK@/$sock}; tpl=${tpl//@PORT@/$port}
  printf '%s\n' "$tpl" >"$conf"; ln -sf "$conf" "/etc/nginx/sites-enabled/$dom"
  if nginx_reload_safe; then
    ok "site ${BD}$dom${N} aktif"; log "nginx site $dom kind=$kind"
    if fw_active && ! fw_allowed_ports | grep -qx 80; then warn "port 80 diblok UFW"; confirm "Allow 80 & 443?" && { ufw allow 80/tcp >/dev/null; ufw allow 443/tcp >/dev/null; ok "80/443 dibuka"; }; fi
    web_probe "http://127.0.0.1" >/dev/null 2>&1; curl -sS -o /dev/null -m 5 -H "Host: $dom" -w "  tes lokal → HTTP %{http_code}\n" http://127.0.0.1
    if dom_points_here "$dom"; then ok "DNS $dom sudah nunjuk ke server ini"; confirm "Pasang SSL Let's Encrypt sekarang?" && ssl_issue "$dom"
    else warn "DNS $dom belum nunjuk ke server ini — arahkan A record dulu, lalu pasang SSL (menu SSL)"; fi
  else rm -f "/etc/nginx/sites-enabled/$dom"; err "site dinonaktifkan karena config error"; fi
}

ssl_issue() { # domain
  need certbot || run "install certbot" apti certbot python3-certbot-nginx || return
  local d="$1" em args=(-d "$d")
  [[ -z $d ]] && { read -rp "  domain: " d; valid_domain "$d" || { err "invalid"; return; }; args=(-d "$d"); }
  [[ ${d//[^.]/} == . ]] && confirm "Sertakan www.$d juga?" && args+=(-d "www.$d")
  read -rp "  email (buat notif expiry): " em; [[ $em =~ ^[^@[:space:]]+@[^@[:space:]]+$ ]] || { err "email invalid"; return; }
  dom_points_here "$d" || warn "DNS belum nunjuk ke sini — kemungkinan gagal"
  certbot --nginx "${args[@]}" --non-interactive --agree-tos -m "$em" --redirect 2>&1 | tail -15 | sed 's/^/  /'
  log "certbot $d"
}

ssl_menu() {
  while true; do
    section "SSL / HTTPS (Let's Encrypt)"
    echo "  ${G}[1]${N} Pasang SSL ke domain  ${G}[2]${N} Daftar sertifikat & sisa hari  ${G}[3]${N} Tes renew  ${G}[4]${N} Cek SSL domain (remote)  ${G}[0]${N} Balik"
    local c d; read -rp "  ${C}»${N} " c
    case $c in
      1) ssl_issue ""; pause;;
      2) for f in /etc/letsencrypt/live/*/cert.pem; do [[ -f $f ]] || continue
           local e days; e=$(openssl x509 -enddate -noout -in "$f" | cut -d= -f2); days=$(( ($(date -d "$e" +%s) - $(date +%s)) / 86400 ))
           printf "  %-32s %s hari lagi (%s)\n" "$(basename "$(dirname "$f")")" "$days" "$e"; done
         systemctl list-timers 2>/dev/null | grep -i certbot | sed 's/^/  /'; pause;;
      3) need certbot && certbot renew --dry-run 2>&1 | tail -8 | sed 's/^/  /'; pause;;
      4) read -rp "  domain: " d; valid_domain "$d" && { echo | openssl s_client -servername "$d" -connect "$d:443" 2>/dev/null | openssl x509 -noout -subject -issuer -dates | sed 's/^/  /'; web_probe "https://$d"; }; pause;;
      0) return;;
    esac
  done
}

site_manager() {
  while true; do
    section "WEB // SITE MANAGER"
    local -a S; mapfile -t S < <(ls /etc/nginx/sites-available 2>/dev/null); local i s st
    for i in "${!S[@]}"; do s=${S[$i]}; [[ -L /etc/nginx/sites-enabled/$s ]] && st="${G}ON ${N}" || st="${D}off${N}"
      printf "  ${G}%2d)${N} [%s] %s\n" $((i+1)) "$st" "$s"; done
    echo "  ${D}──${N} ${G}[e]${N}nable ${G}[d]${N}isable ${R}[r]${N}emove ${G}[t]${N}est URL ${G}[l]${N}og error live ${G}[0]${N} balik"
    local c n; read -rp "  ${C}»${N} " c
    case $c in
      e|d|r) read -rp "  nomor site: " n; [[ $n =~ ^[0-9]+$ ]] && ((n>=1 && n<=${#S[@]})) || continue; s=${S[$((n-1))]}
         case $c in
           e) ln -sf "/etc/nginx/sites-available/$s" "/etc/nginx/sites-enabled/$s"; nginx_reload_safe;;
           d) rm -f "/etc/nginx/sites-enabled/$s"; nginx_reload_safe;;
           r) read -rp "  ketik ${R}$s${N} buat hapus config: " n; [[ $n == "$s" ]] && { rm -f "/etc/nginx/sites-enabled/$s" "/etc/nginx/sites-available/$s"; nginx_reload_safe; info "webroot /var/www/$s TIDAK dihapus"; log "nginx remove $s"; };;
         esac; pause;;
      t) read -rp "  URL (mis. https://domain): " n; [[ $n =~ ^https?:// ]] && web_probe "$n"; pause;;
      l) read -rp "  nomor site: " n; [[ $n =~ ^[0-9]+$ ]] && ((n>=1 && n<=${#S[@]})) && live_tail tail -n 30 -F "/var/log/nginx/${S[$((n-1))]}.error.log" "/var/log/nginx/error.log";;
      0) return;;
    esac
  done
}

php_tune() {
  section "PHP TUNER"
  local v; v=$(php_ver); [[ -n $v ]] || { err "php-fpm belum terinstall"; return; }
  local up mem met tz; RE_SZ='^[0-9]+[KMG]$'
  ask "upload_max_filesize (& post_max_size)" 64M; up=$REPLY
  ask "memory_limit" 256M; mem=$REPLY
  ask "max_execution_time (detik)" 60; met=$REPLY
  ask "timezone PHP" "$(timedatectl show -p Timezone --value 2>/dev/null || echo UTC)"; tz=$REPLY
  [[ $up =~ $RE_SZ && $mem =~ $RE_SZ && $met =~ ^[0-9]+$ && $tz =~ ^[A-Za-z_/+-]+$ ]] || { err "input invalid"; return; }
  cat >"/etc/php/$v/fpm/conf.d/99-charr.ini" <<EOF
upload_max_filesize = $up
post_max_size = $up
memory_limit = $mem
max_execution_time = $met
date.timezone = $tz
expose_php = Off
EOF
  printf 'client_max_body_size %s;\n' "$up" >/etc/nginx/conf.d/charr-upload.conf
  "php-fpm$v" -t 2>&1 | tail -1 | sed 's/^/  /'
  systemctl reload "php${v}-fpm" && nginx_reload_safe; log "php tune $up $mem $met $tz"
}

lemp_verify() {
  section "LEMP // VERIFIKASI END-TO-END"
  local v t r f; v=$(php_ver)
  need nginx && svc_active nginx && ok "nginx aktif ($(nginx -v 2>&1 | cut -d/ -f2))" || err "nginx mati/belum ada"
  [[ -n $v ]] && svc_active "php${v}-fpm" && ok "php${v}-fpm aktif" || err "php-fpm mati/belum ada"
  [[ -n $v && -S /run/php/php${v}-fpm.sock ]] && ok "socket php-fpm ada" || err "socket php-fpm hilang"
  { svc_active mariadb || svc_active mysql; } && ok "MariaDB aktif" || err "MariaDB mati/belum ada"
  nginx -t >/dev/null 2>&1 && ok "nginx -t valid" || err "nginx -t error"
  if need nginx && [[ -n $v ]]; then
    f="charr-test-$RANDOM.php"; mkdir -p /var/www/html
    cat >"/var/www/html/$f" <<'EOF'
<?php
$o = ['php' => PHP_VERSION, 'mysqli' => extension_loaded('mysqli') ? 'ok' : 'MISSING'];
echo json_encode($o);
EOF
    chown www-data:www-data "/var/www/html/$f"
    r=$(curl -s -m 5 "http://127.0.0.1/$f"); rm -f "/var/www/html/$f"
    [[ $r == *'"mysqli":"ok"'* ]] && ok "nginx → PHP-FPM → mysqli OK  ${D}$r${N}" || err "eksekusi PHP via nginx GAGAL (resp: ${r:-kosong}) — jalankan Smart Doctor"
  fi
}

lemp_install() {
  section "LEMP STACK // Nginx + PHP-FPM + MariaDB"
  info "paket: nginx, mariadb-server, php-fpm + ext (mysql cli curl gd mbstring xml zip intl bcmath)"
  confirm "Install sekarang?" || return
  run "apt update" apt-get update
  run "install nginx" apti nginx || return
  run "install mariadb-server" apti mariadb-server || return
  run "install php-fpm + extension" apti php-fpm php-mysql php-cli php-curl php-gd php-mbstring php-xml php-zip php-intl php-bcmath || return
  local v; v=$(php_ver)
  run "enable & start service" systemctl enable --now nginx mariadb "php${v}-fpm"
  db_cli
  run "amankan MariaDB (hapus anonymous user & test db)" bash -c "$DBBIN -e \"DROP USER IF EXISTS ''@'localhost'; DROP USER IF EXISTS ''@'$(hostname)'; DROP DATABASE IF EXISTS test; FLUSH PRIVILEGES;\""
  local sock tpl; sock=$(php_sock)
  tpl='server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    root /var/www/html;
    index index.php index.html index.htm;
    location / { try_files $uri $uri/ =404; }
    location ~ \.php$ { include snippets/fastcgi-php.conf; fastcgi_pass unix:@SOCK@; }
    location ~ /\.ht { deny all; }
}'
  printf '%s\n' "${tpl//@SOCK@/$sock}" >/etc/nginx/sites-available/charr-default
  rm -f /etc/nginx/sites-enabled/default; ln -sf /etc/nginx/sites-available/charr-default /etc/nginx/sites-enabled/charr-default
  nginx_reload_safe
  if fw_active; then confirm "UFW aktif — buka 80/443?" && { ufw allow 80/tcp >/dev/null; ufw allow 443/tcp >/dev/null; ok "80/443 dibuka"; }; fi
  lemp_verify; log "lemp installed php=$v"
  echo; info "lanjut: Buat site (menu Web) • Buat database+user (menu Database) • SSL (menu SSL)"
}

setup_menu() {
  while true; do
    section "VPS SETUP CENTER"
    cat <<EOF
  ${G}[1]${N} ${BD}VPS Baseline Wizard${N} (update, user, swap, firewall, hardening)
  ${G}[2]${N} DNS Center (resolver, domain checker, BIND9)
  ${G}[3]${N} ${BD}LEMP Stack${N} — install Nginx + PHP + MariaDB (1 klik)
  ${G}[4]${N} Buat site Nginx (static / PHP / reverse proxy)
  ${G}[5]${N} Site Manager (on/off/hapus/tes/log)
  ${G}[6]${N} SSL / HTTPS (Let's Encrypt)
  ${G}[7]${N} PHP Tuner (upload, memory, timezone)
  ${G}[8]${N} Verifikasi stack (end-to-end test)   ${G}[0]${N} Balik
EOF
    local c; read -rp "  ${C}»${N} " c
    case $c in
      1) vps_baseline; pause;;
      2) dns_menu;;
      3) lemp_install; pause;;
      4) site_create; pause;;
      5) site_manager;;
      6) ssl_menu;;
      7) php_tune; pause;;
      8) lemp_verify; pause;;
      0) return;;
    esac
  done
}

# ═══════════════════════════════════════════════════════════════════
#  VPS BASELINE WIZARD
# ═══════════════════════════════════════════════════════════════════
vps_baseline() {
  section "VPS BASELINE WIZARD"
  info "tiap langkah bisa di-skip. Urutan: update → identitas → user → swap → tools → firewall → hardening"
  local tz hn u pw sz
  if confirm "1/9 Update & upgrade sistem?"; then run "apt update" apt-get update; run "full-upgrade" aptg full-upgrade; fi
  ask "2/9 Timezone" "Asia/Jakarta"; tz=$REPLY
  if timedatectl list-timezones 2>/dev/null | grep -qx "$tz"; then timedatectl set-timezone "$tz" && timedatectl set-ntp true 2>/dev/null; ok "timezone $tz + NTP"; else warn "timezone gak valid, dilewati"; fi
  ask "3/9 Hostname" "$(hostname)"; hn=$REPLY
  if [[ $hn =~ ^[a-z0-9-]+$ && $hn != "$(hostname)" ]]; then
    hostnamectl set-hostname "$hn"
    grep -q '^127\.0\.1\.1' /etc/hosts && sed -i "s/^127\.0\.1\.1.*/127.0.1.1 $hn/" /etc/hosts || echo "127.0.1.1 $hn" >>/etc/hosts; ok "hostname → $hn"
  fi
  read -rp "  4/9 Buat user sudo baru (kosong = skip): " u
  if [[ -n $u ]]; then
    if [[ $u =~ ^[a-z_][a-z0-9_-]*$ ]] && ! id "$u" >/dev/null 2>&1; then
      adduser --disabled-password --gecos "" "$u" >/dev/null && usermod -aG sudo "$u"
      pw=$(genpw 16); echo "$u:$pw" | chpasswd
      if [[ -s /root/.ssh/authorized_keys ]]; then install -d -m 700 -o "$u" -g "$u" "/home/$u/.ssh"; install -m 600 -o "$u" -g "$u" /root/.ssh/authorized_keys "/home/$u/.ssh/authorized_keys"; ok "SSH key root disalin ke $u"; fi
      ok "user ${BD}$u${N} dibuat (sudo)"; printf "  ${Y}password sementara (catat, gak disimpan):${N} ${BD}%s${N}\n" "$pw"; log "user created $u"
    else warn "username invalid / sudah ada"; fi
  fi
  if [[ -z $(swapon --show --noheadings 2>/dev/null) ]]; then
    if confirm "5/9 Belum ada swap. Bikin swapfile?"; then
      ask "ukuran swap" 2G; sz=$REPLY
      if [[ $sz =~ ^[0-9]+[MG]$ && ! -e /swapfile ]]; then
        fallocate -l "$sz" /swapfile && chmod 600 /swapfile && mkswap /swapfile >/dev/null && swapon /swapfile &&
          { grep -q '^/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >>/etc/fstab; echo 'vm.swappiness=10' >/etc/sysctl.d/99-charr.conf; sysctl -q -p /etc/sysctl.d/99-charr.conf; ok "swap $sz aktif"; } || err "gagal bikin swap"
      else warn "ukuran invalid / /swapfile sudah ada"; fi
    fi
  else ok "5/9 swap sudah ada"; fi
  confirm "6/9 Install tools dasar (curl git htop ncdu tmux unzip jq dnsutils mtr)?" && run "install tools" apti curl wget git htop ncdu tmux unzip zip jq dnsutils mtr-tiny net-tools
  confirm "7/9 Auto security updates?" && auto_updates
  confirm "8/9 Setup firewall (wizard)?" && fw_wizard
  if confirm "9/9 Fail2ban + SSH hardening?"; then f2b_setup; ssh_harden; fi
  echo; ok "${BD}Baseline selesai.${N}"; [[ -f /var/run/reboot-required ]] && warn "reboot disarankan (kernel/lib update)"
}

# ═══════════════════════════════════════════════════════════════════
#  DATABASE MANAGER (MariaDB / MySQL)
# ═══════════════════════════════════════════════════════════════════
DBBIN=""; DBDIR=/var/backups/charr-db
db_cli()  { if need mariadb; then DBBIN=mariadb; elif need mysql; then DBBIN=mysql; else return 1; fi; }
dbq()     { "$DBBIN" -NBe "$1"; }
dbt()     { "$DBBIN" -e "$1"; }
dbv()     { dbq "SHOW GLOBAL STATUS LIKE '$1'" 2>/dev/null | awk '{print $2}'; }
dbvar()   { dbq "SHOW VARIABLES LIKE '$1'" 2>/dev/null | awk '{print $2}'; }
db_dump() { command -v mariadb-dump || command -v mysqldump; }

db_ready() {
  if ! db_cli; then warn "MariaDB/MySQL belum terinstall"; confirm "Install MariaDB?" && run "install mariadb" apti mariadb-server && db_cli || return 1; fi
  svc_active mariadb || svc_active mysql || { err "service database mati"; confirm "Start sekarang?" && { systemctl start mariadb 2>/dev/null || systemctl start mysql; sleep 2; }; }
  dbq "SELECT 1" >/dev/null 2>&1 || { err "gak bisa konek sebagai root (unix_socket). Cek manual: sudo $DBBIN"; return 1; }
}

db_status() {
  db_ready || return; section "DB // STATUS"
  local up; up=$(dbv Uptime); up=${up:-0}
  printf "  %-22s %s\n" "Versi" "$(dbq 'SELECT VERSION()')"
  printf "  %-22s %sh %sm\n" "Uptime" $((up/3600)) $((up%3600/60))
  printf "  %-22s %s / %s\n" "Koneksi aktif / max" "$(dbv Threads_connected)" "$(dbvar max_connections)"
  printf "  %-22s %s\n" "Query total" "$(dbv Questions)"
  printf "  %-22s %s\n" "bind-address" "$(dbvar bind_address)"
  printf "  %-22s %s\n" "Datadir" "$(dbvar datadir) ($(du -sh "$(dbvar datadir)" 2>/dev/null | cut -f1))"
  echo "  ${D}── database & ukuran ──${N}"
  dbt "SELECT table_schema AS db, ROUND(SUM(data_length+index_length)/1024/1024,2) AS size_MB, COUNT(*) AS tables FROM information_schema.tables GROUP BY table_schema ORDER BY size_MB DESC" | sed 's/^/  /'
}

db_create() {
  db_ready || return; section "DB // BUAT DATABASE + USER"
  local d u h pw ex
  read -rp "  nama database: " d; valid_name "$d" || { err "hanya A-Z a-z 0-9 _"; return; }
  ask "nama user" "$d"; u=$REPLY; valid_name "$u" || { err "user invalid"; return; }
  ask "host user (localhost / % / IP)" localhost; h=$REPLY; [[ $h =~ ^[A-Za-z0-9_.%:-]+$ ]] || { err "host invalid"; return; }
  read -rp "  password (kosong = generate kuat): " pw; [[ -z $pw ]] && pw=$(genpw 20)
  [[ $pw =~ $RE_PW ]] || { err "password: hanya huruf/angka/@%+=_.,:/-"; return; }
  ex=$(dbq "SELECT COUNT(*) FROM mysql.user WHERE User='$u' AND Host='$h'")
  if [[ $ex != 0 ]]; then confirm "user $u@$h sudah ada — reset passwordnya?" || return
    dbq "ALTER USER '$u'@'$h' IDENTIFIED BY '$pw'"
  else dbq "CREATE USER '$u'@'$h' IDENTIFIED BY '$pw'"; fi
  dbq "CREATE DATABASE IF NOT EXISTS \`$d\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci; GRANT ALL PRIVILEGES ON \`$d\`.* TO '$u'@'$h'; FLUSH PRIVILEGES" && {
    ok "database & user siap"
    printf "\n  ${BD}${Y}┌─ KREDENSIAL (catat sekarang, gak disimpan) ─────────────${N}\n"
    printf "  ${Y}│${N} DB   : %s\n  ${Y}│${N} USER : %s@%s\n  ${Y}│${N} PASS : ${BD}%s${N}\n  ${Y}│${N} DSN  : mysql://%s:***@127.0.0.1:3306/%s\n" "$d" "$u" "$h" "$pw" "$u" "$d"
    printf "  ${Y}└──────────────────────────────────────────────────────${N}\n"; log "db create $d user $u@$h"; }
}

db_users() { db_ready || return; section "DB // USER"; dbt "SELECT User, Host, IF(plugin='unix_socket' OR plugin='auth_socket','socket',plugin) AS auth FROM mysql.user ORDER BY User" | sed 's/^/  /'; }

db_passwd() {
  db_ready || return; local u h pw; read -rp "  user: " u; valid_name "$u" || { err invalid; return; }
  ask "host" localhost; h=$REPLY; [[ $h =~ ^[A-Za-z0-9_.%:-]+$ ]] || { err invalid; return; }
  read -rp "  password baru (kosong = generate): " pw; [[ -z $pw ]] && pw=$(genpw 20); [[ $pw =~ $RE_PW ]] || { err "password invalid"; return; }
  dbq "ALTER USER '$u'@'$h' IDENTIFIED BY '$pw'" && { ok "password diubah → ${BD}$pw${N}"; log "db passwd $u@$h"; }
}

db_drop() {
  db_ready || return; local d a; dbq "SHOW DATABASES" | grep -Ev '^(information_schema|performance_schema|mysql|sys)$' | sed 's/^/  • /'
  read -rp "  database yang dihapus: " d; valid_name "$d" || { err invalid; return; }
  confirm "Backup dulu?" && db_backup_one "$d"
  read -rp "  ketik ${R}$d${N} buat konfirmasi DROP: " a; [[ $a == "$d" ]] && dbq "DROP DATABASE \`$d\`" && { ok "database $d dihapus"; log "db drop $d"; }
}

db_dropuser() {
  db_ready || return; local u h a; read -rp "  user: " u; valid_name "$u" || { err invalid; return; }; ask "host" localhost; h=$REPLY
  [[ $h =~ ^[A-Za-z0-9_.%:-]+$ ]] || { err invalid; return; }
  read -rp "  ketik ${R}$u${N} buat konfirmasi: " a; [[ $a == "$u" ]] && dbq "DROP USER '$u'@'$h'" && { ok "user dihapus"; log "db dropuser $u@$h"; }
}

db_backup_one() { # db (kosong = semua)
  local d="$1" f dump; dump=$(db_dump); [[ -n $dump ]] || { err "mysqldump/mariadb-dump gak ada"; return 1; }
  mkdir -p "$DBDIR"; chmod 700 "$DBDIR"; f="$DBDIR/${d:-all}-$(date +%Y%m%d-%H%M%S).sql.gz"
  if [[ -z $d ]]; then run "dump SEMUA database" bash -o pipefail -c "'$dump' --single-transaction --routines --events --all-databases | gzip > '$f'"
  else run "dump $d" bash -o pipefail -c "'$dump' --single-transaction --routines --events '$d' | gzip > '$f'"; fi
  [[ -s $f ]] && ok "tersimpan: $f ($(hum "$(stat -c %s "$f")"))" && log "db backup $f"
}

db_backup() {
  db_ready || return; section "DB // BACKUP"
  dbq "SHOW DATABASES" | grep -Ev '^(information_schema|performance_schema|sys)$' | sed 's/^/  • /'
  local d; read -rp "  database (kosong = SEMUA): " d; [[ -z $d ]] || valid_name "$d" || { err invalid; return; }
  db_backup_one "$d"
}

db_restore() {
  db_ready || return; section "DB // RESTORE"
  local -a F; mapfile -t F < <(ls -1t "$DBDIR"/*.sql.gz 2>/dev/null); ((${#F[@]})) || { warn "belum ada backup di $DBDIR"; return; }
  local i n d a; for i in "${!F[@]}"; do printf "  ${G}%2d)${N} %s ${D}(%s)${N}\n" $((i+1)) "${F[$i]##*/}" "$(hum "$(stat -c %s "${F[$i]}")")"; done
  read -rp "  pilih backup: " n; [[ $n =~ ^[0-9]+$ ]] && ((n>=1 && n<=${#F[@]})) || return
  read -rp "  target database (kosong = dump lengkap / all): " d; [[ -z $d ]] || valid_name "$d" || { err invalid; return; }
  read -rp "  ketik ${R}RESTORE${N} buat lanjut (data existing bisa ketimpa): " a; [[ $a == RESTORE ]] || return
  [[ -n $d ]] && dbq "CREATE DATABASE IF NOT EXISTS \`$d\`"
  run "restore ${F[$((n-1))]##*/}" bash -o pipefail -c "zcat '${F[$((n-1))]}' | $DBBIN $d"; log "db restore ${F[$((n-1))]} → ${d:-all}"
}

db_cron() {
  cat >/etc/cron.daily/charr-db-backup <<'EOF'
#!/bin/sh
D=/var/backups/charr-db; mkdir -p $D; chmod 700 $D
DUMP=$(command -v mariadb-dump || command -v mysqldump)
$DUMP --single-transaction --routines --events --all-databases | gzip > $D/all-$(date +%Y%m%d).sql.gz
find $D -name 'all-*.sql.gz' -mtime +14 -delete
EOF
  chmod 755 /etc/cron.daily/charr-db-backup; ok "backup harian aktif (cron.daily, simpan 14 hari) → $DBDIR"; log "db cron on"
}

db_health() {
  db_ready || return; section "DB // HEALTH & TUNING"
  local mu mc pc bp ram rq rd hit sl td tt ab tmpr
  mu=$(dbv Max_used_connections); mc=$(dbvar max_connections); mc=${mc:-151}; mu=${mu:-0}; pc=$((mu*100/mc))
  ((pc>=80)) && warn "koneksi puncak $mu/$mc ($pc%) → naikkan max_connections / pakai pooling" || ok "koneksi puncak $mu/$mc ($pc%)"
  bp=$(dbvar innodb_buffer_pool_size); ram=$(free -m | awk '/Mem:/{print $2}')
  info "innodb_buffer_pool: $((bp/1024/1024))MB dari RAM ${ram}MB → saran ±$((ram*35/100))MB kalau 1 server dgn PHP (bisa 60% kalau khusus DB)"
  rq=$(dbv Innodb_buffer_pool_read_requests); rd=$(dbv Innodb_buffer_pool_reads); rq=${rq:-0}; rd=${rd:-0}
  if ((rq>100000)); then hit=$((100-rd*100/rq)); ((hit<95)) && warn "buffer pool hit ratio ${hit}% (<95%) → naikkan innodb_buffer_pool_size" || ok "buffer pool hit ratio ${hit}%"; fi
  sl=$(dbv Slow_queries); [[ ${sl:-0} -gt 0 ]] && warn "$sl slow query tercatat (slow_query_log=$(dbvar slow_query_log))" || ok "gak ada slow query"
  td=$(dbv Created_tmp_disk_tables); tt=$(dbv Created_tmp_tables); td=${td:-0}; tt=${tt:-0}
  ((tt>1000 && td*100/tt>25)) && warn "tmp table ke disk $((td*100/tt))% → cek query GROUP BY/ORDER BY & tmp_table_size" || ok "tmp table wajar"
  ab=$(dbv Aborted_connects); [[ ${ab:-0} -gt 50 ]] && warn "$ab koneksi gagal (aborted) → cek kredensial app / brute-force" || ok "aborted connects: ${ab:-0}"
  local ba; ba=$(dbvar bind_address); [[ $ba == 0.0.0.0 || $ba == '*' || $ba == '::' ]] && warn "bind-address=$ba → DB terekspos; pastikan UFW batasi 3306" || ok "bind-address=$ba"
  local r; r=$(dbq "SELECT CONCAT(User,'@',Host) FROM mysql.user WHERE (User='' ) OR (User='root' AND Host NOT IN ('localhost','127.0.0.1','::1'))")
  [[ -n $r ]] && err "user berisiko: $(paste -sd' ' <<<"$r")" || ok "gak ada anonymous / root remote"
  if [[ $(dbvar slow_query_log) == OFF ]] && confirm "Aktifkan slow query log (runtime, >1 detik)?"; then dbq "SET GLOBAL slow_query_log=1; SET GLOBAL long_query_time=1" && ok "aktif (hilang setelah restart; permanen → my.cnf)"; fi
}

db_process() {
  db_ready || return; section "DB // PROCESSLIST"; dbt "SHOW FULL PROCESSLIST" | cut -c1-160 | sed 's/^/  /'
  local id; read -rp "  KILL query id (kosong = skip): " id; [[ $id =~ ^[0-9]+$ ]] && dbq "KILL $id" && ok "query $id di-kill"
}

db_check() { db_ready || return; local c; c=$(command -v mariadb-check || command -v mysqlcheck); run "check + auto-repair semua tabel" "$c" --auto-repair --check --all-databases; }

db_remote() {
  db_ready || return; section "DB // AKSES REMOTE"
  local f=/etc/mysql/mariadb.conf.d/99-charr.cnf
  info "bind-address sekarang: $(dbvar bind_address)"
  echo "  ${G}1${N}=buka remote (0.0.0.0)  ${G}2${N}=kunci ke lokal (127.0.0.1)"; local c ip; read -rp "  pilih: " c
  case $c in
    1) warn "Setelah dibuka WAJIB: user dgn host spesifik + UFW allow 3306 hanya dari IP tertentu"
       confirm "Lanjut buka remote?" || return
       printf '[mysqld]\nbind-address = 0.0.0.0\n' >"$f"; systemctl restart mariadb 2>/dev/null || systemctl restart mysql
       ok "remote dibuka"; confirm "Allow 3306 dari 1 IP di UFW sekarang?" && { read -rp "  IP: " ip; [[ $ip =~ $RE_IP ]] && ufw allow from "$ip" to any port 3306 proto tcp comment 'MariaDB remote'; };;
    2) printf '[mysqld]\nbind-address = 127.0.0.1\n' >"$f"; systemctl restart mariadb 2>/dev/null || systemctl restart mysql; ok "dikunci ke lokal";;
  esac; log "db remote toggle $c"
}

db_menu() {
  while true; do
    section "DATABASE MANAGER"
    cat <<EOF
  ${G}[1]${N} Status & daftar database      ${G}[8]${N}  Auto backup harian (cron)
  ${G}[2]${N} ${BD}Buat database + user${N} (wizard)  ${G}[9]${N}  Health & tuning check
  ${G}[3]${N} Daftar user                   ${G}[10]${N} Processlist / kill query
  ${G}[4]${N} Ganti password user           ${G}[11]${N} Check & repair tabel
  ${G}[5]${N} Hapus database                ${G}[12]${N} Akses remote on/off
  ${G}[6]${N} Hapus user                    ${G}[13]${N} Konsol SQL (root)
  ${G}[7]${N} Backup / ${G}[r]${N}estore           ${G}[0]${N}  Balik
EOF
    local c; read -rp "  ${C}»${N} " c
    case $c in
      1) db_status; pause;;  2) db_create; pause;;  3) db_users; pause;;  4) db_passwd; pause;;
      5) db_drop; pause;;    6) db_dropuser; pause;; 7) db_backup; pause;;  r|R) db_restore; pause;;
      8) db_cron; pause;;    9) db_health; pause;;  10) db_process; pause;; 11) db_check; pause;;
      12) db_remote; pause;; 13) db_ready && "$DBBIN";;
      0) return;;
    esac
  done
}

# ═══════════════════════════════════════════════════════════════════
#  SMART DOCTOR — auto diagnose + auto fix
# ═══════════════════════════════════════════════════════════════════
FD_SEV=(); FD_MSG=(); FD_HINT=(); FD_FIX=()
fd_add() { FD_SEV+=("$1"); FD_MSG+=("$2"); FD_HINT+=("$3"); FD_FIX+=("${4:-}"); }

explain() { # teks error → petunjuk
  case "$1" in
    *"Address already in use"*|*"bind()"*"failed"*) echo "port bentrok → cari pemakai: ss -ltnp | grep :<port>; stop service lain / ganti port";;
    *"Permission denied"*)                          echo "izin salah → cek owner/mode file/socket, AppArmor (journalctl -k | grep DENIED)";;
    *"No space left"*)                              echo "disk/inode penuh → jalankan Cleaner (menu 6)";;
    *"syntax error"*|*"unknown directive"*|*"emerg"*|*"Invalid command"*) echo "typo config → test: nginx -t / sshd -t / named-checkconf";;
    *"Cannot allocate memory"*|*"Out of memory"*)   echo "RAM habis → tambah swap / turunin worker & buffer";;
    *"Connection refused"*)                         echo "service tujuan mati / port salah → cek Service Manager";;
    *"No such file or directory"*)                  echo "path/socket salah atau file hilang";;
    *"Too many open files"*)                        echo "limit file descriptor → naikkan LimitNOFILE / worker_rlimit_nofile";;
    *"corrupt"*|*"crashed"*)                        echo "data korup → backup lalu 'Check & repair tabel' (menu DB)";;
    *) echo "";;
  esac
}
first_err() { journalctl -u "$1" -n 60 --no-pager -o cat 2>/dev/null | grep -iE 'error|fail|fatal|denied|refused|emerg|cannot|unable|invalid|in use|corrupt' | tail -3; }

dx_system() {
  local m p mp sw oom dp
  while read -r m p; do
    if ((p>=95)); then fd_add CRIT "disk $m penuh ${p}%" "Cleaner (menu 6) + Storage explorer (menu 5) buat cari biang keroknya" "c_apt; c_journal; c_logs; c_tmp"
    elif ((p>=85)); then fd_add WARN "disk $m ${p}%" "mulai penuh — Cleaner bisa bebasin cache/log" "c_apt; c_journal; c_logs"; fi
  done < <(df -P -x tmpfs -x devtmpfs -x squashfs -x overlay -x efivarfs 2>/dev/null | awk 'NR>1{gsub("%","",$5);print $6,$5}')
  while read -r m p; do ((p>=90)) && fd_add WARN "inode $m ${p}%" "banyak file kecil (session/cache/log) — cari: find $m -xdev -type f | cut -d/ -f1-4 | sort | uniq -c | sort -rn | head"; done \
    < <(df -Pi -x tmpfs -x devtmpfs -x squashfs -x overlay 2>/dev/null | awk 'NR>1{gsub("%","",$5);print $6,$5}' | grep -v ' -$')
  mp=$(mem_pct); sw=$(free | awk '/Swap:/{print $2}')
  ((mp>=90)) && fd_add WARN "RAM ${mp}% terpakai$( ((sw==0)) && echo ', TANPA swap')" "top proses: $(ps -eo comm --sort=-%mem | sed -n 2,4p | paste -sd,) — tambah swap (Setup → Baseline)"
  oom=$(journalctl -k --since '7 days ago' --no-pager 2>/dev/null | grep -oE 'Killed process [0-9]+ \([^)]*\)' | sed -E 's/.*\(([^)]*)\)/\1/' | sort | uniq -c | sort -rn | head -3 | awk '{printf "%s×%s ",$1,$2}')
  [[ -n $oom ]] && fd_add CRIT "OOM-killer bunuh proses (7 hari): $oom" "RAM kurang → tambah swap/RAM, turunin pm.max_children & innodb_buffer_pool_size"
  awk -v l="$(cut -d' ' -f2 /proc/loadavg)" -v c="$(nproc)" 'BEGIN{exit !(l>c*1.5)}' && fd_add WARN "load 5m tinggi ($(cut -d' ' -f2 /proc/loadavg) vs $(nproc) core)" "top CPU: $(ps -eo comm,%cpu --sort=-%cpu | sed -n 2,3p | awk '{printf "%s(%s%%) ",$1,$2}')"
  dp=$(dpkg --audit 2>/dev/null | head -1); [[ -n $dp ]] && fd_add CRIT "dpkg ada paket setengah terinstall/rusak" "$dp" "dpkg --configure -a; apt-get -f install -y"
  [[ $(timedatectl show -p NTPSynchronized --value 2>/dev/null) == yes ]] || fd_add WARN "waktu belum sinkron NTP" "log & sertifikat SSL bisa error kalau jam melenceng" "timedatectl set-ntp true"
  [[ -f /var/run/reboot-required ]] && fd_add INFO "reboot dibutuhkan" "kernel/lib baru terpasang — reboot di jam sepi"
}

dx_units() {
  local u lines hint
  while read -r u; do [[ -n $u ]] || continue
    lines=$(first_err "$u"); hint=$(explain "$lines")
    fd_add CRIT "service gagal: $u" "$(head -1 <<<"$lines" | cut -c1-130)${hint:+  ⇒ $hint}" "systemctl reset-failed $u; systemctl restart $u"
  done < <(systemctl --failed --no-legend --plain 2>/dev/null | awk '{print $1}')
}

dx_net() {
  getent hosts archive.ubuntu.com >/dev/null 2>&1 || fd_add CRIT "DNS resolver gagal" "menu Setup → DNS Center → Set resolver" 
  ping -c1 -W2 1.1.1.1 >/dev/null 2>&1 || fd_add WARN "ping 1.1.1.1 gagal" "cek gateway/route: ip route; ping gateway"
  if need nginx && ss -ltnH 'sport = :80' 2>/dev/null | grep -q . && fw_active; then
    fw_allowed_ports | grep -qx 80 || fd_add WARN "web listen di :80 tapi UFW belum allow 80" "site gak bisa diakses dari luar" "ufw allow 80/tcp; ufw allow 443/tcp"
  fi
  if fw_active; then local p ok_=0; for p in $(ssh_ports); do fw_allowed_ports | grep -qx "$p" && ok_=1; done
    ((ok_)) || fd_add CRIT "UFW aktif tapi port SSH gak di-allow" "risiko lock-out begitu koneksi putus" "for p in $(ssh_ports | paste -sd' '); do ufw limit \$p/tcp; done"; fi
  need sshd && ! sshd -t 2>/dev/null && fd_add CRIT "sshd_config error" "$(sshd -t 2>&1 | head -1) — JANGAN restart ssh sebelum diperbaiki"
  local f; f=$(journalctl -u ssh -u sshd --since '24 hours ago' --no-pager 2>/dev/null | grep -c 'Failed password')
  ((f>50)) && fd_add WARN "$f login SSH gagal (24 jam) — indikasi brute-force" "Security Center → Fail2ban + SSH hardening" "$(need fail2ban-client || echo 'true')"
  need fail2ban-client && ! svc_active fail2ban && fd_add WARN "fail2ban terinstall tapi mati" "" "systemctl enable --now fail2ban"
}

dx_nginx() {
  need nginx || return 0
  local t rc el t500 n o p; t=$(nginx -t 2>&1); rc=$?
  if ((rc!=0)); then fd_add CRIT "nginx config error" "$(grep -m1 -E 'emerg|error' <<<"$t" | cut -c1-150)  ⇒ perbaiki lalu 'nginx -t'"
  elif ! svc_active nginx; then fd_add CRIT "nginx MATI (config valid)" "$(first_err nginx | tail -1 | cut -c1-130)" "systemctl restart nginx"; fi
  if ! svc_active nginx; then for p in 80 443; do
    o=$(ss -ltnpH "sport = :$p" 2>/dev/null | head -1)
    [[ -n $o && $o != *nginx* ]] && fd_add CRIT "port $p dipakai proses lain: $(sed -nE 's/.*\(\("([^"]+)".*/\1/p' <<<"$o")" "matikan proses itu (mis. apache2) atau pindah port"
  done; fi
  el=/var/log/nginx/error.log
  if [[ -s $el ]]; then
    t500=$(tail -n 3000 "$el" | grep -E "^($(date +%Y/%m/%d)|$(date -d yesterday +%Y/%m/%d)) ")
    n=$(grep -c 'connect() to unix:.*failed\|connect() failed (111' <<<"$t500"); ((n>0)) && fd_add CRIT "nginx gagal konek ke upstream/PHP-FPM ($n error/48 jam)" "php-fpm mati atau fastcgi_pass/proxy_pass salah"
    n=$(grep -c 'Permission denied' <<<"$t500"); ((n>0)) && fd_add WARN "nginx 'Permission denied' ($n)" "chown -R www-data:www-data <webroot>; direktori butuh x (755)"
    n=$(grep -c 'upstream timed out' <<<"$t500"); ((n>0)) && fd_add WARN "upstream timeout ($n)" "script/query lambat → naikkan fastcgi_read_timeout atau optimasi (cek slow query)"
    n=$(grep -c 'too large body' <<<"$t500"); ((n>0)) && fd_add WARN "upload ditolak body terlalu besar ($n)" "Setup → PHP Tuner (naikkan client_max_body_size)"
    n=$(grep -c 'Too many open files\|worker_connections are not enough' <<<"$t500"); ((n>0)) && fd_add WARN "limit koneksi/FD nginx ($n)" "naikkan worker_rlimit_nofile & worker_connections"
    n=$(grep -c 'No such file or directory' <<<"$t500"); ((n>20)) && fd_add INFO "$n request ke file yang gak ada" "cek root/try_files atau bot scanning"
  fi
  local al=/var/log/nginx/access.log tot e5
  if [[ -s $al ]]; then tot=$(tail -n 2000 "$al" | wc -l); e5=$(tail -n 2000 "$al" | awk '$9 ~ /^5[0-9][0-9]$/' | wc -l)
    if ((tot>0 && e5*100/tot>=1)); then fd_add WARN "$e5/$tot request terakhir 5xx" "URL terbanyak: $(tail -n 2000 "$al" | awk '$9 ~ /^5/{print $7}' | sort | uniq -c | sort -rn | head -2 | awk '{printf "%s×%s ",$1,$2}')"; fi; fi
  local r; while read -r r; do [[ -n $r && ! -d $r ]] && fd_add WARN "root nginx gak ada: $r" "buat direktori atau perbaiki 'root' di config site"
    [[ -d $r ]] && ! runuser -u www-data -- test -r "$r" 2>/dev/null && fd_add WARN "www-data gak bisa baca $r" "chown -R www-data:www-data $r; chmod -R u+rX,g+rX $r" "chown -R www-data:www-data '$r'"
  done < <(nginx -T 2>/dev/null | awk '$1=="root"{gsub(";","",$2);print $2}' | sort -u)
  local c d days name; for c in /etc/letsencrypt/live/*/cert.pem; do [[ -f $c ]] || continue
    d=$(openssl x509 -enddate -noout -in "$c" | cut -d= -f2); days=$(( ($(date -d "$d" +%s) - $(date +%s)) / 86400 )); name=$(basename "$(dirname "$c")")
    if ((days<0)); then fd_add CRIT "SSL $name KEDALUWARSA" "renew: certbot renew" "certbot renew"
    elif ((days<14)); then fd_add CRIT "SSL $name tinggal $days hari" "auto-renew bermasalah? cek: systemctl list-timers | grep certbot" "certbot renew"
    elif ((days<30)); then fd_add WARN "SSL $name tinggal $days hari" "pastikan timer certbot aktif"; fi
  done
}

dx_php() {
  local v s; v=$(php_ver); [[ -n $v ]] || return 0
  svc_active "php${v}-fpm" || fd_add CRIT "php${v}-fpm mati" "$(first_err "php${v}-fpm" | tail -1 | cut -c1-130)" "systemctl restart php${v}-fpm"
  if need nginx; then while read -r s; do [[ -n $s && ! -S $s ]] && fd_add CRIT "socket fastcgi_pass gak ada: $s" "versi PHP berubah? ganti ke $(php_sock)" ; done \
    < <(nginx -T 2>/dev/null | grep -oE 'fastcgi_pass +unix:[^;]+' | awk '{print $2}' | sed 's/^unix://' | sort -u); fi
  local lg="/var/log/php${v}-fpm.log"
  if [[ -s $lg ]] && tail -n 500 "$lg" | grep -q 'max_children'; then
    local ram; ram=$(free -m | awk '/Mem:/{print $2}'); fd_add WARN "PHP-FPM mentok pm.max_children" "saran ±$((ram*50/100/40)) (RAM ${ram}MB, ~40MB/child) di /etc/php/$v/fpm/pool.d/www.conf"; fi
}

dx_db() {
  db_cli || return 0
  if ! { svc_active mariadb || svc_active mysql; }; then
    local l; l=$(first_err mariadb; first_err mysql); fd_add CRIT "MariaDB/MySQL MATI" "$(tail -1 <<<"$l" | cut -c1-130)  ⇒ $(explain "$l")" "systemctl restart mariadb 2>/dev/null || systemctl restart mysql"; return
  fi
  dbq "SELECT 1" >/dev/null 2>&1 || { fd_add WARN "root gak bisa login via socket" "sudo $DBBIN gagal — cek plugin auth root"; return; }
  local mu mc; mu=$(dbv Max_used_connections); mc=$(dbvar max_connections); mu=${mu:-0}; mc=${mc:-151}
  ((mu*100/mc>=80)) && fd_add WARN "koneksi DB puncak $mu/$mc" "naikkan max_connections / connection pooling"
  ss -ltnH 'sport = :3306' 2>/dev/null | grep -qE '(0\.0\.0\.0|\*|\[::\]):3306' && fd_add WARN "MariaDB listen di semua interface (:3306)" "kunci: DB Manager → Akses remote → lokal, atau batasi UFW" "true"
  journalctl -u mariadb -u mysql --since '24 hours ago' --no-pager -o cat 2>/dev/null | grep -qi 'Too many connections' && fd_add WARN "'Too many connections' muncul (24 jam)" "cek app yang gak nutup koneksi"
  journalctl -u mariadb -u mysql --since '7 days ago' --no-pager -o cat 2>/dev/null | grep -qiE 'corrupt|crashed' && fd_add CRIT "indikasi tabel/InnoDB korup di log" "backup dulu, lalu DB Manager → Check & repair"
}

doctor() {
  FD_SEV=(); FD_MSG=(); FD_HINT=(); FD_FIX=()
  banner; section "SMART DOCTOR — full scan"
  local s; for s in system units net nginx php db; do printf "\r  ${C}scanning${N} %-8s ${D}...${N}\e[K" "$s"; "dx_$s"; done; printf "\r\e[K"
  local i crit=0 warn_=0 sev col; local -a IDX=()
  for sev in CRIT WARN INFO; do
    for i in "${!FD_SEV[@]}"; do [[ ${FD_SEV[$i]} == "$sev" ]] || continue
      case $sev in CRIT) col=$R; crit=$((crit+1));; WARN) col=$Y; warn_=$((warn_+1));; INFO) col=$C;; esac
      printf "  ${col}${BD}[%-4s]${N} %s\n" "$sev" "${FD_MSG[$i]}"
      [[ -n ${FD_HINT[$i]} ]] && printf "         ${D}↳ %s${N}\n" "${FD_HINT[$i]}"
      [[ -n ${FD_FIX[$i]} && ${FD_FIX[$i]} != true ]] && { printf "         ${G}⚙ auto-fix tersedia${N}\n"; IDX+=("$i"); }
    done
  done
  local score=$((100 - crit*20 - warn_*6)); ((score<0)) && score=0
  echo; printf "  ${BD}HEALTH SCORE${N}  %s   ${D}(%d critical, %d warning)${N}\n" "$(bar "$score" 30)" "$crit" "$warn_"
  ((${#FD_SEV[@]}==0)) && ok "semua sehat — gak ada temuan"
  if ((${#IDX[@]})); then
    echo; info "${#IDX[@]} temuan bisa di-fix otomatis"
    for i in "${IDX[@]}"; do
      echo "  ${BD}${FD_MSG[$i]}${N}  ${D}→ ${FD_FIX[$i]}${N}"
      if confirm "Jalankan fix ini?"; then log "doctor fix: ${FD_FIX[$i]}"; eval "${FD_FIX[$i]}" 2>&1 | tail -5 | sed 's/^/    /'; ok "dijalankan"; fi
    done
  fi
}

svc_why() {
  pick_service || return
  section "DIAGNOSA: $SVC"
  systemctl status "$SVC" --no-pager -n 0 2>/dev/null | head -12 | sed 's/^/  /'
  echo "  ${D}── error terbaru di log ──${N}"
  journalctl -u "$SVC" -n 80 --no-pager -o cat 2>/dev/null | grep -iE 'error|fail|fatal|denied|refused|emerg|cannot|unable|invalid|corrupt' | tail -8 | cut -c1-180 | colorize | sed 's/^/  /'
  local h; h=$(explain "$(first_err "$SVC")"); [[ -n $h ]] && info "petunjuk: $h"
  echo "  ${D}── tes config ──${N}"
  case $SVC in
    nginx*) nginx -t 2>&1 | sed 's/^/  /';;
    ssh*)   sshd -t 2>&1 && ok "sshd config valid";;
    php*fpm*) local v; v=$(sed -E 's/^php([0-9.]+)-fpm.*/\1/' <<<"$SVC"); "php-fpm$v" -t 2>&1 | tail -2 | sed 's/^/  /';;
    named*|bind9*) named-checkconf && ok "named config valid";;
    mariadb*|mysql*) db_cli && dbq "SELECT 'DB OK', VERSION()" 2>&1 | sed 's/^/  /';;
    *) info "gak ada tes config khusus untuk $SVC";;
  esac
  confirm "Restart $SVC & cek lagi?" && { systemctl restart "$SVC"; sleep 2; svc_active "$SVC" && ok "$SVC aktif" || { err "$SVC masih gagal"; journalctl -u "$SVC" -n 15 --no-pager -o cat | colorize | sed 's/^/  /'; }; }
}

doctor_menu() {
  while true; do
    section "SMART DOCTOR"
    echo "  ${G}[1]${N} ${BD}Full scan + auto-fix${N}   ${G}[2]${N} Kenapa service X gagal? (diagnosa)   ${G}[3]${N} Probe URL (dns/tls/ttfb)   ${G}[0]${N} Balik"
    local c u; read -rp "  ${C}»${N} " c
    case $c in
      1) doctor; pause;;
      2) svc_why; pause;;
      3) read -rp "  URL: " u; [[ $u =~ ^https?:// ]] && web_probe "$u"; pause;;
      0) return;;
    esac
  done
}

# ═══════════════════════════════════════════════════════════════════
#  LOG EXPLORER
# ═══════════════════════════════════════════════════════════════════
log_summary() { sed -E 's/[0-9]{1,3}(\.[0-9]{1,3}){3}/<ip>/g; s/[0-9]{4}[-\/][0-9]{2}[-\/][0-9]{2}[ T][0-9:.]+//g; s/[0-9a-f]{8,}/<hex>/g; s/[0-9]+/N/g' | sort | uniq -c | sort -rn | head -"${1:-10}"; }

analyze_stream() { # title (stdin = log lines)
  local t n; t=$(mktemp); cat >"$t"; n=$(wc -l <"$t")
  section "$1  ($n baris)"
  if ((n==0)); then ok "kosong / bersih"
  else
    echo "  ${D}── pola paling sering (angka/IP dinormalisasi) ──${N}"; log_summary 10 <"$t" | cut -c1-170 | colorize | sed 's/^/  /'
    echo "  ${D}── 15 baris terakhir ──${N}"; tail -15 "$t" | cut -c1-200 | colorize | sed 's/^/  /'
  fi; rm -f "$t"
}

access_analyze() {
  local f=${1:-/var/log/nginx/access.log}; [[ -s $f ]] || { warn "$f kosong/tidak ada"; return; }
  section "NGINX ACCESS — 5000 request terakhir"
  echo "  ${D}── status code ──${N}"; tail -n 5000 "$f" | awk '{print $9}' | sort | uniq -c | sort -rn | head -8 | sed 's/^/  /'
  echo "  ${D}── top IP ──${N}";      tail -n 5000 "$f" | awk '{print $1}' | sort | uniq -c | sort -rn | head -8 | sed 's/^/  /'
  echo "  ${D}── top URL ──${N}";     tail -n 5000 "$f" | awk '{print $7}' | sort | uniq -c | sort -rn | head -8 | cut -c1-120 | sed 's/^/  /'
  echo "  ${D}── URL penyebab 4xx/5xx ──${N}"; tail -n 5000 "$f" | awk '$9 ~ /^[45]/{print $9, $7}' | sort | uniq -c | sort -rn | head -8 | cut -c1-120 | sed 's/^/  /'
}

logs_menu() {
  while true; do
    section "LOG EXPLORER"
    cat <<EOF
  ${G}[1]${N} Semua error sistem (24 jam)      ${G}[6]${N} SSH / auth
  ${G}[2]${N} Nginx error log                  ${G}[7]${N} Kernel (err/warn)
  ${G}[3]${N} Nginx access — analisis traffic  ${G}[8]${N} Log service pilihan
  ${G}[4]${N} PHP-FPM                          ${G}[9]${N} Live tail berwarna
  ${G}[5]${N} MariaDB                          ${G}[10]${N} Cari keyword di /var/log   ${G}[0]${N} Balik
EOF
    local c k v; read -rp "  ${C}»${N} " c; v=$(php_ver)
    case $c in
      1) journalctl -p err --since '24 hours ago' --no-pager -o cat 2>/dev/null | analyze_stream "ERROR SISTEM 24 JAM"; pause;;
      2) tail -n 1000 /var/log/nginx/error.log 2>/dev/null | analyze_stream "NGINX ERROR"; pause;;
      3) access_analyze; pause;;
      4) { tail -n 500 "/var/log/php${v}-fpm.log" 2>/dev/null; journalctl -u "php${v}-fpm" -n 300 --no-pager -o cat 2>/dev/null | grep -iE 'error|warn'; } | analyze_stream "PHP-FPM"; pause;;
      5) journalctl -u mariadb -u mysql -n 500 --no-pager -o cat 2>/dev/null | grep -iE 'error|warn|crash|corrupt|denied' | analyze_stream "MARIADB"; pause;;
      6) journalctl -u ssh -u sshd --since '24 hours ago' --no-pager -o cat 2>/dev/null | grep -iE 'fail|invalid|refused|error' | analyze_stream "SSH — gagal login 24 jam"; pause;;
      7) dmesg -T --level=err,warn 2>/dev/null | tail -300 | analyze_stream "KERNEL"; pause;;
      8) pick_service && journalctl -u "$SVC" -n 500 --no-pager -o cat 2>/dev/null | analyze_stream "$SVC"; pause;;
      9) echo "  ${D}1=journal error  2=nginx error  3=nginx access  4=syslog service  (Ctrl+C stop)${N}"; read -rp "  pilih: " k
         case $k in
           1) live_tail journalctl -f -p err -o cat;;
           2) live_tail tail -n 20 -F /var/log/nginx/error.log;;
           3) live_tail tail -n 20 -F /var/log/nginx/access.log;;
           4) pick_service && live_tail journalctl -f -u "$SVC" -o cat;;
         esac;;
      10) read -rp "  keyword: " k; [[ -n $k ]] && { grep -rIiF --include='*.log' --include='syslog*' --include='auth*' -- "$k" /var/log 2>/dev/null | tail -30 | cut -c1-200 | colorize | sed 's/^/  /'; }; pause;;
      0) return;;
    esac
  done
}

# ═══════════════════════════════════════════════════════════════════
#  v1.2 — SWAP & MEMORY (low-RAM VPS)
# ═══════════════════════════════════════════════════════════════════
size_mb() { local s=${1^^}; case $s in *G) echo $(( ${s%G} * 1024 ));; *M) echo "${s%M}";; *) echo 0;; esac; }

swap_status() {
  section "SWAP & MEMORY // STATUS"
  free -h | sed 's/^/  /'; echo
  [[ -z $(swapon --show --noheadings 2>/dev/null) ]] && warn "TIDAK ada swap" || swapon --show 2>/dev/null | sed 's/^/  /'
  printf "  swappiness=%s  vfs_cache_pressure=%s  min_free_kbytes=%s\n" "$(cat /proc/sys/vm/swappiness)" "$(cat /proc/sys/vm/vfs_cache_pressure)" "$(cat /proc/sys/vm/min_free_kbytes)"
  need zramctl && zramctl 2>/dev/null | sed 's/^/  /'
  echo "  ${D}── 6 pemakai RAM terbesar ──${N}"
  ps -eo pid,comm,rss --sort=-rss | sed -n 2,7p | awk '{printf "  %-7s %-22s %7.1f MB\n",$1,$2,$3/1024}'
}

swap_create() { # size
  local sz=${1:-2G} mb f=/swapfile fs avail
  [[ $sz =~ ^[0-9]+[MG]$ ]] || { err "ukuran invalid (contoh: 2G / 1024M)"; return 1; }
  mb=$(size_mb "$sz"); fs=$(stat -f -c %T / 2>/dev/null)
  [[ $fs == btrfs || $fs == zfs ]] && { err "root di $fs — swapfile butuh setup khusus, dilewati"; return 1; }
  avail=$(df -Pm / | awk 'NR==2{print $4}')
  ((avail > mb+1024)) || { err "disk kurang: sisa ${avail}MB, butuh $((mb+1024))MB"; return 1; }
  swapon --show=NAME --noheadings 2>/dev/null | grep -qx "$f" && swapoff "$f"
  rm -f "$f"
  fallocate -l "${mb}M" "$f" 2>/dev/null || dd if=/dev/zero of="$f" bs=1M count="$mb" status=none
  chmod 600 "$f"
  mkswap "$f" >/dev/null && swapon "$f" || { err "gagal aktifin swapfile"; return 1; }
  if grep -q '^/swapfile' /etc/fstab; then sed -i 's|^/swapfile.*|/swapfile none swap sw 0 0|' /etc/fstab; else echo '/swapfile none swap sw 0 0' >>/etc/fstab; fi
  ok "swapfile $sz aktif & permanen (fstab)"; log "swap create $sz"
}

swap_remove() {
  swapon --show=NAME --noheadings 2>/dev/null | grep -qx /swapfile && swapoff /swapfile
  rm -f /swapfile; sed -i '\|^/swapfile|d' /etc/fstab; ok "swapfile dihapus"; log "swap remove"
}

swap_zram() {
  modprobe zram 2>/dev/null || { warn "kernel ini gak punya modul zram — dilewati (pakai swapfile aja)"; return 1; }
  run "install zram-tools" apti zram-tools || return 1
  local pct algo; ask "ukuran zram (% dari RAM)" 50; pct=$REPLY
  [[ $pct =~ ^[0-9]+$ ]] && ((pct>=10 && pct<=150)) || { err "invalid"; return 1; }
  for algo in zstd lz4; do
    printf 'ALGO=%s\nPERCENT=%s\nPRIORITY=100\n' "$algo" "$pct" >/etc/default/zramswap
    systemctl enable zramswap >/dev/null 2>&1; systemctl restart zramswap >/dev/null 2>&1; sleep 1
    swapon --show --noheadings 2>/dev/null | grep -q zram && { ok "zram aktif ($algo, $pct% RAM, prioritas 100 — dipakai sebelum swapfile)"; log "zram $algo $pct"; return 0; }
  done
  err "zram gagal aktif — cek: systemctl status zramswap"; return 1
}

swap_tune() { # [auto]
  local ram_kb zr=0 def sw mfk; ram_kb=$(awk '/MemTotal/{print $2}' /proc/meminfo)
  swapon --show --noheadings 2>/dev/null | grep -q zram && zr=1
  def=$((zr ? 80 : 20))
  if [[ ${1:-} == auto ]]; then sw=$def; else ask "vm.swappiness (zram aktif → 80, swap disk saja → 20)" "$def"; sw=$REPLY; fi
  [[ $sw =~ ^[0-9]+$ ]] && ((sw<=200)) || { err "invalid"; return 1; }
  mfk=$((ram_kb/50)); ((mfk<16384)) && mfk=16384
  printf 'vm.swappiness=%s\nvm.vfs_cache_pressure=100\nvm.min_free_kbytes=%s\n' "$sw" "$mfk" >/etc/sysctl.d/98-charr-mem.conf
  [[ -f /etc/sysctl.d/99-charr.conf ]] && sed -i '/^vm\.swappiness/d' /etc/sysctl.d/99-charr.conf
  sysctl -q -p /etc/sysctl.d/98-charr-mem.conf && ok "sysctl: swappiness=$sw, min_free_kbytes=${mfk}KB (headroom biar gak freeze)"
}

swap_auto() { # [yes]
  local ram sz=2G; ram=$(free -m | awk '/Mem:/{print $2}'); ((ram>=3000)) && sz=1G
  info "RAM ${ram}MB → rekomendasi: swapfile ${sz} + zram 50% + tuning kernel"
  [[ ${1:-} == yes ]] || confirm "Jalankan setup swap otomatis?" || return
  swapon --show=NAME --noheadings 2>/dev/null | grep -qx /swapfile || swap_create "$sz"
  swapon --show --noheadings 2>/dev/null | grep -q zram || { [[ ${1:-} == yes ]] && REPLY=50 || true; swap_zram; }
  swap_tune auto
}

ini_set() { # file key value  → "key = value"
  local f=$1 k=$2 v=$3 ke=${2//./\\.}
  if grep -qE "^[;#]?[[:space:]]*${ke}[[:space:]]*=" "$f"; then sed -i -E "0,/^[;#]?[[:space:]]*${ke}[[:space:]]*=.*/ s//${k} = ${v}/" "$f"
  else printf '%s = %s\n' "$k" "$v" >>"$f"; fi
}

lowmem_tune() {
  section "LOW-RAM TUNER (PHP-FPM + MariaDB + journald)"
  local ram v pool max bp; ram=$(free -m | awk '/Mem:/{print $2}')
  info "RAM terdeteksi: ${ram}MB"
  v=$(php_ver)
  if [[ -n $v ]] && confirm "PHP-FPM: pm=ondemand + batasi max_children?"; then
    pool=/etc/php/$v/fpm/pool.d/www.conf; [[ -f $pool.bak-charr ]] || cp "$pool" "$pool.bak-charr"
    max=$((ram*35/100/40)); ((max<3)) && max=3; ((max>20)) && max=20
    ini_set "$pool" pm ondemand; ini_set "$pool" pm.max_children "$max"
    ini_set "$pool" pm.process_idle_timeout 10s; ini_set "$pool" pm.max_requests 300
    if "php-fpm$v" -t >/dev/null 2>&1; then systemctl reload "php${v}-fpm" && ok "php-fpm: ondemand, max_children=$max (~40MB/child)"; else err "php-fpm config error — rollback"; cp "$pool.bak-charr" "$pool"; fi
  fi
  if db_cli && [[ -d /etc/mysql/mariadb.conf.d ]] && confirm "MariaDB: mode hemat RAM (performance_schema off, buffer pool kecil)?"; then
    bp=$((ram*15/100)); ((bp<64)) && bp=64; ((bp>512)) && bp=512
    cat >/etc/mysql/mariadb.conf.d/98-charr-lowmem.cnf <<EOF
[mysqld]
performance_schema = OFF
innodb_buffer_pool_size = ${bp}M
innodb_log_buffer_size = 8M
key_buffer_size = 8M
max_connections = 40
table_open_cache = 400
thread_cache_size = 8
tmp_table_size = 24M
max_heap_table_size = 24M
EOF
    ok "mariadb: buffer pool ${bp}M, max_connections 40, performance_schema OFF"
    confirm "Restart MariaDB sekarang (perlu biar aktif)?" && { systemctl restart mariadb 2>/dev/null || systemctl restart mysql; }
  fi
  if confirm "Batasi journald (RAM/disk kecil)?"; then
    mkdir -p /etc/systemd/journald.conf.d
    printf '[Journal]\nSystemMaxUse=100M\nRuntimeMaxUse=30M\nMaxRetentionSec=2week\n' >/etc/systemd/journald.conf.d/charr.conf
    systemctl restart systemd-journald && ok "journald dibatasi (100M disk / 30M RAM)"
  fi
  log "lowmem tune"
}

swap_menu() {
  while true; do
    swap_status
    section "SWAP & MEMORY"
    cat <<EOF
  ${G}[1]${N} ${BD}AUTO (rekomendasi)${N}: swapfile + zram + tuning   ${G}[5]${N} Tuning kernel (swappiness, min_free)
  ${G}[2]${N} Buat / resize swapfile                            ${G}[6]${N} Low-RAM Tuner (PHP-FPM, MariaDB)
  ${G}[3]${N} Hapus swapfile                                    ${G}[0]${N} Balik
  ${G}[4]${N} zram (swap terkompresi di RAM)
EOF
    local c; read -rp "  ${C}»${N} " c
    case $c in
      1) swap_auto; pause;;
      2) ask "ukuran swapfile" 2G; swap_create "$REPLY"; pause;;
      3) confirm "Hapus /swapfile?" && swap_remove; pause;;
      4) swap_zram; pause;;
      5) swap_tune; pause;;
      6) lowmem_tune; pause;;
      0) return;;
    esac
  done
}

# ═══════════════════════════════════════════════════════════════════
#  v1.2 — SHIELD (anti-DDoS / anti-scan / SSH lane)
# ═══════════════════════════════════════════════════════════════════
CH=/etc/charr; NFT_FILE=$CH/shield.nft; WL=$CH/whitelist.txt; CFG=$CH/shield.conf; SELF=$(readlink -f "$0")
sh_init()  { mkdir -p "$CH"; chmod 700 "$CH"; touch "$WL" "$CFG"; }
cfg_get()  { local v; v=$(grep -E "^$1=" "$CFG" 2>/dev/null | tail -1 | cut -d= -f2-); echo "${v:-$2}"; }
cfg_set()  { sh_init; [[ $2 =~ ^[A-Za-z0-9._,:-]*$ ]] || return 1
             if grep -qE "^$1=" "$CFG"; then sed -i -E "s|^$1=.*|$1=$2|" "$CFG"; else echo "$1=$2" >>"$CFG"; fi; }
wl_valid() { [[ $1 =~ ^[0-9a-fA-F:.]+(/[0-9]{1,3})?$ ]]; }
wl_list()  { grep -vE '^[[:space:]]*(#|$)' "$WL" 2>/dev/null; }
wl_add()   { sh_init; wl_valid "$1" || { err "IP/CIDR invalid: $1"; return 1; }; grep -qxF "$1" "$WL" || echo "$1" >>"$WL"; }
wl_del()   { grep -vxF -- "$1" "$WL" >"$WL.tmp"; mv "$WL.tmp" "$WL"; }
my_ssh_ip(){ local ip=${SSH_CLIENT%% *}; [[ -z $ip ]] && ip=${SSH_CONNECTION%% *}
             [[ -z $ip ]] && ip=$(who -m 2>/dev/null | grep -oE '\([0-9a-fA-F:.]+\)' | tr -d '()'); echo "$ip"; }
shield_on(){ nft list table inet charr_shield >/dev/null 2>&1; }

shield_open_ports() { # port yang MEMANG dibuka (biar traffic sah gak dianggap scan)
  { ssh_ports; echo 80; echo 443; cfg_get EXTRA_PORTS "" | tr ',' '\n'
    need ufw && fw_allowed_ports 2>/dev/null
    ss -tlnH 2>/dev/null | awk '{a=$4; p=a; sub(/.*:/,"",p); h=a; sub(/:[0-9]+$/,"",h); if (h !~ /^(127\.|\[::1\]|::1$)/) print p}'
  } | grep -E '^[0-9]+$' | sort -un | paste -sd,
}

shield_gen() {
  sh_init
  local prof rw rb rc gl gb sshr scanb cf lock wl4 wl6 cf4 cf6 sshp open web_rules="" ct_ssh="" cf_rules="" lock_rule="" ct_web=""
  prof=$(cfg_get PROFILE balanced); cf=$(cfg_get CF_MODE 0); lock=$(cfg_get LOCKDOWN 0)
  case $prof in
    strict) rw=15; rb=30; rc=30; gl=150; gb=250; sshr=4; scanb=4;;
    attack) rw=8;  rb=16; rc=15; gl=80;  gb=120; sshr=3; scanb=3;;
    *)      rw=30; rb=60; rc=60; gl=300; gb=500; sshr=6; scanb=6;;
  esac
  wl4=$(wl_list | grep -v ':' | paste -sd,); wl6=$(wl_list | grep ':' | paste -sd,)
  cf4=$(grep -E '^[0-9.]+/[0-9]+$' "$CH/cf-v4.txt" 2>/dev/null | paste -sd,); cf6=$(grep -E '^[0-9a-fA-F:]+/[0-9]+$' "$CH/cf-v6.txt" 2>/dev/null | paste -sd,)
  sshp=$(ssh_ports | paste -sd,); sshp=${sshp:-22}; open=$(shield_open_ports); open=${open:-22,80,443}
  el() { [[ -n $1 ]] && printf 'elements = { %s }' "$1"; }

  if [[ $lock == 1 ]]; then lock_rule="tcp dport @ssh_ports counter drop"
  else
    [[ ${NO_CTCOUNT:-0} == 1 ]] || ct_ssh="tcp dport @ssh_ports ct state new add @cc_ssh4 { ip saddr ct count over 8 } counter drop
    tcp dport @ssh_ports ct state new add @cc_ssh6 { ip6 saddr ct count over 8 } counter drop"
    lock_rule="$ct_ssh
    tcp dport @ssh_ports ct state new add @m_ssh4 { ip saddr limit rate over ${sshr}/minute burst 5 packets } add @bl4 { ip saddr timeout 30m } log prefix \"CHARR-SSHFLOOD \" counter drop
    tcp dport @ssh_ports ct state new add @m_ssh6 { ip6 saddr limit rate over ${sshr}/minute burst 5 packets } add @bl6 { ip6 saddr timeout 30m } log prefix \"CHARR-SSHFLOOD \" counter drop
    tcp dport @ssh_ports accept"
  fi

  if [[ $cf == 1 && -n $cf4 ]]; then
    cf_rules="tcp dport @web_ports ip saddr @cf4 accept
    tcp dport @web_ports ip6 saddr @cf6 accept
    tcp dport @web_ports counter drop"
  else
    [[ ${NO_CTCOUNT:-0} == 1 ]] || ct_web="tcp dport @web_ports ct state new add @cc_web4 { ip saddr ct count over ${rc} } counter drop
    tcp dport @web_ports ct state new add @cc_web6 { ip6 saddr ct count over ${rc} } counter drop"
    web_rules="$ct_web
    tcp dport @web_ports ct state new add @m_web4 { ip saddr limit rate over ${rw}/second burst ${rb} packets } add @bl4 { ip saddr timeout 10m } counter drop
    tcp dport @web_ports ct state new add @m_web6 { ip6 saddr limit rate over ${rw}/second burst ${rb} packets } add @bl6 { ip6 saddr timeout 10m } counter drop
    tcp dport @web_ports ct state new limit rate over ${gl}/second burst ${gb} packets counter drop
    tcp dport @web_ports accept"
  fi

  cat >"$NFT_FILE" <<EOF
# CHARR//SHIELD — dibuat otomatis $(date '+%F %T') — profil: $prof — jangan edit manual (pakai menu)
table inet charr_shield
delete table inet charr_shield
table inet charr_shield {
  set wl4 { type ipv4_addr; flags interval; auto-merge; $(el "$wl4") }
  set wl6 { type ipv6_addr; flags interval; auto-merge; $(el "$wl6") }
  set cf4 { type ipv4_addr; flags interval; auto-merge; $(el "$cf4") }
  set cf6 { type ipv6_addr; flags interval; auto-merge; $(el "$cf6") }
  set bl4 { type ipv4_addr; flags dynamic,timeout; timeout 30m; size 65535; }
  set bl6 { type ipv6_addr; flags dynamic,timeout; timeout 30m; size 65535; }
  set m_scan4 { type ipv4_addr; flags dynamic,timeout; timeout 1m; size 65535; }
  set m_scan6 { type ipv6_addr; flags dynamic,timeout; timeout 1m; size 65535; }
  set m_ssh4 { type ipv4_addr; flags dynamic,timeout; timeout 1m; size 65535; }
  set m_ssh6 { type ipv6_addr; flags dynamic,timeout; timeout 1m; size 65535; }
  set m_web4 { type ipv4_addr; flags dynamic,timeout; timeout 1m; size 65535; }
  set m_web6 { type ipv6_addr; flags dynamic,timeout; timeout 1m; size 65535; }
  set cc_ssh4 { type ipv4_addr; flags dynamic; size 65535; }
  set cc_ssh6 { type ipv6_addr; flags dynamic; size 65535; }
  set cc_web4 { type ipv4_addr; flags dynamic; size 65535; }
  set cc_web6 { type ipv6_addr; flags dynamic; size 65535; }
  set ssh_ports { type inet_service; elements = { $sshp } }
  set web_ports { type inet_service; elements = { 80, 443 } }
  set open_tcp { type inet_service; elements = { $open } }

  chain input {
    type filter hook input priority -100; policy accept;
    iifname "lo" accept
    ct state invalid counter drop
    ip frag-off & 0x1fff != 0 counter drop
    tcp flags & (fin | syn | rst | psh | ack | urg) == 0 counter drop
    tcp flags & (fin | syn) == fin | syn counter drop
    tcp flags & (syn | rst) == syn | rst counter drop
    tcp flags & (fin | rst) == fin | rst counter drop
    tcp flags & (fin | ack) == fin counter drop
    tcp flags & (psh | ack) == psh counter drop
    tcp flags & (urg | ack) == urg counter drop
    tcp flags & (fin | syn | rst | psh | ack | urg) == fin | psh | urg counter drop
    ct state { established, related } accept
    ip saddr @wl4 accept
    ip6 saddr @wl6 accept
    ip saddr @bl4 counter drop
    ip6 saddr @bl6 counter drop
    icmp type echo-request limit rate 5/second burst 10 packets accept
    icmp type echo-request counter drop
    icmpv6 type echo-request limit rate 5/second burst 10 packets accept
    icmpv6 type echo-request counter drop
    $lock_rule
    $cf_rules
    $web_rules
    meta l4proto tcp ct state new tcp dport != @open_tcp add @m_scan4 { ip saddr limit rate over 6/minute burst ${scanb} packets } add @bl4 { ip saddr timeout 1h } log prefix "CHARR-SCAN " counter drop
    meta l4proto tcp ct state new tcp dport != @open_tcp add @m_scan6 { ip6 saddr limit rate over 6/minute burst ${scanb} packets } add @bl6 { ip6 saddr timeout 1h } log prefix "CHARR-SCAN " counter drop
  }
}
EOF
}

shield_unit() {
  local nftbin; nftbin=$(command -v nft)
  cat >/etc/systemd/system/charr-shield.service <<EOF
[Unit]
Description=CHARR shield (nftables anti-DDoS / anti-scan)
After=network-pre.target
Before=network.target
Wants=network-pre.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=$nftbin -f $NFT_FILE
ExecReload=$nftbin -f $NFT_FILE
ExecStop=-$nftbin delete table inet charr_shield

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload; systemctl enable charr-shield.service >/dev/null 2>&1
}

shield_apply() {
  need nft || run "install nftables" apti nftables || return 1
  local e; NO_CTCOUNT=${NO_CTCOUNT:-0}; shield_gen
  if ! e=$(nft -c -f "$NFT_FILE" 2>&1); then
    warn "validasi penuh gagal — coba tanpa ct-count (kernel cloud?)"; echo "$e" | head -3 | sed 's/^/    /'
    NO_CTCOUNT=1 shield_gen; e=$(nft -c -f "$NFT_FILE" 2>&1) || { err "ruleset gagal: $(head -2 <<<"$e")"; return 1; }
  fi
  nft -f "$NFT_FILE" || { err "gagal load ruleset"; return 1; }
  shield_unit; log "shield apply profile=$(cfg_get PROFILE balanced) cf=$(cfg_get CF_MODE 0) lock=$(cfg_get LOCKDOWN 0)"
}
shield_sync() { shield_on && shield_apply >/dev/null 2>&1; }

shield_sysctl() {
  local ram cm; ram=$(free -m | awk '/Mem:/{print $2}'); cm=$((ram*80)); ((cm<32768)) && cm=32768
  cat >/etc/sysctl.d/98-charr-shield.conf <<EOF
# CHARR//SHIELD — hardening kernel + anti flood
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 1024
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 3
net.core.somaxconn = 1024
net.core.netdev_max_backlog = 2000
net.ipv4.tcp_fin_timeout = 20
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_rfc1337 = 1
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_keepalive_intvl = 15
net.ipv4.conf.all.rp_filter = 2
net.ipv4.conf.default.rp_filter = 2
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
-net.netfilter.nf_conntrack_max = $cm
-net.netfilter.nf_conntrack_tcp_timeout_established = 7200
-net.netfilter.nf_conntrack_tcp_timeout_time_wait = 30
-net.netfilter.nf_conntrack_tcp_timeout_syn_recv = 30
EOF
  sysctl -q -p /etc/sysctl.d/98-charr-shield.conf >/dev/null 2>&1; ok "sysctl: syncookies, rp_filter, conntrack max=$cm, timeout ketat"
}

ngx_shield() {
  need nginx || { info "nginx belum ada — L7 shield dilewati"; return 0; }
  local prof rr rb rc f=/etc/nginx/conf.d/charr-shield.conf tpl t
  prof=$(cfg_get PROFILE balanced)
  case $prof in strict) rr=10; rb=40; rc=25;; attack) rr=5; rb=20; rc=15;; *) rr=20; rb=80; rc=50;; esac
  read -r -d '' tpl <<'EOF' || true
# CHARR//SHIELD L7 — profil @PROF@
map $http_user_agent $charr_bad_ua {
    default "";
    ~*(sqlmap|nikto|nmap|masscan|zgrab|wpscan|dirbuster|gobuster|nuclei|acunetix|havij|hydra|fimap|feroxbuster|whatweb|metasploit|nessus|openvas) $binary_remote_addr;
    "" $binary_remote_addr;
}
limit_req_zone $charr_bad_ua zone=charr_bad:5m rate=1r/m;
limit_req_zone $binary_remote_addr zone=charr_req:10m rate=@RR@r/s;
limit_conn_zone $binary_remote_addr zone=charr_conn:10m;
limit_req zone=charr_bad burst=1 nodelay;
limit_req zone=charr_req burst=@RB@ nodelay;
limit_conn charr_conn @RC@;
limit_req_status 429;
limit_conn_status 429;
client_body_timeout 10s;
client_header_timeout 10s;
send_timeout 15s;
reset_timedout_connection on;
client_header_buffer_size 2k;
large_client_header_buffers 4 8k;
@TOKENS@
EOF
  tpl=${tpl//@PROF@/$prof}; tpl=${tpl//@RR@/$rr}; tpl=${tpl//@RB@/$rb}; tpl=${tpl//@RC@/$rc}
  cp -a "$f" "$f.bak" 2>/dev/null
  printf '%s\n' "${tpl//@TOKENS@/server_tokens off;}" >"$f"
  if ! t=$(nginx -t 2>&1); then
    printf '%s\n' "${tpl//@TOKENS@/}" >"$f"
    t=$(nginx -t 2>&1) || { err "nginx -t gagal — rollback L7 shield"; echo "$t" | head -3 | sed 's/^/    /'
      [[ -f $f.bak ]] && mv "$f.bak" "$f" || rm -f "$f"; return 1; }
  fi
  systemctl reload nginx && ok "nginx L7 shield: ${rr}r/s burst ${rb}, ${rc} koneksi/IP, timeout ketat, blok UA scanner"
}

shield_f2b() {
  need fail2ban-client || run "install fail2ban" apti fail2ban || return 1
  local f=/etc/fail2ban/jail.d/charr-shield.local ign
  ign="127.0.0.1/8 ::1 $(wl_list | paste -sd' ')"
  systemctl enable --now fail2ban >/dev/null 2>&1; sleep 1
  { printf '[DEFAULT]\nignoreip = %s\nbanaction = nftables\nbanaction_allports = nftables[type=allports]\n\n' "$ign"
    if [[ -e /var/log/nginx/error.log ]]; then
      printf '[nginx-limit-req]\nenabled = true\nbackend = auto\nport = http,https\nlogpath = /var/log/nginx/*error.log\nmaxretry = 15\nfindtime = 60\nbantime = 15m\n\n'
      printf '[nginx-botsearch]\nenabled = true\nbackend = auto\nport = http,https\nlogpath = /var/log/nginx/*access.log\nmaxretry = 3\nfindtime = 10m\nbantime = 2h\n\n'
    fi
    [[ -f /var/log/fail2ban.log ]] && printf '[recidive]\nenabled = true\nbackend = auto\nlogpath = /var/log/fail2ban.log\nbantime = 1w\nfindtime = 1d\nmaxretry = 3\n'
  } >"$f"
  systemctl restart fail2ban; sleep 2
  if fail2ban-client ping >/dev/null 2>&1; then ok "fail2ban jails: $(fail2ban-client status 2>/dev/null | awk -F: '/Jail list/{gsub(/[ \t]/,"",$2); print $2}')"
  else err "fail2ban gagal start dengan jail baru — rollback"; rm -f "$f"; systemctl restart fail2ban; return 1; fi
}

# ─────────────── SSH LANE ───────────────
lane_sshd() {
  need sshd || { warn "openssh-server gak ada"; return 1; }
  local f=/etc/ssh/sshd_config.d/00-charr-lane.conf
  mkdir -p /etc/ssh/sshd_config.d
  printf '# CHARR anti-flood sshd\nMaxStartups 10:30:60\nLoginGraceTime 20\nMaxAuthTries 3\nClientAliveInterval 60\nClientAliveCountMax 3\n' >"$f"
  if sshd -t 2>/dev/null; then systemctl reload ssh 2>/dev/null || systemctl reload sshd 2>/dev/null; ok "sshd anti-flood (MaxStartups 10:30:60, grace 20s)"
  else err "sshd config invalid — rollback"; rm -f "$f"; return 1; fi
}

svc_limit() { # unit oom high% max%
  local u=$1.service oom=$2 hi=$3 mx=$4 ram d; systemctl cat "$u" >/dev/null 2>&1 || return 0
  ram=$(free -m | awk '/Mem:/{print $2}'); d=/etc/systemd/system/$u.d; mkdir -p "$d"
  { echo "[Service]"; echo "OOMScoreAdjust=$oom"; echo "Restart=on-failure"; echo "RestartSec=3"
    ((hi>0)) && echo "MemoryHigh=$((ram*hi/100))M"; ((mx>0)) && echo "MemoryMax=$((ram*mx/100))M"; } >"$d/50-charr-limits.conf"
  ok "limit $u — OOM +$oom, MemoryHigh ${hi}%, MemoryMax ${mx}%, auto-restart"
}

lane_earlyoom() {
  run "install earlyoom" apti earlyoom || return 1
  local f=/etc/default/earlyoom
  printf 'EARLYOOM_ARGS="-r 3600 -m 4 -s 8 --avoid (^|/)(sshd|systemd|systemd-logind|systemd-journald|fail2ban-server|dbus-daemon|earlyoom)$ --prefer (^|/)(php-fpm[0-9.]*|apache2|node|python3?|java)$"\n' >"$f"
  systemctl enable earlyoom >/dev/null 2>&1; systemctl restart earlyoom
  svc_active earlyoom && ok "earlyoom aktif — bunuh pemakan RAM (php/node dulu) SEBELUM server freeze; sshd dilindungi" || err "earlyoom gagal start (cek: systemctl status earlyoom)"
}

lane_resources() {
  section "SSH LANE // RESERVASI RESOURCE"
  local ram ml; ram=$(free -m | awk '/Mem:/{print $2}'); ml=$((ram*8/100)); ((ml>128)) && ml=128; ((ml<32)) && ml=32
  run "user.slice (sesi SSH): CPU/IO weight 800, MemoryLow ${ml}M" systemctl set-property user.slice CPUWeight=800 IOWeight=800 MemoryLow="${ml}M"
  local v; v=$(php_ver)
  svc_limit nginx 300 0 25; [[ -n $v ]] && svc_limit "php${v}-fpm" 600 40 55; svc_limit mariadb 200 35 50
  systemctl daemon-reload
  info "sshd sendiri sudah kebal OOM (OpenSSH set oom_score_adj -1000 utk listener)"
  confirm "Restart nginx/php-fpm/mariadb sekarang biar limit aktif (downtime beberapa detik)?" &&
    { for u in nginx "php${v}-fpm" mariadb; do systemctl try-restart "$u" 2>/dev/null; done; ok "service di-restart"; }
  lane_earlyoom
}

lane_whitelist() {
  while true; do
    section "SSH LANE // WHITELIST ADMIN"
    echo "  ${D}IP whitelist BEBAS dari semua rate-limit/blacklist Shield & gak akan di-ban fail2ban.${N}"
    local i=0; while read -r ip; do [[ -n $ip ]] || continue; printf "  ${G}%2d)${N} %s\n" $((++i)) "$ip"; done < <(wl_list)
    ((i)) || echo "  (kosong)"
    echo "  ${G}[a]${N} tambah IP sesi ini ($(my_ssh_ip))  ${G}[m]${N} tambah manual  ${G}[d]${N} hapus  ${G}[0]${N} balik"
    local c ip; read -rp "  ${C}»${N} " c
    case $c in
      a) [[ -n $(my_ssh_ip) ]] && wl_add "$(my_ssh_ip)" && ok "ditambah" && shield_sync || err "IP sesi gak terdeteksi (jalankan via SSH)";;
      m) read -rp "  IP/CIDR: " ip; wl_add "$ip" && ok "ditambah" && shield_sync;;
      d) read -rp "  IP/CIDR yg dihapus: " ip; wl_del "$ip"; ok "dihapus"; shield_sync;;
      0) return;;
    esac
  done
}

lane_lockdown() {
  if [[ $(cfg_get LOCKDOWN 0) == 1 ]]; then cfg_set LOCKDOWN 0; shield_apply && ok "lockdown OFF — SSH terbuka lagi (tetap rate-limited)"; return; fi
  wl_list | grep -q . || { err "whitelist kosong — tambah IP admin dulu"; return; }
  local me a; me=$(my_ssh_ip)
  [[ -n $me ]] && ! wl_list | grep -qxF "$me" && warn "IP sesi ini ($me) BELUM di whitelist → kamu bisa ke-lock!"
  cat <<EOF
  ${BD}LOCKDOWN${N}: port SSH hanya bisa diakses dari IP whitelist. IP lain di-drop di kernel
  (server berat/diserang pun SSH-mu tetap mulus). Risiko: kalau IP-mu berubah, kamu ke-lock
  (solusi: konsol/VNC dari panel VPS). Ada ${BD}dead-man switch${N}: auto-revert 120 detik kalau gak dikonfirmasi.
EOF
  confirm "Aktifkan lockdown?" || return
  cfg_set LOCKDOWN 1; shield_apply || { cfg_set LOCKDOWN 0; return; }
  touch /run/charr-lockdown.pending
  cat >"$CH/revert-lockdown.sh" <<EOF
#!/bin/bash
sleep 120
[ -f /run/charr-lockdown.pending ] || exit 0
rm -f /run/charr-lockdown.pending
sed -i 's/^LOCKDOWN=.*/LOCKDOWN=0/' $CFG
bash "$SELF" shield-reload
EOF
  setsid nohup bash "$CH/revert-lockdown.sh" >/dev/null 2>&1 &
  echo "  buka terminal BARU dan tes SSH dari IP whitelist, lalu konfirmasi di sini."
  read -rp "  ketik ${BD}OK${N} dalam 120 detik: " -t 120 a
  if [[ $a == OK ]]; then rm -f /run/charr-lockdown.pending; ok "lockdown PERMANEN"; log "ssh lockdown on"; else warn "gak dikonfirmasi — auto-revert dijalankan"; fi
}

lane_port_add() {
  systemctl is-active --quiet ssh.socket 2>/dev/null && { err "ssh.socket aktif (socket activation) — atur via 'systemctl edit ssh.socket'"; return; }
  local np p f=/etc/ssh/sshd_config.d/01-charr-port.conf cur
  read -rp "  port SSH tambahan (1024-65535): " np; [[ $np =~ ^[0-9]+$ ]] && ((np>=1024 && np<=65535)) || { err "invalid"; return; }
  ss -tlnH "sport = :$np" 2>/dev/null | grep -q . && { err "port $np dipakai proses lain"; return; }
  cur=$(ssh_ports | grep -vx "$np" | paste -sd' ')
  { echo "# CHARR ssh lane"; for p in $cur $np; do echo "Port $p"; done | sort -u; } >"$f"
  sshd -t 2>/dev/null || { err "sshd config invalid — rollback"; rm -f "$f"; return; }
  need ufw && fw_active && ufw limit "$np/tcp" comment 'SSH lane' >/dev/null
  systemctl reload ssh 2>/dev/null || systemctl reload sshd; sleep 1
  ss -tlnH "sport = :$np" | grep -q . && ok "sshd listen di $np (port lama tetap aktif)" || err "sshd belum listen di $np"
  warn "TES dulu: ssh -p $np user@server (terminal baru). Baru cabut port lama."
  shield_sync; log "ssh port add $np"
}

lane_port_remove() {
  local f=/etc/ssh/sshd_config.d/01-charr-port.conf p rm_ left; local -a P
  [[ -f $f ]] || { warn "belum ada port tambahan dari CHARR"; return; }
  mapfile -t P < <(ssh_ports); ((${#P[@]}>1)) || { err "cuma 1 port — gak bisa dicabut"; return; }
  echo "  port aktif: ${P[*]}"; read -rp "  port yang dicabut: " rm_
  printf '%s\n' "${P[@]}" | grep -qx "$rm_" || { err "bukan port aktif"; return; }
  left=$(printf '%s\n' "${P[@]}" | grep -vx "$rm_")
  { echo "# CHARR ssh lane"; while read -r p; do echo "Port $p"; done <<<"$left"; } >"$f"
  sshd -t 2>/dev/null || { err "sshd config invalid"; return; }
  systemctl reload ssh 2>/dev/null || systemctl reload sshd; sleep 1
  if ss -tlnH "sport = :$rm_" | grep -q .; then
    warn "port $rm_ masih listen (didefinisikan di sshd_config utama?)"
  else
    ok "port $rm_ dicabut — hapus rule UFW-nya di Firewall Manager"
    if confirm "Pasang endlessh tarpit di port $rm_ (bot yang masih nyoba nyerang situ buang-buang waktu doang)?"; then
      need endlessh || run "install endlessh" apti endlessh
      printf 'Port %s\nDelay 10000\nMaxLineLength 32\nMaxClients 4096\nLogLevel 0\n' "$rm_" >/etc/endlessh/config
      mkdir -p /etc/systemd/system/endlessh.service.d
      printf '[Service]\nAmbientCapabilities=CAP_NET_BIND_SERVICE\nCapabilityBoundingSet=CAP_NET_BIND_SERVICE\n' >/etc/systemd/system/endlessh.service.d/override.conf
      systemctl daemon-reload; systemctl enable --now endlessh >/dev/null 2>&1; systemctl restart endlessh; sleep 1
      ss -tlnp 2>/dev/null | grep -q ":$rm_ .*endlessh" && ok "endlessh nge-tarpit port $rm_" || warn "endlessh belum kedengeran — cek: journalctl -u endlessh"
      fw_active && ufw allow "$rm_/tcp" comment 'endlessh tarpit' >/dev/null
    fi
  fi
  shield_sync; log "ssh port remove $rm_"
}

lane_menu() {
  while true; do
    section "SSH LANE — jalur khusus admin"
    printf "  whitelist: ${BD}%s${N}  | lockdown: ${BD}%s${N}  | port SSH: ${BD}%s${N}\n" "$(wl_list | paste -sd' ' | sed 's/^$/(kosong)/')" "$([[ $(cfg_get LOCKDOWN 0) == 1 ]] && echo ON || echo off)" "$(ssh_ports | paste -sd' ')"
    cat <<EOF
  ${G}[1]${N} Whitelist IP admin (bebas limit)     ${G}[5]${N} Reservasi CPU/RAM sesi SSH + limit web/db + earlyoom
  ${G}[2]${N} ${BD}Lockdown${N} SSH: hanya whitelist (dead-man) ${G}[6]${N} Anti-flood sshd
  ${G}[3]${N} Tambah port SSH (transisi aman)       ${G}[7]${N} ${BD}Tailscale${N} (mesh privat, gak butuh IP tetap)
  ${G}[4]${N} Cabut port SSH                        ${G}[0]${N} Balik
EOF
    local c; read -rp "  ${C}»${N} " c
    case $c in
      1) lane_whitelist;;
      2) lane_lockdown; pause;;
      3) lane_port_add; pause;;
      4) lane_port_remove; pause;;
      5) lane_resources; pause;;
      6) lane_sshd; pause;;
      7) lane_tailscale; pause;;
      0) return;;
    esac
  done
}

# ─────────────── Cloudflare-only mode ───────────────
cf_enable() {
  section "SHIELD // CLOUDFLARE-ONLY MODE"
  cat <<EOF
  Serangan volumetrik (banjir bandwidth) TIDAK bisa dihentikan di server 1 vCPU/853MB —
  paket sudah menyumbat jalur sebelum sampai ke sini. Solusi nyata: proxy lewat Cloudflare.
  Mode ini: port 80/443 HANYA menerima IP Cloudflare (+ whitelist admin), IP asli pengunjung
  dipulihkan di nginx (CF-Connecting-IP) supaya rate-limit tetap per-pengunjung.
  ${R}Syarat:${N} domain sudah pakai proxy Cloudflare (awan oranye). Kalau belum, situs MATI dari luar.
EOF
  confirm "Aktifkan?" || return
  need curl || run "install curl" apti curl
  curl -fsS -m 15 https://www.cloudflare.com/ips-v4 -o "$CH/cf-v4.txt" && curl -fsS -m 15 https://www.cloudflare.com/ips-v6 -o "$CH/cf-v6.txt" ||
    { err "gagal download daftar IP Cloudflare"; return 1; }
  grep -qE '^[0-9.]+/[0-9]+$' "$CH/cf-v4.txt" || { err "daftar IP Cloudflare aneh — dibatalin"; return 1; }
  if need nginx; then
    { echo "# CHARR — restore IP asli dari Cloudflare"; grep -E '^[0-9a-fA-F:.]+/[0-9]+$' "$CH/cf-v4.txt" "$CH/cf-v6.txt" | cut -d: -f2- | sed 's/^/set_real_ip_from /; s/$/;/'
      echo "real_ip_header CF-Connecting-IP;"; echo "real_ip_recursive on;"; } >/etc/nginx/conf.d/charr-cloudflare-realip.conf
    nginx_reload_safe || { rm -f /etc/nginx/conf.d/charr-cloudflare-realip.conf; return 1; }
  fi
  cfg_set CF_MODE 1; shield_apply && ok "CF-only mode aktif" && log "cf mode on"
}
cf_disable() {
  cfg_set CF_MODE 0; rm -f /etc/nginx/conf.d/charr-cloudflare-realip.conf; need nginx && nginx_reload_safe; shield_apply && ok "CF-only mode dimatikan (web terbuka langsung dengan rate-limit)"; log "cf mode off"
}

# ─────────────── blacklist, status, radar ───────────────
bl_list() { local s; for s in bl4 bl6; do nft list set inet charr_shield $s 2>/dev/null | grep -oE '[0-9a-fA-F:.]+ (timeout [0-9a-z]+ )?expires [0-9a-z]+'; done; }
bl_menu() {
  while true; do
    section "SHIELD // BLACKLIST DINAMIS"
    local l; l=$(bl_list); [[ -n $l ]] && echo "$l" | sed 's/^/  /' || ok "kosong — belum ada IP yang diblok"
    echo "  ${G}[b]${N} ban manual  ${G}[u]${N} unban IP  ${G}[c]${N} kosongkan semua  ${G}[0]${N} balik"
    local c ip s; read -rp "  ${C}»${N} " c
    case $c in
      b) read -rp "  IP: " ip; wl_valid "$ip" || { err invalid; continue; }; s=bl4; [[ $ip == *:* ]] && s=bl6
         nft add element inet charr_shield $s "{ $ip timeout 1d }" && ok "diblok 1 hari: $ip";;
      u) read -rp "  IP: " ip; s=bl4; [[ $ip == *:* ]] && s=bl6; nft delete element inet charr_shield $s "{ $ip }" && ok "di-unban: $ip";;
      c) nft flush set inet charr_shield bl4; nft flush set inet charr_shield bl6; ok "blacklist dikosongkan";;
      0) return;;
    esac
  done
}

shield_status() {
  section "SHIELD // STATUS"
  if shield_on; then ok "nftables shield ${G}${BD}AKTIF${N} — profil: ${BD}$(cfg_get PROFILE balanced)${N}"; else warn "nftables shield ${R}${BD}BELUM aktif${N} → jalankan FORTRESS"; fi
  [[ $(cfg_get LOCKDOWN 0) == 1 ]] && ok "SSH lockdown: ON (hanya whitelist)" || info "SSH lockdown: off"
  [[ $(cfg_get CF_MODE 0) == 1 ]] && ok "Cloudflare-only: ON" || info "Cloudflare-only: off (web terbuka langsung)"
  info "whitelist admin: $(wl_list | paste -sd' ' | sed 's/^$/(kosong)/')   port SSH: $(ssh_ports | paste -sd' ')"
  info "IP terblokir sekarang: $(bl_list | wc -l)"
  [[ $(sysctl -n net.ipv4.tcp_syncookies 2>/dev/null) == 1 ]] && ok "SYN cookies ON" || warn "SYN cookies off"
  [[ -f /etc/nginx/conf.d/charr-shield.conf ]] && ok "nginx L7 shield terpasang" || warn "nginx L7 shield belum ada"
  svc_active fail2ban && ok "fail2ban: $(fail2ban-client status 2>/dev/null | awk -F: '/Jail list/{gsub(/[ \t]/,"",$2); print $2}')" || warn "fail2ban mati"
  svc_active earlyoom && ok "earlyoom aktif (anti-freeze)" || warn "earlyoom belum aktif"
  info "user.slice CPUWeight=$(systemctl show user.slice -p CPUWeight --value 2>/dev/null)  (sesi SSH diprioritaskan; default 100)"
  [[ -z $(swapon --show --noheadings 2>/dev/null) ]] && warn "swap TIDAK ada — Swap & Memory → AUTO" || ok "swap: $(swapon --show=SIZE --noheadings | paste -sd' ')"
  [[ -f /run/charr-lockdown.pending ]] && warn "dead-man switch lockdown masih PENDING"
}

shield_radar() {
  local k cc cm pct syn est tw; tput civis; clear
  while true; do
    cc=$(cat /proc/sys/net/netfilter/nf_conntrack_count 2>/dev/null || echo 0); cm=$(cat /proc/sys/net/netfilter/nf_conntrack_max 2>/dev/null || echo 1); pct=$((cc*100/(cm>0?cm:1)))
    syn=$(ss -tnH state syn-recv 2>/dev/null | wc -l); est=$(ss -tnH state established 2>/dev/null | wc -l); tw=$(ss -tnH state time-wait 2>/dev/null | wc -l)
    printf '\e[H'
    printf "${BD}${R}CHARR//RADAR${N} ${D}%s • profil %s • [q] keluar${N}\e[K\n" "$(date '+%F %T')" "$(cfg_get PROFILE balanced)"
    printf "${D}$(rep '─' 72)${N}\e[K\n"
    printf " CPU  %s   RAM %s\e[K\n" "$(bar "$(awk '{print int($1*100/'"$(nproc)"')}' /proc/loadavg)" 20)" "$(bar "$(mem_pct)" 20)"
    printf " CONNTRACK %s ${D}%s/%s${N}\e[K\n" "$(bar "$pct" 30)" "$cc" "$cm"
    printf " ESTAB ${BD}%s${N}  SYN_RECV ${BD}%s${N} ${D}(banyak = SYN flood)${N}  TIME_WAIT ${BD}%s${N}\e[K\n" "$est" "$syn" "$tw"
    printf " IP diblok: ${BD}%s${N}   jail f2b banned: ${BD}%s${N}\e[K\n" "$(bl_list | wc -l)" "$(fail2ban-client status 2>/dev/null | grep -c . )"
    printf "${D}$(rep '─' 72)${N}\e[K\n ${BD}TOP SUMBER KONEKSI${N}\e[K\n"
    while read -r c ip; do printf "  %6s  %s\e[K\n" "$c" "$ip"; done < <(ss -tnH 2>/dev/null | awk '$1=="ESTAB"||$1=="SYN-RECV"{ip=$5; sub(/:[0-9]+$/,"",ip); c[ip]++} END{for(i in c) print c[i], i}' | sort -rn | head -7)
    printf "${D}$(rep '─' 72)${N}\e[K\n ${BD}RULE YANG SEDANG MENJATUHKAN PAKET${N}\e[K\n"
    nft list chain inet charr_shield input 2>/dev/null | awk '/counter packets/ {for(i=1;i<=NF;i++) if($i=="packets" && $(i+1)>0){ r=$0; sub(/^[ \t]+/,"",r); sub(/counter packets.*/,"",r); printf "  %8s pkt  %s\n",$(i+1),substr(r,1,62)}}' | sort -rn | head -6 | while read -r l; do printf "%s\e[K\n" "$l"; done
    printf '\e[J'
    read -rsn1 -t 2 k && [[ $k == q || $k == Q ]] && break
  done
  tput cnorm; clear
}

shield_profile() {
  section "SHIELD // PROFIL"
  cat <<EOF
  ${G}1${N} balanced — aman utk publik/NAT (limit web 30 koneksi baru/dtk/IP, SSH 6/menit)
  ${Y}2${N} strict   — lebih ketat (15/dtk, SSH 4/menit)
  ${R}3${N} attack   — mode darurat saat diserang (8/dtk, global cap 80/dtk, SSH 3/menit)
  Catatan: pengunjung di balik CGNAT/kantor share 1 IP → jangan terlalu ketat.
EOF
  local c p; read -rp "  pilih [1-3]: " c
  case $c in 1) p=balanced;; 2) p=strict;; 3) p=attack;; *) return;; esac
  cfg_set PROFILE "$p"; shield_apply && ok "profil nftables: $p"; ngx_shield; log "shield profile $p"
}

shield_remove() {
  confirm "Hapus SEMUA lapisan Shield (nft, nginx L7, jail f2b, sysctl)?" || return
  nft delete table inet charr_shield 2>/dev/null; systemctl disable --now charr-shield.service >/dev/null 2>&1; rm -f /etc/systemd/system/charr-shield.service
  rm -f /etc/nginx/conf.d/charr-shield.conf /etc/nginx/conf.d/charr-cloudflare-realip.conf; need nginx && nginx_reload_safe
  rm -f /etc/fail2ban/jail.d/charr-shield.local; svc_active fail2ban && systemctl restart fail2ban
  rm -f /etc/sysctl.d/98-charr-shield.conf /etc/ssh/sshd_config.d/00-charr-lane.conf; cfg_set LOCKDOWN 0; cfg_set CF_MODE 0
  systemctl reload ssh 2>/dev/null; systemctl daemon-reload; ok "Shield dihapus (swap, earlyoom & limit service dibiarkan)"; log "shield removed"
}

shield_fortress() {
  section "⚡ FORTRESS — hardening berlapis (1 klik)"
  cat <<EOF
  ${BD}Lapisan:${N}
   1 nftables shield  : buang paket cacat/scan (NULL/XMAS/FIN), deteksi port-scan → blacklist otomatis,
                        rate-limit + connlimit per IP (SYN/HTTP flood), rate-limit ICMP, SSH anti brute-flood
   2 kernel sysctl    : SYN cookies, conntrack ketat, rp_filter, anti-redirect
   3 nginx L7         : limit req/conn per IP, timeout anti-slowloris, blok UA scanner (sqlmap/nikto/nmap…)
   4 fail2ban         : jail nginx-limit-req, botsearch, recidive (repeat offender 1 minggu)
   5 SSH lane         : whitelist admin bebas limit, MaxStartups, sesi SSH diprioritaskan CPU/IO,
                        web/db dibatasi MemoryMax + auto-restart, earlyoom (anti-freeze)
EOF
  confirm "Pasang semua lapisan?" || return
  sh_init
  run "update index paket" apt-get update
  run "install nftables fail2ban earlyoom curl" apti nftables fail2ban earlyoom curl ca-certificates || return
  if need ufw && ! fw_active; then confirm "UFW belum aktif — setup wizard dulu (SSH + web)?" && fw_wizard
  elif ! need ufw; then confirm "UFW belum ada — install + wizard?" && { run "install ufw" apti ufw; fw_wizard; }; fi
  local me p; me=$(my_ssh_ip)
  if [[ -n $me ]] && ! wl_list | grep -qxF "$me"; then confirm "Whitelist IP sesi ini ($me) sebagai jalur admin?" && { wl_add "$me"; ok "whitelist: $me"; }; fi
  ask "profil (balanced/strict)" balanced; p=$REPLY; [[ $p =~ ^(balanced|strict)$ ]] || p=balanced; cfg_set PROFILE "$p"
  shield_apply && ok "1/5 nftables shield aktif"
  shield_sysctl
  ngx_shield
  shield_f2b
  lane_sshd
  lane_resources
  [[ -z $(swapon --show --noheadings 2>/dev/null) ]] && { warn "belum ada swap!"; swap_auto; }
  echo; shield_status
  cat <<EOF

  ${BD}Uji dari mesin LAIN (bukan server ini):${N}
    nmap -sS -p 1-2000 <IP-server>   → setelah ±6 port tak-terbuka, IP-mu masuk blacklist (cek Radar)
    Pantau live: sudo charr shield → Attack Radar
  ${Y}Jujur:${N} banjir bandwidth (volumetrik) hanya bisa ditahan upstream → pakai Cloudflare + menu CF-only mode.
  Buka port baru via ufw manual? jalankan Shield → Apply supaya tidak dianggap scan.
EOF
}

shield_menu() {
  while true; do
    shield_status
    section "SHIELD — Anti-DDoS / Anti-Scan"
    cat <<EOF
  ${G}[1]${N} ${BD}⚡ FORTRESS${N} — pasang semua lapisan        ${G}[9]${N}  Sysctl saja
  ${G}[2]${N} Profil (balanced / strict / attack)           ${G}[10]${N} nginx L7 saja
  ${G}[3]${N} ${BD}SSH Lane${N} (whitelist, lockdown, tailscale, port)  ${G}[11]${N} Fail2ban jails saja
  ${G}[4]${N} Blacklist dinamis (lihat/ban/unban)           ${D}── lanjutan / opsional ──${N}
  ${G}[5]${N} Cloudflare-only mode ON (IP allowlist)        ${G}[12]${N} WAF ModSecurity
  ${G}[6]${N} Cloudflare-only mode OFF                      ${G}[13]${N} AppArmor nginx (eksperimental)
  ${G}[7]${N} Attack Radar (live)                           ${G}[14]${N} Cloudflare Tunnel (0 port terbuka)
  ${G}[8]${N} Apply ulang / sync port terbuka                ${Y}[15]${N} Emergency Stop
                                                          ${R}[16]${N} Hapus Shield   ${G}[0]${N} Balik
EOF
    local c; read -rp "  ${C}»${N} " c
    case $c in
      1) shield_fortress; pause;;
      2) shield_profile; pause;;
      3) lane_menu;;
      4) shield_on && bl_menu || { warn "shield belum aktif"; pause; };;
      5) cf_enable; pause;;
      6) cf_disable; pause;;
      7) shield_on && shield_radar || { warn "shield belum aktif"; pause; };;
      8) shield_apply && ok "ruleset di-apply ulang"; pause;;
      9) shield_sysctl; pause;;
      10) ngx_shield; pause;;
      11) shield_f2b; pause;;
      12) waf_toggle; pause;;
      13) apparmor_setup; pause;;
      14) cf_tunnel_setup; pause;;
      15) shield_emergency_stop; pause;;
      16) shield_remove; pause;;
      0) return;;
    esac
  done
}

dx_shield() {
  local ram sw; ram=$(free -m | awk '/Mem:/{print $2}'); sw=$(free -m | awk '/Swap:/{print $2}')
  ((ram<2048 && sw==0)) && fd_add WARN "RAM ${ram}MB tanpa swap" "risiko OOM/hang — Swap & Memory → AUTO" "swap_auto yes"
  if ss -ltnH 'sport = :80' 2>/dev/null | grep -q . || ss -ltnH 'sport = :443' 2>/dev/null | grep -q .; then
    shield_on || fd_add WARN "web terbuka tapi Shield anti-DDoS/scan belum aktif" "Security Center → Shield → FORTRESS"
  fi
  shield_on && ! svc_active charr-shield && fd_add INFO "shield aktif di kernel tapi belum persist saat reboot" "" "systemctl enable --now charr-shield.service"
}

# ═══════════════════════════════════════════════════════════════════
#  v1.3 — EXTRA HARDENING (diadaptasi dari modul "Tumbal Wizard")
#  Catatan adaptasi ada di jawaban chat — versi di sini disesuaikan
#  buat SATU server produksi (bukan pola tumbal/bastion 2-server),
#  dipasang dalam mode complain/opsional & rollback otomatis.
# ═══════════════════════════════════════════════════════════════════

# ── SSH lewat Tailscale (mesh privat, gak butuh IP publik statis) ──
lane_tailscale() {
  section "SSH LANE // TAILSCALE (mesh privat)"
  cat <<EOF
  Beda dari whitelist/lockdown (yang berbasis IP publik kamu): Tailscale bikin IP
  privat yang cuma bisa dipanggil dari device yang login ke akun Tailscale yang sama.
  Gak lewat internet publik sama sekali → jalur ini tetep tembus walau server lagi
  diserang/overload berat, dan gak ke-lock walau IP rumah/kampus kamu ganti-ganti.
  ${D}Catatan jujur: tetep siapin akses konsol dari panel VPS sebagai cadangan kalau
  akun Tailscale kamu sendiri gak bisa diakses.${N}
EOF
  if need tailscale; then ok "tailscale sudah terinstall"
  else
    confirm "Install tailscale?" || return
    run "install tailscale" bash -c 'curl -fsSL https://tailscale.com/install.sh | sh'
  fi
  need tailscale || { err "instalasi gagal"; return; }
  if tailscale status >/dev/null 2>&1; then ok "tailscale sudah aktif"
  else
    info "link login bakal muncul di bawah — buka di browser buat approve device ini"
    confirm "Sekalian aktifkan Tailscale SSH (auth SSH lewat identitas Tailscale, port openssh biasa gak kepake buat jalur ini)?" && REPLY_TS=--ssh || REPLY_TS=
    tailscale up $REPLY_TS 2>&1 | tee -a "$LOG"
  fi
  sleep 1; local tip; tip=$(tailscale ip -4 2>/dev/null)
  if [[ -n $tip ]]; then
    ok "IP tailscale server ini: ${BD}$tip${N}"
    info "dari device lain yang login tailscale: ssh $(whoami)@$tip"
    wl_add "$tip" 2>/dev/null
  else warn "belum dapat IP tailscale — cek: tailscale status"; fi
  log "lane tailscale up"
}

# ── WAF (ModSecurity + OWASP CRS) — opsional, ada risiko false-positive ──
waf_status() { grep -q 'modsecurity on;' /etc/nginx/nginx.conf 2>/dev/null; }
waf_install() {
  section "SHIELD // WAF (ModSecurity + OWASP CRS)"
  nginx_install || return
  cat <<EOF
  ${Y}Perlu diketahui:${N} WAF bisa nge-blok request yang SAH (form upload, API aneh,
  payload gede) kalau rule-nya ketat. Habis dipasang, PANTAU log 1-2 hari
  (menu Log Explorer → Nginx error log) sebelum bener-bener santai.
EOF
  confirm "Install & aktifkan sekarang?" || return
  dpkg -s libnginx-mod-http-modsecurity >/dev/null 2>&1 || run "install modsecurity + CRS" apti libnginx-mod-http-modsecurity modsecurity-crs || return
  mkdir -p /etc/nginx/modsec
  if [[ ! -f /etc/nginx/modsec/modsecurity.conf ]]; then
    local c src=""
    for c in /usr/share/doc/libnginx-mod-http-modsecurity/examples/modsecurity.conf /etc/modsecurity/modsecurity.conf-recommended; do
      [[ -f $c ]] && { src=$c; break; }
    done
    [[ -n $src ]] && cp "$src" /etc/nginx/modsec/modsecurity.conf
  fi
  [[ -f /etc/nginx/modsec/modsecurity.conf ]] || { err "modsecurity.conf gak ketemu — cek: dpkg -L libnginx-mod-http-modsecurity | grep conf"; return; }
  sed -i 's/SecRuleEngine DetectionOnly/SecRuleEngine On/' /etc/nginx/modsec/modsecurity.conf
  [[ -f /usr/share/modsecurity-crs/crs-setup.conf ]] || cp /usr/share/modsecurity-crs/crs-setup.conf.example /usr/share/modsecurity-crs/crs-setup.conf 2>/dev/null
  printf 'Include /etc/nginx/modsec/modsecurity.conf\nInclude /usr/share/modsecurity-crs/crs-setup.conf\nInclude /usr/share/modsecurity-crs/rules/*.conf\n' >/etc/nginx/modsec/main.conf
  cp -a /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak-charr 2>/dev/null
  grep -q 'modsecurity on;' /etc/nginx/nginx.conf 2>/dev/null ||
    sed -i '/http {/a\    modsecurity on;\n    modsecurity_rules_file /etc/nginx/modsec/main.conf;' /etc/nginx/nginx.conf
  if nginx_reload_safe; then
    ok "WAF aktif"; info "tes: curl 'http://127.0.0.1/?x=<script>alert(1)</script>'  (harusnya 403)"
    cfg_set WAF 1; log "waf on"
  else
    err "nginx gagal reload — WAF dibatalin, rollback"; cp -a /etc/nginx/nginx.conf.bak-charr /etc/nginx/nginx.conf 2>/dev/null; nginx_reload_safe
  fi
}
waf_remove() {
  sed -i '/modsecurity on;/d; /modsecurity_rules_file/d' /etc/nginx/nginx.conf 2>/dev/null
  nginx_reload_safe && ok "WAF dimatiin"; cfg_set WAF 0; log "waf off"
}
waf_toggle() { waf_status && { confirm "WAF aktif — matiin?" && waf_remove; } || waf_install; }

# ── AppArmor confinement nginx — eksperimental, mulai dari complain mode ──
apparmor_setup() {
  section "SHIELD // APPARMOR NGINX (eksperimental)"
  need aa-status || { confirm "Install apparmor + apparmor-utils?" && run "install apparmor" apti apparmor apparmor-utils || return; }
  systemctl is-active --quiet apparmor || run "aktifkan apparmor" systemctl enable --now apparmor
  local prof=/etc/apparmor.d/usr.sbin.nginx v sock
  if [[ ! -f $prof ]]; then
    info "belum ada profile nginx — bikin profile dasar (cakupan umum: static+PHP-FPM+SSL+letsencrypt)"
    v=$(php_ver); sock=/run/php/php*.sock
    cat >"$prof" <<EOK
#include <tunables/global>
profile nginx /usr/sbin/nginx flags=(attach_disconnected,complain) {
  #include <abstractions/base>
  #include <abstractions/nameservice>
  #include <abstractions/openssl>
  capability net_bind_service, capability setuid, capability setgid, capability dac_override, capability chown,
  network inet stream, network inet6 stream,
  /usr/sbin/nginx mr,
  /etc/nginx/** r,
  /etc/ssl/** r,
  /etc/letsencrypt/** r,
  /var/log/nginx/* w,
  /var/lib/nginx/** rw,
  /run/nginx.pid rw,
  $sock rw,
  /var/www/** r,
  /usr/share/nginx/** r,
  deny /etc/shadow r,
  deny /root/** rwklx,
  deny /home/*/.ssh/** rwklx,
  deny /etc/ssh/** rwklx,
}
EOK
    apparmor_parser -r "$prof" 2>&1 | tail -5 && ok "profile dimuat (mode complain)"
  fi
  aa-complain nginx 2>/dev/null
  ok "nginx jalan mode ${BD}COMPLAIN${N} (dicatat doang, belum diblok apa-apa)"
  info "biarin 1-2 hari, pantau: journalctl -k | grep -i 'apparmor.*DENIED'"
  cfg_set APPARMOR complain
  if confirm "Udah cek log & aman? Switch ke ENFORCE sekarang?"; then
    if aa-enforce nginx 2>/dev/null && nginx_reload_safe; then
      ok "ENFORCE aktif"; cfg_set APPARMOR enforce; log "apparmor enforce"
      warn "kalau situs jadi error 502/500 abis ini, ini kandidat pertama yang perlu dicek (rollback: aa-complain nginx)"
    else
      err "nginx gagal jalan di enforce — balik ke complain"; aa-complain nginx 2>/dev/null; nginx_reload_safe
    fi
  else log "apparmor complain"; fi
}
apparmor_remove() { aa-complain nginx 2>/dev/null; rm -f /etc/apparmor.d/usr.sbin.nginx; apparmor_parser -R /etc/apparmor.d/usr.sbin.nginx 2>/dev/null; cfg_set APPARMOR off; ok "AppArmor confinement nginx dilepas"; log "apparmor off"; }

# ── Cloudflare Tunnel — alternatif: 0 port terbuka sama sekali ──
cf_tunnel_setup() {
  section "SHIELD // CLOUDFLARE TUNNEL (alternatif: 0 port terbuka)"
  cat <<EOF
  Beda dari 'Cloudflare-only mode' (yang masih buka 80/443 tapi cuma terima IP CF):
  di sini port 80/443 ${BD}GAK PERLU dibuka${N} di UFW sama sekali — traffic masuk lewat
  koneksi outbound tunnel ke Cloudflare. Paling ampuh buat serangan volumetrik.
  Butuh: domain yang DNS-nya di-manage Cloudflare + akun Zero Trust (gratis).
EOF
  confirm "Lanjut install cloudflared?" || return
  if ! need cloudflared; then
    run "tambah repo cloudflare" bash -c '
      mkdir -p --mode=0755 /usr/share/keyrings
      curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg -o /usr/share/keyrings/cloudflare-main.gpg
      echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main" >/etc/apt/sources.list.d/cloudflared.list'
    run "apt update" apt-get update
    run "install cloudflared" apti cloudflared
  fi
  need cloudflared || { err "cloudflared gak ke-install"; return; }
  if systemctl is-active --quiet cloudflared 2>/dev/null; then ok "tunnel udah jalan"; confirm "Pasang ulang pakai token baru?" || return; fi
  cat <<EOF

  ${Y}Ambil token${N} (dari laptop kamu):
   1. Cloudflare Zero Trust dashboard → Networks → Tunnels → Create a tunnel
   2. Connector Cloudflared, kasih nama, COPY token yang muncul
   3. Di Public Hostname arahkan domain kamu ke ${BD}http://localhost:80${N}
EOF
  local tok
  read -rsp "  paste token tunnel (disembunyikan): " tok; echo
  [[ -n $tok ]] || { err "token kosong"; return; }
  cloudflared service install "$tok" >>"$LOG" 2>&1; sleep 2
  if systemctl is-active --quiet cloudflared; then
    ok "cloudflared aktif"; cfg_set CF_TUNNEL 1; log "cf tunnel installed"
    warn "biar manfaatnya kepake penuh: JANGAN buka 80/443 di UFW (menu Firewall Manager)"
  else err "gagal start — cek: journalctl -u cloudflared -n 30"; fi
}
cf_tunnel_remove() { systemctl disable --now cloudflared 2>/dev/null; cfg_set CF_TUNNEL 0; ok "cloudflare tunnel dimatiin (belum uninstall paketnya)"; log "cf tunnel off"; }

# ── Emergency Stop (single-server version — bukan panic/poweroff bastion) ──
shield_emergency_stop() {
  section "SHIELD // EMERGENCY STOP"
  warn "Ini stop nginx SEKARANG → situs down. SSH (whitelist/lockdown/tailscale) TETEP hidup."
  confirm "Stop nginx sekarang?" || return
  systemctl stop nginx 2>/dev/null && ok "nginx stopped"
  confirm "Sekalian aktifkan SSH lockdown (hanya IP whitelist yang bisa SSH)?" && lane_lockdown
  log "shield emergency stop"
  info "nyalain lagi nanti: systemctl start nginx"
}

# ───────────────────────── install as command ─────────────────────────
self_install() {
  install -m 0755 "$(readlink -f "$0")" /usr/local/bin/charr && ok "terinstall → ketik: ${BD}sudo charr${N}"
}

# ───────────────────────── main menu ─────────────────────────
main_menu() {
  local c it k t d col
  while true; do
    banner; status_bar; echo
    local items=(
      "#|MONITOR"
      "1|Daily Briefing|ringkasan harian sekali klik"
      "2|System Fetch|neofetch versi @c.for.charr"
      "3|Health Check|CPU/RAM/disk/service/update"
      "4|Live Monitor|dashboard realtime (q keluar)"
      "#|MANAGE"
      "5|Storage & Apps|deteksi app/folder + ukuran"
      "6|Cleaner|cache, apt, log, snap, docker"
      "7|Service Manager|start/stop/restart/enable/log"
      "8|Network Toolkit|ports, DNS, trace, sweep"
      "10|Package Manager|update, install, purge, fix"
      "#|BUILD"
      "11|VPS Setup Center|baseline, DNS, Nginx, LEMP, SSL"
      "12|Database Manager|buat db/user, backup, tuning"
      "#|SECURE & FIX"
      "9|Security Center|firewall UFW, fail2ban, SSH, audit"
      "13|Smart Doctor|auto-diagnosa error + auto-fix"
      "14|Log Explorer|analisis log pintar + live tail"
      "#|HARDEN (VPS kecil & diserang)"
      "17|Swap & Memory|swapfile, zram, tuning RAM kecil"
      "18|Shield|anti-DDoS/scan, SSH lane, WAF, tailscale"
      "#|DANGER"
      "15|FACTORY RESET|hapus paket sampai akar (aman)"
      "#|SYSTEM"
      "16|Install 'charr'|jadi command global"
      "0|Exit|"
    )
    for it in "${items[@]}"; do
      IFS='|' read -r k t d <<<"$it"
      if [[ $k == '#' ]]; then printf "  ${D}── %s ──${N}\n" "$t"; continue; fi
      col=$G; [[ $k == 15 ]] && col=$R
      printf "   ${col}[%2s]${N} ${BD}%-18s${N} ${D}%s${N}\n" "$k" "$t" "$d"
    done
    echo; read -rp "  ${G}charr${N}@${C}$(hostname)${N} ${D}»${N} " c
    case $c in
      1) daily; pause;;
      2) banner; sysfetch; pause;;
      3) health; pause;;
      4) monitor_live;;
      5) storage_menu;;
      6) cleaner_menu;;
      7) service_menu;;
      8) net_menu;;
      9) security_menu;;
      10) pkg_menu;;
      11) setup_menu;;
      12) db_menu;;
      13) doctor_menu;;
      14) logs_menu;;
      17) swap_menu;;
      18) shield_menu;;
      15) factory_reset; pause;;
      16) self_install; pause;;
      0|q|exit) clear; printf "${G}stay sharp. — %s${N}\n" "$AUTHOR"; exit 0;;
    esac
  done
}

usage() {
  cat <<EOF
CHARR//TOOLKIT v$VERSION — by $AUTHOR
  sudo bash charr.sh [--no-anim] [command]
  (kosong)   menu interaktif          fetch      info sistem
  daily      briefing harian          health     health check
  monitor    live monitor             clean      cleaner
  security   security center          firewall   firewall manager (UFW)
  setup      VPS setup center         lemp       install Nginx+PHP+MariaDB
  db         database manager         doctor     smart doctor (scan + auto-fix)
  logs       log explorer             audit      security audit
  swap       swap & memory tuning     shield     anti-DDoS/scan + SSH lane
  install    pasang sebagai 'charr'
EOF
}

[[ ${1:-} == --no-anim ]] && { ANIM=0; shift; }
mkdir -p "$(dirname "$LOG")"; touch "$LOG" 2>/dev/null
case "${1:-}" in
  "")            intro; main_menu;;
  fetch)         sysfetch;;
  daily)         daily;;
  health)        health;;
  monitor)       monitor_live;;
  clean)         cleaner_menu;;
  audit)         audit;;
  security)      security_menu;;
  firewall|fw)   fw_menu;;
  setup)         setup_menu;;
  lemp)          lemp_install;;
  db)            db_menu;;
  doctor)        doctor;;
  logs)          logs_menu;;
  swap)          swap_menu;;
  shield)        shield_menu;;
  shield-reload) shield_apply;;
  install)       self_install;;
  -h|--help|help) usage;;
  *)             usage; exit 1;;
esac
