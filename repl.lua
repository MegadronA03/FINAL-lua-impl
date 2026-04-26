local pprint = require("pprint")
local ophanim = require("ophanim")

local OState = ophanim.newstate()
--pprint(OState)
--[[
for k,v in pairs(OState.NegI.Manifests) do
    print("-------------------------------- "..k.." --------------------------------")
    pprint(v)
end--]]
print("================================================================")
while true do
    io.write(">")
    local input = io.read()
    if input == "exit" then
        break
    else
        local pres = OState.NegI.parse(input)
        pprint(pres)
        --print("unhandled:")
        --pprint(OState:dispatch(pres))
        --OState.KES:commit()
    end
end
-- starting to make the system alive