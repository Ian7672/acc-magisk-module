apply_on_boot() {

  local entry=
  local file=
  local value=
  local default=
  local arg=${1:-value}
  local exitCmd=false
  local force=false

  [ ${2:-x} != force ] || force=true

  [[ "${applyOnBoot[*]-}${maxChargingVoltage[*]-}" != *--exit* ]] || exitCmd=true

  for entry in ${applyOnBoot[@]-} ${maxChargingVoltage[@]-}; do
    set -- ${entry//::/ }
    [ -f ${1-//} ] || continue
    file=${1-}
    value=${2-}
    if $exitCmd && ! $force; then
      default=${2-}
    else
      default=${3:-${2-}}
    fi
    set +e
    write \$$arg $file 0 &
    set -e
  done

  wait
  $exitCmd && [ $arg = value ] && exit 0 || :
}


apply_on_plug() {

  local entry=
  local file=
  local value=
  local default=
  local arg=${1:-value}

  for entry in ${applyOnPlug[@]-} ${maxChargingVoltage[@]-} \
    ${maxChargingCurrent[@]:-$([ .$arg != .default ] || cat $TMPDIR/ch-curr-ctrl-files 2>/dev/null || :)}
  do
    set -- ${entry//::/ }
    [ -f ${1-//} ] || continue
    file=${1-}
    value=${2-}
    default=${3:-${2-}}
    set +e
    write \$$arg $file 0 &
    set -e
  done

  wait
}


at() {
  ${isAccd:-false} || return 0
  local file=$TMPDIR/schedules/${1/:}
  if [ ! -f $file ] && [ $(date +%H%M) -ge ${file##*/} ] && [ $(date +%H) -eq ${1%:*} ]; then
    mkdir -p ${file%/*}
    shift
    echo "$@" | sed 's/,/\;/g; s|^acc|/dev/acc|g; s| acc| /dev/acc|g' > $file
    . $file || :
  elif [ $(date +%H%M) -lt ${file##*/} ]; then
    rm $file 2>/dev/null || :
  fi
}


calc() {
  awk "BEGIN {print $*}" | tr , .
}


cycle_switches() {

  local on=
  local off=

  touch $TMPDIR/.testingsw

  while read -A chargingSwitch; do

    [ ! -f ${chargingSwitch[0]:-//} ] || {

      flip_sw $1 || :

      if [ "$1" = on ]; then
        not_charging || break
      else
        { set_temp_level 50; set_ch_curr 500; } > /dev/null
        if not_charging ${2-}; then
          # set working charging switch(es)
          s="${chargingSwitch[*]}" # for some reason, without this, the array is null
          . $execDir/write-config.sh
          break
        else
          # reset switch/group that fails to comply, and move it to the end of the list
          flip_sw on 2>/dev/null || :
          if ! ${acc_t:-false}; then
            sed -i "\|^${chargingSwitch[*]}$|d" $TMPDIR/ch-switches
            echo "${chargingSwitch[*]}" >> $TMPDIR/ch-switches
          fi
        fi
      fi
    }
  done < $TMPDIR/ch-switches

  rm $TMPDIR/.testingsw
}


cycle_switches_off() {
  case $prioritizeBattIdleMode in
    true) cycle_switches off Idle;;
    no)   cycle_switches off Discharging;;
  esac
  not_charging || cycle_switches off
}


disable_charging() {

  local autoMode=true

    [[ "${chargingSwitch[*]-}" != *\ -- ]] || autoMode=false

    if [[ "${chargingSwitch[0]-}" = */* ]]; then
      if [ -f ${chargingSwitch[0]} ]; then
        if ! { flip_sw off && not_charging; }; then
          $isAccd || print_switch_fails "${chargingSwitch[@]-}"
          flip_sw on 2>/dev/null || :
          if $autoMode; then
            unset_switch
            cycle_switches_off
          fi
        fi
      else
        invalid_switch
      fi
    else
      cycle_switches_off
    fi

    if $autoMode && ! not_charging; then
      #return 7 # total failure
      notif "⚠️ Exit 7; accd is re-initializing"
      exec $TMPDIR/accd $config --init
    fi

    (set +eux; eval '${runCmdOnPause-}') || :
    chDisabledByAcc=true

  if [ -n "${1-}" ]; then
    case $1 in
      *%)
        print_charging_disabled_until $1
        echo
        set +x
        until [ $(batt_cap) -le ${1%\%} ]; do
          sleep ${loopDelay[1]}
        done
        log_on
        enable_charging
      ;;
      *[hms])
        print_charging_disabled_for $1
        echo
        case $1 in
          *h) sleep $(( ${1%h} * 3600 ));;
          *m) sleep $(( ${1%m} * 60 ));;
          *s) sleep ${1%s};;
        esac
        enable_charging
      ;;
      *m[vV])
        print_charging_disabled_until $1 v
        echo
        set +x
        until [ $(volt_now) -le ${1%m*} ]; do
          sleep ${loopDelay[1]}
        done
        log_on
        enable_charging
      ;;
      *)
        print_charging_disabled
      ;;
    esac
  else
    $isAccd || print_charging_disabled
  fi
}


enable_charging() {

    [ ! -f $TMPDIR/.sw ] || (. $TMPDIR/.sw; rm $TMPDIR/.sw; flip_sw on) 2>/dev/null || :

    if ! $ghostCharging || { $ghostCharging && online; }; then

      flip_sw on || cycle_switches on

      # detect and block ghost charging
      # if ! $ghostCharging && ! not_charging && ! online \
      #   && sleep ${loopDelay[0]} && ! not_charging && ! online
      # then
      #   ghostCharging=true
      #   disable_charging > /dev/null
      #   touch $TMPDIR/.ghost-charging
      #   wait_plug
      #   return 0
      # fi

    else
      wait_plug
      return 0
    fi

    chDisabledByAcc=false

  set_temp_level

  if [ -n "${1-}" ]; then
    case $1 in
      *%)
        print_charging_enabled_until $1
        echo
        set +x
        until [ $(batt_cap) -ge ${1%\%} ]; do
          sleep ${loopDelay[0]}
        done
        log_on
        disable_charging
      ;;
      *[hms])
        print_charging_enabled_for $1
        echo
        case $1 in
          *h) sleep $(( ${1%h} * 3600 ));;
          *m) sleep $(( ${1%m} * 60 ));;
          *s) sleep ${1%s};;
        esac
        disable_charging
      ;;
      *m[vV])
        print_charging_enabled_until $1 v
        echo
        set +x
        until [ $(volt_now) -ge ${1%m*} ]; do
          sleep ${loopDelay[0]}
        done
        log_on
        disable_charging
      ;;
      *)
        print_charging_enabled
      ;;
    esac
  else
    $isAccd || print_charging_enabled
  fi
}


# condensed "case...esac"
eq() {
  eval "case \"$1\" in
    $2) return 0;;
  esac"
  return 1
}


flip_sw() {

  flip=$1
  local on=
  local off=

  set -- ${chargingSwitch[@]-}
  [ -f ${1:-//} ] || return 2
  swValue=

  while [ -f ${1:-//} ]; do

    on="$(parse_value "$2")"
    if [ $3 = 3600mV ]; then
      off=$(cat $1)
      [ $off -lt 10000 ] && off=3600 || off=3600000
    else
      off="$(parse_value "$3")"
    fi

    [ $flip = on ] || cat $currFile > $curThen
    write \$$flip $1 || return 1

    [ $# -lt 3 ] || shift 3
    [ $# -ge 3 ] || break

  done
}


handle_bootloop() {
  local newZygotePID="$(getprop init.svc_debug_pid.zygote)"
  [ "$newZygotePID" = "$zygotePID" ] || {
    cat $log > $dataDir/logs/bootloop-${device}.log
    write() { :; }
    exit 0
  }
}


invalid_switch() {
  $isAccd || print_invalid_switch
  unset_switch
  cycle_switches_off
}


log_on() {
  [ ! -f ${log:-//} ] || {
    [[ $log = */accd-* ]] && set -x || set -x 2>>$log
  }
}


misc_stuff() {
  set -eu
  mkdir -p $dataDir 2>/dev/null || :
  [ -f $config ] || cat $execDir/default-config.txt > $config

  # custom config path
  ! eq "${1-}" "*/*" || {
    [ -f $1 ] || cp $config $1
    config=$1
  }
  unset -f misc_stuff
}


notif() {
  su -lp 2000 -c "/system/bin/cmd notification post -S bigtext -t \"🔋ACC | $(date +%H:%M)\" "Tag$(date +%s)" \"${*:-:)}\"" < /dev/null > /dev/null 2>&1 || :
}


parse_value() {
  if [ -f "$1" ]; then
    chmod a+r $1 && cat $1 || echo 20
  else
    echo "$1" | sed 's/::/ /g'
  fi 2>/dev/null
}


print_header() {
  echo "Advanced Charging Controller (ACC) $accVer ($accVerCode)
(C) 2017-2024, VR25
GPLv3+"
}


resetbs() {
  is_android || return 0
  set +e
  dumpsys batterystats --reset
  rm -rf /data/system/battery*stats*
  dumpsys battery set ac 1
  dumpsys battery set level 100
  sleep 2
  dumpsys battery reset
  set -e
} &>/dev/null


sdp() {
  _DPOL=$1
  echo _DPOL=$1 >> $TMPDIR/.batt-interface.sh
}


unset_switch() {
  charging_switch=
  . $execDir/write-config.sh
}


wait_plug() {
  $isAccd || {
    echo "ghostCharging=true"
    print_unplugged
  }
  while ! online; do
    sleep ${loopDelay[1]}
    ! $isAccd || sync_capacity 2>/dev/null || :
    set +x
  done
  log_on
  enable_charging "$@"
}


write() {

  local i=y
  local seq=5
  local one="$(eval echo $1)"
  local f=$dataDir/logs/write.log
  blacklisted=false

  if [ -f "$2" ] && chown 0:0 $2 && chmod 0644 $2; then
    case "$(grep -E "^(#$2|$2)$" $f 2>/dev/null || :)" in
      \#*) blacklisted=true;;
      */*) eval "echo $1 > $2" || i=x;;
      *) echo $2 >> $f
         eval "echo $1 > $2" || i=x;;
    esac
  else
    i=x
  fi
  f="$(cat $2)" 2>/dev/null || :
  rm $TMPDIR/.nowrite 2>/dev/null || :
  [[ "$one" != */* ]] || one="$(cat $one)"
  ! [[ -n "$f" && "$f" != "$one" ]] || {
    touch $TMPDIR/.nowrite
    i=x
  }
  if [ -n "${exitCode_-}" ]; then
    [ -n "${swValue-}" ] && swValue="$swValue, $f" || swValue="$f"
  fi
  handle_bootloop
  [ $i = x ] && return ${3-1} || {
    for i in $(seq $seq); do
      if eval "echo $1 > $2"; then
        [ $i -eq $seq ] || usleep $((1000000 / $seq))
      else
        handle_bootloop
        return 1
      fi
    done
    chmod 0444 $2
  }
  handle_bootloop
}


# environment

id=acc
domain=vr25
: ${isAccd:=false}
loopDelay=(3 9)
execDir=/data/adb/$domain/acc
export TMPDIR=/dev/.vr25/acc
dataDir=/data/adb/$domain/${id}-data
: ${config:=$dataDir/config.txt}
config_=$config

[ -f $TMPDIR/.ghost-charging ] \
  && ghostCharging=true \
  || ghostCharging=false

trap exxit EXIT

. $execDir/setup-busybox.sh
. $execDir/set-ch-curr.sh
. $execDir/set-ch-volt.sh

device=$(getprop ro.product.device | grep .. || getprop ro.build.product)
zygotePID="$(getprop init.svc_debug_pid.zygote)"

cd /sys/class/power_supply/
. $execDir/batt-interface.sh
. $execDir/android.sh

# load plugins
mkdir -p ${execDir}-data/plugins $TMPDIR/plugins
for f in ${execDir}-data/plugins/*.sh $TMPDIR/plugins/*.sh; do
  if [ -f "$f" ] && [ ${f##*/} != ctrl-files.sh ]; then
    . "$f"
  fi
done
unset f
