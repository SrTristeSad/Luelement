local Platform = {}

local OS_ALIASES = {
    win = "windows",
    win32 = "windows",
    windows = "windows",
    linux = "linux",
    android = "android",
    mac = "macos",
    macos = "macos",
    osx = "macos",
    darwin = "macos",
}

local ARCH_ALIASES = {
    amd64 = "x64",
    x86_64 = "x64",
    x64 = "x64",
    i386 = "x86",
    i686 = "x86",
    x86 = "x86",
    aarch64 = "arm64",
    arm64 = "arm64",
    armv8 = "arm64",
    armv7 = "armv7",
    armv7l = "armv7",
    arm = "armv7",
    armv6 = "armv6",
    armv6l = "armv6",
}

local SUPPORTED = {
    windows_x64 = true,
    windows_x86 = true,
    linux_x64 = true,
    linux_x86 = true,
    linux_arm64 = true,
    linux_armv7 = true,
    linux_armv6 = true,
    android_x64 = true,
    android_x86 = true,
    android_arm64 = true,
    android_arm = true,
    darwin_x64 = true,
}

function Platform.normalize(raw)
    raw = raw or {}

    local os_name = OS_ALIASES[string.lower(tostring(raw.os or ""))]
    local arch = ARCH_ALIASES[string.lower(tostring(raw.arch or ""))]

    if not os_name then
        error("sistema operacional não suportado pelo Luelement: " .. tostring(raw.os))
    end
    if not arch then
        error("arquitetura não suportada pelo Luelement: " .. tostring(raw.arch))
    end

    local engine_os = os_name == "macos" and "darwin" or os_name
    local engine_arch = arch

    -- O repositório do Elementum usa android_arm para ARMv7.
    if os_name == "android" and arch == "armv7" then
        engine_arch = "arm"
    end

    local target = engine_os .. "_" .. engine_arch
    if not SUPPORTED[target] then
        error(string.format(
            "plataforma Elementum ainda não suportada: %s (%s/%s)",
            target,
            os_name,
            arch
        ))
    end

    return {
        os = os_name,
        arch = arch,
        engine_os = engine_os,
        engine_arch = engine_arch,
        target = target,
        executable = os_name == "windows" and "elementum.exe" or "elementum",
    }
end

function Platform.binary_url(config, platform)
    local daemon = assert(config.daemon, "config.daemon ausente")
    local base = assert(daemon.binary_base_url, "daemon.binary_base_url ausente")
    local commit = assert(daemon.binary_commit, "daemon.binary_commit ausente")

    return string.format(
        "%s/%s/%s/%s",
        base:gsub("/$", ""),
        commit,
        platform.target,
        platform.executable
    )
end

return Platform
