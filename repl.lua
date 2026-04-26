local pprint = require("pprint")
local ophanim = require("ophanim")

local OState = ophanim.newstate()
--pprint(OState)
OState.pprint = pprint
print("================================================================")
while true do
    io.write(">")
    local input = io.read()
    if input == "exit" then
        break
    else
        local pres = OState.NegI.parse(input)
        --pprint(pres)
        --print("unhandled:")
        local r = OState:dispatch(pres)
        OState.KES:stage_fill_reserve((r ~= OState.NegI.Manifests.gap) and r or nil)
        OState.KES:commit()
        pprint(r)
        --pprint(OState.KES.bindings)
        --OState.KES:log_bindings(pprint)
    end
end
-- starting to make the system alive