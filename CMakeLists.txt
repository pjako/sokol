#
# project: sokol-samples
#
cmake_minimum_required(VERSION 2.8)

# include the fips main cmake file
get_filename_component(FIPS_ROOT_DIR "../fips" ABSOLUTE)
include("${FIPS_ROOT_DIR}/cmake/fips.cmake")

fips_setup(PROJECT sokol)
fips_ide_group("Imports")
fips_ide_group("")

# just suppress this pesky "missing field initializer warning" for now
if (FIPS_CLANG OR FIPS_GCC)
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wno-missing-field-initializers")
endif()

add_subdirectory(sokol_entry)