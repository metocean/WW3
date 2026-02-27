# WW3 Spack Package - Metocean Solutions Customizations

## Overview

This Spack package builds WAVEWATCH III (WW3) from the NOAA repository with 
Metocean Solutions custom programs and operational configurations integrated 
directly into the source.

## Metocean Customizations

The WW3 build includes:

1. **Custom Programs** (integrated into WW3 build system):
   - `ww3_prnc_sea`: NetCDF field preprocessor for SMC grids
   - `ww3_swanbnd`: SWAN boundary conditions generator

2. **Predefined Switch Files** (in WW3 repo at `model/bin/`):
   - `switch_SMC_IC4`: SMC grid with IC4 ice physics (PR2 UNO SMC)
   - `switch_ST4_IC4`: Standard grid with ST4 and IC4 ice
   - `switch_ST4`: Standard grid with ST4 physics (base configuration)

3. **Custom Compiler Scripts** (in `model/bin/`):
   - `comp`, `link`, `ad3`: Intel oneAPI compiler configurations

All modifications are in the `/source/WW3/model/` directory.

## Approach

### Native Integration with Variants
- All custom modifications live in the WW3 source (in `/source/WW3/model/`)
- No patches needed in Spack package
- Switch files (`switch_ST4`, `switch_ST4_IC4`, `switch_SMC_IC4`) are predefined
- Configurations are selected via Spack variants
- Clean separation: build logic in Spack, source modifications in WW3

### Variant-Based Configuration Selection
Instead of building all configurations, users select which ones to build:
```bash
# Build only ST4 configuration (default)
spack install ww3

# Build specific configurations
spack install ww3 switch=ST4_IC4
spack install ww3 switch=SMC_IC4

# Build multiple configurations
spack install ww3 switch=ST4,ST4_IC4,SMC_IC4
```

## File Structure

```
playbooks/cascade/ww3/
├── spack_package.py              # Clean Spack package (no patches!)
└── README.md                     # This file
```

## How It Works

### 1. Setup Phase (`@run_after("edit")`)
- Runs `w3_setup` to initialize WW3 model directories

### 2. Edit Phase
- No operations needed - all customizations are in the source repo

### 3. Setup Build Environment
- Sets WW3 environment variables using Spack's `setup_build_environment()`:
  - `NETCDF_CONFIG`, `WWATCH3_NETCDF`, `NC_INC`, `NC_LIB`
  - Adds WW3 bin directory to PATH

### 4. Build Phase
For each selected configuration (via `config` variant):

a. **Clean and set up**: `w3_clean` and copy appropriate switch file

b. **Build SHRD programs**: Uses WW3's `w3_make` with native build system
   ```
   w3_make ww3_grid ww3_strt ww3_prnc ww3_bounc ww3_ounf ww3_ounp ww3_swanbnd
   ```
   For SMC_IC4 also builds: `ww3_prnc_sea`

c. **Build DIST/MPI programs**: Switch to `DIST MPI` and build `ww3_shel`

d. **Install**: Copy executables to `<prefix>/bin/<config_name>/`

## Installation

```bash
# Install with default configuration (ST4)
spack install ww3

# Install with specific compiler and configuration
spack install ww3%intel switch=ST4_IC4
spack install ww3%gcc switch=SMC_IC4

# Install multiple configurations
spack install ww3 switch=ST4,ST4_IC4,SMC_IC4

# Install with specific MPI
spack install ww3+mpi ^mpich switch=ST4_IC4
```

## Output Structure

```
<spack-install-prefix>/
└── bin/
    ├── SMC_IC4/
    │   ├── ww3_grid
    │   ├── ww3_strt
    │   ├── ww3_prnc
    │   ├── ww3_prnc_sea    # SMC-specific
    │   ├── ww3_bounc
    │   ├── ww3_ounf
    │   ├── ww3_ounp
    │   ├── ww3_swanbnd
    │   └── ww3_shel
    ├── ST4_IC4/
    │   └── ... (similar)
    └── ST4/
        └── ... (similar)
```
