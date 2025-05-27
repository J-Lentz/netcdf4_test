#!/bin/bash

# Parameters
BASEDIR=$SCRATCH/$USER/gfdl_f/test_netcdf4
LAYOUTS="1 2 3 6"

LOG=`pwd`/perf.log
WRITE_PROG=`pwd`/test_write
READ_PROG=`pwd`/test_read

SRUN=`which srun`

rm -rf $BASEDIR

echo "test_id,nx,ny,layout_x,layout_y,layout_io_x,layout_io_y,netcdf_format,chunk_size_x,chunk_size_y,chunk_size_z,deflate level,shuffle,use_collective,file_size,write_time,read_time,write_mem,read_mem" >${LOG}

i=0

run_test () {
  nx=$1
  ny=$1
  layout_x=$2
  layout_y=$2
  layout_io_x=$3
  layout_io_y=$3
  netcdf_format=$4
  chunksize_x=$5
  chunksize_y=$5
  chunksize_z=1
  deflate_level=$6
  shuffle=$7
  use_collective=$8

  npes=$((layout_x * layout_y))

  # Skip impossible layouts
  [[ $((nx % layout_x)) != 0 ]] && return 0
  [[ $((ny % layout_y)) != 0 ]] && return 0

  # Skip impossible I/O layouts
  [[ $((nx % layout_io_x)) != 0 ]] && return 0
  [[ $((ny % layout_io_y)) != 0 ]] && return 0

  [[ $((layout_x % layout_io_x)) != 0 ]] && return 0
  [[ $((layout_y % layout_io_y)) != 0 ]] && return 0

  # Skip impossible chunk sizes
  [[ $chunksize_x != 0 && $(( (nx / layout_io_x) % chunksize_x)) != 0 ]] && return 0
  [[ $chunksize_y != 0 && $(( (ny / layout_io_y) % chunksize_y)) != 0 ]] && return 0

  (( i++ ))

  echo "Running test $i"

  RUNDIR=${BASEDIR}/${layout_x}x${layout_y}/${layout_io_x}x${layout_io_y}/${netcdf_format}/${i}
  mkdir -p $RUNDIR
  cd $RUNDIR

  # Aim for a filesize of about 1 GB
  niter=$(( 1024*1024*1024 / (nx*ny*8) ))

  cat >input.nml <<EOF
&test_nml
    nx = $nx
    ny = $ny
    niter = $niter
    layout = $layout_x , $layout_y
    io_layout = $layout_io_x , $layout_io_y
    chunksizes = ${chunksize_x}, ${chunksize_y}, ${chunksize_z}
    use_collective = .${use_collective}.
/

&fms2_io_nml
    netcdf_default_format = "$netcdf_format"
    deflate_level         = $deflate_level
    shuffle               = .${shuffle}.
/
EOF

  $SRUN --ntasks=${npes} $WRITE_PROG |& tee write.log

  if [ ${PIPESTATUS[0]} = 0 ]
  then
    echo "Finished writing data"
  else
    echo "write failure" | tee FAIL
    exit 1
  fi

  $SRUN --ntasks=${npes} $READ_PROG |& tee read.log

  if [ ${PIPESTATUS[0]} = 0 ]
  then
    echo "Finished reading data"
  else
    echo "read failure" | tee FAIL
    exit 1
  fi

  write_tmax=`awk '/Total runtime/ {print $5}' write.log`
  read_tmax=`awk '/Total runtime/ {print $5}' read.log`
  file_size=`ls -l data.nc* | awk 'BEGIN {total=0} {total+=$5} END {print total / 1024^2}'`

  memuse_prog='BEGIN {m=0} {if ($1>m) m=$1} END {print m}'
  memuse_write=`awk "$memuse_prog" memuse.write.*`
  memuse_read=`awk "$memuse_prog" memuse.read.*`

  echo "${i},${nx},${ny},${layout_x},${layout_y},${layout_io_x},${layout_io_y},${netcdf_format},${chunksize_x},${chunksize_y},${chunksize_z},${deflate_level},${shuffle},${use_collective},${file_size} MiB,${write_tmax} s,${read_tmax} s,${memuse_write} MiB,${memuse_read} MiB" >>${LOG}
}

function run_netcdf4_battery () {
  n=$1
  layout=$2
  layout_io=$3
  use_collective=$4

  for chunksize in 0 $n
  do
    run_test $n $layout $layout_io netcdf4 $chunksize 0 false $use_collective
  done

  for deflate_level in `seq 0 9`
  do
    run_test $n $layout $layout_io netcdf4 0 $deflate_level false $use_collective
  done

  for shuffle in true false
  do
    run_test $n $layout $layout_io netcdf4 0 0 $shuffle $use_collective
  done
}

for n in 96 384 3072 6144
do
  for layout in $LAYOUTS
  do
    # NetCDF-4 test with use_collective=.true.
    run_test $n $layout $layout netcdf4 0 0 false true

    for layout_io in $LAYOUTS
    do
      # 64-bit test
      run_test $n $layout $layout_io 64bit 0 0 false false

      # NetCDF-4 tests with use_collective=.false.
      run_netcdf4_battery $n $layout $layout_io false
    done
  done
done
