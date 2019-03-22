-- Read and step through dialogue trees created from Dialogger tool.
-- http://stewart.bracken.bz/storage/Dialogger/
local DialogueOp = require "dialogue_op_def"
local VarState = require "variablestate"

local M = {}

M.TNODE_TEXT = "Text"
M.TNODE_NODE = "Node"
M.TNODE_CHOICE = "Choice"
M.TNODE_SET = "Set"
M.TNODE_BRANCH = "Branch"

----------------------------------------------------
-- underscore copy
local function iter(list_or_iter)
    if type(list_or_iter) == "function" then return list_or_iter end

    return coroutine.wrap(function()
        for i = 1, #list_or_iter do
            coroutine.yield(list_or_iter[i])
        end
    end)
end

local function map(list, func)
    local mapped = {}
    for i in iter(list) do
        mapped[#mapped + 1] = func(i)
    end
    return mapped
end

local function extend(dest, src)
    for k, v in pairs(src) do
        dest[k] = v
    end
    return dest
end

----------------------------------------------------
local function validate_node(node)
    if not node.id then
        error("A node is missing it's id. Object #" .. i .. " in " .. file)
    end
end

local function increment_reference(referenced_id, ref_table)
    ref_table[referenced_id] = (ref_table[referenced_id] or 0) + 1
end

local function add_reference(node, ref_table)
    if node.next then
        increment_reference(node.next, ref_table)
    elseif node.choices then
        for i, choice_id in ipairs(node.choices) do
            increment_reference(choice_id, ref_table)
        end
    elseif node.branches then
        for branch_name, branch_id in pairs(node.branches) do
            increment_reference(branch_id, ref_table)
        end
    end
end

local function start_nodes(id_table, references_table)
    local start_nodes = {}
    for id, _ in pairs(id_table) do
        if not references_table[id] then
            table.insert(start_nodes, id_table[id])
        end
    end
    return start_nodes
end

-- dl_save_json is a string with dialogger game save string contents
function M.load(dl_json_table)
    --json should be array of object for game version save
    if type(dl_json_table) ~= "table" then
        error("expected a table representation of dialogger JSON game export format.")
    end
    --if it's not a list of objects, then it's wrong
    local nodes = dl_json_table

    local id_table = {}
    local references_table = {}
    for _, node in ipairs(nodes) do
        --per node logic
        validate_node(node)
        id_table[node.id] = node
        add_reference(node, references_table)
    end
    local start_nodes = start_nodes(id_table, references_table)

    if #start_nodes ~= 1 then
        error("The dialogue tree has too many beginning nodes.")
    end
    return {
        start_node = start_nodes[1],
        id_table = id_table,
        file = file
    }
end

-- Returns a list of tables with id and name properties
local function collect_choice_nodes(choices, tree)
    return map(choices,
        function(i)
            local node = tree.id_table[i]
            return { id = node.id, name = node.name }
        end)
end

local function nodeToString(node)
    return node.type .. "[" .. node.id .. "]"
end

local function missingChoiceError(node, tree)
    error("Choice selection is required when executing node '" .. nodeToString(node) .. "' in file: " .. tree.file)
end

local function copy_node(node)
    return extend({}, node)
end

local function get_branch_next(node, game_context)
    local next_node_id
    if DialogueOp.branch_has_op(node.variable) then
        next_node_id = DialogueOp.get_op_branch_next_id(node, game_context)
    else
        next_node_id = node.branches[game_context.get(node.variable)]
    end
    if not next_node_id then
        next_node_id = node.branches["_default"]
    end
    return next_node_id
end

local function execute_node(head, tree, game_context)
    if not head then return end

    game_context.visit(copy_node(head)) --for hosuekeeping or anything clearing the current text / choices

    local next_node_id = nil
    local node_type = head.type
    if node_type == M.TNODE_NODE then
        if head.choices then
            game_context.choices(collect_choice_nodes(head.choices, tree))
        end

        local choice = coroutine.yield()

        if head.choices then
            if not choice then
                return missingChoiceError(head, tree)
            end
            local choice_id = type(choice) == "string" and choice or choice.id
            next_node_id = tree.id_table[choice_id].next
        else
            next_node_id = head.next
        end
    elseif node_type == M.TNODE_TEXT then
        game_context.text(head.name)
        if head.choices then
            game_context.choices(collect_choice_nodes(head.choices, tree))
        end

        local choice = coroutine.yield()

        if head.choices then
            if not choice then
                return missingChoiceError(head, tree)
            end
            local choice_id = type(choice) == "string" and choice or choice.id
            next_node_id = tree.id_table[choice_id].next
        else
            next_node_id = head.next
        end
    elseif node_type == M.TNODE_SET then
        game_context.set(head.variable, head.value)
        next_node_id = head.next
    elseif node_type == M.TNODE_BRANCH then
        next_node_id = get_branch_next(head, game_context)
    end

    if next_node_id then
        execute_node(tree.id_table[next_node_id], tree, game_context)
    end
end

--create a tree_execution that steps through the dialogue tree.
-- parameters is the tree table from load
-- game_context is the client interface for callbacks to show text, choices, and set/get variables
-- game_context should have four methods,
--   get(var_name)
--   set(var_name, string_value)
--   choice(choice_list)
--   visit(node_table) -- called just before any node is executed
--   text(text_node_name)
function M.begin(tree, game_context)
    return coroutine.create(function()
        -- execute start nodes (only one for first iteration; error if more than one for now)
        local head = tree.start_node
        execute_node(head, tree, game_context)
    end)
end

-- usage: do .. while not M.finished(tree_execution)
function M.finished(tree_execution)
    return coroutine.status(tree_execution) == "dead"
end

--choice_selection is an optional string if the tree is expecting a choice to be made. It is the string id or the table
function M.next(tree_execution, choice_selection_idstr_or_table)
    if M.finished(tree_execution) then error("Error calling next(), this dialogue tree is already finished.")
    end
    local status, err = coroutine.resume(tree_execution, choice_selection_idstr_or_table)
    if not status then error(err) end
end

-- Returns an empty game context with a variablestate setup and returned as second return value
function M.new_game_context()
    local vars = VarState()
    return {
        visit = function(n)
        end,
        choices = function(choice_list)
        end,
        text = function(text_node)
        end,
        set = function(var_name, value)
            vars:set(var_name, value)
        end,
        get = function(var_name)
            return vars:get(var_name)
        end,
        get_numeric = function(var_name)
            return vars:get_numeric(var_name)
        end,
        is_numeric = function(var_name)
            return vars:is_numeric(var_name)
        end
    }, vars
end

return M