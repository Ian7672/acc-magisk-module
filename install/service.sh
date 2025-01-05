#!/system/bin/sh
# $id initializer
# Copyright 2017-2021, VR25
# License: GPLv3+

id=acc
domain=vr25
TMPDIR=/dev/.$domain/$id
execDir=/data/adb/$domain/$id
dataDir=/data/adb/$domain/${id}-data

[[ -f $execDir/disable || -f $dataDir/logs/bootloop-*.log ]] && exit 14

# wait til the lockscreen is ready and give some bootloop grace period
slept=false
until [ .$(getprop init.svc.bootanim 2>/dev/null) = .stopped ]; do
  sleep 10 && slept=true
done
$slept && sleep 60
unset slept

mkdir -p $TMPDIR
export dataDir domain execDir id TMPDIR
. $execDir/setup-busybox.sh
. $execDir/release-lock.sh
exec start-stop-daemon -bx $execDir/${id}d.sh -S -- "$@" || exit 12
