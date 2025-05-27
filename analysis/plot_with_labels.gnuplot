#!/usr/bin/gnuplot -c

filename=ARG1
set xlabel ARG2
set ylabel ARG3
set key off

set terminal png
set output filename.".png"
set key off

set xrange [0:7]
set yrange [0:7]

plot filename using 1:2:3 with labels
