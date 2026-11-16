# Source audit — списки KIMI (Moonshot AI) и ZCode (Z.ai / Zhipu)

Дата анализа: 2026-11-15 (статусы обновлены 2026-11-16). Документ
фиксирует происхождение данных: список содержит только домены,
подтверждённые официальной документацией, и их текущие endpoint-/32.

## 1. Источники данных (официальные только)

| Данные | URL | Что подтверждено | Дата |
|---|---|---|---|
| API China Moonshot | https://platform.kimi.com/docs/api/authentication | `https://api.moonshot.cn/v1`; платформа `platform.kimi.com` (легаси `platform.moonshot.cn` → 301) | 2026-11-15 |
| API Global Moonshot | https://platform.kimi.ai/docs/get-your-api-key | `https://api.moonshot.ai/v1` | 2026-11-15 |
| Kimi Code endpoint | https://www.kimi.com/code/docs/en | `https://api.kimi.ai/coding/` | 2026-11-15 |
| API Global Z.ai | https://docs.z.ai/guides/overview/quick-start.md | `https://api.z.ai/api/paas/v4/` | 2026-11-15 |
| API China Zhipu | https://docs.bigmodel.cn/cn/guide/start/quick-start.md | `https://open.bigmodel.cn/api/paas/v4/chat/completions` | 2026-11-15 |
| Платформа Zhipu | https://docs.bigmodel.cn/ | `bigmodel.cn` | 2026-11-15 |
| Принадлежность IP/ASN | https://stat.ripe.net (network-info, whois, as-overview, prefix-overview) | см. sources/evidence.json | 2026-11-15 |
| Резолв endpoint-IP | https://dns.google/resolve, https://cloudflare-dns.com/dns-query (DoH) | текущие A-записи | ежедневно |

Легаси-домен `api.zhipuai.cn` в текущей официальной документации не
упоминается — в списки **не включён** (недоказанное не публикуется).

## 2. Отклонения от «классических» CIDR-списков (осознанные)

1. **Нет `{svc}_cidr_ipv4.txt`** — проверка (см. §3) показала, что у
   Moonshot AI и Zhipu/Z.AI нет собственных анонсируемых префиксов.
   Пустые файлы не публикуются; вместо них `{svc}_endpoints_ipv4.txt`.
2. **Файлы без комментариев** — текстовые списки содержат только
   значения, по одному на строку; метаданные — в README/audit/sources.
3. **Endpoint-IP в нотации /32** — унифицированная CIDR-нотация.

## 3. Проверка отсутствия собственных префиксов (доказательства)

- PeeringDB API: `net?name__contains=moonshot|zhipu|z.ai` — пусто.
- bgp.tools search: отдаёт страницу (200), результаты рендерятся JS —
  извлечь нельзя; в HTML ASN-записей нет.
- RIPEstat по всем официальным доменам: каждый эндпоинт — префикс
  Alibaba (AS37963/AS45102/AS24429), ChinaNet Hebei IDC (AS134760),
  China Telecom IDC (AS23724), Cloudflare или Vercel. Whois-орг-имена
  «Moonshot»/«Zhipu» не встречаются.
- Полная детализация: `sources/evidence.json`.

**Опровергнутое утверждение**: фрагмент выдачи поиска bgp.tools
ассоциировал `38.145.202.0/24` с Moonshot AI. Проверка: origin
AS18978 (Enzu Inc), whois Cogent/Enzu, PTR `us1.node.check-host.net`
(нода мониторинга). К Moonshot отношения не имеет — в списки не
включено. Пример работы правила «неподтверждённое не публикуется».

## 4. Статусы

| Проверка | Статус | Примечание |
|---|---|---|
| Генератор запускается и создаёт валидные списки | B | last_run.json |
| Домены — документально подтверждены | D | §1 |
| Отсутствие собственных CIDR-префиксов | D (доказано RIPEstat/whois/PeeringDB) | §3 |
| Endpoint-IP актуальны на момент коммита | B | ротация — см. diff между коммитами |
| Raw-URL доступны | **A** | curl 2026-11-16: 4/4 URL → HTTP 200 |
| CI-обновление (GitHub Actions) | **A** | workflow run success, bot коммитит изменения |
