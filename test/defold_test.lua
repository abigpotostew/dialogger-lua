local Dialogue = require "bindings.defold"

local _ = require "underscore"

local VariableState = require "variablestate"
local Json = require "json"

local function readAll(file)
    local f = assert(io.open(file, "rb"))
    local content = f:read("*all")
    f:close()
    return content
end

local sys = {}
sys.load_resource = function(file)
    return readAll(file)
end

local json = {}
json.decode = function(str)
    return Json.decode(str)
end

rawset(_G, "sys", sys)
rawset(_G, "json", json)

describe("Some tests", function()
    local var_state, game_context, choices, variables, visit_stack, tree, execution
    before_each(function()
        -- this function will be run before each test
        var_state = VariableState()
        tree = nil
        execution = nil
        choices = {}
        variables = {}
        visit_stack = {}
        game_context = {
            visit = function(n)
                choices = {}
                _.push(visit_stack, n)
            end,
            choices = function(cs)
                choices = {}
                _.each(cs, function(i) choices[tostring(i.name)] = i end)
            end,
            text = function(t)
            end,
            set = function(var, val)
                var_state:set(var, val)
            end,
            get = function(var)
                return var_state:get(var)
            end,
            get_numeric = function(var)
                return var_state:get_numeric(var)
            end,
            is_numeric = function(var)
                return var_state:is_numeric(var)
            end
        }
    end)

    local function load(filename)
        local file = "test/data/"..filename
        tree = Dialogue.load(file)
    end


    it("Single text node", function()
        load("single.json")
        execution = Dialogue.begin(tree, game_context)
        Dialogue.next(execution)
        --pprint("AFTER NEXT CALL")
        assert(not Dialogue.finished(execution))
        assert(visit_stack[1].type == Dialogue.TNODE_TEXT)
        assert(visit_stack[1].name == "one")
        Dialogue.next(execution)
        assert(Dialogue.finished(execution))
        assert(#visit_stack == 1)
    end)

    it("Simple Choice path a", function()
        load("single_choice.json")

        execution = Dialogue.begin(tree, game_context)
        Dialogue.next(execution)
        assert(visit_stack[1].type == Dialogue.TNODE_TEXT)
        assert(visit_stack[1].name == "one")
        assert(# (_.values(choices)) == 2)
        local choices1a = choices["one_a"]
        Dialogue.next(execution, choices1a)
        assert(visit_stack[2].type == Dialogue.TNODE_TEXT)
        assert(visit_stack[2].name == "two_a")
        assert(not Dialogue.finished(execution))
        Dialogue.next(execution)
        assert(Dialogue.finished(execution))
        assert(#visit_stack == 2)
    end)

    it("Simple Choice path b", function()
        load("single_choice.json")
        execution = Dialogue.begin(tree, game_context)
        Dialogue.next(execution)
        assert(visit_stack[1].type == Dialogue.TNODE_TEXT)
        assert(visit_stack[1].name == "one")
        assert(# (_.values(choices)) == 2)
        local choices1a = choices["one_b"]
        Dialogue.next(execution, choices1a)
        assert(visit_stack[2].type == Dialogue.TNODE_TEXT)
        assert(visit_stack[2].name == "two_b")
        assert(not Dialogue.finished(execution))
        Dialogue.next(execution)
        assert(Dialogue.finished(execution))
        assert(#visit_stack == 2)
    end)

    local function test_simple_branch(file, value, final_node_name)
        load(file)
        execution = Dialogue.begin(tree, game_context)
        Dialogue.next(execution)
        assert(#visit_stack == 3)

        assert(visit_stack[1].type == Dialogue.TNODE_SET)
        assert(visit_stack[1].variable == "var1")
        assert(visit_stack[1].value == value)

        assert(visit_stack[2].type == Dialogue.TNODE_BRANCH)

        assert(visit_stack[3].type == Dialogue.TNODE_NODE)
        assert(visit_stack[3].name == final_node_name)

        Dialogue.next(execution)
        assert(Dialogue.finished(execution))
        assert(#visit_stack == 3)
        return true
    end
    it("Simple branch path 1", function()
        local success = test_simple_branch("simple_branch.json", "1", "correct")
        assert(success)
    end)

    it("Simple branch default branch", function()
        local success =test_simple_branch("simple_branch_default.json", "10", "default")
        assert(success)
    end)

    local function test_branch_op(file, final_node_name)
        load(file)
        execution = Dialogue.begin(tree, game_context)
        Dialogue.next(execution)
        assert(#visit_stack == 2)

        assert(visit_stack[1].type == Dialogue.TNODE_BRANCH)
        assert(visit_stack[2].type == Dialogue.TNODE_NODE)
        assert(visit_stack[2].name == final_node_name)

        Dialogue.next(execution)
        assert(Dialogue.finished(execution))
        assert(#visit_stack == 2)
        return true
    end
    --Test equals op
    it("branch op numeric equals 1", function()
        var_state:set("var1", 1)
        local success = test_branch_op("branch_op_eq_1_2.json", "1")
        assert(success)
    end)
    it("branch op numeric equals 1.0", function()
        var_state:set("var1", 1.0)
        local success = test_branch_op("branch_op_eq_1_2.json", "1")
        assert(success)
    end)
    it("branch op numeric equals no match", function()
        var_state:set("var1", 3.999)
        local success = test_branch_op("branch_op_eq_1_2.json", "default")
        assert(success)
    end)
    --Test greater than op
    it("branch op numeric 0 not greater than [1,2]", function()
        var_state:set("var1", 0)
        local success = test_branch_op("branch_op_gt_1_2.json", "default")
        assert(success)
    end)
    it("branch op numeric 0.5 not greater than [1,2]", function()
        var_state:set("var1", .5)
        local success = test_branch_op("branch_op_gt_1_2.json", "default")
        assert(success)
    end)
    it("branch op numeric 1 not greater than [1,2]", function()
        var_state:set("var1", "1.0")
        local success = test_branch_op("branch_op_gt_1_2.json", "default")
        assert(success)
    end)
    it("branch op numeric 1.01 greater than [1]", function()
        var_state:set("var1", "1.00001")
        local success = test_branch_op("branch_op_gt_1_2.json", "1")
        assert(success)
    end)
    --test greater than or equal to op
    it("branch op numeric 0.5 not ge [1,2]", function()
        var_state:set("var1", "0.5")
        local success = test_branch_op("branch_op_ge_1_2.json", "default")
        assert(success)
    end)
    it("branch op numeric 1 ge [1]", function()
        var_state:set("var1", "1")
        local success = test_branch_op("branch_op_ge_1_2.json", "1")
        assert(success)
    end)
end)