local pprint = require("pprint")
local ophanim = require("ophanim")

local OState = ophanim.newstate()
--pprint(OState)
OState.pprint = pprint

local quote_test = function ()
    io.write("testing quoting:\t")
    return OState:dispatch(OState.NegI.parse([[[a:1; b:{;a}; [a:55;b()][] ][] ]])).state == 55
end
local contain_test = function ()
    io.write("testing isolation:\t")
    return OState:dispatch(OState.NegI.parse([[[a:1; b:{;a}; (a:55;b())[] ][] ]])).state == 1
end
local grounding_test = function ()
    io.write("testing grounding:\t")
    return OState:dispatch(OState.NegI.parse([[[a:1; b:[;a]; [a:55;b()][] ][] ]])).state == 1
end
local labeling_test = function ()
    io.write("testing labeling:\t")
    return OState:dispatch(OState.NegI.parse([[ [a : 2; a : 3; a][] ]])).state == 3
end

print("LOADING=========================================================")
pprint(contain_test())
pprint(quote_test())
pprint(grounding_test())
pprint(labeling_test())
print("NegI REPL v0.0.1 (Pre-Alpha)====================================")

OState.KES:write_entry("REPL", OState.make.Manifest({ -- we describle REPL authority here, instead of using arbitrary commands
        can = {
            exit = {call = OState.make.Artifact([[]], "REPL can exit call")}
        }
    },{

    
}))

OState.KES:push_layer(1,true)
while true do
    io.write(">")
    local input = io.read()
    if input == "exit" then -- reimplement as manifest in REPL Frame
        break
    else
        local e = OState.NegI.parse(input) or OState.NegI.Manifests.gap
        e = OState:dispatch(e); e = e or OState.NegI.Manifests.gap -- evaluation
        e = OState:dispatch(e); e = (e ~= OState.NegI.Manifests.gap) and e or nil -- get
        OState.KES:stage_fill_reserve(e)
        OState.KES:commit()
        pprint(e)
    end
end
OState.KES:pop_layer()
-- starting to make the system alive