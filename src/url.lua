local M = {}

local function is_unreserved(byte)
    return (byte >= 48 and byte <= 57)
        or (byte >= 65 and byte <= 90)
        or (byte >= 97 and byte <= 122)
        or byte == 45
        or byte == 46
        or byte == 95
        or byte == 126
end

function M.encode(value)
    value = tostring(value or "")
    return (value:gsub(".", function(char)
        local byte = string.byte(char)
        if is_unreserved(byte) then
            return char
        end
        return string.format("%%%02X", byte)
    end))
end

function M.query(params)
    if not params then
        return ""
    end

    local keys = {}
    for key, value in pairs(params) do
        if value ~= nil then
            keys[#keys + 1] = key
        end
    end
    table.sort(keys)

    local parts = {}
    for _, key in ipairs(keys) do
        parts[#parts + 1] = M.encode(key) .. "=" .. M.encode(params[key])
    end

    if #parts == 0 then
        return ""
    end
    return "?" .. table.concat(parts, "&")
end

return M
