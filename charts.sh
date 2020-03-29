#!/usr/bin/env bash

# Set strict error checking
set -emou pipefail
LC_CTYPE=C

# Enable debug output if $DEBUG is set to true
[ "${DEBUG:=false}" = 'true' ] && set -x

# Optional
DISABLE_COLORS="${DISABLE_COLORS:="false"}"
TEST_CPUS="${TEST_CPUS:="1 2 4 8 16 32 64"}"
TEST_ITERATIONS="${TEST_ITERATIONS:="5"}"
RESULTS_DIR="${RESULTS_DIR:=""}"

# Generate graphs
generate_charts() {
  for c in 50 100 200 300 400 500 100-ssl 100-no-pool; do
    printf '' > "${RESULTS_DIR}/results-${c}.dat"
    printf '' > "${RESULTS_DIR}/latency-${c}.dat"

    for i in ${TEST_CPUS}; do
      if [[ -f "results-${c}/${i}-1.log" ]]; then
        echo -en "$i\t" >> "${RESULTS_DIR}/results-${c}.dat"
        grep 'tps.*including' results-${c}/${i}-[0-9]* | cut -f3 -d' ' \
          | st --avg -no-header >> "${RESULTS_DIR}/results-${c}.dat"

        echo -en "$i\t" >> "${RESULTS_DIR}/latency-${c}.dat"
        grep 'latency average' results-${c}/${i}-[0-9]* | cut -f4 -d' ' \
          | st --avg -no-header >> "${RESULTS_DIR}/latency-${c}.dat"
      fi
    done
  done

  printf '' > "${RESULTS_DIR}/stats-p.dat"
  printf '' > "${RESULTS_DIR}/stats-l.dat"
  for c in 50 100 200 300 400 500; do

    for i in ${TEST_CPUS}; do
      if [[ -f "results-${c}/${i}-1.log" ]]; then
        grep 'tps.*including' results-${c}/${i}-[0-9]* | cut -f3 -d' ' \
          | st --avg --min --max --stddev >> "${RESULTS_DIR}/stats-p.dat"

        grep 'latency average' results-${c}/${i}-[0-9]* | cut -f4 -d' ' \
          | st --avg --min --max --stddev >> "${RESULTS_DIR}/stats-l.dat"
      fi
    done
  done


  gnuplot <<-EOF
    set terminal svg size 1200,800 enhanced font "Verdana,20" rounded dashed

    set key right center 
    set key box
    set yrange [0:]
    set ytics nomirror
    set xlabel "Instance size (vCPUs)"

    # Line style
    set style line 1 lc rgb '#b2182b' lw 3 pt 7 pi -1 ps 0.8 
    set style line 2 lc rgb '#2166ac' lw 3 pt 9 pi -1 ps 0.8 
    set style line 3 lc rgb '#d6604d' lw 3 pt 5 pi -1 ps 0.8 
    set style line 4 lc rgb '#4393c3' lw 3 pt 11 pi -1 ps 0.8 
    set style line 5 lc rgb '#f4a582' lw 3 pt 13 pi -1 ps 0.8 
    set style line 6 lc rgb '#92c5de' lw 3 pt 15 pi -1 ps 0.8 
    set style line 7 lc rgb '#fddbc7' lw 3 pt 7 pi -1 ps 0.8 
    set style line 8 lc rgb '#d1e5f0' lw 3 pt 7 pi -1 ps 0.8 

    set pointintervalbox 1.2
    set style increment user

    # Border style
    set style line 11 lc rgb '#808080' lt 1
    set border 4 back ls 11
    set tics nomirror

    # Grid
    set style line 12 lc rgb '#808080' lt 0 lw 2
    set grid back ls 12

    # Plot
    set output "${RESULTS_DIR}/generic.svg"
    set multiplot layout 2,1 title "{/:Bold Cloud SQL Performance (-c 200)}"
    unset xlabel
    set ylabel "tps"
    plot "${RESULTS_DIR}/results-200.dat" using 1:2 title "Performance" with linespoints ls 1
    set xlabel "Instance size (vCPUs)"
    set ylabel "ms"
    plot "${RESULTS_DIR}/latency-200.dat" using 1:2 title "Latency" with linespoints ls 2 dashtype 3
    unset multiplot
    
    set output "${RESULTS_DIR}/ssl.svg"
    set multiplot layout 2,1 title "{/:Bold Cloud SQL Performance - SSL (-c 100)}"
    unset xlabel
    set ylabel "tps"
    plot "${RESULTS_DIR}/results-100.dat" using 1:2 title "Performance" with linespoints ls 1, \
         "${RESULTS_DIR}/results-100-ssl.dat" using 1:2 title "Perf. - SSL" with linespoints ls 2
    set xlabel "Instance size (vCPUs)"
    set ylabel "ms"
    plot "${RESULTS_DIR}/latency-100.dat" using 1:2 title "Latency" with linespoints ls 1 dashtype 3, \
         "${RESULTS_DIR}/latency-100-ssl.dat" using 1:2 title "Lat. - SSL" with linespoints ls 2 dashtype 3
    unset multiplot

    set output "${RESULTS_DIR}/no-pool.svg"
    set multiplot layout 2,1 title "{/:Bold Cloud SQL Performance - No Connection Pooling (-c 100)}"
    unset xlabel
    set ylabel "tps"
    plot "${RESULTS_DIR}/results-100.dat" using 1:2 title "Performance" with linespoints ls 1, \
         "${RESULTS_DIR}/results-100-no-pool.dat" using 1:2 title "Perf. - No Pooling" with linespoints ls 2
    set xlabel "Instance size (vCPUs)"
    set ylabel "ms"
    plot "${RESULTS_DIR}/latency-100.dat" using 1:2 title "Latency" with linespoints ls 1 dashtype 3, \
         "${RESULTS_DIR}/latency-100-no-pool.dat" using 1:2 title "Lat. - No Pooling" with linespoints ls 2 dashtype 3
    unset multiplot

    set output "${RESULTS_DIR}/stats-p.svg"
    set key right top
    set multiplot layout 2,1 title "{/:Bold Cloud SQL Performance - stats}"
    unset xlabel
    unset xtics
    set ylabel "tps"
    plot "${RESULTS_DIR}/stats-p.dat" using 4 title "Performance - stddev" with linespoints ls 1
    set ylabel "ms"
    plot "${RESULTS_DIR}/stats-l.dat" using 4 title "Latency - stddev" with linespoints ls 2 dashtype 3
    unset multiplot

    set title "{/:Bold Cloud SQL Performance - Concurrent Clients × TPS}"
    set key right center
    set ylabel "tps"
    set xtics
    set output "${RESULTS_DIR}/performance-all.svg"
    set ylabel "tps"
    plot for [i in "50 100 200 300 400 500"] "${RESULTS_DIR}/results-".i.".dat" using 1:2 title i." clients" with linespoints

    set title "{/:Bold Cloud SQL Performance - Concurrent Clients × Latency}"
    set output "${RESULTS_DIR}/latency-all.svg"
    set ylabel "ms"
    plot for [i in "50 100 200 300 400 500"] "${RESULTS_DIR}/latency-".i.".dat" using 1:2 title i." clients" with linespoints
EOF
}

# Main script
main() {
  generate_charts
}

# Helper that allows to run indifivual functions
if [ -n "${*}" ]; then
  "${@}"
else
  main
fi
