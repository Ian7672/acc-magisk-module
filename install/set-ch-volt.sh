set_ch_volt() {

  local f=$TMPDIR/.volt-default
  local isAccd=${isAccd:-false}

  ! [[ -f $f && .${1-} = .- ]] || return 0

  if [ -n "${1-}" ]; then

    set -- $*

    apply_on_boot_() {
      (applyOnBoot=()
      apply_on_boot ${*-})
    }

    grep -q / $TMPDIR/ch-volt-ctrl-files 2>/dev/null || {
      $isAccd || print_no_ctrl_file v
      return 0
    }

    # restore
    if [ $1 = - ]; then
      apply_on_boot_ default force
      max_charging_voltage=
      $isAccd || print_volt_restored
      touch $f

    else
      apply_voltage() {
        eval "maxChargingVoltage=($1 $(sed "s|::v|::$1|" $TMPDIR/ch-volt-ctrl-files) ${2-})" \
          && unset max_charging_voltage mcv \
          && apply_on_boot_ \
          && {
            $isAccd || print_volt_set $1
          } || return 1
      }

      # = [3700-4300] millivolts
      if [ $1 -ge 3700 -a $1 -le 4300 ]; then
        apply_voltage $1 ${2-} || return 1

      # < 3700 millivolts
      elif [ $1 -lt 3700 ]; then
        $isAccd || echo "[3700-4300]$(print_mV; print_only)"
        apply_voltage 3700 ${2-} || return 1

      # > 4300 millivolts
      elif [ $1 -gt 4300 ]; then
        $isAccd || echo "[3700-4300]$(print_mV; print_only)"
        apply_voltage 4300 ${2-} || return 1
      fi
      rm $f 2>/dev/null || :
    fi

  else
    # print current value
    $isAccd && echo ${maxChargingVoltage[0]-} \
      || echo "${maxChargingVoltage[0]:-$(print_default)}$(print_mV)"
    return 0
  fi
}
