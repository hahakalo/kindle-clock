# Kindle 墨水屏常亮大字时钟

> 把一台闲置的旧 Kindle 改造成"插电即用"的桌面常亮时钟：超大时间 + 日期星期 + 实时天气，老人友好，永不熄屏。

**[English](#english)** | 中文

---

## 项目介绍

一台吃灰的旧 Kindle，越狱后改造成专用墨水屏时钟：

```
        9月16日          ← 日期（72px）
        星期三           ← 星期（58px）
        22:41           ← 时间（超大，隔 3 米可读）
        25°C            ← 温度（96px）
         晴             ← 天气（58px）
```

- **常亮**：脚本每 20 秒维持一次防休眠，插电即永久显示，每分钟走字
- **老人友好**：全屏大字、多行分区、纯黑白墨水屏对比度
- **零依赖**：不依赖浏览器、不依赖局域网服务器、不依赖任何外部主机——全部在 Kindle 本机运行
- **开机自启**：重启后时钟自动恢复，无需任何操作
- **天气**：Open-Meteo 免费接口（无需 key），每 30 分钟更新；断网时时钟照常走

## 我的设备（实测通过）

| 项目 | 信息 |
|---|---|
| 机型 | Kindle Basic 3（第 10 代，2019 款，无阅读灯版） |
| 固件 | 5.18.1.1.1 |
| 屏幕 | 600×800，167 DPI，8bpp 灰度墨水屏 |
| 越狱方式 | [SpringBreak](https://kindlemodding.org/jailbreaking/SpringBreak/)（商店缓存漏洞，越狱时需短暂联网） |
| 关键依赖 | 越狱自带 `fbink`（libkh）、系统自带 `eips`、upstart、lipc |

> 理论上任何能装 SpringBreak / 有 fbink 的 Kindle 均可套用，只需按屏幕分辨率重新生成图片。

## 方案原理（为什么长这样）

本项目走过浏览器、HTTP 服务、网络转发等弯路后（见下方踩坑记录），最终收敛为**最朴素也最可靠的架构**：

1. **预渲染图片**：在电脑上用 Python + Pillow 预先生成全部画面——1440 张分钟图 + 2562 张日期星期图 + 793 张天气图，全部是 600×800 或 600×200 的灰度 PNG。**设备端零文字排版**，从根源消灭字体/定位/渲染类故障。
2. **设备端只做"换图"**：`clock.sh` 每分钟用 fbink 把三张图叠进 framebuffer（时间打底 + 顶部日期 + 底部天气），一次 GC16 整屏刷新，墨水屏原生显示。
3. **Kiosk 冻结**：绘制完成后 `kill -STOP` 冻结系统 UI 进程（cvm/awesome），任何程序都无法再重画屏幕盖住时钟，同时后台进程也不会被系统清理。
4. **三重保活**：upstart 开机自启服务 / setsid 独立会话 / scriptlet 本体兜底，任何一层活着时钟就在。

## 仓库结构

```
kindle-clock/
├── README.md               # 本文档
├── clock.html              # 网页版时钟（替代方案，免越狱，详见"替代方案"）
└── clock-setup/
    ├── clock.sh            # 设备端时钟脚本（最终方案，拷到 Kindle documents/）
    └── mkpics.py           # 图片生成器（在电脑上运行，需 Python3 + Pillow）
```

## 安装步骤

### 第 1 步：越狱（已越狱可跳过）

按 [kindlemodding.org](https://kindlemodding.org/jailbreak-wizard.html) 的向导选择适合你固件的越狱方式。5.18.1.1.1 用 SpringBreak：

1. 设备已注册亚马逊账号、开启飞行模式、重启
2. USB 连电脑，屏幕出现标准传输画面后，运行官方一键脚本（见 SpringBreak 官方文档）
3. 拔线 → 打开商店（提示联网时关闭飞行模式）→ 等待越狱页面加载完成
4. **越狱成功后必须重新插线运行一次工具清理填充文件**，否则开机要 15 分钟以上

### 第 2 步：生成图片（在电脑上）

```bash
# 依赖：Python 3 + Pillow
pip install --user Pillow

# 字体：mkpics.py 需要一个粗体 TTF（如 Arial Bold / 思源黑体 Heavy）
# 放到 clock-setup/Arial-Bold.ttf（版权原因未入库）
# 中文部分自动调用 macOS 系统字体，Linux 用户请自行改 mkpics.py 里的字体路径

cd clock-setup
python3 mkpics.py
# 输出 ../clockimg/{time,banner,wx}/ 共约 4800 张 PNG，约 34MB
```

### 第 3 步：拷贝到 Kindle

USB 连接 Kindle，把以下内容拷入（约 5-8 分钟）：

```
clockimg/time/    →  Kindle 根目录 /clockimg/time/
clockimg/banner/  →  Kindle 根目录 /clockimg/banner/
clockimg/wx/      →  Kindle 根目录 /clockimg/wx/
clock.sh          →  Kindle /documents/clock.sh
```

弹出并拔线。

### 第 4 步：启动

打开 Kindle 书库，点击新出现的条目 **「大字时钟 Big Clock」**（KPV scriptlet）——屏幕闪一下桌面后（1-2 秒冻结生效期），时钟出现并开始每分钟走字。同时自动安装开机自启，以后重启无需任何操作。

## 使用说明

| 场景 | 操作 |
|---|---|
| 日常使用 | 插上电源线即可。常亮是自动的：脚本每 20 秒维持一次防休眠信号 |
| 重启后 | 无需操作，开机自启服务自动恢复时钟 |
| 天气 | 保持 Wi-Fi 连接，每 30 分钟自动更新（Open-Meteo，免费无 key） |
| 触摸无反应 | 正常现象——时钟模式下系统 UI 已冻结（这正是屏幕不被覆盖的原因） |
| 紧急恢复 | 长按电源键约 10 秒强制重启（硬件级，永远有效）；重启后时钟自动回来 |
| 彻底停用 | USB 连接后在 documents 文件夹新建名为 `STOP` 的空文件，20 秒内自动解冻、清理自启、退出 |

**耗电与发热**：常亮 + 每分钟刷新 + Wi-Fi 常开的功耗高于正常待机，请保持插电使用。

**修改天气城市**：编辑 `clock.sh` 中 `weather()` 函数里的经纬度（默认香港 22.3193, 114.1694），改成你的城市坐标即可（Open-Meteo 官网可查）。

## 踩坑记录（血泪史，按时间顺序）

这些坑消耗了大量时间，记录于此，后人绕行：

1. **`~ds` 防休眠命令被封**：老 Kindle 社区流传的主页搜索栏输 `~ds` 禁用屏保的方法，在 5.18.1.1.1 固件上已被封禁（输完按电源键照样锁屏），只能越狱后用 `lipc-set-prop com.lab126.powerd preventScreenSaver 1` 循环维持。
2. **实验性浏览器不支持 `file://`**：弹出"无法通过本协议下载文件，只支持 HTTP/HTTPS"——网页版必须有 HTTP 服务器。
3. **旧 Kindle 浏览器地址栏会"劫持"输入**：自动补全成历史记录里的旧网址，且"清除历史记录"操作后依然如故，最终无法手动访问任何新地址。
4. **`localhost`/`127.0.0.1` 本机回环可用，但历史记录里的局域网地址（如 `192.168.x.x:8000`）无法通过任何方式重定向回本机**：ifconfig 别名、ip route local 表、iptables nat REDIRECT（该固件根本没有 iptables）逐一尝试全部失败，wget 日志显示包发出后被静默丢弃。
5. **Mac 当 HTTP 服务器不可行**：依赖 Mac 常开，且换网络后 IP 变化导致书签失效。
6. **系统自带 eips 不认 Pillow 生成的 GIF**：报 `unknown image type`，时间图从未显示——GIF 调色板/格式兼容性问题，改用 PNG 后 fbink 直接支持。
7. **scriptlet 退出时系统会清理后台进程 + 桌面重画盖屏**：这是"闪退回桌面"的真凶。日志证明时钟完整绘制过两轮，随后进程被杀。解法：绘制后 `kill -STOP` 冻结 UI（kiosk 模式）+ upstart/setsid 三重保活。
8. **图片文件名重名陷阱**：日期图用 `月日` 不补零命名时，`1月11日` 与 `11月1日` 都是 `111`，互相覆盖后一年有 18 天显示错误日期。改用补零（`0111`/`1101`）根治。
9. **越狱后首次开机极慢属正常**：SpringBreak 填充文件未清理时，开机最长 15 分钟，**不要**误判为变砖而强制重启。
10. **墨水屏残影**：常亮显示数小时后会有淡残影，时钟每分钟用 GC16 波形整屏刷新，基本可控；长期使用如出现顽固残影，重启一次即可深度清屏。

## 替代方案：网页版（免越狱）

仓库里的 `clock.html` 是纯网页版时钟（自适应大字、天气、点击横屏、防残影整点重绘），适合：

- 不想越狱的设备：Mac/PC 上 `python3 -m http.server 8000` 后，Kindle 浏览器访问 `http://<电脑IP>:8000/clock.html`（需同一局域网）
- 但在本文的目标设备上，受坑 3/4/5 限制，网页版**无法脱离电脑独立常亮**，故仅作参考保留

## 致谢

- [KindleModding 社区](https://kindlemodding.org/) — SpringBreak 越狱与文档
- [FBInk](https://github.com/NiLuJe/FBInk)（NiLuJe）— 墨水屏 framebuffer 绘制
- [Open-Meteo](https://open-meteo.com/) — 免费天气 API
- KPV scriptlet 机制让"点书启动脚本"成为可能

## License

MIT

---

<a name="english"></a>

# Kindle E-Ink Always-On Clock (English)

> Turn a dusty old Kindle into a plug-in-and-forget desk clock: huge time + date/weekday + live weather, senior-friendly, never sleeps.

**English** | **[中文](#kindle-墨水屏常亮大字时钟)**

---

## Overview

A jailbroken old Kindle repurposed as a dedicated e-ink clock:

- **Always on**: the script renews a prevent-screensaver property every 20 s; with USB power it displays 24/7, updating every minute
- **Senior-friendly**: full-screen large text, multi-row layout, pure black & white
- **Zero external dependencies**: no browser, no LAN server, no host computer — everything runs on the Kindle itself
- **Auto-start on boot**: after a reboot the clock comes back by itself
- **Weather**: free Open-Meteo API (no key), refreshed every 30 min; offline the clock keeps ticking

## Tested Device

| Item | Info |
|---|---|
| Model | Kindle Basic 3 (10th gen, 2019, non-backlit) |
| Firmware | 5.18.1.1.1 |
| Screen | 600×800, 167 DPI, 8bpp grayscale |
| Jailbreak | [SpringBreak](https://kindlemodding.org/jailbreaking/SpringBreak/) |
| Key deps | bundled `fbink` (libkh), system `eips`, upstart, lipc |

## How It Works

After dead ends with browsers, HTTP servers and network redirects (see Pitfalls), the project converged on the simplest reliable architecture:

1. **Pre-rendered images**: ~4,800 grayscale PNGs generated on the computer (1,440 minute images + 2,562 date/weekday images + 793 weather images). Zero text layout happens on the device.
2. **The device only swaps images**: every minute `clock.sh` composites three PNGs into the framebuffer with fbink and does one GC16 full refresh.
3. **Kiosk freeze**: after drawing, system UI processes (cvm/awesome) are frozen with `kill -STOP`, so nothing can ever paint over the clock, and background processes survive scriptlet cleanup.
4. **Triple keep-alive**: upstart boot service / setsid session / scriptlet itself.

## Repo Structure

```
kindle-clock/
├── README.md               # this doc
├── clock.html              # web-based clock (alternative, no jailbreak needed)
└── clock-setup/
    ├── clock.sh            # device-side clock script (copy to Kindle documents/)
    └── mkpics.py           # image generator (run on computer, needs Python3 + Pillow)
```

## Installation

### 1. Jailbreak (skip if done)

Follow the wizard at [kindlemodding.org](https://kindlemodding.org/jailbreak-wizard.html). For firmware 5.18.1.1.1 use SpringBreak. **Important**: after a successful jailbreak, plug back in and run the tool once more to clean up filler files, or boots will take 15+ minutes.

### 2. Generate images (on computer)

```bash
pip install --user Pillow
# Place a bold TTF at clock-setup/Arial-Bold.ttf (not in repo for licensing)
# CJK glyphs use macOS system fonts; Linux users edit font paths in mkpics.py

cd clock-setup
python3 mkpics.py     # -> ../clockimg/{time,banner,wx}/ (~4,800 PNGs, ~34 MB)
```

### 3. Copy to Kindle

```
clockimg/time/    ->  /clockimg/time/
clockimg/banner/  ->  /clockimg/banner/
clockimg/wx/      ->  /clockimg/wx/
clock.sh          ->  /documents/clock.sh
```

Eject and unplug.

### 4. Start

Open the Kindle library and tap the new entry **"Big Clock"** (KPV scriptlet). The screen flashes the home page for 1–2 s (before the freeze takes effect), then the clock appears and ticks every minute. Boot auto-start is installed in the same step.

## Usage

| Scenario | Action |
|---|---|
| Daily use | Just keep it plugged in. Always-on is automatic (anti-sleep signal every 20 s) |
| After reboot | Nothing — the boot service restores the clock |
| Weather | Keep Wi-Fi on; refreshed every 30 min |
| Touch unresponsive | Expected — the UI is frozen (that's why nothing can cover the clock) |
| Emergency escape | Hold the power button ~10 s for a hard reboot (always works); the clock returns afterwards |
| Stop for good | Create an empty file named `STOP` in documents/ via USB; it unfreezes, removes auto-start and exits within 20 s |

**Power/heat**: always-on + Wi-Fi draws more than standby — keep it plugged in.

**Change city**: edit the coordinates in `weather()` inside `clock.sh` (default: Hong Kong).

## Pitfalls (in order of encounter)

1. **`~ds` anti-screensaver command is blocked** on firmware 5.18.1.1.1; only the jailbroken `lipc-set-prop ... preventScreenSaver 1` loop works.
2. **The experimental browser rejects `file://`** ("only HTTP and HTTPS are supported") — a web clock needs an HTTP server.
3. **The old browser's address bar hijacks input** with history auto-complete; even after "clear history" it persists.
4. **No way to redirect an old LAN URL back to localhost**: alias, local route table, iptables (not present on this firmware) all failed silently.
5. **A computer-hosted server is not viable** (must stay on; IP changes break bookmarks).
6. **System eips can't read Pillow-generated GIFs** (`unknown image type`); PNGs work fine with fbink.
7. **Scriptlet exit kills background processes and the home screen repaints over everything** — the real "crash to home" culprit. Fixed by freezing UI processes (kiosk) + triple keep-alive.
8. **Filename collision trap**: date images named without zero-padding collide (`1月11日` vs `11月1日`), corrupting 18 days a year. Zero-padding fixes it.
9. **First boot after jailbreak can take up to 15 minutes** if filler files aren't cleaned — do not mistake it for a brick.
10. **E-ink ghosting**: mostly handled by GC16 full refreshes each minute; a reboot deep-cleans stubborn ghosts.

## Alternative: web version (no jailbreak)

`clock.html` is a standalone web clock (adaptive big digits, weather, tap-to-rotate, hourly anti-ghost repaint). Serve it from any computer (`python3 -m http.server 8000`) and open `http://<computer-IP>:8000/clock.html` on the same LAN. On the target device it cannot stay on without the computer, which is why the image-based approach exists.

## Credits

- [KindleModding](https://kindlemodding.org/) — SpringBreak jailbreak
- [FBInk](https://github.com/NiLuJe/FBInk) by NiLuJe — e-ink framebuffer drawing
- [Open-Meteo](https://open-meteo.com/) — free weather API

## License

MIT
