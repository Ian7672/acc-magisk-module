#!/system/bin/sh
# Advanced Charging Controller
# Copyright 2017-2024, VR25
# License: GPLv3+


daemon_ctrl() {

  local isRunning=false

  flock -n 0 <>$TMPDIR/acc.lock || isRunning=true

  case "${1-}" in

    start)
      if $isRunning; then
        print_already_running
        return 8
      else
        print_started
        echo
        exec $TMPDIR/accd $config
      fi
    ;;

    stop)
      if $isRunning; then
        . $execDir/release-lock.sh
        print_stopped
        return 0
      else
        print_not_running
        return 9
      fi
    ;;

    restart)
      if $isRunning; then
        print_restarted
      else
        print_started
      fi
      echo
      exec $TMPDIR/accd $config
    ;;

    *)
      if $isRunning; then
        print_is_running "$accVer ($accVerCode)" "(PID $(cat $TMPDIR/acc.lock))"
        return 0
      else
        print_not_running
        return 9
      fi
    ;;
  esac
}


edit() {
  local file="$1"
  shift
  case "${1-}" in
    a) echo >> $file
       shift
       two=($*)
       if grep -iv "^: ${two[1]%?};" $file > $TMPDIR/.tmp; then
         cat $TMPDIR/.tmp > $file
         rm $TMPDIR/.tmp
       fi
       unset two
       echo "$@" | sed 's/,/;/' >> $file;;

    d) shift; sed -Ei "\#$*#d" $file;;

    g) [ "$file" = "$config" ] || {
         install -m 666 $file /data/local/tmp/
         file=/data/local/tmp/${file##*/}
       }
       shift
       ext_app $file "$@";;

    h) [ -n "${2-}" ] || exit 0
       if grep -q "# $2 (.*) #" $file; then
         sed -n "/# $2 (.*) #/,/^$/p" $file | filter
       elif grep -q "# .* ($2) #" $file; then
         sed -n "/# .* ($2) #/,/^$/p" $file | filter
       fi;;

    "") case $file in
          *.log|*.md|*.help) less $file;;
          *) nano -$ $file || vim $file || vi $file || ext_app $file;;
        esac 2>/dev/null;;
    *) IFS="$(printf ' \t\n')" eval "$* $file";;
  esac
}


ext_app() {
  am start -a android.intent.action.${2:-EDIT} \
           -t "text/${3:-plain}" \
           -d file://$1 \
           --grant-read-uri-permission &>/dev/null || :
}


filter() {
  sed '/^$/d; s/ # /, /; s/ #//; s/^# //; s/#//'
}


get_prop() { sed -n "s|^$1=||p" ${2:-$config}; }


switch_fails() {
  print_switch_fails
  ! not_charging >/dev/null || {
    print_resume
    while not_charging; do
      sleep 1
    done
  }
  return 10
}


test_charging_switch() {

  local idleMode=false
  local failed=false
  local acc_t=true
  chargingSwitch=($@)

  echo

  [ -n "${swCount-}" ] \
    && echo "$swCount/$swTotal: ${chargingSwitch[@]-}" \
    || echo "${chargingSwitch[@]-}"

  echo "chargingSwitch=($*)" > $TMPDIR/.sw
  flip_sw off
  ! [ $? -eq 2 ] || {
    flip_sw on
    switch_fails
    return 10
  }

  ${blacklisted:-false} && {
    print_blacklisted
    return 10
  }

  ! not_charging && failed=true || {
    [ $_status = Idle ] && idleMode=true
  }

  flip_sw on 2>/dev/null

  if ! $failed && ! not_charging; then
    print_switch_works
    echo "  battIdleMode=$idleMode"
    $idleMode && return 15 || return 0
  else
    switch_fails
  fi
}


exxit() {
  local exitCode=$?
  set +eux
  ! ${noEcho:-false} && ${verbose:-true} && echo
  [[ "$exitCode" = [05689] ]] || {
    eq "$exitCode" "[127]|10" && logf --export
    echo
  }
  cd /
  exit $exitCode
}


parse_switches() {

  local f=$TMPDIR/.parse_switches.tmp
  local i=
  local n=

  [ -n "${2-}" ] || set -- $TMPDIR/ch-switches "${1-}"

  if [ -z "${2-}" ]; then
    set -- $1 $(echo $dataDir/logs/power_supply-${device}.log)
    [ -f $2 ] || $execDir/power-supply-logger.sh
  fi

  cat -v "$2" > $f

  for i in $(grep -Ein '^  ((1|0)$|.*able.*)' $f | cut -d: -f1); do

    n=$i
    i="$(sed -n "$(($n - 1))p" "$f")"
    n=$(sed -n ${n}p $f | sed 's/^  //')

    case $n in
      0) n="$n 1";;
      1) n="$n 0";;
      disable) n="$n enable";;
      disabled) n="$n enabled";;
      enable) n="$n disable";;
      enabled) n="$n disabled";;
      DISABLE) n="$n ENABLE";;
      DISABLED) n="$n DISABLED";;
      ENABLE) n="$n DISABLE";;
      ENABLED) n="$n DISABLED";;
      *) continue;;
    esac

    i=${i#*/power_supply/}

    # exclude all known switches
    ! grep -q "$i " $1 || continue

    i="$(echo "$i $n" | grep -Eiv 'reset|authentic|brightness|calibrat|capacitance|count|curr|cycle|daemon|demo|design|detect|disk|factory|flash|info|init|mask|moist|nvram|online|otg|parallel|present|priority|reboot|report|resistance|runtime|ship|shutdown|shutdown|state|status|step|temp|timer|type|type|update|user|verif|volt|wake|wakeup')" || :

    [ -z "$i" ] || echo "$i"

  done

  rm $f
}


rollback() {
  if [[ ".${*-}" != *v* ]]; then
    print_wait
    for i in $execDir/*; do
      [[ $i = */system ]] || rm -rf $i
    done
    rm -rf $dataDir/backup/system
    cp -a $dataDir/backup/* $execDir/
    if [[ ".${*-}" = *n* ]]; then
      rm $execDir/config.txt
    else
      mv -f $execDir/config.txt $config
    fi
    $execDir/service.sh --init
    printf "✅ "
  fi
  i=$dataDir/backup/module.prop
  [ -f $i ] || i=$execDir/module.prop
  sed -n 's/^versionCode=//p' $i
}


set_prop_() {
  . $execDir/set-prop.sh
  set_prop "$@"
}


! ${verbose:-true} || echo
execDir=/data/adb/vr25/acc
defaultConfig=$execDir/default-config.txt

# load generic functions
. $execDir/logf.sh
. $execDir/misc-functions.sh

if [ "${1:-y}" = -x ] ||  eq "${2-}" "p|parse"; then
  log=/sdcard/Download/acc-${device}.log
  [ $1 != -x ] || shift
else
  log=$TMPDIR/acc-${device}.log
fi

# verbose
if ${verbose:-true} && !  eq "${1-}" "-l*|--log*|-w*|--watch*"; then
  [ -z "${LINENO-}" ] || export PS4='$LINENO: '
  touch $log
  [ $(du -k $log | cut -f 1) -ge 256 ] && : > $log
  echo "###$(date)###" >> $log
  echo "versionCode=$(sed -n s/versionCode=//p $execDir/module.prop 2>/dev/null)" >> $log
  set -x 2>>$log
fi


accVer=$(get_prop version $execDir/module.prop)
accVerCode=$(get_prop versionCode $execDir/module.prop)

unset -f get_prop

misc_stuff "${1-}"
[[ "${1-}" != */* ]] || shift

. $config


# load default language (English)
. $execDir/strings.sh

# load translations
: ${language:=en}
if ${verbose:-true} && [ -f $execDir/translations/$language/strings.sh ]; then
  . $execDir/translations/$language/strings.sh
fi

grep -q .. $execDir/translations/$language/README.html 2>/dev/null \
  && readMe=$execDir/translations/$language/README.html \
  || readMe=$dataDir/README.html


# aliases/shortcuts
# daemon_ctrl status (acc -D|--daemon): "accd,"
# daemon_ctrl stop (acc -D|--daemon stop): "accd."
[[ "$0" != *accd* ]] || {
  case $0 in
    *accd.) daemon_ctrl stop;;
    *) daemon_ctrl;;
  esac
  exit $?
}


case "${1-}" in

  "")
    . $execDir/wizard.sh
    wizard
  ;;

  [0-9]*)
    pause_capacity=$1
    resume_capacity=${2:-5000}
    . $execDir/write-config.sh
    echo "✅"
  ;;

  -b*|--rollback*)
    rollback "${*-}"
  ;;

  -c|--config)
    shift; edit $config "$@"
  ;;

  -d|--disable)
    shift
    ${verbose:-true} || exec > /dev/null
    ! daemon_ctrl stop > /dev/null || print_stopped
   . $execDir/acquire-lock.sh
    disable_charging "$@"
  ;;

  -D|--daemon)
    shift; daemon_ctrl "$@"
  ;;

  -e|--enable)
    shift
    ${verbose:-true} || exec > /dev/null
    ! daemon_ctrl stop > /dev/null || print_stopped
    . $execDir/acquire-lock.sh
    enable_charging "$@"
  ;;


  -f|--force|--full)

    [[ ".${2-}" = .-* ]] && _two= || _two="${2-}"
    _two="${_two:-100}"
    cp -f $config $TMPDIR/.acc-f-config
    config=$TMPDIR/.acc-f-config
    sed -i '/^:/d' $config

    (allow_idle_above_pcap=
    cooldown_capacity=
    cooldown_charge=
    cooldown_current=
    cooldown_pause=
    cooldown_temp=
    idle_apps=
    max_charging_current=
    max_charging_voltage=
    max_temp=
    off_mid=false
    pause_capacity=$_two
    resume_capacity=$((_two - 2))
    resume_temp=
    temp_level=
    . $execDir/write-config.sh)

    # additional options
    _extra=false
    case "${2-}" in
      [0-9]*) [[ ".${3-}" != .-* ]] || { shift 2; _extra=true; };;
      -*) shift 1; _extra=true;;
    esac
    ! $_extra || eval $TMPDIR/acca $config "$@"

    print '\n:; online || exec $TMPDIR/accd' >> $config
    print_charging_enabled_until ${_two}%
    echo
    exec $TMPDIR/accd $config
  ;;


  -F|--flash)
    shift
    set +eux
    trap - EXIT
    $execDir/flash-zips.sh "$@"
  ;;


  -H|--health)

    counter=$(set +e; grep -E '[1-9]+' */charge_counter 2>/dev/null | head -n 1 | sed 's/.*://' || :)
    health=
    level=$(batt_cap)
    mAh=${2-}

    [ -n "$mAh" ] || { echo "${0##*/} $1 <mAh>"; exit; }
    [ -n "$counter" ] || { echo "!"; exit; }

    [ $counter -lt 10000 ] || counter=$(calc $counter / 1000)
    health=$(calc "$counter * 100 / $level * 100 / $mAh" | xargs printf %.1f)
    [ ${health%.*} -le 99 ] && echo ${health}% || echo "!"
  ;;

  -i|--info)
    . $execDir/batt-info.sh
    batt_info "${2-}" | more
  ;;

  -la)
    shift
    logf --acc "$@"
  ;;

  -le)
    logf --export
  ;;

  -l|--log)
    shift
    logf "$@"
  ;;

  -n|--notif)
    shift
    notif "${@-}"
  ;;

  -p|--parse)
    shift
    parse_switches "$@"
  ;;

  -r|--readme)
    if [ .${2-} = .g ]; then
      edit $readMe g VIEW html
    else
      edit ${readMe%html}md
    fi
  ;;

  -R|--resetbs)
    dumpsys batterystats --reset
    rm -rf /data/system/battery*stats* 2>/dev/null || :
    echo "✅"
  ;;

  -sc)
    set_prop_ --current ${2-}
  ;;

  -sd)
    set_prop_ --print-default "${2-.*}"
  ;;

  -sl)
    set_prop_ --lang
  ;;

  -sp)
    set_prop_ --print "${2-.*}"
  ;;

  -sr)
    set_prop_ --reset "$@"
  ;;

  -ss)
    shift
    set_prop_ --charging_switch
  ;;

  -ss:)
    set_prop_ --charging_switch:
  ;;

  -ss::)
    sort $dataDir/logs/working-switches.log | nl -s ") " -w 2 -v 1
  ;;

  -sv)
    shift
    set_prop_ --voltage "$@"
  ;;

  -s|--set)
    shift
    set_prop_ "$@"
  ;;


  -t|--test)

    parsed=
    exitCode_=10
    exitCode=$exitCode_
    logF_=$dataDir/logs/acc-t_output-${device}.log
    logF=/sdcard/Download/acc-t_output-${device}_$(date +%Y-%m-%d_%H-%M-%S).log

    shift
    print_wait
    print_unplugged

    ! daemon_ctrl stop > /dev/null && daemonWasUp=false || {
      daemonWasUp=true
      echo "#!/system/bin/sh
        sleep 2
        exec $TMPDIR/accd $config_" > $TMPDIR/.accdt
      chmod 0755 $TMPDIR/.accdt
    }

    . $execDir/acquire-lock.sh

    grep -Ev '^$|^#' $config > $TMPDIR/.config
    config=$TMPDIR/.config

    exxit() {
      rm $TMPDIR/.testingsw
      if [ -n "$parsed" ]; then
        cat $TMPDIR/ch-switches $_parsed 2>/dev/null > $parsed \
          && sort -u $parsed | sed 's/ $//; /^$/d' > $TMPDIR/ch-switches
      fi
      if [ -f $TMPDIR/.sw ]; then
        while IFS= read line; do
          [ -n "$line" ] || continue
          ! grep -q "$line " $TMPDIR/.sw || sed -i "\|$line|d" $dataDir/logs/write.log
        done < $dataDir/logs/write.log
      fi
      cp -f $logF $logF_ 2>/dev/null
      ! $daemonWasUp || start-stop-daemon -bx $TMPDIR/.accdt -S --
      exit $exitCode
    }

    set +e
    touch $TMPDIR/.testingsw
    trap exxit EXIT
    not_charging && enable_charging > /dev/null

    not_charging && {
      print_unplugged
      while not_charging; do
        sleep 1
        set +x
      done
      log_on
    }

    . $execDir/read-ch-curr-ctrl-files-p2.sh
    echo
    { echo versionCode=$(sed -n s/versionCode=//p $execDir/module.prop 2>/dev/null || :)
    echo
    grep . */online
    echo
    grep '^chargingSwitch=' $config; } | tee $logF

    if [ -z "${2-}" ]; then
      !  eq "${1-}" "p|parse" || parsed=$TMPDIR/.parsed
      [ -z "$parsed" ] || {
        _parsed=$dataDir/logs/parsed.log
        if parse_switches > $parsed; then
          set -- $parsed
          ! ${verbose:-true} || {
            print_panic
            read -n 1 a
            echo
            case "$a" in
              ""|y) edit $parsed;;
              a) exit;;
            esac
          }
        else
          echo
          exit
        fi
      }
      swCount=1
      swTotal=$(wc -l ${1-$TMPDIR/ch-switches} | cut -d ' ' -f 1)
      sort -u $TMPDIR/ch-switches > $TMPDIR/ch-switches_
      mv -f $TMPDIR/ch-switches_ $TMPDIR/ch-switches
      while read _chargingSwitch; do
        echo "x$_chargingSwitch" | grep -Eq '^x$|^x#' && continue
        [ -f "$(echo "$_chargingSwitch" | cut -d ' ' -f 1)" ] && {
          { test_charging_switch $_chargingSwitch; echo $? > $TMPDIR/.exitCode; } \
            | tee -a $logF
          rm $TMPDIR/.sw 2>/dev/null || :
          swCount=$((swCount + 1))
          exitCode_=$(cat $TMPDIR/.exitCode)
          if [ -n "$parsed" ] && [ $exitCode_ -ne 10 ]; then
            grep -q "^$_chargingSwitch$" $_parsed 2>/dev/null \
              || echo "$_chargingSwitch" >> $_parsed
          fi
          case $exitCode in
            15) ;;
            0) [ $exitCode_ -eq 15 ] && exitCode=15;;
            *) exitCode=$exitCode_;;
          esac
        }
      done < ${1-$TMPDIR/ch-switches}
      echo
    else
      { test_charging_switch "$@"; echo $? > $TMPDIR/.exitCode; } \
        | tee -a $logF
      rm $TMPDIR/.sw 2>/dev/null || :
      exitCode=$(cat $TMPDIR/.exitCode)
      echo
    fi

    print_acct_info
    echo
    exit $exitCode
  ;;


  -T|--logtail)
    tail -F $TMPDIR/accd-*.log
  ;;

  -u|--upgrade)
    shift
    local array[0]=
    local reference=

    for i; do
      array+=("$i")
      case "$i" in
        -c|--changelog)
        ;;
        -f|--force)
        ;;
        -n|--non-interactive)
        ;;
        *)
          unset array[$((${#array[@]}-1))]
          reference="$i"
        ;;
      esac
    done
    test ${#array[@]} -lt 2 || unset array[0]

    test -n "$reference" || {
      grep -Eq '^version=.*-(beta|dev|rc)' $execDir/module.prop \
        && reference=dev \
        || reference=master
    }

    ! test -f /data/adb/vr25/bin/curl || {
      test -x /data/adb/vr25/bin/curl \
        || chmod -R 0755 /data/adb/vr25/bin
    }

    dl() {
      if [ ".${1-}" != .wget ] && i=$(which curl) && [ ".$(head -n 1 ${i:-//} 2>/dev/null || :)" != ".#!/system/bin/sh" ]; then
        curl --help | grep '\-\-dns\-servers' >/dev/null && dns="--dns-servers 9.9.9.9,1.1.1.1" || dns=
        curl $dns --progress-bar --insecure -Lo \
          $TMPDIR/install-online.sh https://raw.githubusercontent.com/VR-25/acc/dev/install-online.sh || dl wget
      else
        PATH=${PATH#*/busybox:} /dev/.vr25/busybox/wget -O $TMPDIR/install-online.sh --no-check-certificate \
          https://raw.githubusercontent.com/VR-25/acc/dev/install-online.sh
      fi
    }

    dl
    trap - EXIT
    set +eu
    installDir=$(readlink -f $execDir)
    installDir=${installDir%/*}
    . $TMPDIR/install-online.sh "${array[@]}" %$installDir% $reference
  ;;

  -U|--uninstall)
    set +eu
    ! ${verbose:-true} || {
      print_uninstall
      echo yes/no
      read ans
      [ .$ans = .yes ] || exit 0
    }
    /system/bin/sh $execDir/uninstall.sh
    echo "✅"
  ;;

  -v|--version)
    echo "$accVer ($accVerCode)"
  ;;

  -w*|--watch*)
    two="${2//,/|}"
    sleepSeconds=${1#*h}
    sleepSeconds=${sleepSeconds#*w}
    : ${sleepSeconds:=1}
    . $execDir/batt-info.sh
    while :; do
      clear
      if ${verbose:-true}; then
        batt_info "${two-}"
      else
        batt_info "${two-}" | grep -v '^$' 2>/dev/null || :
      fi
      sleep $sleepSeconds
      set +x
    done
  ;;

  *)
    . $execDir/print-help.sh
    shift
    print_help_ "$@"
  ;;

esac

exit 0
