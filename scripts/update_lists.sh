#!/usr/bin/env bash
# scripts/update_lists.sh — регенерация списков Service-CIDR-Lists.
#
# Что делает:
#   1. Читает курируемые списки официальных доменов из sources/*.domains
#      (только документально подтверждённые домены; см. docs/audit.md).
#   2. Через DoH (Google + Cloudflare) резолвит текущие A-записи и
#      формирует {svc}_endpoints_ipv4.txt (IP/32, sort -u).
#   3. Формирует {svc}_domains.txt (чистые строки, без комментариев).
#
# Собственные анонсируемые префиксы (ASN-based *_cidr_ipv4.txt) НЕ
# генерируются: проверка 2026-11-15 показала, что Moonshot AI и Zhipu/Z.AI
# не имеют собственных ASN/префиксов — доказательства в sources/evidence.json.
#
# Гарантии: set -Eeuo pipefail; кавычки; без eval;
# только https к фиксированным DoH-хостам с проверкой хоста; атомарная
# запись (tmp → validate → mv); повторный запуск идемпотентен.

set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCES_DIR="${REPO_ROOT}/sources"
RUN_STAMP="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

# --- фиксированные разрешённые DoH-хосты (проверяются на публичность) ---
readonly -a DOH_URLS=(
  'https://dns.google/resolve?name=%s&type=A'
  'https://cloudflare-dns.com/dns-query?name=%s&type=A'
)

# Строгий IPv4: каждый октет 0-255.
readonly IPV4_RE='^(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])(\.(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])){3}$'
# Имя хоста: RFC-1123-подобное, строчные.
readonly HOST_RE='^([a-z0-9]([a-z0-9_-]*[a-z0-9])?\.)*[a-z]([a-z0-9-]*[a-z0-9])?$'

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
log() { printf '[update_lists] %s\n' "$*" >&2; }

# Отказ localhost/loopback/приватных/зарезервированных адресов в хосте URL.
assert_public_host() {
  local host="$1" ip oct1 oct2
  [[ "$host" =~ $HOST_RE ]] || die "недопустимое имя хоста: ${host}"
  case "$host" in
    localhost|*.localhost|*.local|*.lan|*.arpa|*.internal) die "резервный хост: ${host}" ;;
  esac
  if [[ "$host" =~ ^[0-9.]+$ ]]; then
    [[ "$host" =~ $IPV4_RE ]] || die "некорректный IPv4-литерал: ${host}"
    IFS=. read -r oct1 oct2 _ _ <<<"$host"
    # 0/8, 10/8, 127/8, 169.254/16, 172.16/12, 192.168/16, 100.64/10 и т.п.
    if (( oct1 == 0 || oct1 == 10 || oct1 == 127 )) ||
       { (( oct1 == 172 )) && (( oct2 >= 16 && oct2 <= 31 )); } ||
       { (( oct1 == 192 )) && (( oct2 == 168 )); } ||
       { (( oct1 == 169 )) && (( oct2 == 254 )); } ||
       { (( oct1 == 100 )) && (( oct2 >= 64 && oct2 <= 127 )); }; then
      die "приватный/резервный адрес запрещён: ${host}"
    fi
  fi
}

# A-записи домена через все разрешённые DoH-резолверы (IPv4, без CNAME).
doh_a_records() {
  local name="$1" url resp out=""
  [[ "$name" =~ $HOST_RE ]] || { log "пропуск некорректного домена: ${name}"; return 0; }
  for url in "${DOH_URLS[@]}"; do
    assert_public_host "$(printf '%s' "$url" | sed -E 's#^https://([^/?]+).*$#\1#')"
    resp="$(curl -fsS --max-time 15 -H 'accept: application/dns-json' \
      "${url/\%s/${name}}" 2>/dev/null || true)"
    [[ -n "$resp" ]] || continue
    out+="$(printf '%s' "$resp" \
      | jq -r 'if .Status == 0 then (.Answer[]? | select(.type == 1) | .data) else empty end' \
      2>/dev/null || true)"$'\n'
  done
  printf '%s' "$out" | grep -E "$IPV4_RE" | sort -u || true
}

# Атомарная запись: tmp → валидация → mv.
atomic_write() {
  local dst="$1" tmp="${1}.tmp"
  [[ -s "$tmp" ]] || die "пустой результат для ${dst}"
  mv -f "$tmp" "$dst"
}

# service <имя-каталога> <слаг-файлов (lowercase)> <sources-файл>
build_service() {
  local svc="$1" slug="$2" src="$3"
  local dir="${REPO_ROOT}/${svc}"
  mkdir -p "$dir"

  # 1. Домены: убрать // -комментарии и пустые строки, отсортировать.
  local domains_tmp="${dir}/${slug}_domains.txt.tmp"
  awk '{ sub(/\/\/.*/, ""); gsub(/^[ \t]+|[ \t]+$/, ""); print }' "$src" \
    | grep -Ev '^$' | sort -u > "$domains_tmp"
  while IFS= read -r d; do
    [[ -n "$d" ]] || continue
    [[ "$d" =~ $HOST_RE ]] || die "некорректный домен в ${src}: ${d}"
  done < "$domains_tmp"
  atomic_write "${dir}/${slug}_domains.txt"

  # 2. Endpoints: резолв каждого домена → IP/32.
  local ips_tmp="${dir}/${slug}_endpoints_ipv4.txt.tmp"
  : > "$ips_tmp"
  local d total=0
  while IFS= read -r d; do
    [[ -n "$d" ]] || continue
    local recs
    recs="$(doh_a_records "$d")"
    if [[ -z "$recs" ]]; then
      log "${svc}: ${d} — нет A-записей у разрешённых резолверов (пропущено)"
      continue
    fi
    printf '%s\n' "$recs" | sed 's/$/\/32/' >> "$ips_tmp"
    total=$(( total + $(printf '%s\n' "$recs" | wc -l) ))
  done < "${dir}/${slug}_domains.txt"

  grep -E "^([0-9]{1,3}\.){3}[0-9]{1,3}/32$" "$ips_tmp" | sort -u > "${ips_tmp}.sorted" \
    || die "${svc}: ни один домен не резолвится — список endpoints пуст"
  mv -f "${ips_tmp}.sorted" "$ips_tmp"
  atomic_write "${dir}/${slug}_endpoints_ipv4.txt"

  printf '%s\n' "$(wc -l < "${dir}/${slug}_domains.txt") $(wc -l < "${dir}/${slug}_endpoints_ipv4.txt")"
}

main() {
  local kimi_counts zcode_counts
  kimi_counts="$(build_service Kimi kimi "${SOURCES_DIR}/kimi.domains")"
  zcode_counts="$(build_service ZCode zcode "${SOURCES_DIR}/zcode.domains")"

  jq -n --arg run "$RUN_STAMP" \
        --arg k "$kimi_counts" --arg z "$zcode_counts" \
        '{run_utc: $run,
          kimi:   {domains: ($k | split(" ")[0] | tonumber), endpoints: ($k | split(" ")[1] | tonumber)},
          zcode:  {domains: ($z | split(" ")[0] | tonumber), endpoints: ($z | split(" ")[1] | tonumber)}}' \
    > "${SOURCES_DIR}/last_run.json"
  log "готово: Kimi(domains/endpoints)=${kimi_counts}, ZCode=${zcode_counts}"
}

main "$@"
