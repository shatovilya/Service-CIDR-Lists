# Service-CIDR-Lists

Автоматически обновляемые списки доменов и текущих IPv4-адресов сервисов
**KIMI (Moonshot AI)** и **ZCode (Z.ai / Zhipu)**.

Данные — только из официальных источников, никаких сторонних
агрегаторов. Обновление — ежедневно через GitHub Actions (04:17 UTC).

## Файлы

| Файл | Содержимое | Обновление |
|---|---|---|
| [`Kimi/kimi_domains.txt`](Kimi/kimi_domains.txt) | Официальные домены Moonshot/Kimi (API и продукты) | при изменении доков (вручную) |
| [`Kimi/kimi_endpoints_ipv4.txt`](Kimi/kimi_endpoints_ipv4.txt) | Текущие A-записи этих доменов (IPv4/32) | ежедневно (DoH) |
| [`ZCode/zcode_domains.txt`](ZCode/zcode_domains.txt) | Официальные домены Z.ai/BigModel | при изменении доков (вручную) |
| [`ZCode/zcode_endpoints_ipv4.txt`](ZCode/zcode_endpoints_ipv4.txt) | Текущие A-записи этих доменов (IPv4/32) | ежедневно (DoH) |

Raw-URL (ветка `main`):

```
https://raw.githubusercontent.com/shatovilya/Service-CIDR-Lists/main/Kimi/kimi_domains.txt
https://raw.githubusercontent.com/shatovilya/Service-CIDR-Lists/main/Kimi/kimi_endpoints_ipv4.txt
https://raw.githubusercontent.com/shatovilya/Service-CIDR-Lists/main/ZCode/zcode_domains.txt
https://raw.githubusercontent.com/shatovilya/Service-CIDR-Lists/main/ZCode/zcode_endpoints_ipv4.txt
```

## Формат

- Чистые строки без комментариев: домен или CIDR (`…/32`) на строку,
  `\n`, без trailing whitespace, отсортировано и уникально.
- Домены — голые имена (`example.com`).

## Почему нет списков CIDR-префиксов сервисов

Ни Moonshot AI, ни Zhipu/Z.AI **не владеют собственными
анонсируемыми IP-префиксами**: их инфраструктура размещена на
Alibaba Cloud (AS37963/AS45102/AS24429), ChinaNet/China Telecom IDC
(AS134760/AS23724), Cloudflare и Vercel. Диапазоны этих провайдеров —
общие с тысячами других сервисов, публиковать их нельзя.

Поэтому IP-списки здесь — **текущие endpoint-/32** официально
задокументированных доменов, полученные через DoH (Google +
Cloudflare). Адреса ротируются (смотри diff между соседними
коммитами — он это наглядно показывает) и являются общими адресами
CDN/облака.

Полная доказательная база (включая проверку и опровержение чужих
утверждений, например привязки `38.145.202.0/24` к Moonshot) — в
[`docs/audit.md`](docs/audit.md) и [`sources/evidence.json`](sources/evidence.json).

## Обновление

- Ежедневно в 04:17 UTC —
  [GitHub Actions](.github/workflows/update.yml) запускает
  `scripts/update_lists.sh` и коммитит изменения.
- Вручную: `bash scripts/update_lists.sh` (нужны `curl`, `jq`).

## Статусы проверок

| Что | Статус | Где |
|---|---|---|
| Домены подтверждены официальной документацией | D | docs/audit.md |
| Endpoint-резолвы свежие на дату коммита | B | sources/last_run.json |
| Собственные CIDR-префиксы сервисов | отсутствуют (доказано) | docs/audit.md |
| Raw-URL доступны | A | curl 2026-11-16, 4/4 → 200 |

## Лицензия

MIT — см. [LICENSE](LICENSE).
