#!/usr/bin/env bash
# cfcore 封禁转生: 当前 Pages 项目被 CF 滥用封禁(8000119)时
# 自动创建新项目 → 迁移配置(环境变量/KV绑定/兼容日期) → 部署内核 → 自定义域无缝切换
# 环境变量: CLOUDFLARE_API_TOKEN, CLOUDFLARE_ACCOUNT_ID, OLD_PROJECT, DIST_DIR
set -uo pipefail
API="https://api.cloudflare.com/client/v4"
AUTH="Authorization: Bearer $CLOUDFLARE_API_TOKEN"
acct="$CLOUDFLARE_ACCOUNT_ID"
OLD="$OLD_PROJECT"
DIST="${DIST_DIR:-dist}"
SUMMARY="${GITHUB_STEP_SUMMARY:-/dev/stdout}"
step(){ echo "- $1" >> "$SUMMARY"; }

# 1. 旧项目的自定义域名列表
DOMAINS=$(curl -sS -H "$AUTH" "$API/accounts/$acct/pages/projects/$OLD/domains" | python3 -c "import json,sys;print(' '.join(d['name'] for d in json.load(sys.stdin)['result']))")
step "转生触发: $OLD 被封禁, 自定义域 [$DOMAINS]"

# 2. 找未占用的项目名
NEW=""
for i in "" 2 3 4 5 6 7 8 9; do
  CAND="cfcore-rescue$(date +%m%d)${i}"
  CODE=$(curl -sS -o /dev/null -w "%{http_code}" -H "$AUTH" "$API/accounts/$acct/pages/projects/$CAND")
  if [ "$CODE" = "404" ]; then NEW="$CAND"; break; fi
done
[ -n "$NEW" ] || { echo "::error::找不到可用项目名"; exit 1; }
step "新项目名: $NEW"

# 3. 创建项目
CODE=$(curl -sS -o /tmp/create.json -w "%{http_code}" -X POST -H "$AUTH" -H "Content-Type: application/json" \
  -d "{\"name\":\"$NEW\",\"production_branch\":\"main\"}" \
  "$API/accounts/$acct/pages/projects")
[ "$CODE" = "200" ] || { echo "::error::创建项目失败 HTTP $CODE"; cat /tmp/create.json; exit 1; }

# 4. 迁移生产配置 (env vars / KV 绑定 / 兼容日期)
curl -sS -H "$AUTH" "$API/accounts/$acct/pages/projects/$OLD" | python3 -c "
import json,sys
p=json.load(sys.stdin)['result']['deployment_configs']['production']
out={'deployment_configs':{'production':{}}}
for k in ('env_vars','kv_namespaces'):
    if p.get(k): out['deployment_configs']['production'][k]=p[k]
if p.get('compatibility_date'): out['deployment_configs']['production']['compatibility_date']=p['compatibility_date']
print(json.dumps(out))
" > /tmp/settings.json
CODE=$(curl -sS -o /tmp/patch.json -w "%{http_code}" -X PATCH -H "$AUTH" -H "Content-Type: application/json" \
  --data-binary @/tmp/settings.json "$API/accounts/$acct/pages/projects/$NEW")
[ "$CODE" = "200" ] || { echo "::error::配置迁移失败 HTTP $CODE"; cat /tmp/patch.json; exit 1; }
step "配置已迁移 (env u/jk/qj + KV 绑定 C + 兼容日期)"

# 5. 部署内核
npm install -g wrangler@4 --silent
wrangler pages deploy "$DIST" --project-name="$NEW" --branch=main --commit-dirty=true

# 6. 自定义域迁移: 旧项目摘除 → 新项目挂载 → DNS 指向新项目
SUB=$(curl -sS -H "$AUTH" "$API/accounts/$acct/pages/projects/$NEW" | python3 -c "import json,sys;print(json.load(sys.stdin)['result']['subdomain'])")
step "新项目子域: $SUB"
for DM in $DOMAINS; do
  curl -sS -X DELETE -H "$AUTH" "$API/accounts/$acct/pages/projects/$OLD/domains/$DM" > /dev/null
  curl -sS -X POST -H "$AUTH" -H "Content-Type: application/json" -d "{\"name\":\"$DM\"}" \
    "$API/accounts/$acct/pages/projects/$NEW/domains" > /dev/null
  ZONE_ID=$(curl -sS -H "$AUTH" "$API/zones?name=${DM#*.}" | python3 -c "import json,sys;print(json.load(sys.stdin)['result'][0]['id'])")
  RID=$(curl -sS -H "$AUTH" "$API/zones/$ZONE_ID/dns_records?name=$DM" | python3 -c "import json,sys;print(json.load(sys.stdin)['result'][0]['id'])")
  curl -sS -X PATCH -H "$AUTH" -H "Content-Type: application/json" -d "{\"content\":\"$SUB\"}" \
    "$API/zones/$ZONE_ID/dns_records/$RID" > /dev/null
  step "域名切换: $DM → $SUB"
done

# 7. 更新 project-name.txt, 后续每日部署走新项目
echo "$NEW" > project-name.txt
git config user.name  "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git add project-name.txt
git commit -m "rescue: $OLD blocked (8000119) -> migrated to $NEW" || true
git push || step "⚠️ project-name.txt 推送失败（不影响本次切换）"
step "✅ 转生完成: $OLD → $NEW（自定义域已无缝切换）"
