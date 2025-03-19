#!/bin/bash

# Parameters
BASEDIR=$SCRATCH/$USER/gfdl_f/test_netcdf4
LAYOUTS="1 2 3 6 12"
NITER=1

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

  cat >input.nml <<EOF
&test_nml
    nx = $nx
    ny = $ny
    niter = $NITER
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

for n in 96 # 384 3072 6144
do
  for layout in $LAYOUTS
  do
    for layout_io in $LAYOUTS
    do
      run_test $n $layout $layout_io 64bit 0 0 false false

      for chunksize in 0 16 32 96
      do
        for deflate_level in `seq 0 9`
        do
          for shuffle in true false
          do
            USE_COLLECTIVE=false

            # Perform the collective I/O test if the layout and I/O layout are the same
            [[ $layout != 1 && $layout_io = $layout ]] && USE_COLLECTIVE+=" true"

            for use_collective in $USE_COLLECTIVE
            do
              run_test $n $layout $layout_io netcdf4 $chunksize $deflate_level $shuffle $use_collective
            done
	  done
        done
      done
    done
  done
done
