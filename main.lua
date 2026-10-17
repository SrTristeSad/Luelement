local Host = require("src.addko_host")
local App = require("src.app")

local api = rawget(_G, "addko")
local host = Host.new(api)
local app = App.new(host)

local Plugin = {}

function Plugin.start()
    return app:start()
end

function Plugin.route(name, params)
    return app:route(name, params)
end

function Plugin.stop()
    return app:stop()
end

return Plugin
