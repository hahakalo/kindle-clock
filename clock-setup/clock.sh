#!/bin/sh
# Name: 大字时钟 Big Clock
# Author: hahakalo
#
# v6 新增「电源键双击退出」—— 修复冻结后无法退出的问题：
#   屏幕触摸在冻结模式下不可用（这正是防覆盖机制），因此退出做成物理按键：
#   3 秒内快速连按两下电源键 = 退出时钟（解冻、停服务、回桌面）
#   单按电源键 = 无反应（防误触）；长按 = 硬件强制重启（不变）
#   退出后重启不会自动运行时钟，想再用：书库点「大字时钟」
#
# v5 维护窗口（保留）：
#   - 脚本自拷贝到 /tmp 运行，不占用用户分区，USB 读写安全
#   - 重启后前 120 秒 + 每小时整点后 60 秒系统自动解冻（维护期，插 USB 最稳）
#
# v4 横竖屏（保留）：documents/HENG：无=竖屏；1=横屏(充电口右)；2=横屏(充电口左)
# v3 要点（保留）：预渲染图片 + fbink 绘制 + 冻结防覆盖 + 三重进程保活

IMG=/mnt/us/clockimg
DOC=/mnt/us/documents
FBINK=/mnt/us/libkh/bin/fbink
EIPS=/usr/sbin/eips
LOG=$DOC/clock.log
PIDF=/tmp/bigclock.pid
FROZ=/tmp/clock-frozen.pids
ORI=0   # 0=竖屏 1=横屏L(充电口右) 2=横屏R(充电口左)

# ================= 入口（点击书库条目） =================
if [ "$1" != "bg" ]; then
  rm -f "$LOG" "$DOC/STOP" /tmp/clock-quit
  echo "===== entry $(date) =====" >> "$LOG"
  # 解冻（清上次残留）+ 先杀旧进程（先 CONT 再 KILL，防旧进程处于停止态卡住 initctl）
  [ -f "$FROZ" ] && { for p in $(cat "$FROZ"); do kill -CONT $p 2>/dev/null; done; rm -f "$FROZ"; }
  for p in /tmp/clock-pro.pid /tmp/clock-display.pid "$PIDF"; do
    [ -f "$p" ] && { OP=$(cat "$p"); kill -CONT $OP 2>/dev/null; kill -9 $OP 2>/dev/null; }
  done
  rm -f "$PIDF"
  for j in clock-pro clock-display clock-alwayson clock-httpd clock-web8000 bigclock; do
    /sbin/initctl stop $j >> "$LOG" 2>&1
  done
  rm -f /etc/upstart/clock-pro.conf /etc/upstart/clock-display.conf \
        /etc/upstart/clock-alwayson.conf /etc/upstart/clock-httpd.conf \
        /etc/upstart/clock-web8000.conf >> "$LOG" 2>&1
  /sbin/initctl reload-configuration >> "$LOG" 2>&1
  # 清旧实验文件
  rm -f /mnt/us/clockimg/*.gif /mnt/us/clockfont.ttf >> "$LOG" 2>&1
  rm -f "$DOC"/clock-pro.sh "$DOC"/clock-pro.log "$DOC"/clock.html >> "$LOG" 2>&1
  rm -f "$DOC"/clock-fix*.sh "$DOC"/clock-display.sh "$DOC"/clock-setup.sh \
        "$DOC"/busybox "$DOC"/Arial-Bold.ttf "$DOC"/clock.sh.bak >> "$LOG" 2>&1
  # 安装开机自启
  if ! (echo > /etc/.t) 2>/dev/null; then
    mount -o remount,rw / >> "$LOG" 2>&1
  fi
  rm -f /etc/.t
  cat > /etc/upstart/bigclock.conf << EOF
start on started framework
respawn
normal exit 1
exec /bin/sh $DOC/clock.sh bg
EOF
  /sbin/initctl reload-configuration >> "$LOG" 2>&1
  /sbin/initctl start bigclock >> "$LOG" 2>&1
  mount -o remount,ro / >> "$LOG" 2>&1
  # 保活链：upstart 起来没？没起 -> setsid/nohup 再拉；再不行 -> 自己变成时钟
  alive() { [ -f "$PIDF" ] && kill -0 "$(cat "$PIDF")" 2>/dev/null; }
  sleep 3
  alive || {
    if command -v setsid >/dev/null 2>&1; then
      setsid /bin/sh "$0" bg </dev/null >/dev/null 2>&1 &
    else
      nohup /bin/sh "$0" bg >/dev/null 2>&1 &
    fi
    sleep 3
  }
  alive || exec /bin/sh "$0" bg   # scriptlet 本体变时钟（永不返回）
  exit 0
fi

# ================= 后台主程序 =================
# ---- 自拷贝到 /tmp 运行：不占用 /mnt/us，USB 模式可正常卸载用户分区 ----
case "$0" in
  /tmp/*) ;;
  *) cp "$0" /tmp/clock.sh 2>>"$LOG" && exec /bin/sh /tmp/clock.sh bg ;;
esac

echo "===== bg $(date) pid $$ =====" >> "$LOG"
if [ -f "$PIDF" ] && kill -0 "$(cat "$PIDF")" 2>/dev/null; then
  echo "another instance alive, exit" >> "$LOG"; exit 1
fi
echo $$ > "$PIDF"
[ -f "$FROZ" ] && { for p in $(cat "$FROZ"); do kill -CONT $p 2>/dev/null; done; rm -f "$FROZ"; }

[ -f $IMG/time/0000.png ] || {
  echo "FATAL: no clockimg/time" >> "$LOG"
  $EIPS "CLOCK FAIL: clockimg/time missing" >/dev/null 2>&1
  exit 1
}

# ---------- 模式自检 ----------
MODE=1
if [ -x "$FBINK" ]; then
  "$FBINK" -g file=$IMG/time/0000.png,halign=CENTER,valign=MIDDLE -b >>"$LOG" 2>&1 || MODE=2
else
  MODE=2
fi
if [ "$MODE" = "2" ]; then
  $EIPS -g $IMG/time/0000.png >>"$LOG" 2>&1 || MODE=3
fi
echo "MODE=$MODE" >> "$LOG"

# ---------- 读取横竖屏设置（HENG 文件，USB 可改） ----------
read_ori() {
  ORI=0
  if [ -f "$DOC/HENG" ]; then
    ORI=1
    read V < "$DOC/HENG" 2>/dev/null
    case "$V" in
      2*|r*|R*) ORI=2 ;;
    esac
  fi
}

WXIMG=""; WXLINE=""; WTIME=0

weather() {
  R=$(curl -k -s -m 15 "https://api.open-meteo.com/v1/forecast?latitude=22.3193&longitude=114.1694&current=temperature_2m,weather_code" 2>>"$LOG")
  T=$(echo "$R" | sed -n 's/.*"temperature_2m":\(-\{0,1\}[0-9][0-9.]*\).*/\1/p' | cut -d. -f1)
  C=$(echo "$R" | sed -n 's/.*"weather_code":\([0-9][0-9]*\).*/\1/p')
  echo "wx t=$T code=$C" >> "$LOG"
  if [ -n "$T" ] && [ -n "$C" ]; then
    [ "$T" -lt -10 ] 2>/dev/null && T=-10
    [ "$T" -gt 50 ] 2>/dev/null && T=50
    case "$C" in
      0) DI=0 ;; 1) DI=1 ;; 2) DI=2 ;; 3) DI=3 ;;
      45|48) DI=4 ;; 51|53|55) DI=5 ;; 56|57|66|67) DI=6 ;;
      61) DI=7 ;; 63) DI=8 ;; 65) DI=9 ;;
      71|73|75|77|85|86) DI=10 ;; 80|81|82) DI=11 ;; 95|96|99) DI=12 ;; *) DI=2 ;;
    esac
    WXIMG="T${T}D${DI}.png"; WXLINE="${T}C"
  else
    WXIMG=""; WXLINE=""
  fi
  WTIME=$(date +%s)
  SZ=$(wc -c < "$LOG" 2>/dev/null || echo 0)
  [ "$SZ" -gt 400000 ] 2>/dev/null && { tail -n 400 "$LOG" > "$LOG.t" 2>/dev/null && mv "$LOG.t" "$LOG"; }
}

weekday_cn() {
  W=$(date +%u 2>/dev/null)
  [ -n "$W" ] || W=$(( ($(date +%w) + 6) % 7 + 1 ))
  case "$W" in
    1) echo 星期一 ;; 2) echo 星期二 ;; 3) echo 星期三 ;;
    4) echo 星期四 ;; 5) echo 星期五 ;; 6) echo 星期六 ;; 7) echo 星期日 ;;
  esac
}

draw() {
  HM=$(date +%H%M)
  if [ "$MODE" = "1" ]; then
    M=$(date +%m); D=$(date +%d)
    W=$(date +%u 2>/dev/null)
    [ -n "$W" ] || W=$(( ($(date +%w) + 6) % 7 + 1 ))
    if [ "$ORI" = "1" ]; then
      "$FBINK" -g file=$IMG/time_l/$HM.png,halign=CENTER,valign=MIDDLE -b >>"$LOG" 2>&1
      "$FBINK" -g file=$IMG/banner_l/$M$D-$W.png,halign=RIGHT,valign=TOP -b >>"$LOG" 2>&1
      [ -n "$WXIMG" ] && "$FBINK" -g file=$IMG/wx_l/$WXIMG,halign=LEFT,valign=TOP -b >>"$LOG" 2>&1
    elif [ "$ORI" = "2" ]; then
      "$FBINK" -g file=$IMG/time_r/$HM.png,halign=CENTER,valign=MIDDLE -b >>"$LOG" 2>&1
      "$FBINK" -g file=$IMG/banner_r/$M$D-$W.png,halign=LEFT,valign=TOP -b >>"$LOG" 2>&1
      [ -n "$WXIMG" ] && "$FBINK" -g file=$IMG/wx_r/$WXIMG,halign=RIGHT,valign=TOP -b >>"$LOG" 2>&1
    else
      "$FBINK" -g file=$IMG/time/$HM.png,halign=CENTER,valign=MIDDLE -b >>"$LOG" 2>&1
      "$FBINK" -g file=$IMG/banner/$M$D-$W.png,halign=CENTER,valign=TOP -b >>"$LOG" 2>&1
      [ -n "$WXIMG" ] && "$FBINK" -g file=$IMG/wx/$WXIMG,halign=CENTER,valign=BOTTOM -b >>"$LOG" 2>&1
    fi
    "$FBINK" -s top=0,left=0,width=600,height=800 -W GC16 >>"$LOG" 2>&1
  elif [ "$MODE" = "2" ]; then
    $EIPS -g $IMG/time/$HM.png >>"$LOG" 2>&1
    LINE=" $(date +%Y-%m-%d) $(weekday_cn)"
    [ -n "$WXLINE" ] && LINE="$LINE $WXLINE"
    $EIPS "$LINE" >>"$LOG" 2>&1
  else
    $EIPS " $(date +%H:%M) $(date +%m-%d) $(weekday_cn) $WXLINE" >>"$LOG" 2>&1
  fi
}

freeze() {
  FROZEN=""
  for name in cvm awesome framework; do
    for p in $(pidof $name 2>/dev/null); do
      kill -STOP $p 2>/dev/null && FROZEN="$FROZEN $p"
    done
  done
  echo "$FROZEN" > "$FROZ"
  echo "frozen:$FROZEN" >> "$LOG"
}

unfreeze() {
  [ -f "$FROZ" ] && {
    for p in $(cat "$FROZ"); do kill -CONT $p 2>/dev/null; done
    rm -f "$FROZ"
    echo "unfrozen" >> "$LOG"
  }
}

# ---------- 电源键双击退出（冻结模式下屏幕触摸不可用，用物理按键） ----------
# 直接读内核输入事件：EV_KEY(1) KEY_POWER(116) VALUE=1(按下)
# 3 秒内两次按下 -> 写 STOP 文件，主循环 20 秒内执行停表
power_watch() {
  D=$(grep -A4 'gpio-keys' /proc/bus/input/devices 2>/dev/null | grep -o 'event[0-9][0-9]*' | head -n 1)
  PD=/dev/input/${D:-event0}
  [ -c "$PD" ] || { echo "watch: no power dev" >> "$LOG"; return; }
  echo "watch: $PD" >> "$LOG"
  if command -v timeout >/dev/null 2>&1; then TMO="timeout 3500"; else TMO=""; fi
  LASTP=0
  while [ ! -f /tmp/clock-quit ]; do
    E=$($TMO dd if=$PD bs=16 count=1 2>/dev/null | od -d 2>/dev/null | tr -s ' \n' '  ')
    if [ -z "$E" ]; then sleep 1; continue; fi
    set -- $E
    TY=""; CO=""; VA=""
    case $# in
      8) TY=$5; CO=$6; VA=$7 ;;      # 无偏移列
      9|10) TY=$6; CO=$7; VA=$8 ;;   # 带偏移列（可能还带尾偏移）
    esac
    [ -n "$TY" ] || continue
    if [ "$TY" = "1" ] && [ "$CO" = "116" ] && [ "$VA" = "1" ]; then
      NOW=$(date +%s)
      echo "power press $NOW" >> "$LOG"
      if [ "$LASTP" != "0" ] && [ $((NOW - LASTP)) -le 3 ]; then
        echo "POWER DOUBLE-PRESS -> exit" >> "$LOG"
        touch "$DOC/STOP"
        return
      fi
      LASTP=$NOW
    fi
  done
}

stop_clock() {
  unfreeze
  touch /tmp/clock-quit 2>/dev/null
  rm -f "$PIDF"
  if ! (echo > /etc/.t) 2>/dev/null; then mount -o remount,rw / 2>/dev/null; fi
  rm -f /etc/.t /etc/upstart/bigclock.conf
  /sbin/initctl reload-configuration 2>/dev/null
  /sbin/initctl stop bigclock 2>/dev/null
  mount -o remount,ro / 2>/dev/null
  $EIPS "Clock stopped" >/dev/null 2>&1
  echo "stopped by STOP file" >> "$LOG"
  exit 1
}

# ---------- 启动序列：电源键监视 -> 画两轮 -> 冻结交给主循环窗口逻辑 ----------
rm -f /tmp/clock-quit
power_watch &
read_ori
echo "start ori=$ORI" >> "$LOG"
draw
weather
draw

START=$(date +%s)
GRACE=120
LAST=$(date +%H%M)
LASTORI=$ORI
while true; do
  [ -f $DOC/STOP ] && stop_clock
  read_ori
  if [ "$ORI" != "$LASTORI" ]; then
    LASTORI=$ORI
    echo "orientation -> $ORI" >> "$LOG"
    draw
  fi
  HM=$(date +%H%M)
  [ "$HM" != "$LAST" ] && { LAST=$HM; draw; }
  N=$(date +%s)
  [ $((N - WTIME)) -ge 1800 ] && { weather; draw; }
  # ===== 维护窗口：每小时第 00 分钟，或开机后前 120 秒 =====
  WIN=0
  [ "$(date +%M)" = "00" ] && WIN=1
  [ $((N - START)) -lt $GRACE ] && WIN=1
  if [ "$WIN" = "1" ]; then
    if [ -f "$FROZ" ]; then
      echo "window open $(date +%H:%M:%S)" >> "$LOG"
      unfreeze
    fi
    draw
  else
    if [ ! -f "$FROZ" ]; then
      echo "window closed, freezing $(date +%H:%M:%S)" >> "$LOG"
      freeze
    fi
  fi
  lipc-set-prop com.lab126.powerd preventScreenSaver 1 2>/dev/null
  sleep 20
done
