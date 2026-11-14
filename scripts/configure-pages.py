# 配置 Pages 项目的环境变量与绑定（通用工具）
# 用法: python3 configure-pages.py <project> <config-json-file>
# config-json: {"env_vars": {...}, "kv_namespaces": {...}, "durable_object_bindings": [...]}
import json, os, sys, urllib.request, time

TOKEN = os.environ.get('CLOUDFLARE_API_TOKEN', '')
ACCT = os.environ.get('CLOUDFLARE_ACCOUNT_ID', '')
project = sys.argv[1]
cfgpath = sys.argv[2]

cfg = json.load(open(cfgpath, encoding='utf-8'))
body = json.dumps({'deployment_configs': {'production': cfg}}).encode()
url = f'https://api.cloudflare.com/client/v4/accounts/{ACCT}/pages/projects/{project}'

for attempt in range(5):
    try:
        req = urllib.request.Request(url, data=body, headers={
            'Authorization': f'Bearer {TOKEN}', 'Content-Type': 'application/json'}, method='PATCH')
        with urllib.request.urlopen(req, timeout=60) as r:
            d = json.load(r)
        prod = d['result']['deployment_configs']['production']
        print('配置成功:', sorted((prod.get('env_vars') or {}).keys()),
              '| KV:', sorted((prod.get('kv_namespaces') or {}).keys()),
              '| DO:', sorted((prod.get('durable_object_bindings') or {}).keys()))
        sys.exit(0)
    except Exception as e:
        print(f'重试 {attempt+1}:', str(e)[:80])
        time.sleep(6)
print('::error::配置失败')
sys.exit(1)
