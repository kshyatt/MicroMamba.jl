module MicroMamba

if isdefined(Base, :Experimental) && isdefined(Base.Experimental, Symbol("@compiler_options"))
    # Note: compile=min makes --code-coverage not work
    @eval Base.Experimental.@compiler_options optimize=0 infer=false #compile=min
end

import CodecBzip2: Bzip2DecompressorStream
import Downloads: download
import Scratch: @get_scratch!
import Tar

mutable struct State
    install_dir::String
    root_dir::String
    available::Bool
    platform::String
    url::String
    executable::String
    version::VersionNumber
end

const STATE = State("", "", true, "", "", "", VersionNumber(0))

const DEFAULT_PLATFORM =
    Sys.ARCH == :x86_64 ?
        Sys.iswindows() ? "win-64" :
        Sys.islinux() ? "linux-64" :
        Sys.isapple() ? "osx-64" : "" :
    Sys.ARCH == :aarch64 ?
        Sys.islinux() ? "linux-aarch64" : "" :
    Sys.ARCH == :powerpc64le ?
        Sys.islinux() ? "linux-ppc64le" : "" : ""

function platform()
    if STATE.platform == ""
        if DEFAULT_PLATFORM == ""
            error("MicroMamba does not support your platform")
        else
            STATE.platform = DEFAULT_PLATFORM
        end
    end
    STATE.platform
end

const DEFAULT_URL = "https://micro.mamba.pm/api/micromamba/{platform}/{version}"

const MIN_VERSION = v"0.19.1"

function install_dir()
    if STATE.install_dir == ""
        STATE.install_dir = @get_scratch!("install")
    end
    return STATE.install_dir
end

function root_dir()
    get(ENV, "JULIA_MICROMAMBA_ROOT_PREFIX") do
        if STATE.root_dir == ""
            STATE.root_dir = @get_scratch!("root")
        end
        STATE.root_dir
    end
end

function url()
    if STATE.url == ""
        ver = get(ENV, "JULIA_MICROMAMBA_VERSION", "latest")
        url = get(ENV, "JULIA_MICROMAMBA_URL", DEFAULT_URL)
        url = replace(url, "{platform}" => _->platform()) # _->platform() to skip calling platform() (which might raise) when not needed
        url = replace(url, "{version}" => ver)
        STATE.url = url
    end
    STATE.url
end

function _log(io::IO, args...)
    printstyled(io, "  MicroMamba ", color=:light_green, bold=true)
    println(io, args...)
    flush(io)
end

"""
    executable()

Return the path to a MicroMamba executable.

Will download and install MicroMamba if required.

May throw an error, for example if your platform is not supported. See `available()`.
"""
function executable(; io::IO=stdout)
    if STATE.executable == ""
        # Set to true again below, unless any errors are thrown
        STATE.available = false
        # Find the MicroMamba executable
        fromenv = false
        if haskey(ENV, "JULIA_MICROMAMBA_EXECUTABLE")
            fromenv = true
            STATE.executable = ENV["JULIA_MICROMAMBA_EXECUTABLE"]
        else
            # Use version installed in the package dir
            exename = Sys.iswindows() ? "micromamba.exe" : "micromamba"
            exe = joinpath(install_dir(), exename)
            if _version(exe) < MIN_VERSION
                # If doesn't exist or too old, download and install
                mktempdir() do dir
                    file = joinpath(dir, "micromamba.tar.bz2")
                    _log(io, "Downloading: $(url())")
                    download(url(), file)
                    _log(io, "Installing: $exe")
                    odir = joinpath(dir, "micromamba")
                    open(file) do io
                        Tar.extract(Bzip2DecompressorStream(io), odir)
                    end
                    iexe = Sys.iswindows() ? joinpath(odir, "Library", "bin", exename) : joinpath(odir, "bin", exename)
                    mkpath(dirname(exe))
                    cp(iexe, exe, force=true)
                end
            end
            STATE.executable = exe
        end
        # Check the MicroMamba version
        STATE.version = _version(STATE.executable)
        if STATE.version == VersionNumber(0)
            # Zero means the version could not be determined
            error("$(STATE.executable) does not seem to be a MicroMamba executable")
        elseif STATE.version < MIN_VERSION
            # Too low, raise an error unless the user explicitly specified the executable or version
            if !fromenv && get(ENV, "JULIA_MICROMAMBA_VERSION", "latest") != string(STATE.version)
                error("MicroMamba at $(STATE.executable) is version $(STATE.version) which is older than the minimum supported version $(MIN_VERSION) of this package")
            end
        end
        STATE.available = true
        # Check if the an old MicroMamba directory is still there (~/.julia/micromamba)
        for depotdir in DEPOT_PATH
            olddir = joinpath(depotdir, "micromamba")
            isdir(olddir) && @warn "Old MicroMamba directory still exists, it can be deleted: $olddir"
        end
    end
    STATE.executable
end

function _version(exe)
    ans = VersionNumber(0)
    try
        for line in eachline(`$exe --version`)
            m = match(r"^micromamba: *([^ ]+)$", line)
            if m !== nothing
                ans = VersionNumber(m.captures[1])
            end
        end
    catch
    end
    ans
end

"""
    version()

The version of MicroMamba at `executable()`.

Will download and install MicroMamba if required.

May throw an error, for example if your platform is not supported. See `available()`.
"""
function version(; io::IO=stdout)
    executable(io=io)
    STATE.version
end

"""
    available()

Return `true` if MicroMamba is available.

If so, `executable()` and `version()` will not throw.

Will download and install MicroMamba if required.
"""
function available(; io::IO=stdout)
    if STATE.available && STATE.executable == ""
        try
            executable(io=io)
        catch
            STATE.available = false
        end
    end
    STATE.available
end

"""
    cmd([args])

Construct a command which calls MicroMamba, optionally with additional arguments.

By default, the root prefix is a folder in the Julia depot. It can be over-ridden with
the environment variable `JULIA_MICROMAMBA_ROOT_PREFIX`. To use the default root prefix
instead (e.g. as set by `~/.mambarc`) set this variable to the empty string.
"""
function cmd(; io::IO=stdout)
    ans = `$(executable(io=io))`
    root = root_dir()
    if root != ""
        ans = `$ans -r $root`
    end
    ans
end
cmd(args; io::IO=stdout) = `$(cmd(io=io)) $args`

end # module
