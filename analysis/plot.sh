#!/bin/bash
set -euo pipefail
#set -x

basedir=`pwd`
data_basedir=$basedir/data
plot_basedir=$basedir/plots
perf_log=$basedir/../test/perf.log
GRIDS="96 384 3072 6144"

dirs_label_plots="64bit netcdf4_baseline netcdf4_baseline_pctdiff netcdf4_chunk netcdf4_chunk_pctdiff netcdf4_collective_read netcdf4_collective_read_pctdiff"
dirs_all="$dirs_label_plots netcdf4_deflate"

# Clean existing files
rm -rf $data_basedir $plot_basedir
for d in $dirs_all
do
    mkdir -p $data_basedir/$d $plot_basedir/$d
done

# Generate data files corresponding to each grid size
awk -f format_data.awk $perf_log

# Generate netcdf4-64bit data
for f in {96,384,3072,6144}.{read,write}_time
do
    # NetCDF4 baseline, compared to 64bit
    paste $data_basedir/64bit/$f $data_basedir/netcdf4_baseline/$f | awk -f merge.awk >$data_basedir/netcdf4_baseline_pctdiff/$f

    # Netcdf4 with chunking, compared to 64bit
    paste <(awk '$2 == 1' $data_basedir/64bit/$f) $data_basedir/netcdf4_chunk/$f | awk -f merge.awk >$data_basedir/netcdf4_chunk_pctdiff/$f
done

for g in $GRIDS
do
    f="${g}.read_time"
    paste <(awk '$1 == $2' $data_basedir/64bit/$f) $data_basedir/netcdf4_collective_read/$f | awk -f merge.awk >$data_basedir/netcdf4_collective_read_pctdiff/$f
done

for d in $dirs_label_plots
do
    # Plot each data file
    find $data_basedir/$d -type f -exec ./plot_with_labels.gnuplot '{}' "Layout" "I/O Layout" ';'
done

cd $data_basedir/netcdf4_deflate
for n in $GRIDS
do
    for metric in read write
    do
        echo "Skipping deflate level plot for $n ... $metric"
        #$basedir/plot_deflate_level.gnuplot $n $metric
    done
done

# Move plots into a plots/ directory.
#for d in $dirs_all
for d in $dirs_label_plots
do
    mv $data_basedir/$d/*.png $plot_basedir/$d/
done

# Transfer plots to GFDL
module load gcp
timestamp=`date +%s`
gcp -r -cd $plot_basedir/ gfdl:~/netcdf4_plots/$timestamp/
