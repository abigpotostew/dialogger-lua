# dialogger-lua

### About
`dialogger-lua` is a lua module for stepping through dialogue trees created with Dialogger https://github.com/etodd/dialogger

Dialogger is a standalone web application that allows users to create static dialogue trees with branching behavior and save them as json to a file. The output is .dl format but is json underneath.

This module provides a lua runtime for execution of Dialogger trees.

The library tracks the current position in the tree and provides a callback to your application or game when each node is visited. The library also evaluates branch conditions.

### Bindings
I have included a binding for the Defold game engine which has support for reading files and parsing json builtin. The defold binding in `bindings/defold.lua` can be used in the same way but requires the file to be passed in as a file path.
 
 
### Usage
#### Setup
Run the dialogger application, create a tree, then save the game file (Right click > Export game file). You can save this as `.dl` or as `.json`.


#### Example
```lua
local dialogger = require "dialogger"
local json = require "json"

local function readAll(file)
    local f = assert(io.open(file, "rb"))
    local content = f:read("*all")
    f:close()
    return content
end

-- Load tree definition into memory.
-- For defold binding, just pass the file string into load()
local tree = Dialogue.load(json.decode(readAll("test/data/single_choice.lua")))

-- Create a sample game context which stores the branch variable state. 
-- game_context is your interface into what's happening while walking the tree. You can put any code in the interface 
-- functions.
local game_context = Dialogue.new_game_context()

-- Start evaluating the tree. The execution maintains the state of stepping through the tree.
-- begin() will start stepping through the tree and will stop (yield) at the first "node" or "text" node 
-- Keep a reference to this execution. 
local execution = Dialogue.begin(tree, game_context)

-- Example for stepping through the whole tree.
while not M.finished(execution) do
    Dialogue.next(execution) 
end

-- Or if your tree has choices, the game_context is passed choice_list before pausing execution. You must pass a single 
-- choice back to the subsequent call to next() like so:
Dialogue.next(execution) 
-- get the choice_list from game_context, select one, and pass it back into next
local my_choice = choice_list[1] -- choice_list is from game_context
Dialogue.next(execution, my_choice)
```

### Branches
The library by default supports simple string equality for branch conditions. When a branch is defined with condition `my_variable` and branches
- `Default`
- `huzzah`

and the `my_variable` contains the string `huzzah` then the huzzah branch is selected.


### Numeric Branches
Additionally the library includes numeric parsing and evaluation for branch conditions.

The library uses the delimeter `&` followed by an operator to evaluate the branch condition numerically.
For example, consider a branch with name `my_variable&lt` and three branch conditions:
- `Default`
- `1`
- `5`

The evaluation uses the less than operator to effectively become:
```lua
if my_variable < 1 then
    -- step to the `1` branch
else if my_variable < 5 then
    -- step to the `5` branch
else
    -- step to the `Default` branch
end
```

If the `game_context` has a variable with name `my_variable` set to `"2"`, then the branch condition will evaluate to branch `5`. If `my_variable` is `"0"` then branch `1` is selected.

`Default` branch is a special case that is chosen if all other branches fail. 

Numeric evaluation is always enabled.

Supported operators are:
- "eq" -- ==
- "ne" -- ~=
- "gt" -- >
- "ge" -- >=
- "lt" -- <
- "le" -- <=


### Tree definition best practice
- Must have 1 starting node.
- Start with "text", "node", or "branch" node type.
- To have the first tree interaction be a choice, start with a "node" node and link the choices to that. 
- Don't use the ampersand character `&` in your branch condition unless you want numeric evaluation
- Use your own short unique IDs in the text and choice nodes and store the full dialogue text in another file like csv.

