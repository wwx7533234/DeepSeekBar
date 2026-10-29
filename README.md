# DeepSeekBar — 菜单栏余额与用量小助手

macOS 菜单栏工具：一眼查看 DeepSeek API **余额**与**官方用量**（与平台网页版一致）。界面为 380pt 宽的轻量控制面板，支持深色 / 浅色模式。

## 功能

- **余额（两种来源可选）**：设置里「余额来源」可选 **自动 / API Key / 网页账号**。自动模式**优先用网页账号**里的钱包余额（与网页版一致），未登录或 token 过期时回落到 API Key（`GET /user/balance`）；也可以锁定其中一种。
- **余额**：调用官方 `GET /user/balance` 接口，菜单栏直接显示余额数字（如 `¥110`），点开面板可看充值余额 / 赠送余额 / 账户状态，自动定时刷新 + 一键手动刷新。
- **充值（工具内页面）**：余额卡「+ 充值」不再弹独立窗口，而是切换到工具自己的充值页；页面内嵌 DeepSeek 官方充值页（`platform.deepseek.com/top_up`），复用网页登录态，支持在线充值 / 对公汇款与官方支付方式。支付过程中面板内实时刷新余额，返回后再次自动刷新。
- **API 管理（工具内页面）**：点击底部钥匙图标进入 API 管理页，可查看平台 API Keys、新建、重命名、删除；列表只显示脱敏 Key，新建后完整 Key 只显示一次，并支持一键复制或设为当前余额查询 Key。
- **官方用量（与网页版一致）**：DeepSeek 官方 API 不提供用量查询接口，但平台网页（platform.deepseek.com）有用量页。App 内置「网页授权」——弹出 WebView 扫码/验证码登录一次，自动捕获登录 token，随后调用网页同款内部接口展示：累计消费、近 30 天消费、日均消费、请求次数、Tokens、消费趋势、模型分布。**余额与用量共用同一刷新频率自动刷新**。Token 失效后重新授权即可。
- **安全**：API Key 与官方登录 Token 存本地凭证文件（`~/Library/Application Support/DeepSeekBar/credentials.json`，权限 600），不上传任何数据。

## 界面（v1.4 · 刻度重设计）

整套界面换成一套「刻度」语言：一块连续的仪表面板，不再是一叠卡片。

- **去掉的东西**：品牌渐变卡、玻璃胶囊、卡片堆叠、18pt 大圆角、柔和投影、渐变 DS 方块、蓝紫渐变柱、径向光晕。
- 层级只由排版和 1px 发丝线建立：等宽小标签（`DEEPSEEK BAR` / `SYNC` / `30D` / `TOKENS`）+ 表格数字，刷新时数字不跳宽。
- 全屏只有一个信号色，出现即代表「当前」：悬停的那根柱、今天、选中的刷新频率、余额换算行。
- **余额是唯一主角**（46pt），下面一行把它换算成「按日均 ¥0.99 计，余额约可用 2.2 个月」，让数字变成判断。
- **30 天趋势**是 30 根细柱立在基线上，30 天全部可见、不需要横向滚动；悬停出 1px 光标与该日读数，轴下补峰值金额与日期。
- **模型构成**用 36 格刻度尺表示占比（单一模型时不画空刻度），图例与刻度同色阶。
- 设置 / API 管理 / 充值页沿用同一套台账：区块头 + 发丝线 + 方角控件；输入框改为下划线，状态标记去掉底色，只留方点 + 等宽字。
- 动效：页面切换淡入、数值 `contentTransition`、图标悬停浮出 1px 信号色刻度、同步时一条 1px 走线。
- 菜单栏数字改为等宽，余额刷新时不再左右跳。
- **菜单栏图标可选**（设置 → 菜单栏）：**常规图标**（鲸鱼标记，只画图标不显示金额）/ **显示余额**（只写 ¥ 金额，不占图标位），切换即时生效，带实时预览。
- **面板固定 380×600，四个页面同高**：菜单栏面板的窗口高度在打开时就定死了，切换页面不会跟着变，所以页面高度必须一致，否则底部操作栏会被裁掉。

## 构建与运行

```bash
# 直接编译运行（调试，会出现在 Dock）
swift run DeepSeekBar

# 打包成正式 .app（菜单栏应用，不占 Dock）
./scripts/make_app.sh
open dist/DeepSeekBar.app
```

## 使用

1. 点击菜单栏图标打开面板 → 右上角齿轮进入设置。
2. 填入 DeepSeek API Key（platform.deepseek.com → API Keys）→ 保存 → 测试连接，余额即显示。
3. 用量统计：设置里点「网页登录授权」→ 弹出窗口扫码/验证码登录一次 → 自动同步官方用量（累计消费、请求次数、Tokens、近 30 天图表、模型分布），之后定时自动刷新。
4. 充值：点余额卡右下角「+ 充值」→ 面板切换到充值页 → 在官方页面完成支付 → 支付过程中顶部余额自动更新，返回后再次刷新。
5. API 管理：点右上角钥匙图标 → 查看/新建/重命名/删除 API Keys；新建后完整 Key 只显示一次，可复制或一键设为当前余额查询 Key。

## 数据位置

| 数据 | 位置 |
|---|---|
| API Key / 官方 Token | `~/Library/Application Support/DeepSeekBar/credentials.json`（600 权限） |
| 设置 | UserDefaults（刷新频率） |

## 开发备注

- 调试参数（`swift run DeepSeekBar` 或 `.build/debug/DeepSeekBar`）：
  - `--window`：弹出 380pt 无边框预览窗口（便于截图/验证 UI；预览窗口用 NSWindow + NSHostingController 实现）
  - `--settings` / `--recharge` / `--api`：配合 `--window` 直接打开对应页面
  - `--dark` / `--light`：强制深色 / 浅色外观，便于双模式截图
  - `--snapshot <png>`：ImageRenderer 快速截图（适合主面板/设置页）
  - `--snapshot-view <png>`：NSHostingView 整页截图（可渲染 ScrollView，如 API 管理页）
  - `--snapshot-topup <png>`：单独渲染官方充值页 380×600 截图（锁屏也可用）
  - `--webauth`：启动即弹官方授权窗口（配合 `[WebAuth]` 日志监控抓 token 过程）
  - 环境变量 `DSBAR_UPSTREAM`：覆盖上游 API 地址（本地 mock 测试 / 自托管网关）
- 技术栈：SwiftUI `MenuBarExtra`（macOS 14+）+ Swift Charts + WKWebView（授权抓 token / 页面内嵌充值 / API 管理）。
- 目录：`Sources/DeepSeekBar/`（AppState 状态、OfficialAPI 官方接口/API Key 管理、WebAuthController 授权、RechargePage/RechargeWebView 充值页、APIKeysPage 管理页、MainPage/SettingsPage 界面、DesignSystem 设计令牌）。
- 官方接口真实结构与逆向细节见 skill `macos-swiftui-app-dev`。
- v1.8.0 · 2026-10 · 界面重设计（刻度）+ 余额来源可选 + 菜单栏图标可选
