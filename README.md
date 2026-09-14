# Kindle 时钟 / Kindle Clock

[中文](#中文) | [English](#english)

---

<a id="中文"></a>

## 中文

把闲置 Kindle 改造为墨水屏桌面时钟的单文件网页应用。专为旧版 Kindle 实验性浏览器优化，支持常亮显示、实时天气、屏幕旋转与网络校时。

### 功能列表

- **大字号时钟**：24 小时制（默认）/ 12 小时制切换，字号随屏幕自适应
- **日期与星期**：每天自动更新一次
- **实时天气**：Open-Meteo 免费接口（无需 API key），显示天气描述与温度，默认香港，可通过 URL 参数自定义城市
- **网络校时**：通过 timeapi.io 每小时校准一次，精确到秒，不依赖设备本地时钟
- **屏幕旋转**：竖屏 / 横屏（90° / 270°）三种方向，适配不同摆放方式，选择自动记忆
- **防残影**：每小时整点全屏黑白闪一次，强制墨水屏全局刷新，缓解长期常亮的残影问题
- **墨水屏优化**：仅在内容变化时更新 DOM，减少刷新与闪烁；离线时自动隐藏天气行
- **旧设备兼容**：不依赖 flexbox / viewport 单位，兼容旧版 WebKit 浏览器

### 安装步骤

#### 方式一：局域网 HTTP 服务（无需越狱）

> 适用于固件较新、浏览器禁用了 `file://` 协议的设备。

1. 在与 Kindle 同一 Wi-Fi 的电脑上，进入本目录启动服务：

   ```bash
   python3 -m http.server 8000
   ```

2. 在 Kindle 实验性浏览器地址栏输入（替换为电脑的局域网 IP）：

   ```
   http://192.168.x.x:8000/clock.html
   ```

3. 确认浏览器设置中已开启 JavaScript。

#### 方式二：越狱后本机服务（推荐长期使用）

> 适用于已越狱（如 SpringBreak）的设备，完全脱离外部电脑。

1. 将 `clock.html` 复制到 Kindle 的 `documents` 目录，`clock-setup/install.sh` 复制到任意目录。
2. 通过 SSH / KUAL 终端以 root 执行：

   ```bash
   sh /mnt/us/clock-setup/install.sh
   ```

3. 脚本会安装两个开机自启服务：
   - **屏幕常亮**：循环维持 `preventScreenSaver`，阻止屏保与休眠
   - **本机 Web 服务**：busybox httpd 监听 8080 端口

### 使用说明

- **切换显示模式**：点击屏幕循环切换 显示秒数 → 12 小时制 → 24 小时制
- **旋转屏幕**：点击右上角「旋转」按钮，循环 竖屏 → 横屏(90°) → 横屏(270°)
- **自定义城市**（URL 参数）：

  ```
  clock.html?lat=31.23&lon=121.47&city=上海      # 天气位置
  clock.html?tz=9                                  # 时区偏移（默认 +8）
  ```

- **常亮说明**：未越狱设备可在主页搜索栏输入 `~ds` 尝试禁用屏保（部分固件已失效，验证方法：输入后按电源键不再锁屏即生效；重启后失效）；越狱设备由 `install.sh` 安装的服务维持常亮。
- **耗电**：墨水屏仅在刷新时耗电，插电使用无续航压力；建议保持 Wi-Fi 开启以显示天气并校时。

---

<a id="english"></a>

## English

A single-file web app that turns an idle Kindle into an e-ink desk clock. Optimized for the legacy Kindle experimental browser, featuring always-on display, live weather, screen rotation, and network time sync.

### Features

- **Large clock**: 24-hour format (default) / 12-hour toggle, font size adapts to screen
- **Date & weekday**: auto-updated once per day
- **Live weather**: Open-Meteo free API (no API key required), shows condition and temperature; defaults to Hong Kong, customizable via URL params
- **Network time sync**: calibrated hourly via timeapi.io, accurate to the second, independent of the device clock
- **Screen rotation**: portrait / landscape (90° / 270°), adapts to any placement, choice is remembered
- **Ghosting prevention**: full-screen inverted flash at the top of every hour forces a full e-ink refresh
- **E-ink friendly**: DOM updates only when content changes, minimizing refreshes and flicker; weather row auto-hides when offline
- **Legacy compatible**: no flexbox / viewport units, works on old WebKit browsers

### Installation

#### Option 1: LAN HTTP server (no jailbreak required)

> For devices whose browser has disabled the `file://` protocol.

1. On a computer on the same Wi-Fi as the Kindle, start a server in this directory:

   ```bash
   python3 -m http.server 8000
   ```

2. In the Kindle experimental browser, enter (replace with your computer's LAN IP):

   ```
   http://192.168.x.x:8000/clock.html
   ```

3. Make sure JavaScript is enabled in browser settings.

#### Option 2: On-device server after jailbreak (recommended for long-term use)

> For jailbroken devices (e.g. via SpringBreak); fully independent of any computer.

1. Copy `clock.html` to the Kindle's `documents` directory and `clock-setup/install.sh` to any directory.
2. Run as root via SSH / KUAL terminal:

   ```bash
   sh /mnt/us/clock-setup/install.sh
   ```

3. The script installs two boot-persistent services:
   - **Always-on display**: keeps setting `preventScreenSaver` to block the screensaver and sleep
   - **Local web server**: busybox httpd listening on port 8080

### Usage

- **Display modes**: tap the screen to cycle seconds → 12-hour → 24-hour
- **Rotate**: tap the "旋转" (rotate) button at the top-right to cycle portrait → landscape(90°) → landscape(270°)
- **Customize via URL params**:

  ```
  clock.html?lat=31.23&lon=121.47&city=Shanghai   # weather location
  clock.html?tz=9                                  # timezone offset (default +8)
  ```

- **Always-on notes**: on non-jailbroken devices, try typing `~ds` in the home search bar to disable the screensaver (patched on some firmwares; to verify, press the power button afterwards — if it no longer locks, it worked; resets on reboot). On jailbroken devices, the service installed by `install.sh` keeps the screen on.
- **Power**: e-ink only draws power when refreshing — fine to keep plugged in. Wi-Fi is recommended for weather and time sync.

### Credits

- Weather data by [Open-Meteo](https://open-meteo.com/)
- Time sync by [timeapi.io](https://timeapi.io/)
- Jailbreak guides: [KindleModding Wiki](https://kindlemodding.org/)

## License

MIT
