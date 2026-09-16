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
- **横竖屏切换**：USB 放置/删除 `documents/HENG` 文件即可切换横屏（两个方向）/竖屏，拔线后 20 秒内生效，信息点完全相同
- **电源键退出**：3 秒内快速连按两下电源键即可退出时钟回到桌面——再也不怕锁死（触摸屏在冻结模式下不可用，故用物理按键）
- **维护窗口**：重启后 2 分钟内 + 每小时整点后 1 分钟内系统自动解冻，这些时段插 USB 维护最稳
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
# 输出 ../clockimg/ 共 9 个子目录（竖屏 + 横屏两方向），约 14,400 张 PNG，约 95MB
```

### 第 3 步：拷贝到 Kindle

USB 连接 Kindle，把以下内容拷入（约 14,400 张图片共 95MB，拷贝约 15-20 分钟）：

```
clockimg/time/ time_l/ time_r/           →  Kindle 根目录 /clockimg/（时间：竖屏+横屏×2）
clockimg/banner/ banner_l/ banner_r/     →  Kindle /clockimg/（日期星期）
clockimg/wx/ wx_l/ wx_r/                 →  Kindle /clockimg/（天气）
clock.sh                                 →  Kindle /documents/clock.sh
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
| 横屏/竖屏 | USB 连接后改 `documents/HENG` 文件：删除 = 竖屏；内容 `1` = 横屏（充电口在右）；内容 `2` = 横屏（充电口在左）。拔线后 20 秒内自动切换，无需重启 |
| 退出时钟（回桌面） | **3 秒内快速连按两下电源键**。20 秒内自动解冻、停止服务、回到桌面。之后重启不会自动运行时钟；想再用：书库点「大字时钟」 |
| USB 维护最佳时机 | 重启后 2 分钟内，或每小时整点后 1 分钟内（系统自动解冻，USB 读写最可靠）。冻结期间插 USB 虽能看到盘，但设备端缓存可能读不到新写入的文件 |
| 触摸无反应 | 正常现象——时钟模式下系统 UI 已冻结（这正是屏幕不被覆盖的原因）。退出用电源键双击 |
| 紧急恢复 | 长按电源键约 10 秒强制重启（硬件级，永远有效）；重启后时钟自动回来 |
| 彻底停用 | USB 连接后在 documents 文件夹新建名为 `STOP` 的空文件，20 秒内自动解冻、清理自启、退出 |

**耗电与发热**：常亮 + 每分钟刷新 + Wi-Fi 常开的功耗高于正常待机，请保持插电使用。

**修改天气城市**：见下方「自定义配置」。

## 自定义配置

一句话原则：**"长什么样"在预渲染图片里（改 mkpics.py，需重新生成图片）；"多久一次/在哪里"在设备脚本里（改 clock.sh，换文件即生效）**。

| 想改什么 | 改哪里 | 默认值 | 生效方式 |
|---|---|---|---|
| 天气更新频率 | `clock.sh` 主循环里的 `1800`（单位：秒） | 30 分钟 | 重新拷 clock.sh 到 documents/，书库点一下「大字时钟」重启脚本即可，无需动图片 |
| 天气城市 | `clock.sh` `weather()` 里的 `latitude=22.3193&longitude=114.1694` | 香港 | 同上（坐标可在 Open-Meteo 官网查询） |
| 字体大小/布局/日期格式 | `mkpics.py`（时间 192/252px、日期 72px、星期 58px、温度 96px，各段均有注释） | 见脚本 | 电脑上 `python3 mkpics.py` 重新生成，再把 clockimg/ 拷回 Kindle（约 95MB） |
| 天气描述用词 | `mkpics.py` 的 `DESCS` 列表 | 晴/局部多云/多云… | 重新生成图片；**必须同步**修改 `clock.sh` 里 weather_code → 序号的 `case` 映射，两边顺序一一对应 |

## 换一台 Kindle 怎么迁移？

整套方案只有三样东西跟具体设备绑定：**越狱方式、屏幕分辨率、fbink 路径**。其余（脚本逻辑、全套图片、电源键双击退出、横竖屏切换）直接复用。

1. **查新机固件 → 选越狱方式**：到 [kindlemodding.org 越狱向导](https://kindlemodding.org/jailbreak-wizard.html) 按固件版本选择（本项目的 5.18.1.1.1 用 SpringBreak，其他固件可能是其他工具）。越狱后务必插线再跑一次工具清理填充文件，否则开机要 15 分钟以上。
2. **核对屏幕分辨率**：与 600×800 相同 → 直接复用现有 `clockimg/`；不同（如 Paperwhite 高分屏）→ 需改 `mkpics.py`：顶部 `W, H`（竖屏）/ `LW, LH`（横屏）、banner 与 wx 的画布尺寸（`600,200` / `800,170`，共 4 处）、各字号按比例放大；同时改 `clock.sh` `draw()` 末尾 GC16 刷新区域的 `width=600,height=800`。然后重新生成图片。
3. **拷贝文件**：USB 连新机，`clockimg/` 的 9 个子目录 → 根目录 `/clockimg/`；`clock.sh` → `/documents/`。
4. **核对 fbink 路径**：`clock.sh` 顶部的 `FBINK=/mnt/us/libkh/bin/fbink`，新机越狱方案若把 fbink 放在别处，改这一行即可。
5. **启动**：书库点「大字时钟」。电源键双击退出是 v8 自动扫描输入设备实现的，换机型无需改代码。
6. **旧机退役（可选）**：在维护窗口（重启后 2 分钟内 / 每小时整点后 1 分钟内）插 USB，往 documents/ 放一个名为 `STOP` 的空文件即彻底停用；或直接删除 `/clockimg/` 与 `/documents/clock.sh`。

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
11. **冻结 UI 与 USB 维护的死锁**：冻结 cvm/awesome 后屏幕确实稳了，但设备端文件缓存导致「USB 写入的 STOP 停表文件」运行中的脚本看不见（Mac 能写进去、设备读不到），且退出机制全部依赖 USB——形成死锁。曾导致设备锁死在时钟界面，只能强启。解法（v5/v6）：脚本自拷贝到 `/tmp` 内存运行（不占用户分区）+ 定时维护窗口（重启后 2 分钟、每小时整点 1 分钟解冻）+ **电源键双击退出**（后台直接读内核输入事件 `/dev/input/eventX`，不依赖屏幕触摸与 USB，冻结状态下照常工作）。
12. **shell 解析 `od -d` 输出的坑**：不同 od 实现输出字段数不同（8/9/10 个：有无偏移列、有无尾偏移列），按固定下标解析会漏判。解法：按 `case $#` 分支处理；另外 zsh 测试脚本时变量不做词分割，`set -- $E` 结果与设备上的 sh 不同，测试必须用 `sh -c`。
13. **电源键不在 gpio-keys 设备上**：Basic 3 的电源键挂在名为 `bd71827-power` 的输入设备（event1），而非老机型教程默认的 `gpio-keys`（event0）——照搬硬编码监视 gpio-keys 会导致双击退出毫无反应，且无任何报错。v8 改为启动时扫描 `/proc/bus/input/devices`，凡名称含 key/pwr/power 的输入设备全部并行监视；无匹配时退化为监视全部 event 设备。

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
- **Portrait/landscape switch**: create/delete the `documents/HENG` file over USB — landscape (two directions) or portrait, effective within 20 s after unplugging, identical information
- **Power-button exit**: double-press the power button within 3 s to exit the clock and return to the home screen — no more lock-ins (touch is dead while frozen, hence a physical button)
- **Maintenance windows**: the system auto-unfreezes for the first 2 min after boot and for 1 min at the top of every hour — plug USB during these windows for reliable maintenance
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
python3 mkpics.py     # -> ../clockimg/ 9 subdirs (~14,400 PNGs, ~95 MB)
```

### 3. Copy to Kindle

```
clockimg/time/ time_l/ time_r/           ->  /clockimg/
clockimg/banner/ banner_l/ banner_r/     ->  /clockimg/
clockimg/wx/ wx_l/ wx_r/                 ->  /clockimg/
clock.sh                                 ->  /documents/clock.sh
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
| Portrait/landscape | Edit `documents/HENG` over USB: absent = portrait; content `1` = landscape (USB port on the right); `2` = landscape (USB port on the left). Takes effect within 20 s after unplugging |
| Exit the clock | **Double-press the power button within 3 s.** It unfreezes, stops the service and returns to home within 20 s. The clock won't auto-start after reboots; tap "Big Clock" in the library to use it again |
| Best time for USB maintenance | Within 2 min after a reboot, or within 1 min after any full hour (the system auto-unfreezes). Outside windows, files written over USB may be invisible to the running script due to device-side caching |
| Touch unresponsive | Expected — the UI is frozen (that's why nothing can cover the clock). Exit with the power-button double-press |
| Emergency escape | Hold the power button ~10 s for a hard reboot (always works); the clock returns afterwards |
| Stop for good | Create an empty file named `STOP` in documents/ via USB; it unfreezes, removes auto-start and exits within 20 s |

**Power/heat**: always-on + Wi-Fi draws more than standby — keep it plugged in.

**Change city**: see [Customization](#customization) below.

## Customization

Rule of thumb: **what it looks like lives in the pre-rendered images (edit mkpics.py, regenerate); how often / where lives in the device script (edit clock.sh, just re-copy it)**.

| To change | Edit | Default | How to apply |
|---|---|---|---|
| Weather refresh interval | `1800` (seconds) in the main loop of `clock.sh` | 30 min | Re-copy clock.sh to documents/ and tap "Big Clock" to restart the script — no image changes needed |
| Weather city | coordinates `latitude=22.3193&longitude=114.1694` in `weather()` | Hong Kong | Same as above (lookup coordinates on open-meteo.com) |
| Font sizes / layout / date format | `mkpics.py` (time 192/252 px, date 72 px, weekday 58 px, temp 96 px — commented in the script) | see script | Re-run `python3 mkpics.py` on the computer, copy clockimg/ back to the Kindle (~95 MB) |
| Weather wording | the `DESCS` list in `mkpics.py` | 晴/局部多云/… | Regenerate images; you **must also** update the weather_code → index `case` mapping in `clock.sh` — the two must stay in sync |

## Migrating to Another Kindle

Only three things are device-specific: **the jailbreak method, the screen resolution, and the fbink path**. Everything else (script logic, all images, power-button double-press exit, orientation switching) carries over as-is.

1. **Check the new device's firmware → pick a jailbreak**: follow the [kindlemodding.org wizard](https://kindlemodding.org/jailbreak-wizard.html) (this project's 5.18.1.1.1 uses SpringBreak; other firmwares may need other tools). After jailbreaking, plug in and run the tool once more to clean filler files, or boots take 15+ minutes.
2. **Check the screen resolution**: same 600×800 → reuse the existing `clockimg/` as-is; different (e.g. a high-res Paperwhite) → edit `mkpics.py`: `W, H` (portrait) / `LW, LH` (landscape) at the top, the banner & wx canvas sizes (`600,200` / `800,170`, 4 places), and scale up font sizes proportionally; also update the GC16 refresh region `width=600,height=800` at the end of `draw()` in `clock.sh`. Then regenerate the images.
3. **Copy files**: `clockimg/`'s 9 subdirs → `/clockimg/` at the Kindle root; `clock.sh` → `/documents/`.
4. **Verify the fbink path**: `FBINK=/mnt/us/libkh/bin/fbink` near the top of `clock.sh`; adjust if your jailbreak bundle puts fbink elsewhere.
5. **Start**: tap "Big Clock" in the library. The double-press exit auto-scans input devices (v8) — no per-model tweaks needed.
6. **Retire the old device (optional)**: during a maintenance window (within 2 min after a reboot, or within 1 min after a full hour), plug USB and drop an empty file named `STOP` into documents/; or simply delete `/clockimg/` and `/documents/clock.sh`.

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
11. **Freeze vs. USB maintenance deadlock**: freezing cvm/awesome stabilized the screen, but device-side file caching made USB-written STOP files invisible to the running script (the Mac could write them, the device couldn't see them), while every exit mechanism depended on USB — a deadlock that once locked the device on the clock screen. Fixes (v5/v6): run the script from a `/tmp` self-copy (user partition stays unmounted), scheduled maintenance windows (2 min after boot, 1 min each full hour), and the **power-button double-press exit** (reads kernel input events from `/dev/input/eventX` directly — works while frozen, no touch or USB needed).
12. **Parsing `od -d` in shell**: different od builds emit 8/9/10 fields (leading offset, trailing offset), so fixed-index parsing silently fails. Fix: branch on `case $#`; also, zsh doesn't word-split variables, so `set -- $E` behaves differently than on-device sh — always test parsers with `sh -c`.
13. **The power button is not on gpio-keys**: on Basic 3 it lives on an input device named `bd71827-power` (event1), not the `gpio-keys` (event0) older guides assume — a hardcoded gpio-keys watcher makes the double-press exit silently dead. v8 auto-scans `/proc/bus/input/devices` at startup and watches every device whose name contains key/pwr/power in parallel, falling back to all event devices if nothing matches.

## Alternative: web version (no jailbreak)

`clock.html` is a standalone web clock (adaptive big digits, weather, tap-to-rotate, hourly anti-ghost repaint). Serve it from any computer (`python3 -m http.server 8000`) and open `http://<computer-IP>:8000/clock.html` on the same LAN. On the target device it cannot stay on without the computer, which is why the image-based approach exists.

## Credits

- [KindleModding](https://kindlemodding.org/) — SpringBreak jailbreak
- [FBInk](https://github.com/NiLuJe/FBInk) by NiLuJe — e-ink framebuffer drawing
- [Open-Meteo](https://open-meteo.com/) — free weather API

## License

MIT
