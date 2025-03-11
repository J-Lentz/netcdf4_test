#!/bin/sh

# Parameters
RUNDIR=$SCRATCH/$USER/gfdl_f/test_netcdf4
niter=1

LOG=`pwd`/perf.log
WRITE_PROG=`pwd`/test_write
READ_PROG=`pwd`/test_read

SRUN=`which srun`

rm -rf $RUNDIR
mkdir $RUNDIR

echo "test_id,nx,ny,layout_x,layout_y,layout_io_x,layout_io_y,niter,netcdf_format,chunk_size_x,chunk_size_y,chunk_size_z,deflate level,shuffle,use_collective,file_size,write_time,read_time" >${LOG}

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
  npes_io=$((layout_io_x * layout_io_y))

  # Skip impossible layouts
  [[ $((nx % layout_x)) != 0 ]] && return 0
  [[ $((ny % layout_y)) != 0 ]] && return 0

  # Skip impossible I/O layouts
  [[ $((nx % layout_io_x)) != 0 ]] && return 0
  [[ $((ny % layout_io_y)) != 0 ]] && return 0

  [[ $((layout_x % layout_io_x)) != 0 ]] && return 0
  [[ $((layout_y % layout_io_y)) != 0 ]] && return 0

  # Skip impossible chunk sizes
  [[ $(( (nx / layout_io_x) % chunksize_x)) != 0 ]] && return 0
  [[ $(( (ny / layout_io_y) % chunksize_y)) != 0 ]] && return 0
  
  # Skip the collective I/O test if the I/O layout is 1x1
  [[ "$use_collective" = "true" && $npes_io == 1 ]] && return 0

  (( i++ ))

  echo "Running test $i"
  mkdir ${RUNDIR}/${i}
  cd ${RUNDIR}/${i}

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
    echo "write failure" | tee err.write
    return 1
  fi

  $SRUN --ntasks=${npes} $READ_PROG |& tee read.log

  if [ ${PIPESTATUS[0]} = 0 ]
  then
    echo "Finished reading data"
  else
    echo "read failure" | tee err.read
    return 1
  fi

  write_time=`awk '/Total runtime/ {print $6}' write.log`
  read_time=`awk '/Total runtime/ {print $6}' read.log`
  file_size=`ls -lh data.nc | awk '{print $5}'`

  echo "${i},${nx},${ny},${layout_x},${layout_y},${layout_io_x},${layout_io_y},${niter},${netcdf_format},${chunksize_x},${chunksize_y},${chunksize_z},${deflate_level},${shuffle},${use_collective},${file_size},${write_time},${read_time}" >>${LOG}
}

for n in 96 384 # 3072
do
  for layout in 1 2 3 6 12 24 32
  do
    for layout_io in 1 2 3 6 12 24
    do
      run_test $n $layout $layout_io 64bit 1 0 false false

      for chunksize in 1 2 3 4
      do
        for deflate_level in `seq 0 9`
        do
          for shuffle in true false
          do
            for use_collective in true false
            do
              run_test $n $layout $layout_io netcdf4 $chunksize $deflate_level $shuffle $use_collective
            done
	  done
        done
      done
    done
  done
done
