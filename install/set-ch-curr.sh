set_ch_curr() {

  local f=$TMPDIR/.curr-default
  local verbose=${verbose:-true}

  ! [[ -f $f && .${1-} = .- ]] || return 0

  if [[ .${1-} = .*% ]]; then
    set_temp_level ${1%\%}
    return
  fi

  $verbose || {
    exxit() { exit $?; }
    . $execDir/misc-functions.sh
  }

  ! ${isAccd:-false} || verbose=false

  # check support
  if [ ! -f $TMPDIR/.ch-curr-read ]; then
    if not_charging; then
      ! $verbose || {
        print_read_curr
        print_wait_plug
        echo
      }
      set +x
      while not_charging; do sleep 1; done
      log_on
    fi
    . $execDir/read-ch-curr-ctrl-files-p2.sh
  fi
  grep -q / $TMPDIR/ch-curr-ctrl-files 2>/dev/null || {
    ! $verbose || print_no_ctrl_file
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
      ! $verbose || print_curr_restored
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
            ! $verbose || print_curr_set $1
          } || return 1
      }

      # [0-9999] milliamps range
      if [ $1 -ge 0 -a $1 -le 9999 ]; then
        apply_current $1 || return 1
      else
        ! $verbose || echo "[0-9999]$(print_mA; print_only)"
        return 11
      fi
      rm $f 2>/dev/null || :
    fi

  else
    # print current value
    ! $verbose && echo ${maxChargingCurrent[0]-} \
      || echo "${maxChargingCurrent[0]:-$(print_default)}$(print_mA)"
    return 0
  fi
}
