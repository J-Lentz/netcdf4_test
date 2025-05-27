#!/bin/bash

basedir=`pwd`
data_basedir=$basedir/data
plot_basedir=$basedir/plots
perf_log=$basedir/../test/perf.log

dirs_label_plots="64bit netcdf4_baseline comparison_baseline netcdf4_chunk comparison_chunk collective_read"
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
    paste $data_basedir/64bit/$f $data_basedir/netcdf4_baseline/$f | awk -f merge.awk >$data_basedir/comparison_baseline/$f

    if [[ -f $data_basedir/netcdf4_chunk/$f ]]
    then
        paste $data_basedir/64bit/$f $data_basedir/netcdf4_chunk/$f | awk -f merge.awk >$data_basedir/comparison_chunk/$f
    fi
done

for d in $dirs_label_plots
do
    # Plot each data file
    find $data_basedir/$d -type f -exec ./plot_with_labels.gnuplot '{}' "Layout" "I/O Layout" ';'
done

cd $data_basedir/netcdf4_deflate
for n in 96 384 3072 6144
do
    for metric in read write
    do
        $basedir/plot_deflate_level.gnuplot $n $metric
    done
done

# Move plots into a plots/ directory.
for d in $dirs_all
do
    mv $data_basedir/$d/*.png $plot_basedir/$d/
done

# Transfer plots to GFDL
module load gcp
timestamp=`date +%s`
gcp -r -cd $plot_basedir gfdl:~/netcdf4_plots/$timestamp
