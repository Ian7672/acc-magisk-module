is_android() {
  [ ! -d /data/usbmsc_mnt/ ] && [ -x /system/bin/dumpsys ] \
    && [[ "$(readlink -f $execDir)" != *com.termux* ]] \
    && pgrep -f zygote >/dev/null
}

# cmd battery and dumpsys wrappers
if is_android; then
  cmd_batt() {
    if [ $1 = get ]; then
      { dumpsys battery | sed -n "s/^  $2: //p"; } 2>/dev/null || :
    else
      /system/bin/cmd battery "$@" < /dev/null 2>/dev/null || :
    fi
  }
  dumpsys() { /system/bin/dumpsys "$@" 2>/dev/null || :; }
else
  cmd_batt() { :; }
  dumpsys() { :; }
  ! ${isAccd:-false} || {
    chgStatusCode=0
    dischgStatusCode=0
  }
fi
