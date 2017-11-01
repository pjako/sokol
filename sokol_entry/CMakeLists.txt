fips_begin_lib(sokol_entry)
    fips_files(sokol_entry.h _sokol_entry.osx.impl.m)
    fips_frameworks_osx(Cocoa Metal MetalKit QuartzCore)
fips_end_lib()