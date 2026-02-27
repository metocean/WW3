# WW3 Native Build System Integration

## Summary

Integrated `ww3_prnc_sea` and `ww3_swanbnd` into WW3's native build system so they can be built with `w3_make` instead of manual `ifx` compiler calls. Also updated compiler configuration for Intel oneAPI compatibility.

## Changes Made

### 1. [model/bin/cmplr.env](file:///source/WW3/model/bin/cmplr.env)

**Intel oneAPI Compiler Support:** Updated `comp_seq` from `ifort` to `ifx` in:
- **Line 56:** MPT compiler section - `comp_seq='ifx'`
- **Line 135:** Intel compiler section - `comp_seq='ifx'`
- **Line 145:** Cheyenne-specific configuration - `comp_seq='ifx'`

This ensures compatibility with Intel oneAPI compilers, which use `ifx` (Intel Fortran Compiler) instead of the legacy `ifort`.

### 2. [model/bin/make_makefile.sh](file:///source/WW3/model/bin/make_makefile.sh)

**Line 117:** Added custom programs to the build list
```bash
progs="$progs ww3_prnc_sea ww3_swanbnd"
```

**Lines 139-140:** Added program descriptions
```bash
ww3_prnc_sea) IDstring='NetCDF field preprocessor for SMC grids' ;;
ww3_swanbnd) IDstring='SWAN boundary conditions generator' ;;
```

### 3. [model/bin/build_utils.sh](file:///source/WW3/model/bin/build_utils.sh)

**Lines 1019-1030:** Added dependency definitions for standalone programs
```bash
ww3_prnc_sea)
    core=
    data=
    prop=
    sourcet=
    IO=
    aux= ;;
ww3_swanbnd)
    core=
    data=
    prop=
    sourcet=
    IO=
    aux= ;;
```

These empty dependency lists indicate standalone programs with no WW3 module dependencies.

### 4. [model/bin/link](file:///source/WW3/model/bin/link)

**Lines 122-125:** Added curl library for ww3_prnc_sea
```bash
# curl library for ww3_prnc_sea
if [ "$prog" = 'ww3_prnc_sea' ] ; then
  libs="$libs -lcurl"
fi
```

## How It Works

### Before (Manual Compilation)
```bash
# ww3_prnc_sea
ifx -c $NC_INC -O3 -g -traceback -assume byterecl ../src/ww3_prnc_sea.f90
ifx -lcurl -o ../exe/ww3_prnc_sea ww3_prnc_sea.o $NC_LIB

# ww3_swanbnd  
ifx -O3 -assume byterecl ../src/ww3_swanbnd.f -o ../exe/ww3_swanbnd
```

### After (WW3 Native Build)
```bash
w3_make ww3_prnc_sea ww3_swanbnd
```

The WW3 build system now:
1. Recognizes these programs in the program list
2. Compiles them using the standard `comp` script (which has correct NetCDF flags)
3. Links them using the `link` script (which now includes curl for ww3_prnc_sea)
4. Places executables in `model/exe/` directory

## Benefits

- ✅ **No manual ifx calls needed** in Spack package or Ansible playbooks
- ✅ **Consistent build process** - uses same compiler wrappers as other WW3 programs
- ✅ **Proper dependency handling** - WW3's build system manages compilation order
- ✅ **Compiler flexibility** - respects compiler selection through WW3's build system
- ✅ **Cleaner maintenance** - all build logic in WW3's native scripts

## Spack Package Impact

The [spack_package.py](file:///source/ansible-hpc-software/playbooks/cascade/ww3/spack_package.py) already references these programs:

```python
progs_shrd = [
    "ww3_grid", "ww3_strt", "ww3_prnc", "ww3_bounc", 
    "ww3_ounf", "ww3_ounp", "ww3_swanbnd"  # ✅ Now builds via w3_make
]

progs_smc = ["ww3_prnc_sea"]  # ✅ Now builds via w3_make
```

No changes needed to the Spack package - it already uses `w3_make`, which now handles these programs correctly.

## Testing

To verify the integration works:

```bash
cd /source/WW3/model/bin

# Setup WW3 (creates wwatch3.env)
./w3_setup model -c intel -q

# Copy a switch file
cp switch_ST4 switch

# Build the programs
./w3_make ww3_swanbnd
./w3_make ww3_prnc_sea

# Check executables were created
ls -l ../exe/ww3_swanbnd ../exe/ww3_prnc_sea
```

## File Locations

Source files are integrated into WW3:
- [model/src/ww3_prnc_sea.f90](file:///source/WW3/model/src/ww3_prnc_sea.f90) - 897 lines, NetCDF preprocessor
- [model/src/ww3_swanbnd.f](file:///source/WW3/model/src/ww3_swanbnd.f) - 203 lines, SWAN boundary generator
