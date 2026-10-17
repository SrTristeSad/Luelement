local total = 0
local failed = 0

local function fail(message)
    error(message, 2)
end

function _G.test(name, fn)
    total = total + 1
    local ok, err = pcall(fn)
    if ok then
        print("[PASS] " .. name)
    else
        failed = failed + 1
        print("[FAIL] " .. name .. ": " .. tostring(err))
    end
end

function _G.assert_equal(actual, expected, message)
    if actual ~= expected then
        fail((message or "valores diferentes")
            .. " | esperado=" .. tostring(expected)
            .. " atual=" .. tostring(actual))
    end
end

function _G.assert_true(value, message)
    if value ~= true then
        fail(message or ("esperado true, atual=" .. tostring(value)))
    end
end

function _G.assert_contains(text, expected, message)\n    text = tostring(text or "")
    if not text:find(expected, 1, true) then
        fail((message or "texto não contém valor")
            .. " | esperado=" .. tostring(expected)
            .. " atual=" .. text)
    end
end

require("tests.url_spec")
require("tests.platform_spec")
require("tests.preflight_spec")
require("tests.rpc_bridge_spec")
require("tests.standalone_config_spec")
require("tests.elementum_client_spec")
require("tests.daemon_manager_spec")
require("tests.companion_spec")
require("tests.ui_spec")
require("tests.app_spec")

print(string.format("\n%d teste(s), %d falha(s)", total, failed))
if failed > 0 then
    error("testes falharam")
end
