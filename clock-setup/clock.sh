#!/bin/sh
# Name: 大字时钟 Big Clock
# Author: hahakalo
#
# v3 kiosk 版：解决"画完被桌面覆盖 / 后台进程被杀"
#   - 绘制成功后冻结系统 UI（cvm/awesome），任何程序都无法再重画覆盖时钟
#   - 三重进程保活：upstart 服务 / setsid 独立会话 / scriptlet 本体兜底
#   - 停止方法：documents 里放一个名为 STOP 的文件，20 秒内自动解冻退出
#   - 紧急恢复：长按电源键约 10 秒强制重启（硬件级，永远有效）
#   - 重启后 upstart 自动恢复时钟
#
# 布局（全图片，无文字排版）：
#   顶部 banner/{MMDD}-{W}.png 日期+星期 / 中部 time/HHMM.png / 底部 wx/T{t}D{d}.png

IMG=/mnt/us/clockimg
DOC=/mnt/us/documents
FBINK=/mnt/us/libkh/bin/fbink
EIPS=/usr/sbin/eips
LOG=$DOC/clock.log
PIDF=/tmp/bigclock.pid
FROZ=/tmp/clock-frozen.pids

# ================= 入口（点击书库条目） =================
if [ "$1" != "bg" ]; then
  rm -f "$LOG"
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
  # 清旧文件 + banner 目录迁移
  rm -f /mnt/us/clockimg/*.gif /mnt/us/clockfont.ttf >> "$LOG" 2>&1
  rm -f "$DOC"/clock-pro.sh "$DOC"/clock-pro.log "$DOC"/clock.html >> "$LOG" 2>&1
  rm -f "$DOC"/clock-fix*.sh "$DOC"/clock-display.sh "$DOC"/clock-setup.sh \
        "$DOC"/busybox "$DOC"/Arial-Bold.ttf >> "$LOG" 2>&1
  if [ -d $IMG/banner2 ]; then
    rm -rf $IMG/banner
    mv $IMG/banner2 $IMG/banner
    echo "banner migrated: $(ls $IMG/banner 2>/dev/null | wc -l)" >> "$LOG"
  fi
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
    "$FBINK" -g file=$IMG/time/$HM.png,halign=CENTER,valign=MIDDLE -b >>"$LOG" 2>&1
    "$FBINK" -g file=$IMG/banner/$M$D-$W.png,halign=CENTER,valign=TOP -b >>"$LOG" 2>&1
    [ -n "$WXIMG" ] && "$FBINK" -g file=$IMG/wx/$WXIMG,halign=CENTER,valign=BOTTOM -b >>"$LOG" 2>&1
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

stop_clock() {
  unfreeze
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

# ---------- 启动序列：先画 -> 冻结 -> 再画一次盖掉可能的桌面闪现 ----------
draw
weather
draw
freeze
sleep 3
draw

LAST=$(date +%H%M)
while true; do
  [ -f $DOC/STOP ] && stop_clock
  HM=$(date +%H%M)
  [ "$HM" != "$LAST" ] && { LAST=$HM; draw; }
  N=$(date +%s)
  [ $((N - WTIME)) -ge 1800 ] && { weather; draw; }
  lipc-set-prop com.lab126.powerd preventScreenSaver 1 2>/dev/null
  sleep 20
done
