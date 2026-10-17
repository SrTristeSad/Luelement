local RpcBridge = require("src.rpc_bridge")

local fake = {
    platform = function()
        return { os = "windows", arch = "amd64" }
    end,
    ui_refresh = function() end,
    ui_update = function() end,
    notify = function() end,
    keyboard = function(_, value)
        return value
    end,
    dialog_ok = function() return true end,
    dialog_confirm = function() return true end,
    dialog_select = function() return 2 end,
    file_picker = function() return "C:/teste.torrent" end,
    player_play = function() return true end,
    player_file = function() return "http://127.0.0.1/video" end,
    player_is_playing = function() return true end,
    player_is_paused = function() return false end,
    player_watch_times = function()
        return { watchedTime = "12", videoDuration = "120", error = "" }
    end,
    player_seek = function() end,
    player_subtitles = function() return {} end,
    player_set_subtitles = function() end,
    data_path = function(_, path) return "data/" .. (path or "") end,
    plugin_path = function(_, path) return "plugin/" .. (path or "") end,
    locale = function() return { language = "pt", region = "BR" } end,
    log = function() end,
    progress_create = function() return { cancelled = false } end,
    progress_is_cancelled = function(_, h) return h.cancelled == true end,
    progress_update = function() end,
    progress_close = function() end,
}

local bridge = RpcBridge.new(fake, {
    id = "io.addko.luelement",
    name = "Luelement",
    version = "test",
    rpc = { host = "127.0.0.1", port = 65221 },
})

test("rpc Ping responde booleano", function()
    assert_equal(bridge:dispatch("Ping", {}), true)
end)

test("rpc Player_IsPlaying responde inteiro esperado pelo Go", function()
    assert_equal(bridge:dispatch("Player_IsPlaying", {}), 1)
    assert_equal(bridge:dispatch("Player_IsPaused", {}), 0)
end)

test("rpc Dialog_Select encaminha índice", function()
    assert_equal(bridge:dispatch("Dialog_Select", { "Arquivo", { "a", "b", "c" } }), 2)
end)

test("rpc progress mantém handle entre chamadas", function()
    local id = bridge:dispatch("DialogProgress_Create", { "Elementum", "", "", "" })
    assert_true(type(id) == "string")
    assert_equal(bridge:dispatch("DialogProgress_IsCanceled", { id }), 0)
    assert_equal(bridge:dispatch("DialogProgress_Update", { id, 50, "Buffer" }), 0)
    assert_equal(bridge:dispatch("DialogProgress_Close", { id }), 0)
end)

test("rpc window properties preservam valor", function()
    assert_equal(bridge:dispatch("SetWindowProperty", { "foo", "bar" }), "")
    assert_equal(bridge:dispatch("GetWindowProperty", { "foo" }), "bar")
end)
