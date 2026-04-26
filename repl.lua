local ophanim = require("ophanim")

local OState = ophanim.newstate()
for k,v in pairs(OState) do
    print(k..": "..tostring(v))
end
print("================================================================")
print(tostring(OState.NegI.parse("{}")))
-- starting to make the system alive