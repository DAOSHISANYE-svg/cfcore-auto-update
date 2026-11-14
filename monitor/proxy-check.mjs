// VLESS over WebSocket 端到端代理测试
// 用法: node proxy-check.mjs <名称> <主机> <WS路径> <UUID>
// 通过真实代理链路访问 ip-api.com，验证出口 IP。退出码 0=通 1=不通 2=配置缺失
const [name, host, path, uuid] = process.argv.slice(2);
if (!uuid || uuid.replace(/-/g, '').length !== 32) {
  console.error(`⚠️  ${name}: UUID 未配置（检查仓库 Secrets）`);
  process.exit(2);
}
function vlessHeader(uuid, port, host) {
  return Buffer.concat([
    Buffer.from([0x00]),
    Buffer.from(uuid.replace(/-/g, ''), 'hex'),
    Buffer.from([0x00]),
    Buffer.from([0x01]),
    Buffer.from([(port >> 8) & 0xff, port & 0xff]),
    Buffer.from([0x02]),
    Buffer.from([host.length]),
    Buffer.from(host),
  ]);
}
const ws = new WebSocket(`wss://${host}${path}`, { headers: { 'User-Agent': 'v2rayN/6.0' } });
ws.binaryType = 'arraybuffer';
let buf = Buffer.alloc(0), done = false;
const t = setTimeout(() => {
  if (!done) { console.error(`❌ ${name}: E2E 超时(15s)`); process.exit(1); }
}, 15000);
ws.addEventListener('open', () => {
  ws.send(Buffer.concat([
    vlessHeader(uuid, 80, 'ip-api.com'),
    Buffer.from('GET /json?fields=query,country HTTP/1.1\r\nHost: ip-api.com\r\nConnection: close\r\n\r\n'),
  ]));
});
ws.addEventListener('message', (ev) => {
  buf = Buffer.concat([buf, Buffer.from(ev.data)]);
  if (buf.length >= 2 && !done) {
    const dataStart = 2 + buf[1];
    if (buf.length > dataStart) {
      done = true; clearTimeout(t);
      const payload = buf.slice(dataStart).toString('utf-8');
      const status = payload.split('\r\n')[0];
      const m = payload.match(/\{.*\}/);
      if (status.includes(' 200') && m) {
        const j = JSON.parse(m[0]);
        console.log(`✅ ${name}: E2E 代理通 → 出口 ${j.query} (${j.country})`);
        ws.close(); setTimeout(() => process.exit(0), 200);
      } else {
        console.error(`❌ ${name}: 代理响应异常 — ${status}`);
        process.exit(1);
      }
    }
  }
});
ws.addEventListener('error', (e) => { clearTimeout(t); console.error(`❌ ${name}: ${e.message || e.type}`); process.exit(1); });
