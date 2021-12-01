# MicroMamba.jl

A Julia interface to the [`MicroMamba`](https://mamba.readthedocs.io/en/latest/user_guide/micromamba.html) package manager.

## Installation

```
pkg> add https://github.com/cjdoris/MicroMamba.jl
```

## Usage

The API consists of the following three functions:
- `executable()` returns a path to a MicroMamba executable.
- `version()` returns the version of the above executable.
- `available()` returns true if MicroMamba is available on this system.

In all three cases, MicroMamba will be downloaded and installed (local to the package)
if required.

Note that `executable()` and `version()` can throw errors, such as if MicroMamba is not
supported on this platform. The `available()` function exists to check for this: if it
returns true, then the other functions will succeed.

## Environment variables

The following environment variables customise the behaviour of this package.
- `JULIA_MICROMAMBA_EXECUTABLE`: If set, it must be the path of a MicroMamba executable to
  use instead of downloading it. It becomes the return value of `executable()`.
- `JULIA_MICROMAMBA_URL`: The URL to download MicroMamba from if required.
  The following string replacements are made:
  - `{platform}` is replaced with the platform, such as `linux-64`.
  - `{version}` is replaced with the desired version, such as `latest` or `0.19.0`.
- `JULIA_MICROMAMBA_VERSION`: If MicroMamba needs to be downloaded, this specifies the version.