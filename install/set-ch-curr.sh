set_ch_curr() {

  local f=$TMPDIR/.curr-default
  local isAccd=${isAccd:-false}

  ! [[ -f $f && .${1-} = .- ]] || return 0

  [[ .${1-} != .*% ]] || {
    set_temp_level ${1%\%}
    return
  }

  # check support
  [ -f $TMPDIR/.ch-curr-read ] || {
    ! not_charging || {
      $isAccd || {
        print_read_curr
        print_unplugged
      }
      (set +x; while not_charging; do sleep 1; done)
    }
    . $execDir/read-ch-curr-ctrl-files-p2.sh
  }
  grep -q / $TMPDIR/ch-curr-ctrl-files 2>/dev/null || {
    $isAccd || print_no_ctrl_file
    return 0
  }

  if [ -n "${1-}" ]; then

    apply_on_plug_() {
      (applyOnPlug=()
      maxChargingVoltage=()
      apply_on_plug ${1-})
    }

    # restore
    if [ $1 = - ]; then
      apply_on_plug_ default
      max_charging_current=
      $isAccd || print_curr_restored
      touch $f

    else

      apply_current() {
        eval "
          if [ $1 -ne 0 ]; then
            maxChargingCurrent=($1 $(sed "s|::v|::$1|" $TMPDIR/ch-curr-ctrl-files))
          else
            maxChargingCurrent=($1 $(sed "s|::v.*::|::$1::|" $TMPDIR/ch-curr-ctrl-files))
          fi
        " \
          && unset max_charging_current mcc \
          && apply_on_plug_ \
          && {
            $isAccd || print_curr_set $1
          } || return 1
      }

      # [0-9999] milliamps range
      if [ $1 -ge 0 -a $1 -le 9999 ]; then
        apply_current $1 || return 1
      else
        $isAccd || echo "[0-9999]$(print_mA; print_only)"
        return 11
      fi
      rm $f 2>/dev/null || :
    fi

  else
    # print current value
    $isAccd && echo ${maxChargingCurrent[0]-} \
      || echo "${maxChargingCurrent[0]:-$(print_default)}$(print_mA)"
    return 0
  fi
}
