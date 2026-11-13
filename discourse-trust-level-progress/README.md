# discourse-trust-level-progress

让普通用户在**自己的**个人资料摘要页（`/u/你的用户名/summary`）看到距离下一信任等级的逐项进度，数据口径与管理员后台的 Trust Level Requirements 一致。

## 行为

- 新用户 / TL1：按 `tl1_requires_*`、`tl2_requires_*` 站点设置逐项对比（与核心升级逻辑的 `>`、`>=` 判断一致）。
- TL2：直接复用核心的 `TrustLevel3Requirements` 计算 TL3 的 100 天滚动窗口数据（访问天数、浏览/阅读量、点赞、被禁言封禁等），因此数值与后台一致，不是前端近似。
- TL3 / TL4：显示保级状态，只列出低于保级线的项，并提示 grace period。
- 卡片只在本人摘要页渲染；接口 `/trust-level-progress.json` 需要登录，且只返回当前登录用户的数据，不接收用户名参数。

## 安装（Docker 标准安装）

```bash
cd /var/discourse
# 1. 把本目录放到 plugins/ 下
sudo cp -r /path/to/discourse-trust-level-progress plugins/
# 2. 重新构建（会短暂停服）
sudo ./launcher rebuild app
```

或者在 `containers/app.yml` 的 `hooks: after_code:` 里加 clone 命令，让 `rebuild` 自动拉取。

## 安装（非 Docker / 开发环境）

把目录复制到 Discourse 根目录的 `plugins/` 下，然后：

```bash
RAILS_ENV=production bundle exec rake assets:precompile
# 重启 puma / sidekiq
```

## 验证

1. 管理后台 → 插件，能看到 `discourse-trust-level-progress` 且无报错。
2. 站点设置里搜索 `trust_level_progress_enabled`（默认开启）。
3. 登录后打开 `/u/你的用户名/summary`，统计块上方出现进度卡片。
4. 命令行验证接口（需带登录 Cookie/CSRF，或直接用浏览器访问）：

```bash
curl -s https://你的域名/trust-level-progress.json --cookie "_t=..." | jq
```

返回结构：

```json
{
  "mode": "tl3",
  "current_trust_level": 2,
  "target_trust_level": 3,
  "title": "距离 TL3 的进度（当前 TL2）",
  "summary": "还差 3 项",
  "summary_state": "pending",
  "alerts": [{ "level": "warn", "text": "..." }],
  "items": [
    {
      "key": "days_visited",
      "label": "访问天数",
      "value_text": "62 天",
      "required_text": "50 天",
      "percent": 100,
      "met": true,
      "hint": null
    }
  ]
}
```

## 说明与限制

- 文案由服务端按当前请求的界面语言渲染（已含 zh_CN / en）。
- 升级由 Discourse 的后台任务执行，满足全部条件后通常在一到两天内生效，卡片会显示"已满足全部条件"但等级可能尚未变化。
- TL3 的数字是实时计算（每次打开页面查一次），数据量大时首屏会略慢；没做缓存是为了避免显示过期差距。
- 最低版本要求 Discourse 3.2（依赖 `api.renderInOutlet` 与 `above-user-summary-stats` outlet）。
- 卸载：删除 `plugins/discourse-trust-level-progress` 后重新 rebuild。

## 目录结构

```
plugin.rb                                  # 插件声明、路由、样式注册
app/controllers/.../trust_level_progress_controller.rb
lib/.../requirements.rb                    # 逐项差距计算
assets/javascripts/discourse/initializers/ # 挂载到 outlet
assets/javascripts/discourse/components/   # 卡片组件（js + hbs）
assets/stylesheets/trust-level-progress.scss
config/settings.yml
config/locales/{server,client}.{en,zh_CN}.yml
```
