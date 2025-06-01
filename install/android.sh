is_android() {
  [ ! -d /data/usbmsc_mnt/ ] && [ -x /system/bin/dumpsys ] \
    && [[ "$(readlink -f $execDir)" != *com.termux* ]] \
    && pgrep -f zygote >/dev/null
}


# dumpsys wrappers

if is_android; then

  dumpsys() { /system/bin/dumpsys "$@" || :; }

  dsys_batt() {
    if [ $1 = get ]; then
      dumpsys battery | sed -n "s/^  $2: //p"
    else
      dumpsys battery "$@"
    fi
  }

else

  dsys_batt() { :; }

  dumpsys() { :; }
  ! ${isAccd:-false} || {
    chgStatusCode=0
    dischgStatusCode=0
  }

fi
