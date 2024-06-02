wizard() {

  clear
  echo
  print_header

  echo
  { daemon_ctrl | sed "s/ $accVer ($accVerCode)//"; } || :
  echo

echo -n "1) $(print_lang)
2) $(print_cmds)
3) $(print_doc)
4) $(print_re_start_daemon)
5) $(print_stop_daemon)
6) $(print_export_logs)
7) $(print_charge_once)
8) $(print_uninstall)
9) $(print_edit config.txt)
a) $(print_reset_bs)
b) $(print_test_cs)
c) $(print_update)
d) $(print_flash_zips)
e) $(print_i)
f) $(print_undo)
z) $(print_exit)

#? "
  read -n 1 choice
  echo
  echo

  case $choice in

    1)
      . $execDir/set-prop.sh; set_prop --lang
      exec $TMPDIR/acc
    ;;

    2)
      . $execDir/print-help.sh
      print_help_ g
      edit $TMPDIR/.help
      exec wizard
    ;;

    3)
      edit $readMe g VIEW html
      edit ${readMe%html}md
      exec wizard
    ;;

    4)
      $TMPDIR/accd
      exec wizard
    ;;

    5)
      daemon_ctrl stop > /dev/null || :
      exec wizard
    ;;

    6)
      logf --export
      echo
      print_press_key
      read -n 1
      exec wizard
    ;;

    7)
      clear
      echo
      echo -n ""
      print_1shot
      echo
      echo
      echo -n "> "
      read level
      clear
      exec $TMPDIR/acc --full ${level-}
      unset level
      print_press_key
      read -n 1
      exec wizard
    ;;

    8)
      set +eu
      print_uninstall
      echo "> yes/no: "
      read ans
      [ .$ans = .yes ] || exec wizard
      exec $execDir/uninstall.sh
    ;;

    9)
      edit $config g
      edit $config
      exec wizard
    ;;

    a)
      dumpsys batterystats --reset
      rm /data/system/batterystats* 2>/dev/null || :
      exec wizard
    ;;

    b)
      $TMPDIR/acc --test || :
      print_press_key
      read -n 1
      exec wizard
    ;;

    c)
      $TMPDIR/acc --upgrade --changelog || :
      print_press_key
      read -n 1
      exec $TMPDIR/acc
    ;;

    d)
      (
        set +eux
        trap - EXIT
        $execDir/flash-zips.sh
      ) || :
      echo
      print_press_key
      read -n 1
      exec $TMPDIR/acc
    ;;

    e)
      . $execDir/batt-info.sh
      batt_info
      echo
      print_press_key
      read -n 1
      exec wizard
    ;;

    f)
      rollback -v
      echo "> yes/no: "
      read ans
      [ .$ans != .yes ] || rollback
      exec $TMPDIR/acc
    ;;

    z)
      exit 0
    ;;

    *)
      print_wip
      sleep 1
      exec wizard
    ;;
  esac
}
