#!/bin/sh
#
# Kindle 时钟常亮部署脚本（越狱成功后使用）
#
# 功能：
#   1. 安装「屏幕常亮」开机自启服务（阻止屏保/休眠）
#   2. 安装「本机 Web 服务器」开机自启服务（浏览器访问 clock.html 用）
#   3. 两项服务立即生效，无需重启
#
# 用法（越狱后，通过 SSH 或 KUAL 终端以 root 执行）：
#   sh /mnt/us/clock-setup/install.sh
#
# 前提：clock.html 已放在 Kindle 的 documents 文件夹中
#

echo "==== Kindle 时钟常亮部署 ===="

# ---------- 1. 屏幕常亮（阻止屏保） ----------
cat > /etc/upstart/clock-alwayson.conf << 'EOF'
# 时钟常亮：循环设置 preventScreenSaver，防止被系统重置
start on started powerd
respawn
exec /bin/sh -c 'while true; do lipc-set-prop com.lab126.powerd preventScreenSaver 1; sleep 30; done'
EOF
echo "[1/2] 常亮服务已安装: /etc/upstart/clock-alwayson.conf"

# ---------- 2. 本机 Web 服务器 ----------
# 检测系统 busybox 是否带 httpd 功能
BB=""
for b in /usr/bin/busybox /bin/busybox; do
  if [ -x "$b" ] && "$b" 2>/dev/null | grep -qw httpd; then
    BB="$b"
    break
  fi
done

if [ -z "$BB" ]; then
  echo "警告: 系统 busybox 不含 httpd，跳过 Web 服务安装。"
  echo "      备选: 通过 KPM/KindleForge 安装带 Web 服务的管理插件。"
else
  cat > /etc/upstart/clock-httpd.conf << EOF
# 本机 Web 服务器: 浏览器访问 http://localhost:8080/clock.html
start on started framework
respawn
exec $BB httpd -p 8080 -h /mnt/us/documents
EOF
  echo "[2/2] Web 服务已安装: /etc/upstart/clock-httpd.conf (使用 $BB)"
fi

# ---------- 3. 立即生效 ----------
lipc-set-prop com.lab126.powerd preventScreenSaver 1 \
  && echo "常亮已开启(即时生效, 重启后由 upstart 自动维持)"

if [ -n "$BB" ]; then
  "$BB" httpd -p 8080 -h /mnt/us/documents &
  echo "Web 服务已启动(即时生效, 重启后由 upstart 自动维持)"
fi

echo ""
echo "==== 部署完成 ===="
echo "现在在实验性浏览器打开: http://localhost:8080/clock.html"
echo "无需 Wi-Fi 也能显示时钟; 连 Wi-Fi 时会额外显示天气并联网校时"
