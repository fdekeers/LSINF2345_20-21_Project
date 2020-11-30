set term pdf color enhanced
set output 'pss_indegree.pdf'

set tmargin 1
set lmargin 12
set rmargin 2
set bmargin 5

set xlabel "Cycles"
set ylabel "In-degree of nodes running the PS service"
set grid y

set key top right

set xrange [0:200]
set xtics (1,20,40,60,80,100,120,140,160,180,200)

set yrange [0:30]
set mytics 2

set style line 1 lt 2 lc 1 lw 2 pt 1 ps 3
set style line 2 lt 2 lc 2 lw 2 pt 1 ps 3

plot \
	'healer_deployment.data' using ($1):($2):($3) with yerrorbars ls 1 title "Healer", \
  'swapper_deployment.data' using ($1):($2):($3) with yerrorbars ls 2 title "Swapper"
