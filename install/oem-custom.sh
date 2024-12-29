_grep() { grep -Eq "$1" ${2:-$config}; }
_set_prop() { sed -i "\|^${1}=|s|=.*|=$2|" ${3:-$config}; }
_get_prop() { sed -n "\|^$1=|s|.*=||p" ${2:-$config} 2>/dev/null || :; }

# patch/reset [broken/obsolete] config
if (set +x; . $config) >/dev/null 2>&1; then
  configVer=0$(_get_prop configVerCode)
  defaultConfVer=0$(cat $TMPDIR/.config-ver)
  [ $configVer -eq $defaultConfVer ] || {
    # if [ $configVer -lt 202404070 ]; then
    #   $TMPDIR/acca $config --set thermal_suspend=
    # else
      $TMPDIR/acca $config --set dummy=
    # fi
  }
else
  cat $execDir/default-config.txt > $config
fi

# battery idle mode for OnePlus devices
! _grep '^chargingSwitch=.battery/op_disable_charge 0 1 battery/input_suspend 0 0.$' \
  || loopCmd='[ $(cat battery/input_suspend) != 1 ] || echo 0 > battery/input_suspend'

# battery idle mode for Google Pixel 2/XL and devices with similar hardware
! _grep '^chargingSwitch=./sys/module/lge_battery/parameters/charge_stop_level' \
  || loopCmd='[ $(cat battery/input_suspend) != 1 ] || echo 0 > battery/input_suspend'

# idle mode - sony xperia
echo 1 > battery_ext/smart_charging_activation 2>/dev/null || :

# block "ghost charging on steroids" (Xiaomi Redmi 3 - ido)
[ ! -f $TMPDIR/accd-ido.log ] || touch $TMPDIR/.ghost-charging

# mt6795, exclude ChargerEnable switches (troublesome)
! getprop | grep -E mt6795 > /dev/null || {
  ! _grep ChargerEnable $execDir/ctrl-files.sh || {
    sed -i /ChargerEnable/d $TMPDIR/ch-switches
    sed -i /ChargerEnable/d $execDir/ctrl-files.sh
  }
}

# msm8937 reports wrong current; disable current-based status detection
! getprop ro.product.board | grep -i msm8937 || {
  [ .$(_get_prop battStatusWorkaround) = .false ] \
    || $TMPDIR/acca $config --set batt_status_workaround=false
}

# msm8937 reports wrong current; disable current-based status detection
! getprop ro.product.board | grep -i msm8937 || {
  [ .$(_get_prop battStatusWorkaround) = .false ] \
    || $TMPDIR/acca $config --set batt_status_workaround=false
}

# MSM8953 current polarity lags
! getprop ro.product.board | grep -i MSM8953 || {
  grep -q "^:; _DPOL=+" $config || echo ":; _DPOL=+" >> $config
}

unset -f _grep _get_prop _set_prop
unset configVer defaultConfVer
