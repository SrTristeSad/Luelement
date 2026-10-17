local RpcBridge = {}
RpcBridge.__index = RpcBridge

local unpack_args = table.unpack or unpack

local function args_list(value)
    if type(value) == "table" then
        return value
    end
    return {}
end

function RpcBridge.new(host, config)
    return setmetatable({
        host = host,
        config = config,
        server = nil,
        objects = {},
        properties = {},
        sequence = 0,
    }, RpcBridge)
end

function RpcBridge:next_id(prefix)
    self.sequence = self.sequence + 1
    return string.format("%s-%d", prefix or "obj", self.sequence)
end

function RpcBridge:localize(value)
    -- Nesta primeira implementação o Luelement não carrega o catálogo de
    -- strings do Kodi. O frontend poderá traduzir LOCALIZE[...] depois.
    return tostring(value or "")
end

function RpcBridge:dispatch(method, params)
    params = args_list(params)

    local handlers = {
        Ping = function()
            return true
        end,
        Reset = function()
            self.objects = {}
            return ""
        end,
        Refresh = function()
            self.host:ui_refresh()
            return ""
        end,
        Update = function(_, url)
            self.host:ui_update(url)
            return ""
        end,
        InstallAddon = function()
            return ""
        end,
        UpdateLocalAddons = function()
            return ""
        end,
        UpdateAddonRepos = function()
            return ""
        end,
        SystemInformation = function()
            local p = self.host:platform()
            return string.format("Luelement %s (%s/%s)", self.config.version, p.os, p.arch)
        end,
        Notify = function(_, header, message)
            self.host:notify(self:localize(header), self:localize(message))
            return ""
        end,
        Keyboard = function(_, default_value, heading, hidden)
            return self.host:keyboard(default_value or "", self:localize(heading), hidden == true) or ""
        end,
        Translate = function(_, text)
            return self:localize(text)
        end,
        TranslateText = function(_, text)
            return self:localize(text)
        end,
        Dialog = function(_, title, message)
            self.host:dialog_ok(self:localize(title), self:localize(message))
            return 1
        end,
        Dialog_Browse_Single = function(_, browse_type, heading)
            local _ = browse_type
            return self.host:file_picker(self:localize(heading)) or ""
        end,
        Dialog_Confirm = function(_, title, message)
            return self.host:dialog_confirm(self:localize(title), self:localize(message)) and 1 or 0
        end,
        Dialog_Confirm_With_Timeout = function(_, title, message)
            return self.host:dialog_confirm(self:localize(title), self:localize(message)) and 1 or 0
        end,
        Dialog_Select = function(_, title, items)
            return self.host:dialog_select(self:localize(title), items or {})
        end,
        Dialog_Select_With_Options = function(_, title, items, autoclose, preselect)
            local _ = autoclose
            return self.host:dialog_select(self:localize(title), items or {}, preselect)
        end,
        Dialog_Select_Large = function(_, title, subject, items)
            return self.host:dialog_select(
                self:localize(title) .. " " .. tostring(subject or ""),
                items or {}
            )
        end,
        Dialog_Text = function(_, title, text)
            self.host:dialog_ok(self:localize(title), self:localize(text))
            return 1
        end,
        Window_Is_Loading = function()
            return 0
        end,
        Wait_Window_Loaded = function()
            return 1
        end,
        OpenDirectory = function(_, path)
            self.host:ui_update(path)
            return ""
        end,
        Playlist_Left = function()
            return 0
        end,
        Playlist_Size = function()
            return 0
        end,
        Playlist_Add = function()
            return ""
        end,
        Playlist_Clear = function()
            return ""
        end,
        Player_Open = function(_, item)
            self.host:player_play(item)
            return ""
        end,
        Player_Open_With_Labels = function()
            return ""
        end,
        Player_Open_With_Timeout = function(_, item)
            self.host:player_play(item)
            return ""
        end,
        Player_GetPlayingFile = function()
            return self.host:player_file()
        end,
        Player_IsPlaying = function()
            return self.host:player_is_playing() and 1 or 0
        end,
        Player_IsPaused = function()
            return self.host:player_is_paused() and 1 or 0
        end,
        Player_WatchTimes = function()
            return self.host:player_watch_times()
        end,
        Player_Seek = function(_, position)
            self.host:player_seek(position or 0)
            return ""
        end,
        Player_GetSubtitles = function()
            return self.host:player_subtitles()
        end,
        Player_SetSubtitles = function(_, urls)
            self.host:player_set_subtitles(urls or {})
            return true
        end,
        ConvertLanguage = function(_, language)
            return tostring(language or "")
        end,
        GetPlatform = function()
            local platform = self.host:platform()
            return {
                os = platform.os,
                arch = platform.arch,
                kodi = 20,
                version = "Luelement",
            }
        end,
        GetAddonInfo = function()
            return {
                author = "SrTristeSad",
                description = "Luelement",
                disclaimer = "",
                fanart = "",
                icon = "",
                id = self.config.id,
                name = self.config.name,
                profile = self.host:data_path(""),
                stars = "",
                summary = "Luelement",
                type = "plugin",
                version = self.config.version,
                path = self.host:plugin_path(""),
                home = self.host:data_path(""),
                xbmc = "",
            }
        end,
        AddonFailure = function()
            return 0
        end,
        AddonCheck = function()
            return 0
        end,
        AddonSettings = function()
            return ""
        end,
        AddonSettingsOpened = function()
            return 0
        end,
        GetLanguage = function()
            return self.host:locale().language
        end,
        GetLocalizedString = function(_, id)
            return tostring(id or "")
        end,
        GetSetting = function()
            return ""
        end,
        GetAllSettings = function()
            return {}
        end,
        SetSetting = function()
            return true
        end,
        GetWindowProperty = function(_, key)
            return self.properties[tostring(key)] or ""
        end,
        SetWindowProperty = function(_, key, value)
            self.properties[tostring(key)] = value or ""
            return ""
        end,
        GetCurrentView = function()
            return ""
        end,
        TranslatePath = function(_, path)
            return tostring(path or "")
        end,
        Log = function(_, message)
            self.host:log("debug", tostring(message or ""))
            return ""
        end,
        Dialog_CloseAll = function()
            return 1
        end,
        Dialog_CloseAllConfirms = function()
            return 1
        end,
        DialogInsert = function()
            return { type = "cancelled", path = "" }
        end,
        DialogProgress_Create = function(_, ...)
            local id = self:next_id("progress")
            self.objects[id] = self.host:progress_create(...)
            return id
        end,
        DialogProgress_IsCanceled = function(_, id)
            return self.host:progress_is_cancelled(self.objects[id]) and 1 or 0
        end,
        DialogProgress_Update = function(_, id, percent, ...)
            self.host:progress_update(self.objects[id], percent or 0, ...)
            return 0
        end,
        DialogProgress_Close = function(_, id)
            self.host:progress_close(self.objects[id])
            self.objects[id] = nil
            return 0
        end,
        DialogProgressBG_Create = function(_, ...)
            local id = self:next_id("progress-bg")
            self.objects[id] = self.host:progress_create(...)
            return id
        end,
        DialogProgressBG_IsFinished = function()
            return 0
        end,
        DialogProgressBG_Update = function(_, id, percent, ...)
            self.host:progress_update(self.objects[id], percent or 0, ...)
            return 0
        end,
        DialogProgressBG_Close = function(_, id)
            self.host:progress_close(self.objects[id])
            self.objects[id] = nil
            return 0
        end,
        DialogProgressBG_Cleanup = function()
            for id, object in pairs(self.objects) do
                if tostring(id):match("^progress") then
                    self.host:progress_close(object)
                    self.objects[id] = nil
                end
            end
            return 0
        end,
        OverlayStatus_Create = function()
            local id = self:next_id("overlay")
            self.objects[id] = true
            return id
        end,
        OverlayStatus_Update = function()
            return 0
        end,
        OverlayStatus_Show = function()
            return 0
        end,
        OverlayStatus_Hide = function()
            return 0
        end,
        OverlayStatus_Close = function(_, id)
            self.objects[id] = nil
            return 0
        end,
        UpNext_Notify = function()
            return true
        end,
        ToggleWatched = function()
            return ""
        end,
        GetKodiLog = function()
            return ""
        end,
    }

    local handler = handlers[method]
    if not handler then
        error("método RPC Elementum ainda não implementado: " .. tostring(method))
    end

    local result = handler(self, unpack_args(params))
    if result == nil then
        return true
    end
    return result
end

function RpcBridge:handle_message(text)
    local ok, request = pcall(function()
        return self.host:decode_json(text)
    end)

    if not ok or type(request) ~= "table" then
        return self.host:encode_json({
            jsonrpc = "2.0",
            id = 0,
            error = "invalid JSON-RPC request",
        })
    end

    local success, result = pcall(function()
        return self:dispatch(request.method, request.params)
    end)

    if success then
        return self.host:encode_json({
            jsonrpc = "2.0",
            id = request.id or 0,
            result = result,
        })
    end

    self.host:log("warning", "RPC " .. tostring(request.method) .. " falhou: " .. tostring(result))
    return self.host:encode_json({
        jsonrpc = "2.0",
        id = request.id or 0,
        error = tostring(result),
    })
end

function RpcBridge:start()
    if self.server then
        return self.server
    end

    local rpc = self.config.rpc
    self.server = self.host:start_line_server({
        host = rpc.host,
        port = rpc.port,
        on_message = function(line)
            return self:handle_message(line)
        end,
    })

    self.host:log("info", string.format(
        "Ponte RPC Elementum ouvindo em %s:%d",
        rpc.host,
        rpc.port
    ))
    return self.server
end

function RpcBridge:stop()
    if not self.server then
        return true
    end
    self.host:stop_server(self.server)
    self.server = nil
    return true
end

return RpcBridge
