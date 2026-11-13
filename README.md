# cfcore 云端自动更新

cfcore（Cloudflare Pages 项目 `cfcore`，内核来自 [byJoey/cfnew](https://github.com/byJoey/cfnew) 精简内核）的自动更新方案。

## 工作流程

| 步骤 | 说明 |
|---|---|
| 1. 定时触发 | 每天 `06:17 UTC`（北京时间 14:17），与其他工作流错开 |
| 2. 查上游 | `byJoey/cfnew` 最新 Release（api.github.com，稳定） |
| 3. 下载内核 | 从 Release 标签拉取 `_worker.js`（约 37KB），完整性校验 >20KB |
| 4. hash 比对 | sha256 与 `deployed-hash.txt` 对比，无变化跳过 |
| 5. 部署 | `wrangler pages deploy dist --project-name=cfcore`（项目级 env/KV 绑定自动继承） |
| 6. 冒烟验证 | 主地址 HTTP 非 200 即 fail |
| 7. 记录 hash | 提交 `deployed-hash.txt` |

## 需要配置的 Secrets（一次性）

仓库 → Settings → Secrets and variables → Actions → New repository secret：

| 名称 | 值 |
|---|---|
| `CLOUDFLARE_API_TOKEN` | CF 面板创建的 API Token（权限：Account / Cloudflare Pages / Edit） |
| `CLOUDFLARE_ACCOUNT_ID` | `071c36c227211679dd1537626856116f` |

## 手动触发

Actions → **cfcore Auto Update** → Run workflow（`force=true` 强制重部署）

## 回滚

Cloudflare 控制台 → Pages → cfcore → Deployments → 选旧版本 Rollback

## 相关链接

- 上游仓库：https://github.com/byJoey/cfnew （面板：https://cfnew.xy.kg/）
- 线上地址：https://cfcore-6ha.pages.dev
