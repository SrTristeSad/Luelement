local Platform = require("src.platform")
local StandaloneConfig = require("src.standalone_config")

local DaemonManager = {}
DaemonManager.__index = DaemonManager

local function join(...)
    local parts = { ... }
    local out = {}
    for _, value in ipairs(parts) do
        local part = tostring(value or "")
        part = part:gsub("\\", "/")
        part = part:gsub("^/+", "")
        part = part:gsub("/+$", "")
        if part ~= "" then
            table.insert(out, part)
        end
    end
    return table.concat(out, "/")
end

local function dirname(path)
    local normalized = tostring(path or ""):gsub("\\", "/")
    return normalized:match("^(.*)/[^/]+$") or "."
end

function DaemonManager.new(host, client, config)
    return setmetatable({
        host = host,
        client = client,
        config = config,
        handle = nil,
        owned = false,
        runtime = nil,
    }, DaemonManager)
end

function DaemonManager:is_ready()
    local ok, value = pcall(function()
        return self.client:status()
    end)
    return ok, value
end

function DaemonManager:build_paths(platform)
    local version = assert(self.config.daemon.engine_version)
    local root = self.host:data_path(join("elementum", version))
    local engine_dir = self.host:data_path(join("elementum", version, platform.target))

    return {
        root = root,
        plugin = self.host:plugin_path(""),
        engine_dir = engine_dir,
        executable = self.host:data_path(join(
            "elementum",
            version,
            platform.target,
            platform.executable
        )),
        packaged_executable = self.host:plugin_path(join(
            "native",
            platform.target,
            platform.executable
        )),
        profile = self.host:data_path(join("elementum", version, "profile")),
        temp = self.host:data_path(join("elementum", version, "temp")),
        torrents = self.host:data_path(join("elementum", version, "torrents")),
        library = self.host:data_path(join("elementum", version, "library")),
        downloads = self.host:data_path(join("elementum", version, "downloads")),
        config = self.host:data_path(join("elementum", version, "elementum-config.json")),
        log = self.host:data_path(join("elementum", version, "elementum.log")),
    }
end

function DaemonManager:ensure_directories(paths)
    local directories = {
        paths.root,
        paths.engine_dir,
        paths.profile,
        paths.temp,
        paths.torrents,
        paths.library,
        paths.downloads,
        dirname(paths.config),
        dirname(paths.log),
    }

    for _, path in ipairs(directories) do
        self.host:mkdirp(path)
    end
end

function DaemonManager:ensure_binary(platform, paths)
    if self.host:file_exists(paths.packaged_executable) then
        self.host:log("info", "Usando binário Elementum empacotado: " .. paths.packaged_executable)
        return paths.packaged_executable
    end

    if self.host:file_exists(paths.executable) then
        self.host:log("info", "Usando binário Elementum em cache: " .. paths.executable)
        return paths.executable
    end

    if self.config.daemon.auto_download ~= true then
        error("binário Elementum não encontrado e download automático está desativado")
    end

    local url = Platform.binary_url(self.config, platform)
    self.host:log("info", "Baixando Elementum " .. self.config.daemon.engine_version .. " para " .. platform.target)
    self.host:download_file(url, paths.executable)

    if not self.host:file_exists(paths.executable) then
        error("download do binário Elementum terminou sem criar o arquivo esperado")
    end

    if platform.os ~= "windows" then
        self.host:set_executable(paths.executable)
    end

    return paths.executable
end

function DaemonManager:write_config(platform, paths)
    local bundle = StandaloneConfig.build(
        self.config,
        platform,
        paths,
        self.host:locale()
    )
    self.host:write_text(paths.config, self.host:encode_json(bundle))
    return paths.config
end

function DaemonManager:spawn(binary, paths)
    local args = {
        "-configPath=" .. paths.config,
        "-addonPath=" .. paths.plugin,
        "-profilePath=" .. paths.profile,
        "-tempPath=" .. paths.temp,
        "-torrentsPath=" .. paths.torrents,
        "-libraryPath=" .. paths.library,
        "-downloadsPath=" .. paths.downloads,
        "-logPath=" .. paths.log,
        "-localHost=" .. self.config.elementum.host,
        "-localPort=" .. tostring(self.config.elementum.port),
        "-remoteHost=" .. self.config.rpc.host,
        "-remotePort=" .. tostring(self.config.rpc.port),
        "-disableParentProcessWatcher",
        "-disableLibrarySync",
    }

    self.host:log("info", "Iniciando daemon Elementum standalone com ponte RPC Lua")
    self.handle = self.host:spawn_process({
        path = binary,
        args = args,
        cwd = dirname(binary),
        env = {},
        hidden = true,
    })
    self.owned = true
end

function DaemonManager:wait_until_ready()
    local poll_ms = self.config.daemon.startup_poll_ms or 250
    local timeout_seconds = self.config.elementum.startup_timeout_seconds or 20
    local attempts = math.max(1, math.floor((timeout_seconds * 1000) / poll_ms))

    for _ = 1, attempts do
        local ok, status = self:is_ready()
        if ok then
            return status
        end
        self.host:sleep(poll_ms)
    end

    error(string.format(
        "Elementum não respondeu em %ss. Consulte o log do daemon.",
        tostring(timeout_seconds)
    ))
end

function DaemonManager:start()
    local ready, status = self:is_ready()
    if ready then
        self.host:log("info", "Elementum já está disponível em " .. self.client.base_url)
        return {
            already_running = true,
            owned = false,
            status = status,
        }
    end

    if self.config.daemon.auto_start ~= true then
        error("Elementum está offline e daemon.auto_start está desativado")
    end

    local platform = Platform.normalize(self.host:platform())
    local paths = self:build_paths(platform)
    self:ensure_directories(paths)
    local binary = self:ensure_binary(platform, paths)
    self:write_config(platform, paths)

    self.runtime = {
        platform = platform,
        paths = paths,
        binary = binary,
    }

    local ok, result = pcall(function()
        self:spawn(binary, paths)
        return self:wait_until_ready()
    end)

    if not ok then
        if self.handle then
            pcall(function()
                self.host:stop_process(self.handle)
            end)
        end
        self.handle = nil
        self.owned = false
        error(result)
    end

    return {
        already_running = false,
        owned = true,
        status = result,
        platform = platform.target,
        log = paths.log,
        rpc = string.format("%s:%d", self.config.rpc.host, self.config.rpc.port),
    }
end

function DaemonManager:stop()
    if not self.owned then
        return {
            stopped = false,
            reason = "daemon_not_owned",
        }
    end

    pcall(function()
        self.client:shutdown()
    end)

    local poll_ms = 250
    local timeout_seconds = self.config.daemon.shutdown_timeout_seconds or 5
    local attempts = math.max(1, math.floor((timeout_seconds * 1000) / poll_ms))

    for _ = 1, attempts do
        local ready = self:is_ready()
        if not ready then
            self.handle = nil
            self.owned = false
            return { stopped = true, forced = false }
        end
        self.host:sleep(poll_ms)
    end

    if self.handle then
        pcall(function()
            self.host:stop_process(self.handle)
        end)
    end

    self.handle = nil
    self.owned = false
    return { stopped = true, forced = true }
end

function DaemonManager:diagnostics()
    local platform = Platform.normalize(self.host:platform())
    local paths = self:build_paths(platform)
    local ready, status = self:is_ready()

    return {
        ready = ready,
        status = status,
        owned = self.owned,
        platform = platform,
        paths = paths,
        rpc = self.config.rpc,
        binary_url = Platform.binary_url(self.config, platform),
    }
end

return DaemonManager
