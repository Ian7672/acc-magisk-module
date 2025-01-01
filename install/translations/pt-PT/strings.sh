# Português, Portugal (pt-PT)

print_already_running() {
  echo "accd já está em execução"
}

print_started() {
  echo "accd foi iniciado"
}

print_stopped() {
  echo "accd foi parado"
}

print_not_running() {
  echo "accd não está em execução"
}

print_restarted() {
  echo "accd foi reiniciado"
}

print_is_running() {
  echo "accd $1 está em execução $2"
}

print_config_reset() {
  echo "A configuração padrão foi restaurada"
}

print_invalid_switch() {
  echo "Interruptor de carga inválido, [${chargingSwitch[@]-}]"
}

print_charging_disabled_until() {
  echo "Recarga desativada até % <= $1"
}

print_charging_disabled_for() {
  echo "Recarga desativada por $1"
}

print_charging_disabled() {
  echo "Recarga desativada"
}

print_charging_enabled_until() {
  echo "Recarga ativada até % >= $1"
}

print_charging_enabled_for() {
  echo "Recarga ativada por $1"
}

print_charging_enabled() {
  echo "Recarga ativada"
}

print_unplugged() {
  printf "Conecte o carregador primeiro 🔌\n\n"
}

print_switch_works() {
  echo "[$@] funciona"
}

print_switch_fails() {
  echo "[$@] não funciona"
}

print_not_found() {
  echo "$1 não encontrado"
}

#print_help() {

print_exit() {
  echo "Sair"
}

print_choice_prompt() {
  echo "(?) Introduza um número e clique [enter]: "
}

print_auto() {
  echo "Automático"
}

print_default() {
 echo "Predefinição"
}

print_curr_restored() {
  echo "Máxima corrente de recarga padrão restaurada"
}

print_volt_restored() {
  echo "Máxima voltagem padrão de recarga restaurada"
}

print_read_curr() {
  echo "Antes the prosseguir, o acc precisa obter os padrões máximos de corrente de recarga"
  print_unplugged
  echo -n "- À espera..."
}

print_curr_set() {
  echo "Máxima corrente de recarga definida para $1 miliamperes"
}

print_volt_set() {
  echo "Máxima voltagem de recarga definida para $1 milivolts"
}

print_curr_range() {
  echo "Apenas [$1] (miliamperes)"
}

print_volt_range() {
  echo "Apenas [$1] (milivolts)"
}
