idle_discharging() {
  if [ ${curNow#-} -le $idleThreshold ]; then
    _status=Idle
    return 0
  fi
  case "${_DPOL-}" in
    +) [ $curNow -ge 0 ] && _status=Discharging || _status=Charging;;
    -) [ $curNow -lt 0 ] && _status=Discharging || _status=Charging;;
    *) [ $curThen = null ] || {
          eq "$curThen,$curNow" "-*,[0-9]*|[0-9]*,-*" && _status=Discharging || _status=Charging
       };;
  esac
}


not_charging() {

  local i=
  local j=
  local sw=
  local _STI=${_STI:-35} # switch test iterations
  local switch=${flip-}; flip=
  local curThen=$(cat $curThen)
  local chargingSwitch="${chargingSwitch[*]-}"
  local idleThreshold=${idleThreshold:-10}
  local battStatusOverride="${battStatusOverride-}"
  local battStatusWorkaround=${battStatusWorkaround-}
  local wsLog=$dataDir/logs/working-switches.log

  [[ "$chargingSwitch" = *\ -- ]] && chargingSwitch="${chargingSwitch% --}" || battStatusOverride=

  case "$currFile" in
    */current_now|*/?attery?verage?urrent) [ ${ampFactor:-$ampFactor_} -eq 1000 ] || idleThreshold=${idleThreshold}000;;
    *) battStatusWorkaround=false;;
  esac

  if [ -z "${battStatusOverride-}" ] && [ -n "$switch" ]; then
    for i in $(seq $_STI); do
      if [ "$switch" = off ]; then
        ! status ${1-} || {
          sw=$(grep "\[[id]\] $chargingSwitch" $wsLog 2>/dev/null || :)
          while :; do
            j=$(echo $_status | sed -E 's/^(.).*/\1/; s/I/i/; s/D/d/')
            if [ -n "$sw" ]; then
              [[ "$sw" = \[$j\]* ]] || { sed -i "\|$chargingSwitch|d" $wsLog; sw=; continue; }
            else
              printf "[$j] $chargingSwitch" >> $wsLog
              case "$chargingSwitch" in
                *current*) [[ "$$chargingSwitch" = *current_cmd* ]] || echo " {mcc}";;
                *control_limit_max*|*siop_level*|*temp_level*) echo " {tl}";;
                *voltage*) echo " {mcv}";;
                *) echo;;
              esac >> $wsLog
            fi
            break
          done
          return 0
        }
      else
        status ${1-} || return 1
      fi
      [ ! -f $TMPDIR/.nowrite ] || { rm $TMPDIR/.nowrite 2>/dev/null || :; break; }
      [ $i = $_STI ] || sleep 1
    done
    [ "$switch" = on ] || return 1
  else
    status ${1-}
  fi
}


online() {
  local i=
  for i in $(online_f); do
    grep -q 0 $i || return 0
  done
  return 1
}


online_f() {
  ls -1 */online | grep -Ei '^ac/|^dc/|^mains/|^mtk\-.*(chg|charger)/|^pc_port/|^smb[0-9]{3}\-usb/|^usb/|ucsi.*pmic|^wireless/' || :
}


read_status() {
  local status="$(cat $battStatus)"
  case "$status" in
    Cmd*discharging) printf Discharging;;
    Charging|Discharging) printf %s $status;;
    Not?charging) printf Idle;;
    *) printf Discharging;;
  esac
}


set_temp_level() {
  local f=$TMPDIR/.tl-custom
  local a=
  local b=battery/siop_level
  local l=${1:-${tempLevel-}}
  [ -n "$l" ] || return 0
  [[ $l -eq 0 && ! -f $f ]] && return 0 || :
  if [ -f $b ]; then
    chmod a+w $b && echo $((100 - $l)) > $b || :
  else
    for a in */num_system_temp*levels; do
      b=$(echo $a | sed 's/\/num_/\//; s/s$//')
      if [ ! -f $a ] || [ ! -f $b ]; then
        continue
      fi
      chmod a+w $b && echo $(( ($(cat $a) * l) / 100 )) > $b || :
    done
  fi
  for a in */charge_control_limit_max; do
    b=${a%_max}
    if [ ! -f $a ] || [ ! -f $b ]; then
      continue
    fi
    chmod a+w $b && echo $(( ($(cat $a) * l) / 100 )) > $b || :
  done
  [ $l -ne 0 ] && touch $f || rm $f 2>/dev/null || :
}


status() {

  local i=0
  local return1=false
  local csw2=${chargingSwitch[2]-}
  local curNow=$(cat $currFile)

  _status=$(read_status)

  if [ -n "${battStatusOverride-}" ]; then
    [[ .${chargingSwitch[2]-} != */* ]] || csw2="$(cat ${chargingSwitch[2]})"
    if  eq "$battStatusOverride" "Discharging|Idle"; then
      [ "$(cat ${chargingSwitch[0]})" != "$csw2" ] || _status=$battStatusOverride
    else
      _status=$(set -eu; eval '$battStatusOverride') || :
    fi
  elif $battStatusWorkaround; then
    idle_discharging
  fi

  [ -z "${exitCode_-}" ] || echo -e "  ${switch:--} (${swValue:-N/A})\t$(calc $curNow \* 1000 / ${ampFactor:-$ampFactor_} | xargs printf %.f)mA\t$_status"

  for i in Discharging DischargingDischarging Idle IdleIdle; do
    [ $i != ${1-}$_status ] || return 0
  done

  return 1
}


volt_now() {
  grep -o '^....' $voltNow
}


if ${_INIT:-false}; then


  # Nexus 10 (manta)
  f1=smb???-battery/status
  f2=ds????-fuelgauge/capacity


  if ls $f1 $f2 >/dev/null 2>&1; then
    batt=${f2%/*}
  else
    for batt in maxfg/capacity */capacity; do
      if [ -f ${batt%/*}/status ]; then
        batt=${batt%/*}
        break
      fi
    done
  fi

  [[ $batt != */capacity ]] || exit 1


  for battStatus in sm????_bms/status $batt/status $f1; do
    [ ! -f $battStatus ] || break
  done

  [ -f $battStatus ] || exit 1
  unset f1 f2


  echo 250 > $TMPDIR/.dummy-temp

  for temp in $batt/temp $batt/batt_temp bms/temp ${battStatus%/*}/temp $TMPDIR/.dummy-temp; do
    [ ! -f $temp ] || break
  done


  echo 0 > $TMPDIR/.dummy-mcc

  for currFile in rt*-charger/current_now battery/current_now $batt/current_now bms/current_now battery/?attery?verage?urrent \
    /sys/devices/platform/battery/power_supply/battery/?attery?verage?urrent \
    ${battStatus%/*}/current_now $TMPDIR/.dummy-mcc
  do
    [ ! -f $currFile ] || break
  done


  voltNow=$batt/voltage_now
  [ -f $voltNow ] || voltNow=$batt/batt_vol
  [ -f $voltNow ] || {
    echo 3900 > $TMPDIR/.voltage_now
    voltNow=$TMPDIR/.voltage_now
  }


  ampFactor=$(sed -n 's/^ampFactor=//p' $dataDir/config.txt 2>/dev/null || :)
  ampFactor_=${ampFactor:-1000}

  if [ $ampFactor_ -eq 1000000 ] || [ $(sed s/-// $currFile) -ge 16000 ]; then
    ampFactor_=1000000
  fi

  curThen=$TMPDIR/.mcc
  rm $curThen 2>/dev/null || :


  echo "ampFactor_=$ampFactor_
batt=$batt
battCapacity=$batt/capacity
battStatus=$battStatus
currFile=$currFile
curThen=$curThen
idleThreshold=${idleThreshold:-10}
_STI=\${_STI:-35}
temp=$temp
voltNow=$voltNow" > $TMPDIR/.batt-interface.sh

  _INIT=false


else
  touch $TMPDIR/.batt-interface.sh
  . $TMPDIR/.batt-interface.sh
fi

[ -f $curThen ] || echo null > $curThen

batt_cap() {
  local l=$(dsys_batt get level)
  local l2=$(cat $battCapacity)
  [ -n "$l" ] && echo $l || echo $l2
}
