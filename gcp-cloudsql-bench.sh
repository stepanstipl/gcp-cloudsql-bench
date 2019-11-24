#!/usr/bin/env sh

# Set strict error checking
set -emou pipefail
LC_CTYPE=C

# Enable debug output if $DEBUG is set to true
[ "${DEBUG:=false}" = 'true' ] && set -x

# Get script name
THIS_SCRIPT="$(basename "${0}")"

# Required variables
TF_VAR_project="${TF_VAR_project:?"Environment variable must be set"}"

# Optional
DISABLE_COLORS="${DISABLE_COLORS:="false"}"
PGBENCH_RUN_CLIENTS="${PGBENCH_RUN_CLIENTS:="50"}"
PGBENCH_RUN_TIME="${PGBENCH_RUN_TIME:="300"}"
PGBENCH_SCALE_FACTOR="${PGBENCH_SCALE_FACTOR:="100"}"
PGBENCH_WORKER_THREADS="${PGBENCH_WORKER_THREADS:="8"}"
PRINT_PREFIX="${PRINT_PREFIX:=""}"
REQUIRED_BINARIES="${REQUIRED_BINARIES:="gcloud terraform awk gnuplot"}"
TEST_CPUS="${TEST_CPUS:="1 2 4 8 16 32 64"}"
TEST_ITERATIONS="${TEST_ITERATIONS:="5"}"
TF_VAR_region="${TF_VAR_region:="europe-west2"}"
RESULTS_DIR="${RESULTS_DIR:=""}"

# Runtime
CLIENT_INSTANCE_NAME=""
CLIENT_INSTANCE_ZONE=""
SQL_IP=""
SQL_USER=""
SQL_PASSWORD=""
SQL_DB=""

# Check if we have colors available, it looks good :)
check_colors(){
  if command -v tput > /dev/null && [ "${DISABLE_COLORS}" != 'true' ]; then
    COLORS="$(tput colors)"
    if [ -n "${COLORS}" ] && [ "${COLORS}" -ge 8 ]; then
      GREEN="$(tput setaf 2)"
      RED="$(tput setaf 1)"
      YELLOW="$(tput setaf 3)"
      NOCOL="$(tput sgr0)"
    fi
  else
    GREEN=''
    RED=''
    YELLOW=''
    NOCOL=''
  fi
}

# Print message
print() {
  echo "${YELLOW}${PRINT_PREFIX}${NOCOL}${*}"
}

# Print message
print_header() {
  echo "${YELLOW}${PRINT_PREFIX}###${NOCOL}"
  echo "${YELLOW}${PRINT_PREFIX}### ${*}${NOCOL}"
  echo "${YELLOW}${PRINT_PREFIX}###${NOCOL}"
}

# Print error and exit with given return code
fail() {
  print "${RED}${1}${NOCOL}" >&2
  exit "${2}"
}

# Check if we have all the dependencies
verify_binaries() {
  for bin in ${REQUIRED_BINARIES}; do
    [ -x "$(command -v "${bin}")" ] || fail "Required dependency ${bin} not found in path" 1
  done
}

bootstrap() {
  print_header "Bootstrapping testing infrastructure"

  terraform init
  terraform apply -auto-approve
  
  CLIENT_INSTANCE_NAME="$(terraform output client_instance_name)"
  CLIENT_INSTANCE_ZONE="$(terraform output client_instance_zone)"
  SQL_IP="$(terraform output sql_ip)"
  SQL_USER="$(terraform output sql_user)"
  SQL_PASSWORD="$(terraform output sql_password)"
  SQL_DB="$(terraform output sql_db)"

  wait_for_db
  pgbench_init
}

destroy() {
  terraform destroy -auto-approve
}

run_remote_command() {
  command="${*}"
  gcloud compute ssh "${CLIENT_INSTANCE_NAME}" --tunnel-through-iap --command "${command}" --zone "${CLIENT_INSTANCE_ZONE}"
}

wait_for_db() {
  print "Waiting for the database..."
  test_cmd="PGCONNECT_TIMEOUT=1 psql 'postgres://${SQL_USER}:${SQL_PASSWORD}@${SQL_IP}/${SQL_DB}' -c '\d' 1>/dev/null 2>&1"
  run_remote_command "while ! ${test_cmd}; do echo -n '.'; sleep 1; done"
}

pgbench_init() {
  print "Initializing pgbench..."

  PGBENCH_INIT_OPTIONS="${PGBENCH_INIT_OPTIONS:="-s ${PGBENCH_SCALE_FACTOR}"}"

  run_remote_command "pgbench 'postgres://${SQL_USER}:${SQL_PASSWORD}@${SQL_IP}/${SQL_DB}' -i ${PGBENCH_INIT_OPTIONS}"
}

pgbench_run() {
  name="${1}"

  RESULTS_DIR="${RESULTS_DIR:="$(mktemp -d "./results-$(date '+%Y-%m-%dT%H-%M')-XXXX")"}"
  PGBENCH_RUN_OPTIONS="${PGBENCH_RUN_OPTIONS:="-j ${PGBENCH_WORKER_THREADS} -T ${PGBENCH_RUN_TIME} -c ${PGBENCH_RUN_CLIENTS}"}"

  print "Running pgbench ${name}"
  run_remote_command "pgbench 'postgres://${SQL_USER}:${SQL_PASSWORD}@${SQL_IP}/${SQL_DB}' ${PGBENCH_RUN_OPTIONS}" \
    | tee "${RESULTS_DIR}/${name}.log"
}

setup_and_run() {
  cpus="${1}"
  print_header "Test for ${cpus}x vCPUs Instance"

  export TF_VAR_cpus="${cpus}"
  terraform apply -auto-approve

  # prewarm
  wait_for_db
  pgbench_run "${cpus}-prewarm"

  for i in $(seq 1 ${TEST_ITERATIONS}); do
    pgbench_run "${cpus}-${i}"
  done
}

# Generate graphs
generate_charts() {
  printf '' > "${RESULTS_DIR}/results.dat"

  for i in ${TEST_CPUS}; do
    printf '%s ' "${i}" >> "${RESULTS_DIR}/results.dat"
    grep 'tps.*including' ${RESULTS_DIR}/${i}-[0-9]* | cut -f3 -d' ' \
      | awk '{ sum += $1} END { print sum / NR }' >> "${RESULTS_DIR}/results.dat"
  done

  gnuplot <<-EOF
    set title "CloudSQL Performance - pgbench"
    set terminal svg size 640,480 enhanced font "Verdana,16" rounded dashed
    set output "${RESULTS_DIR}/results.svg"
    set yrange [0:]
    # Line style
    set style line 1 lt rgb "#A00000" lw 3 pt 7 ps 0.9
    set style line 2 lt rgb "#00A000" lw 3 pt 9 ps 0.9
    set style line 3 lt rgb "#5060D0" lw 3 pt 5 ps 0.9
    set style line 4 lt rgb "#F25900" lw 3 pt 13 ps 0.9
    # Border style
    set style line 11 lc rgb '#808080' lt 1
    set border 3 back ls 11
    set tics nomirror
    # Grid
    set style line 12 lc rgb '#808080' lt 0 lw 1
    set grid back ls 12
    # Plot
    plot "${RESULTS_DIR}/results.dat" using 1:2 notitle with lines ls 1, \
         "${RESULTS_DIR}/results.dat" using 1:2 notitle with points ls 1
EOF

}

# Main script
main() {
  # Init helper functions
  check_colors
  verify_binaries

  # Initial bootstrap
  bootstrap

  # Main loop
  for i in ${TEST_CPUS}; do
    setup_and_run "${i}"
  done

  # Teardown
  destroy
}

# Helper that allows to run indifivual functions
if [ -n "${1}" ]; then
  "${@}"
else
  main
fi
