-- Put functions in this file to use them in several other scripts.
-- To get access to the functions, you need to put:
-- require "my_directory.my_file"
-- in any script using the functions.
local M = {}

local DEFAULT_BRANCH_NAME = "_default"
local BRANCH_SPLIT_PATTERN = "&"
local OP_EQ = "eq" -- ==
local OP_NE = "ne" -- ~=
local OP_GT = "gt" -- >
local OP_GE = "ge" -- >=
local OP_LT = "lt" -- <
local OP_LE = "le" -- <=
local operators_lookup = {
    [OP_EQ] = function(a, b) return a == b end,
    [OP_NE] = function(a, b) return a ~= b end,
    [OP_GT] = function(a, b) return a > b end,
    [OP_GE] = function(a, b) return a >= b end,
    [OP_LT] = function(a, b) return a < b end,
    [OP_LE] = function(a, b) return a <= b end,
}

-- this doesn't work for lua 5.3, but does work for 5.1
local function csplit(str, sep)
    local ret = {}
    local n = 1
    for w in str:gmatch("([^" .. sep .. "]*)") do
        ret[n] = ret[n] or w -- only set once (so the blank after a string is ignored)
        if w == "" then
            n = n + 1
        end -- step forwards on a blank but not a string
    end
    return ret
end

function split(s, delimiter)
    result = {};
    for match in (s .. delimiter):gmatch("(.-)" .. delimiter) do
        table.insert(result, match);
    end
    return result;
end

local function get_op_and_var_str(branch_var)
    local split = split(branch_var, BRANCH_SPLIT_PATTERN)
    return operators_lookup[split[2]], split[1]
end

function M.branch_has_op(branch_var)
    return string.find(branch_var, BRANCH_SPLIT_PATTERN)
end

local function apply_op(op, numeric_var, branches)
    for branch_condition, next_node_id in pairs(branches) do
        if DEFAULT_BRANCH_NAME ~= branch_condition then
            local numeric_branch_condition = tonumber(branch_condition) --todo safe call this and warn if invalid
            if op(numeric_var, numeric_branch_condition) then
                return next_node_id
            end
        end
    end
end

function M.get_op_branch_next_id(branch_node, game_context)
    local op, variable = get_op_and_var_str(branch_node.variable)
    if not op then
        error("Unknown op for branch node:", branch_node)
        -- defer to the default branch if operator is unknown
    end
    if not game_context.is_numeric(variable) then
        error("Game state variable '" .. variable .. "' does not have a numeric value for branch " .. branch_node.id)
    end
    if op then
        -- TODO if the variable is not yet initialized then this fails
        local numeric_var = game_context.get_numeric(variable)
        return apply_op(op, numeric_var, branch_node.branches)
    end
end

return M