#!/bin/sh
# Name: 大字时钟 Big Clock
# Author: hahakalo
#
# v4 新增横竖屏切换（信息点完全相同）：
#   documents/HENG 文件控制方向，拔线后 20 秒内自动生效，无需重启：
#     无 HENG 文件   -> 竖屏（默认）
#     HENG 内容为 1  -> 横屏·充电口在右侧观看
#     HENG 内容为 2  -> 横屏·充电口在左侧观看
#   横屏图片为预旋转版本：time_l/time_r、banner_l/banner_r、wx_l/wx_r
#
# v3 要点（保留）：
#   - 绘制成功后冻结系统 UI（cvm/awesome），任何程序都无法再重画覆盖时钟
#   - 三重进程保活：upstart 服务 / setsid 独立会话 / scriptlet 本体兜底
#   - 停止：documents 里放一个名为 STOP 的文件，20 秒内自动解冻退出
#   - 紧急恢复：长按电源键约 10 秒强制重启（硬件级，永远有效）
#   - 重启后 upstart 自动恢复时钟
#
# 布局（全图片，无文字排版）：
#   竖屏: banner(顶) + time(中) + wx(底)
#   横屏: banner(一侧) + time(中) + wx(对侧)，图片已在电脑端旋转好

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
  rm -f "$LOG" "$DOC/STOP"
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
        "$DOC"/busybox "$DOC"/Arial-Bold.ttf >> "$LOG" 2>&1
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
read_ori
echo "start ori=$ORI" >> "$LOG"
draw
weather
draw
freeze
sleep 3
draw

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
  lipc-set-prop com.lab126.powerd preventScreenSaver 1 2>/dev/null
  sleep 20
done
