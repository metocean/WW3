# The WAVEWATCH III Framework

WAVEWATCH III<sup>&reg;</sup>  is a community wave modeling framework that includes the
latest scientific advancements in the field of wind-wave modeling and dynamics.

## Metocean Solutions Fork

This fork includes custom modifications and programs developed by Metocean Solutions
for operational ocean forecasting applications. See the
[Metocean Modifications](#metocean-modifications) section below for details.

## General Features

WAVEWATCH III<sup>&reg;</sup> solves the random phase spectral action density
balance equation for wavenumber-direction spectra. The model includes options
for shallow-water (surf zone) applications, as well as wetting and drying of
grid points. Propagation of a wave spectrum can be solved using regular
(rectilinear or curvilinear) and unstructured (triangular) grids. See
[About WW3](https://github.com/NOAA-EMC/WW3/wiki/About-WW3) for a
detailed description of WAVEWATCH III<sup>&reg;</sup>. For a web-based
view of the WAVEWATCH III<sup>&reg;</sup> source code
refer to the [WW3 doxygen documentation](https://noaa-emc.github.io/WW3).

## Installation

The WAVEWATCH III<sup>&reg;</sup>  framework package has two parts that need to be combined so
all runs smoothly: the GitHub repo itself, and a binary data file bundle that
needs to be obtained from our ftp site. Steps to successfully acquire and install
the framework are outlined in our [Quick Start](https://github.com/NOAA-EMC/WW3/wiki/Quick-Start)
guide.

## Disclaimer

The United States Department of Commerce (DOC) GitHub project code is provided
on an 'as is' basis and the user assumes responsibility for its use. DOC has
relinquished control of the information and no longer has responsibility to
protect the integrity, confidentiality, or availability of the information. Any
claims against the Department of Commerce stemming from the use of its GitHub
project will be governed by all applicable Federal law. Any reference to
specific commercial products, processes, or services by service mark,
trademark, manufacturer, or otherwise, does not constitute or imply their
endorsement, recommendation or favoring by the Department of Commerce. The
Department of Commerce seal and logo, or the seal and logo of a DOC bureau,
shall not be used in any manner to imply endorsement of any commercial product
or activity by DOC or the United States Government.

---

## Metocean Modifications

This fork includes the following Metocean Solutions-specific modifications:

### Custom Programs

Two additional programs have been integrated into the WW3 build system:

#### ww3_prnc_sea
NetCDF field preprocessor optimized for sea conditions and Spherical Multi-Cell (SMC) grids.
This program extends the standard `ww3_prnc` functionality with:
- Enhanced processing for SMC grid configurations
- Optimized handling of boundary conditions for regional ocean forecasting
- Integration with operational data pipelines

**Source**: `model/src/ww3_prnc_sea.f90`

**Build**: Automatically built when using the `switch_MOS_SMC_IC4` configuration

#### ww3_swanbnd
SWAN boundary conditions generator for nested model configurations.
This utility creates boundary condition files in SWAN format from WW3 output,
enabling one-way nesting of SWAN models within WW3 forecasting systems.

**Source**: `model/src/ww3_swanbnd.f`

**Build**: Automatically built with standard WW3 configurations

### Predefined Switch Configurations

Three operational configurations are provided as predefined switch files in `model/bin/`:

#### switch_MOS_SMC_IC4
SMC grid configuration with IC4 ice physics:
- Physics: `PR2 UNO SMC ST4` (Second-order propagation with SMC grid)
- Ice: `IC4` (Advanced ice physics)
- Use case: High-resolution coastal forecasting with ice

#### switch_MOS_ST4_IC4
Standard grid with ST4 physics and IC4 ice:
- Physics: `PR3 UQ ST4` (Third-order propagation)
- Ice: `IC4` (Advanced ice physics)
- Use case: Operational forecasting in ice-affected regions

#### switch_MOS_ST4
Standard grid with ST4 physics:
- Physics: `PR3 UQ ST4` (Third-order propagation)
- Ice: `IC0` (No ice physics)
- Use case: General operational wave forecasting

### Building with Metocean Configurations

```bash
# Setup WW3 with a Metocean configuration
cd model
./bin/w3_setup . -c intel -s MOS_ST4_IC4

# Build standard programs
./bin/w3_make ww3_grid ww3_strt ww3_prnc ww3_shel

# Build custom programs
./bin/w3_make ww3_prnc_sea    # For SMC configurations
./bin/w3_make ww3_swanbnd     # For SWAN nesting
```

### Spack Installation

This fork is designed to work seamlessly with Spack package management:

```bash
spack install ww3%intel@oneapi
```

The Spack package automatically builds all three configurations (SMC_IC4, ST4_IC4, ST4)
with appropriate compiler settings and dependencies.

### Modifications to Build System

The following files have been modified to support custom programs:

- **model/bin/make_makefile.sh**: Added `ww3_prnc_sea` and `ww3_swanbnd` to the
  standard program list, integrating them into WW3's dependency management and
  build infrastructure.

### Compatibility

These modifications are built on top of WW3 commit `3eb8161fdc999f4046fac7d77febff70c399c4f8`
and maintain full compatibility with upstream WAVEWATCH III functionality. All standard
WW3 programs and configurations continue to work as expected.

### Contributing

For issues or questions specific to Metocean modifications, please contact
Metocean Solutions. For general WW3 issues, refer to the upstream
[NOAA-EMC/WW3](https://github.com/NOAA-EMC/WW3) repository.
