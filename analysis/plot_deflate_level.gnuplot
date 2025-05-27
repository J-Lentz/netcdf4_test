#!/usr/bin/gnuplot -c

n=ARG1
perf_metric=ARG2

set key off
set terminal pngcairo
set output sprintf("c%s_%s_time.png", n, perf_metric)

set multiplot layout 6,6 columnsfirst upwards title sprintf("c%s: %s time", n, perf_metric)

# i: Layout
# j: I/O layout
do for [i = 1:6] {
    do for [j = 1:6] {
        filename = sprintf("%s.%d.%d.%s_time", n, i, j, perf_metric)
        stats filename nooutput
        if (GPVAL_ERRNO) {
            # skip
            plot 0
            reset errors
        }
        else {
            #set title sprintf("%d / %d", i, j)
            plot filename using 1:2
        }
    }
}
