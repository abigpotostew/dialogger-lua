-- Binding for defold which includes file loading and json parsing
-- Usage is the same except the load() function accepts a string file location.
local Dialogger = require("dialogger")

local M = {}

M.TNODE_TEXT = "Text"
M.TNODE_NODE = "Node"
M.TNODE_CHOICE = "Choice"
M.TNODE_SET = "Set"
M.TNODE_BRANCH = "Branch"

-- dl_save_json is a string with dialogger game save string contents
function M.load(file)
    local data = sys.load_resource(file)
    if data == nil then
        error("The dialogue file does not exist. Is the file path correct? "..file)
    end
    local nodes = json.decode(data)
    return Dialogger.load(nodes)
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
    return Dialogger.begin(tree, game_context)
end

-- usage: do .. while not M.finished(tree_execution)
function M.finished(tree_execution)
    return Dialogger.finished(tree_execution)
end

--choice_selection is an optional string if the tree is expecting a choice to be made. It is the string id or the table
function M.next(tree_execution, choice_selection_idstr_or_table)
    return Dialogger.next(tree_execution, choice_selection_idstr_or_table)
end

-- Returns an empty game context with a variablestate setup and returned as second return value
function M.new_game_context()
    return Dialogger.new_game_context()
end

return M