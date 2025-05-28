{
    layout_64bit = $1;
    layout_io_64bit = $2;
    data_64bit = $3;

    layout_netcdf4 = $4;
    layout_io_netcdf4 = $5;
    data_netcdf4 = $6;

    assert(layout_64bit == layout_netcdf4 && layout_io_64bit == layout_io_netcdf4);

    pct_diff = 100.0 * (data_netcdf4 - data_64bit) / data_64bit;
    print layout_netcdf4, layout_io_netcdf4, pct_diff;
}
