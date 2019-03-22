local M = {}
M.__index = M

local function lower(name)
    return string.lower(name)
end

function M:get(name)
    return self.variables[lower(name)]
end

function M:get_numeric(name)
    return tonumber(self:get(name))
end

function M:is_numeric(name)
    return pcall(function()
        return self:get_numeric(name)
    end)
end

function M:set(name, value)
    self.variables[lower(name)] = tostring(value)
end

function M:get_all()
    local out = {}
    for k, v in pairs(self.variables) do
        out[k] = v
    end
    return out
end

function M:clear()
    self.variables = {}
end

M.__call = function()
    local out = { variables = {} }
    setmetatable(out, M)
    return out
end

local VariableState = {}
setmetatable(VariableState, M)
return VariableState