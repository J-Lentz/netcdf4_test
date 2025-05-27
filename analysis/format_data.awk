BEGIN {
    FS=",";
    OFS="\t";
    BASEDIR="data/";
}

{
	test_id = $1;
	nx = $2;
	ny = $3;
	layout_x = $4;
	layout_y = $5;
	layout_io_x = $6;
	layout_io_y = $7;
	netcdf_format = $8;
	chunk_size_x = $9;
	chunk_size_y = $10;
	chunk_size_z = $11;
	deflate_level = $12;
	shuffle = $13;
	use_collective = $14;
	file_size = $15;
	write_time = $16;
	read_time = $17;
	write_mem = $18;
	read_mem = $19;

        # 64bit baseline
	if (netcdf_format == "64bit") {
            print layout_x, layout_io_x, 1000*write_time >> (BASEDIR "64bit/" nx ".write_time")
            print layout_x, layout_io_x, 1000*read_time  >> (BASEDIR "64bit/" nx ".read_time")
	}

        # netcdf4 with all features disabled
	if (netcdf_format == "netcdf4" && chunk_size_x*chunk_size_y*chunk_size_z == 0 && deflate_level==0 && shuffle=="false" && use_collective=="false") {
            print layout_x, layout_io_x, 1000*write_time >> (BASEDIR "netcdf4_baseline/" nx ".write_time")
            print layout_x, layout_io_x, 1000*read_time  >> (BASEDIR "netcdf4_baseline/" nx ".read_time")
	}

        # netcdf4 with chunking (no deflate level, no shuffle)
	if (netcdf_format == "netcdf4" && chunk_size_x*layout_io_x==nx && chunk_size_y*layout_io_y==ny && chunk_size_z==1 && deflate_level==0 && shuffle=="false" && use_collective=="false") {
            print layout_x, layout_io_x, 1000*write_time >> (BASEDIR "netcdf4_chunk/" nx ".write_time")
            print layout_x, layout_io_x, 1000*read_time  >> (BASEDIR "netcdf4_chunk/" nx ".read_time")
	}

        # netcdf4 with deflate level
	if (netcdf_format == "netcdf4" && chunk_size_x*chunk_size_y*chunk_size_z == 0 && shuffle=="false" && use_collective=="false") {
            print deflate_level, 1000*write_time >> (BASEDIR "netcdf4_deflate/" nx "." layout_x "." layout_io_x ".write_time")
            print deflate_level, 1000*read_time  >> (BASEDIR "netcdf4_deflate/" nx "." layout_x "." layout_io_x ".read_time")
	}

        # netcdf4 collective reads (no chunking; no deflate level; no shuffle)
	if (netcdf_format == "netcdf4" && chunk_size_x*chunk_size_y*chunk_size_z == 0 && deflate_level==0 && shuffle=="false" && use_collective=="true") {
            print layout_x, layout_io_x, 1000*read_time  >> (BASEDIR "collective_read/" nx ".read_time")
	}
}
