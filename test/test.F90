#define KIND_ r8_kind

program test_netcdf_perf

use fms_mod, only: fms_init, fms_end, check_nml_error
use fms2_io_mod, only: FmsNetcdfDomainFile_t, open_file, close_file, flush_file, &
                       register_axis, register_variable_attribute, write_data, &
                       read_data, unlimited
use netcdf_io_mod, only: netcdf_add_variable
use mpp_mod, only: mpp_error, fatal, stderr, input_nml_file, mpp_pe
use mpp_domains_mod, only : mpp_domains_set_stack_size, mpp_define_domains, &
                            mpp_define_io_domain, mpp_get_compute_domain, &
                            mpp_get_data_domain, domain2d
use mpp_memutils_mod, only: mpp_mem_dump
use fms_string_utils_mod, only: string
use random_numbers_mod, only: randomNumberStream, initializeRandomNumberStream, &
                              getRandomNumbers
use platform_mod, only: r4_kind, r8_kind

implicit none

integer :: nx
integer :: ny
integer :: niter
character(*), parameter :: filename="data.nc"

integer, dimension(2) :: layout = [1, 1]
integer, dimension(2) :: io_layout = [1, 1]
integer, dimension(3) :: chunksizes = [0, 0, 0]
logical :: use_collective = .false.

type(domain2d) :: domain
integer :: is, ie, js, je !< Data domain
integer :: isc, iec, jsc, jec !< Compute domain

type(FmsNetcdfDomainFile_t) :: fileobj

namelist /test_nml/ nx, ny, niter, layout, io_layout, chunksizes, use_collective

call fms_init

call read_test_nml

if (use_collective) then
#ifdef WRITE_TEST
  io_layout = [1, 1]
#endif

#ifdef READ_TEST
  fileobj%use_collective = .true.
#endif
endif

call define_domain

#ifdef WRITE_TEST
call write_netcdf_file
call report_memuse("write")
#endif

#ifdef READ_TEST
call read_netcdf_file
call report_memuse("read")
#endif

call fms_end

contains

subroutine define_domain
  integer, parameter :: stack_size = 17280000

  call mpp_domains_set_stack_size(stack_size)
  call mpp_define_domains( [1, nx, 1, ny], layout, domain)
  call mpp_define_io_domain(domain, io_layout)

  call mpp_get_data_domain(domain, is, ie, js, je)
  call mpp_get_compute_domain(domain, isc, iec, jsc, jec)
end subroutine define_domain

subroutine read_test_nml
  integer :: ierr

  read (input_nml_file, nml=test_nml, iostat=ierr)
  ierr = check_nml_error(ierr, 'test_nml')
end subroutine read_test_nml

subroutine test_netcdf_file_open(mode)
  character(*), intent(in) :: mode

  if (.not.open_file(fileobj, filename, mode, domain)) then
    call mpp_error(FATAL, "Failed to open netcdf file: " // filename)
  endif

  call register_axis(fileobj, "x", "x")
  call register_axis(fileobj, "y", "y")
  call register_axis(fileobj, "iter", unlimited)
end subroutine test_netcdf_file_open

subroutine write_netcdf_file
  integer, parameter :: seed = 0
  type(randomNumberStream) :: random_stream !> Random number stream
  integer :: iter

  real(KIND_), dimension(isc:iec, jsc:jec) :: rand

  random_stream = initializeRandomNumberStream(seed)

  call test_netcdf_file_open("write")

  if (product(chunksizes).ne.0) then
    call netcdf_add_variable(fileobj, "random", "double", dimensions=["x", "y", "iter"], &
                             chunksizes=chunksizes)
  else
    call netcdf_add_variable(fileobj, "random", "double", dimensions=["x", "y", "iter"])
  endif

  do iter=1,niter
    call getRandomNumbers(random_stream, rand)
    call write_data(fileobj, "random", rand, unlim_dim_level=iter)
  enddo

  call flush_file(fileobj)
  call close_file(fileobj)
end subroutine write_netcdf_file

subroutine read_netcdf_file
  integer :: iter
  real(KIND_), dimension(is:ie, js:je) :: rand

  call test_netcdf_file_open("read")

  do iter=1,niter
    call read_data(fileobj, "random", rand, unlim_dim_level=iter)
  enddo

  call close_file(fileobj)
end subroutine read_netcdf_file

subroutine report_memuse(suffix)
  character(*), intent(in) :: suffix
  integer :: unit
  real(r8_kind) :: memuse

  call mpp_mem_dump(memuse)

  open(newunit=unit, file="memuse." // suffix // "." // string(mpp_pe()), action="write", status="new")
  write(unit, "(f8.3)") memuse
  close(unit)
end subroutine report_memuse

end program test_netcdf_perf
