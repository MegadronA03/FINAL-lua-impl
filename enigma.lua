return (function ()
    --Idea: ENIGMA - Epistemic Negotiation Interface for/of Gentzen Manifested Abstractions
    --Syntax: NegI - Negotiation Interface (the interface)
    --System: FINAL - Final Is Not A Language (the substrate)

    -- This works more or less as ship of thesus, FINAL provides common interfaces for other manifests to communicate with each other in platform agnostic way
    local newstate = function () -- something similar to lua_newstate but for FINAL
        local new_conv = function (c, ...) --helps chaining like resolve_chain("salt")(4)(5)(1).r
            local h = {c = c,r = {...}}
            setmetatable(h, {
                __call = function (self, ...)
                    return new_conv(c, c(...))
                end })
            return h
        end
        local table_invert = function (t)
            local s={}
            for k,v in pairs(t) do
                s[v]=k
            end
            return s
        end
        local bimap_write = function (bimap, view_key, index, value)
            local views = {bimap[view_key]}
            for i,e in pairs(bimap) do if i ~= view_key then views[2] = bimap[i]; break end end
            if value ~= nil then
                views[1][index] = value
                views[2][value] = index
            else
                views[2][views[1][index]] = nil
                views[1][index] = nil end end
        local FLESH = { -- stands for "FINAL Local Environment Shared Handles"
            FIS = { -- "FINAL Internal State" - used by particular manifests to pass around some data. Could be avoided via KES, but those values are quite commonly used, so it will influence performance.
                tail_context = nil, -- context from pop_layer
                pending_labels = nil, -- "API" for labels, that are about to be loaded by something
            },
            KES = { -- "Knowledge Environment State" (considered finished, until bugs will be found)
                layers = {{d = 1,c = {}}}, -- stack of references, string names ready for free (initial layer is preloaded)
                labels = {}, -- Map<label: String, {records: Map<layer_id: Integer, reference: Integer>, order: BiMap<layer_id: Integer, order: Integer>}> holds labeled refences 
                bindings = {}, -- Array<bind: Number, {records: Map<layer_id: Integer, entry: Manifest>, order: BiMap<layer_id: Integer, order: Integer>}> holds references to data
                relevance = { -- tracks what currently available in active context
                    dl = {[1]=1}, -- Array<depth: Integer, layer_id: Integer> 
                    ld = {[1]=1}}, -- Map<layer_id: Integer, depth: Integer> stores which layers are relevent to current context, mostly used as Set<layer_id: Integer>
                isolations = { -- tracks where grounded layer must be used. basically ordered Set<depth: Integer>
                    ["od"] = {}, -- Array<order: Integer, depth: Integer> 
                    ["do"] = {}}, -- Map<depth: Integer, order: Integer> "this is the reason I hate keywords"

                resolve = function (self, ref, partial) -- note that strings are names for indicies
                    if (type(ref) ~= "string" and type(ref) ~= "number") then
                        error("FINAL: FLESH.KES:resolve - invalid argument, expected number or string", 2)
                    end
                    local rt = (type(ref) == "number") and self.bindings[ref] or self.labels[ref] -- we override the table depending on what we resolving
                    if (rt == nil) then return end -- the environment don't know about this binding so we exit early, this line is optional
                    local m
                    if #rt.order.ol > #self.relevance.dl then -- NOTE: records store changes per each layer, so this checks if it's effective to do vertical or horizontal search traversal
                        for i = #self.relevance.dl, 1, -1 do -- inverse order, because we pick fresh ones, in order to hit early
                            local e = self.relevance.dl[i]
                            if rt.order.lo[e] then m = rt.records[e]; break end -- we do not use rt.records[e], because it may contain nil, due to "namespace" reservation
                        end
                    else
                        for i = #rt.order.ol, 1, -1 do -- inverse order, because we pick fresh ones, in order to hit early
                            local e = rt.order.ol[i]
                            if self.relevance.ld[e] then m = rt.records[e]; break end
                        end
                    end
                    if type(ref) == "string" and not partial then -- we assume that labels store actual indicies, labels are intentionally alias for indicies
                        return self:resolve(m)
                    end
                    return m -- Manifest(lua table, that represnts it) or nil (or binding, if partial selected)
                end,
                push_layer = function (self, parent, grounded, isolated, context)
                    --we make an exception for root layer, because there's nothing to isolate against
                    local l
                    if (#self.layers > 0) then -- initial layer is preloaded, but I still add it if user decide to pop the root layer and there will be those who would like to do that for the fun of it (hi tsoding)
                        if (type(parent) ~= "number") then error("enigma: FLESH.KES:push_layer - parent<number> expected for explicit grounded, got "..type(parent), 2) end -- I also think that root layers should be definable if no parent specified
                        local p_depth = (parent and self.layers[parent].d or 0) -- parent depth
                        local iso_depth_i, iso_depth = #self.isolations.od, nil
                        while ((self.isolations.od[iso_depth_i] or 0) > p_depth) -- we check if layer definition was outside of isolation. also binary search could be applied here
                            iso_depth = self.isolations.od[iso_depth_i]
                            iso_depth_i = iso_depth_i - 1 end
                        if (iso_depth and not grounded) then -- if dynamic defined outside isolation, then it shouldn't consider effect of isolation
                            parent = self.relevance.dl[iso_depth - 1] -- find parent of layer outside of isolation
                            p_depth = (parent and (self.layers[parent].d) or 0) -- parent depth
                            grounded = true end
                        l = { -- new layer data
                            d = (grounded and p_depth or (self.layers[#self.layers].d or 0)) + 1, -- new layer depth
                            s = grounded and {r={},i={}} or nil, -- if there is grounded, then those are shadowed layers (r - relevance, i - isolation)
                            c = context -- `c` is Set<reference: Number|String, exist: Boolean> references relvant to this context layer
                    else l = {d = 1, s = grounded and {r={},i={}} or nil, c = (size and table.create) and table.create(0, size) or {}}} end
                    if isolated then bimap_write(self.isolations, "od", #self.isolations.od+1, l.d) end -- isolated (external binding resolving, causes it to use resolving oblivious to effects from here)
                    if grounded then -- grounded
                        for i = l.d, #self.relevance.dl do -- exclude all layers between parent and new layer via depth
                            l.s.r[#l.s.r+1] = self.relevance.dl[i] -- add shadowed layers (we can ask depth form them directly)
                            bimap_write(self.relevance, "dl", i, nil) end -- removing irrelevant layers
                        if iso_depth then -- if crossing or sealing isolations
                        for i = self.isolations["do"][iso_depth], #self.isolations.od do -- iso_depth is calculated anyways, but I think I need to reorganize this code
                            l.s.i[#l.s.i+1] = self.isolations.od[i] -- add shadowed isolations (we can ask depth form them directly)
                            bimap_write(self.isolations, "od", i, nil) end end end -- removing irrelevant isolations
                    self.layers[#self.layers+1] = l
                    bimap_write(self.relevance, "ld", #self.layers, l.d)
                    return #self.layers -- used if Sequence will define another Sequence
                end,
                pop_layer = function (self, migrate) -- P.S. while push and pop suggest stack structure, this isn't purely just that due to parent detours
                    self.isolations["do"][self.layers[#self.layers].d] = nil -- lift isolation sandbox
                    local shadowed_data = self.layers[#self.layers].s
                    if shadowed_data then
                        for _,e in ipairs(shadowed_data.r) do -- restoring shadowed context relevance
                            bimap_write(self.relevance, "ld", e, self.layers[e].d) end
                        for _,e in ipairs(shadowed_data.i) do -- restoring shadowed context isolations
                            bimap_write(self.isolations, "od", #self.isolations.od + 1, e) end end
                    if not migrate then
                        for i,_ in pairs(self.layers[#self.layers].c) do -- removing references from bindings
                            local db = (type(i) == "number") and self.bindings or self.labels
                            local rt = db[i]
                            rt.records[#self.layers] = nil
                            bimap_write(rt.order, "lo", #self.layers, nil)
                            if #rt.records <= 0 then db[i] = nil end end end
                    if (#self.layers > 0) then self.layers[#self.layers] = nil end -- removing layer
                    return migrate and self.layers[#self.layers + 1].c or nil -- for tail calls it's preferably to return lifted context
                end,
                get_context = function (self) return #self.layers end, -- used by Sequence to memorise context for later use
                write_entry = function (self, ref, m) -- reference : Number|String, [manifest: Any|Nil]
                    ref = ref or (#self.bindings + 1)
                    local db = self.bindings
                    if type(ref) == "string" then -- do binding first, then labeling
                        m = self:write_entry(self:resolve(ref, true) or (#self.bindings + 1), m)
                        db = self.labels
                    end
                    db[ref] = db[ref] or { records = {}, order = {ol = {}, lo = {}} }
                    db[ref].records[#self.layers] = m -- note that nil will reserve the place on layer
                    bimap_write(db[ref].order, "lo", #self.layers, #db[ref].order.lo + 1)
                    if not self.layers[#self.layers].c[ref] then -- if it's new binding for this context
                        self.layers[#self.layers].c[ref] = true
                    end return ref
                end, -- entry writes could only happen in current context
                direct_snapshot = function (self, layer_id, c)
                    c = c or {}
                    for i,_ in pairs(self.layers[layer_id].c) do
                        local db = (type(i) == "number") and self.bindings or self.labels
                        c[i] = db[i].records[layer_id] end
                    return c end,
                inner_snapshot = function (self) -- used in tuple, in order to track writes
                    return self.direct_snapshot(#self.layers)
                end,
                cview_snapshot = function (self, outer)
                    local c = {}
                    for i = #self.relevance.dl, 1, -1 do
                        local e = self.relevance.dl[i]
                        for i,_ in pairs(self.layers[e].c) do
                            local db = (type(i) == "number") and self.bindings or self.labels
                            c[i] = c[i] or db[i].records[e] end end
                    return c
                end,
            },
            import = function (o)-- imports lua object "o" inside FINAL environment
                -- it should find FINAL's host knowledge and apply appropriate interface from it.
                if o then
                    local h = FLESH.KES:resolve("host")
                    local hl = h.state.labels
                    local hb = h.state.items
                    local n = { -- need rework to Native
                        protocol = FLESH.KES:resolve("Native").state, -- protocol and state are tables, not references. this solves metacircularity problem 
                        interface = hb[hl[type(o)]], -- should probably replace with protocol call from `host` tuple
                        external = o
                    }
                    setmetatable(n, {__index = function (s,i) -- we make lazy fetch on Artifact, because we have a metacircular situation
                        local v = rawget(s,i)
                        if i ~= "protocol" then return v end
                            v = FLESH.KES:resolve("Native").state
                            rawset(s,i,v) 
                            setmetatable(s, nil) end
                        return v})
                    return FLESH.KES:write_entry(nil, n)
                else
                    return "gap" -- we have direct match here, no need to store it
                end
            end,
            dispatch = function (lterm, rterm, protocol)
                if lterm == nil then return end
                if rterm and rterm.protocol and rterm.protocol.unhandled then
                    return FLESH.dispatch(rterm, nil, rterm.protocol) -- unhandled exectuion
                end
                if protocol then
                    if rterm then
                        if protocol.responders then
                            local label_p = FLESH.KES.bindings[FLESH.KES.bindings.Label.records[FLESH.host_layer]].records[FLESH.host_layer] -- we use direct access, because this stuff will depend on furst record anyways
                            if FLESH.capcheck(label_p, rterm) then return {protocol = protocol.responders[rterm.state.name], state = lterm.state} end end
                        if protocol.handled then
                            local artifact_p = FLESH.KES.bindings[FLESH.KES.bindings.Artifact.records[FLESH.host_layer]].records[FLESH.host_layer]
                            local tuple_p = FLESH.KES.bindings[FLESH.KES.bindings.Tuple.records[FLESH.host_layer]].records[FLESH.host_layer]
                            local hanc = FLESH.KES:resolve(protocol.unhandled)
                            if FLESH.capcheck(artifact_p, hanc) then
                                return hanc.state.data.artifact(lterm, rterm)
                            else return FLESH.dispatch(hanc, {
                                protocol = tuple_p.state,
                                state = {items = {lterm, rterm}, labels = {"self", "arg"}}}, hanc.protocol) end -- needs some standartization on how this should be passed around, don't like hardcoded "self" and "arg"
                        end
                    else
                        if protocol.unhandled then
                            local artifact_p = FLESH.KES.bindings[FLESH.KES.bindings.Artifact.records[FLESH.host_layer]].records[FLESH.host_layer]
                            local unhc = FLESH.KES:resolve(protocol.unhandled)
                            if FLESH.capcheck(artifact_p, unhc) then
                                return unhc.state.data.artifact(lterm)
                            else return FLESH.dispatch(unhc, lterm, unhc.protocol) end
                        else
                            return lterm
                        end
                    end
                else
                    if lterm.protocol then return FLESH.dispatch(lterm, rterm, lterm.protocol) else
                        if rterm then return {
                                protocol = FLESH.KES.bindings[FLESH.KES.bindings.Error.records[FLESH.host_layer]].records[FLESH.host_layer].state,
                                state = {desc = "ENIMGA: FLESH.dispatch Error: missing protocol")} -- TODO: this error neeed more verbosity
                        else
                            return lterm end end end 
            end,
            --env methods
            --artifact = function (self, arg) end,
            reset = function (self) end, -- inits defaults and other stuff
        }

        --FLESH.host_layer = FLESH.KES:push_layer() -- we will use it in order to reference stuff at the base
        FLESH.host_layer = 1 -- we already have layer in KES, so no need for push_layer
        for _,e in pairs({
            "Native","Artifact","Error","Protocol","Manifest","gap","Number",
            "String","Label","Tuple","Sequence","Membrane","Negotiation"
        }) do
            FLESH.KES:write_entry(e) -- we can directly write stuff, without explicitly defining binding
        end

        -- Artifact assumptions:
        -- on handled it recieves 2 manifests (tabels, not KES IDs): self, arg
        -- on unhandled it's just self (tables, not KES IDs)
        -- the return should return Manifest (tables, not KES IDs)

        local artifact_chunk = [[function (_, arg) -- _, {chunk/code, outer, env, mode}
            if type(arg) ~= "table" then
                arg = FLESH.export(arg) end
            local chunk, outer, env, mode = (lns.unpack or lns.table.unpack)(arg) -- TODO: convert passed in manifests into values
            local ref = FLESH.KES:write_entry()
            local exref = FLESH.KES:write_entry() -- I added so KES:write_entry will return where write happened
            local chunkname = "FLESH.KES:bindings["..tostring(ref).."].records["..tostring(FLESH.KES:get_context()).."]"
            outer = outer or false
            mode = mode or "t"
            local plfmt = { __index = function (s,i) -- we make lazy fetch on Artifact, because we have a metacircular situation
                local v = rawget(s,i)
                if i ~= "protocol" then return v end
                if type(v) ~= "table" then
                    v = FLESH.KES:resolve(v).state
                    rawset(s,i,v) 
                    setmetatable(s, nil) end 
                return v end}
            local a, e
            if (chunk.chdef and chunk.artifact) then -- we skip load process for already loaded chunk
                a = chunk.artifact
                chunk = chunk.chdef -- must be passed, so FINAL can describle itself with host
            elseif (type(chunk) == "string")
                a, e = lns.load(chunk, chunkname, mode, {lns = outer and lns or nil, FLESH = FLESH, env = env}) 
                if (e) then
                    local em = {
                        protocol = "Error", 
                        state = {desc = exref}}
                    setmetatable(em, plfmt)
                    FLESH.KES:write_entry(exref, {external = "Artifact: Failed to create due to host error: "..e}) -- gonna need string, or better yet, make Error adapt to availabale conditions
                    FLESH.KES:write_entry(ref, em)
                    return ref end
                a = a() end
            FLESH.KES:write_entry(exref, {external = {
                    artifact = a,
                    lua_chunk = chunk,
                    lua_chunkname = chunkname,
                    lua_mode = mode,
                    lua_outer = outer,
                    lua_env = env
            }})
            local am = {
                protocol = "Artifact",
                state = {
                    data = exref, -- exref about to be removed
                    def_context = FLESH.KES:get_context()}}
            setmetatable(am, plfmt)
            FLESH.KES:write_entry(ref, am)
            return ref end]]

        local raw_artifact = (function () 
            local ref = FLESH.KES:write_entry()
            local chunkname = "FLESH.KES:bindings["..tostring(ref).."].records["..tostring(FLESH.KES:get_context()).."]"
            local a, e = load(artifact_chunk, chunkname, "t", {lns = _ENV, FLESH = FLESH})
            if (e) then -- library side fail - we panic
                error(e, 2) end
            return a() end)()
        FLESH.artifact = function (chunk, outer, env, mode)
            return raw_artifact(nil, {chunk = chunk, outer = outer or true, env = env, mode = mode}) end
        local artifact_manifest = FLESH.artifact({chdef = artifact_chunk, artifact = raw_artifact}, true)

        FLESH.capcheck = function(self, arg)
            for i,e in pairs(self.state) do
                if (arg.protocol[i] ~= e) then
                    return false end end -- that should be Boolean Manifest
            for i,e in pairs(self.state.responders) do
                if (arg.protocol.responders[i] ~= e) then
                    return false end end -- that should be Boolean Manifest
            return true end

        --common between protocol manifests
        local capability_check = FLESH.artifact([[return function (self, arg)
            return FLESH.capcheck(self, arg) and FLESH.KES:resolve("true") or FLESH.KES:resolve("false") end]])

        local host_name = FLESH.KES:write_entry() -- we reserve space for the host name 

        FLESH.KES:write_entry("Native", { -- should represent state during introspection, to make it hostile
            protocol = {
                is = {handled = capability_check},
                ["="] = nil}, -- generated by host, can't be constructed directly
            state = {
                responder = {
                    name = {unhandled = host_name}}}}) -- it's later constructed a string with "Lua 5.5"

        FLESH.KES:write_entry("Artifact", { -- Artifact for handling external authority
            protocol = {
                is = {handled = capability_check},
                ["="] = artifact_manifest},
            state = {
                responders = {
                    reload = {unhandled = FLESH.artifact([[return function (self)
                        local adesc = self.state.data
                        return FLESH.KES:resolve(FLESH.artifact(adesc.lua_chunk, adesc.lua_outer, adesc.lua_env, adesc.lua_mode)) end]])}},
                handled = FLESH.artifact([[return function(self, arg)
                    local tunp = lns.unpack or lns.table.unpack
                    return self.state.data.artifact(tunp(arg)) end]])}})

        FLESH.KES:write_entry("Error", { -- Error "as value"
            protocol = {
                is = {handled = capability_check},
                ["="] = {handled = FLESH.artifact([[]])}},
            state = {
                responders = {
                    error_name = {unhandled = FLESH.artifact([[]])}, 
                    error_desc = {unhandled = FLESH.artifact([[]])}, 
                    error_caller = {unhandled = FLESH.artifact([[]])},
                    error_trace = {unhandled = FLESH.artifact([[]])},
                },    

            }
        })

        -- no implicit conversions, this is only between this specific implementation
        local make_trans_op = function (op, bool)
            return FLESH.artifact([[function (self, arg)
                if (FLESH.capcheck({state = self.protocol},arg)) then
                    return {
                        protocol = self.protocol,
                        state = ((self.state ]]..op..[[ arg.state)]]..bool or (" and 1 or 0")..[[)}
                else
                    return -- Error manifest
                end
            end]])
        end
        local make_trans = function (trans)
            return FLESH.artifact([[function (self)
                return {
                    protocol = self.protocol,
                    state = (]]..trans..[[(self.state))}
            end]])
        end
        local make_host_res_init = function (host_type)
            return FLESH.artifact([[function (self, arg)
                -- wrap host resource manifest
                if (FLESH.capcheck(self,arg)) then return arg end -- literal uses same protocol, so we just passing
                if (type(arg) == "]]..host_type..[[") then return {protocol = self.state,state = arg}} end
                return -- Error manifest
            end]])
        end

        local host_enum = table_invert({"nil","boolean","number","string","userdata","function","thread","table","unknown"})
        local host_tuple = {
            protocol = FLESH.KES:resolve("Tuple").state,
            state = {
                labels = host_enum,
                data = {
                    FLESH.KES:write_entry(nil, {protocol = {},state = {}}), -- nil
                    FLESH.KES:write_entry(nil, {protocol = { -- boolean
                        responders = {
                            is = {handled = capability_check},
                            ["="] = make_host_res_init("boolean")}},
                    state = {
                        responders = {
                            ["|"] = {handled = make_trans_op("or")},
                            ["&"] = {handled = make_trans_op("and")},
                            ["~"] = {unhandled = make_trans("not")},
                            ["=="] = {handled = make_trans_op("==")},
                            ["~="] = {handled = make_trans_op("~=")},
                        }
                    }}),
                    FLESH.KES:write_entry(nil, {protocol = { -- number
                        responders = {
                            is = {handled = capability_check},
                            ["="] = make_host_res_init("number")}},
                    state = {
                        responders = {
                            ["+"] = {handled = make_trans_op("+")},
                            ["-"] = {handled = make_trans_op("-")},
                            ["*"] = {handled = make_trans_op("*")},
                            ["/"] = {handled = make_trans_op("/")},
                            ["%"] = {handled = make_trans_op("%")},
                            ["^"] = {handled = make_trans_op("^")},
                            ["|"] = {handled = make_trans_op("|")},
                            ["&"] = {handled = make_trans_op("&")},
                            ["<<"] = {handled = make_trans_op("<<")},
                            [">>"] = {handled = make_trans_op(">>")},
                            ["=="] = {handled = make_trans_op("==")},
                            ["~="] = {handled = make_trans_op("~=")},
                            ["<"] = {handled = make_trans_op("<")},
                            [">"] = {handled = make_trans_op(">")},
                            ["<="] = {handled = make_trans_op("<=")},
                            [">="] = {handled = make_trans_op(">=")},
                            abs = {unhandled = make_trans("math.abs")},
                            acos = {unhandled = make_trans("math.acos")},
                            asin = {unhandled = make_trans("math.asin")},
                            atan = {unhandled = make_trans("math.atan")},
                            ceil = {unhandled = make_trans("math.ceil")},
                            cos = {unhandled = make_trans("math.cos")},
                            deg = {unhandled = make_trans("math.deg")},
                            exp = {unhandled = make_trans("math.exp")},
                            floor = {unhandled = make_trans("math.floor")},
                            fmod = {unhandled = make_trans("math.fmod")},
                            frexp = {unhandled = make_trans("math.frexp")},
                            huge = {unhandled = make_trans("math.huge")},  -- const
                            ldexp = {unhandled = nil}, -- math.ldexp (m, e) - Returns m2e, where e is an integer.
                            log = {unhandled = make_trans("math.log")},
                            max = {unhandled = make_trans("math.max")},
                            maxinteger = {unhandled = make_trans("math.maxinteger")}, -- const
                            min = {unhandled = make_trans("math.min")},
                            mininteger = {unhandled = make_trans("math.mininteger")}, -- const
                            modf = {unhandled = nil}, -- Returns the integral part of x and the fractional part of x. Its second result is always a float.
                            pi = {unhandled = make_trans("math.pi")}, -- const
                            rad = {unhandled = make_trans("math.rad")},
                            --random = {unhandled = make_trans("math.random")},
                            --randomseed = {handled = nil}, -- [x, [y]]
                            sin = {unhandled = make_trans("math.sin")},
                            sqrt = {unhandled = make_trans("math.sqrt")},
                            tan = {unhandled = make_trans("math.tan")},
                            tointeger = {unhandled = make_trans("math.tointeger")},
                            type = {unhandled = nil}, -- returns "integer" or "float" or fail
                            ult = {handled = nil}, -- math.ult (m, n)
                            to = {
                                responders = {
                                    string = {unhandled = FLESH.artifact([[function (self)
                                        return { -- UNFINISHED
                                            protocol = FLESH.KES:resolve(host_tuple.state.items[host_tuple.state.labels.string]).state,
                                            state = tostring(self.state)}
                                    end]])}}}
                        }
                    }}),
                    FLESH.KES:write_entry(nil, {protocol = { -- string
                        responders = {
                            is = {handled = capability_check},
                            ["="] = make_host_res_init("string")}},
                    state = {
                        responders = {
                            ["+"] = {handled = make_trans_op("..")},
                            ["=="] = {handled = make_trans_op("==")},
                            ["~="] = {handled = make_trans_op("~=")},
                            to = {
                                responders = {
                                    number = {unhandled = FLESH.artifact([[function (self)
                                        return {
                                            protocol = FLESH.KES:resolve(host_tuple.state.items[host_tuple.state.labels.number]).state,
                                            state = tonumber(self.state)}
                                    end]])}}}
                        }
                    }}),
                    FLESH.KES:write_entry(nil, {protocol = { -- userdata UNFINISHED (lua can operate with it)
                        responders = {
                        is = {handled = capability_check},
                        ["="] = make_host_res_init("userdata")}},
                    state = {}}),
                    FLESH.KES:write_entry(nil, {protocol = { -- function
                        responders = {
                        is = {handled = capability_check},
                        ["="] = make_host_res_init("function")}},
                    state = {
                        handled = FLESH.artifact([[function (self, arg)
                            local tuple_p
                            self.state
                        end]])
                    }}),
                    FLESH.KES:write_entry(nil, {protocol = { -- thread
                        responders = {
                            is = {handled = capability_check},
                            ["="] = make_host_res_init("thread")}},
                    state = {}}),
                    FLESH.KES:write_entry(nil, {protocol = { -- table
                        responders = {
                            is = {handled = capability_check},
                            ["="] = FLESH.artifact([[function (self, arg)
                                -- create from table literal and native
                                if (FLESH.capcheck(self,arg)) then return arg end -- literal uses same protocol, so we just passing
                                if (type(arg) == "table") then return {protocol = self.state,state = arg}} end
                                return -- Error manifest
                            end]])}},
                    state = {
                        responders = {
                            ["+"] = {handled = make_trans_op("..")},
                            ["=="] = {handled = make_trans_op("==")},
                            ["~="] = {handled = make_trans_op("~=")},
                            size = {handled = make_trans("#")},
                        },
                        handled = FLESH.artifact([[function (self, arg)
                            -- TODO: we somehow need to check if arg is a number or a manifest
                            return FLESH.import(self[arg.state]) -- we need to chanage the intent of import, so it would use this data
                        end]])
                    }}),
                    FLESH.KES:write_entry(nil, {protocol = { -- unknown
                        responders = {
                            is = {handled = capability_check},
                            ["="] = FLESH.artifact([[function (self, arg) -- UNFINISHED
                                return {protocol = self.state,state = arg}
                            end]])}},
                    state = {}}),
                }}}
        FLESH.KES:write_entry("host", host_tuple)

        FLESH.KES:write_entry("Protocol", { -- Protocol for new Protocols
            protocol = {
                responders = {
                    of = {handled = FLESH.artifact([[]])},
                    is = {handled = capability_check}, -- capability_check is shared artifact
                    ["="] = {handled = FLESH.artifact([[]])}
                },
                handled = FLESH.artifact([[]]), -- artifact for creating new protocol manifests
            },
            state = {
                is = capability_check
            }
        })
        FLESH.KES:write_entry("Manifest", { -- Protocol for directly constructing Manifests
            protocol = {
                responders = {
                    is = {handled = capability_check}, -- capability_check is shared artifact 
                    ["="] = {handled = FLESH.artifact([[return function (self, arg) 
                    
                    --we take Tuple from arg
                    --make manifest for the KES with actual lua tables
                    --store it inside KES (of course)
                    --add lua metatable so I won't have to chain KES accesses
                    --return new manifest's reference

                end]])},
                },
            },
            state = {} -- thats the any type
        })
        
        FLESH.KES:write_entry("//", {protocol = {
            handled = FLESH.artifact("return function (self, arg) return { protocol = { handled = FLESH.artifact(\"return function (self, arg) return arg end\")}} end")}})
        FLESH.KES:write_entry("gap", {protocol = {}, state = {}})
        


        FLESH.KES:write_entry("Number", FLESH.KES:resolve(host_tuple.state.items[host_tuple.state.labels.number]))
        FLESH.KES:write_entry("String", FLESH.KES:resolve(host_tuple.state.items[host_tuple.state.labels.string]))
        FLESH.KES:write_entry("Label", { -- it's job is just labeling manifests
            protocol = {
                is = {handled = capability_check},
                ["="] = {handled = FLESH.artifact([[]])}
            },
            state = {
                responders = {
                    [":"] = {unhandled = FLESH.artifact([[return function (self)
                        FIS.pending_labels[self.state.name] = true
                        return { protocol = { handled = FLESH.artifact("return function (self, arg) return arg end")} }end]])},
                    ["name"] = {unhandled = FLESH.artifact([[return function (self)
                        return {
                            protocol = FLESH.KES.bindings[FLESH.KES.bindings.String.records[FLESH.host_layer] ].records[FLESH.host_layer].state,
                            state = self.state.name}
                    end]])},
                },
                unhandled = FLESH.artifact([[return function (self) 
                    return FLESH.KES:resolve(self.state.name)
                end]])
            }
        })
        FLESH.KES:write_entry("Tuple", {
            protocol = {
                is = {handled = capability_check},
                ["="] = {handled = FLESH.artifact([[]])}
            },
            state = {
                responders = {
                    ["+"] = {handled = FLESH.artifact([[]])},
                    ["*"] = {handled = FLESH.artifact([[]])},
                    load = {unhandled = FLESH.artifact([[return function (self)
                        local labels, items = self.state.labels, self.state.items
                        if labels then
                            if items then
                                for i,e in pairs(labels) do
                                    FIS.pending_labels[i] = true -- items[e]... FIS.pending_labels can't sustain this, I need different interface for passing pending context effects. I also have same problem in membranes
                                end end end end]])},
                    ["."] = {unhandled = FLESH.artifact([[return function (self) --TODO
                        self.state.labels
                    end]])},
                },
                handled = FLESH.artifact([[return function (self, arg) 
                    local num_p = FLESH.KES.bindings[FLESH.KES.bindings.Number.records[FLESH.host_layer] ].records[FLESH.host_layer]
                    if (FLESH.capcheck(num_p, arg)) then

                    else if (FLESH.capcheck({state = self.protocol}, arg) and arg) then -- slicing in python style

                    else

                    end
                end]])
            }
        })
        FLESH.KES:write_entry("Sequence", {
            protocol = {
                is = {handled = capability_check},
                ["="] = {handled = FLESH.artifact([[]])}
            },
            state = {
                responders = {
                    prods = {unhandled = FLESH.artifact([[]])}, -- in order to get raw data, @ must be used
                    creturn = {unhandled = FLESH.artifact([[]])}, -- in order to get raw data, @ must be used
                    introspect = {unhandled = FLESH.artifact([[]])}
                },
                handled = FLESH.artifact([[return function (self, arg)
                    local prods = self.state.prods
                    FLESH.KES:push_layer(self.state.parent, self.state.grounded, self.state.isolated, FLESH.FIS.tail_context or table.create(0, #prods))
                    local pl = {}
                    FIS.pending_labels = pl
                    local tuple_p = FLESH.KES.bindings[FLESH.KES.bindings.Tuple.records[FLESH.host_layer] ].records[FLESH.host_layer]
                    if (FLESH.capcheck(tuple_p, arg)) then FLESH.dispatch(arg,nil,arg.protocol.responders.load) end
                    for i,e in pairs(FIS.pending_labels) do FLESH.KES:write_entry() end
                    for i,e in ipairs(prods) do
                        local s = FLESH.KES:resolve(e)
                        pl = {}
                        FIS.pending_labels = pl
                        FIS.def_grounded, FIS.def_isolated = false, false
                        if (s.protocol.unhandled) then s = FLESH.dispatch(s, nil, s.protocol) end
                        for i,e in pairs(pl) do FLESH.KES:write_entry(i, s) end
                    end
                    FIS.pending_labels = {} 
                    local s = FLESH.KES:resolve(self.state.creturn)
                    --FLESH.FIS.tail_context = FLESH.KES.layers[#FLESH.KES.layers]
                    if (s.protocol.unhandled) then s = FLESH.dispatch(s, nil, s.protocol) end -- no TCO due to inderection
                    FLESH.KES:pop_layer()
                    return s
                end]])
            }
        })
        FLESH.KES:write_entry("Membrane", { -- controls effect(or context layer mutations) propogation of current context layer relative to other context layers
            protocol = {
                is = {handled = capability_check},
                ["="] = {handled = FLESH.artifact([[]])}
            },
            state = {
                unhandled = FLESH.artifact([[return function (self) -- do consider that this is definition of something, meaning it paints
                    local content = FLESH.KES:resolve(self.state.content)
                    --if content and content.state then
                        if (self.state.kind == 2) then -- grounded
                            -- store context, where this membrane was defined
                            FIS.def_grounded = true -- should have probably done direct Sequence manipulation, instead of using FIS, but on other side I should add handled clause to sequence for specifying what mode to use
                        elseif (self.state.kind == 1) then -- dynamic (or wrapper)
                            -- neutral, inherit active behaviour. If user desire default behaviour
                        elseif (self.state.kind == 0) then -- isolated
                            FIS.def_isolated = true
                            -- outer implicit mutation from inner is restricted at definition context layer
                        else
                            return {
                                protocol = FLESH.assets.protocols.Error,
                                state = {
                                    desc = "Membrane: Invalid kind"
                            }}
                        end-- end
                    return FLESH.dispatch(content, nil, content.protocol)
                end]]),
            }
        })
        FLESH.KES:write_entry("Negotiation", {
            protocol = {
                is = {handled = capability_check},
                ["="] = {handled = FLESH.artifact([[]])}
            },
            state = {
                bindings = {
                    
                },
                unhandled = FLESH.artifact([[return function (self)
                    -- resolve terms: we hold references in state, not data
                    local lt = FLESH.KES:resolve(self.state.lterm)
                    local rt = FLESH.KES:resolve(self.state.rterm)
                    
                    return FLESH.dispatch(lt, rt, lt.protocol)
                end]])
            }
        })
        FLESH.KES:write_entry("false", {
            protocol = FLESH.KES:resolve("Number").state,
            state = {value = FLESH.KES:write_entry(nil,{external = 0})}})
        FLESH.KES:write_entry("true", {
            protocol = FLESH.KES:resolve("Number").state,
            state = {value = FLESH.KES:write_entry(nil,{external = 1})}})
        FLESH.KES:write_entry(host_name, {
            protocol = FLESH.KES:resolve("String").state,
            state = {value = FLESH.KES:write_entry(nil,{external = "Lua 5.5"})}})

        local AST = { -- refactoring the Sequence generator for parser
            GAP = function () 
                return "gap" -- we don't have anything on here
            end,
            NUMBER = function (value)
                return FLESH.KES:write_entry(nil, {
                    protocol = FLESH.KES.bindings[FLESH.KES.bindings.Number.records[FLESH.host_layer]].records[FLESH.host_layer].state,
                    state = value}) end,
            STRING = function (value)
                return FLESH.KES:write_entry(nil, {
                    protocol = FLESH.KES.bindings[FLESH.KES.bindings.String.records[FLESH.host_layer]].records[FLESH.host_layer].state,
                    state = value}) end,
            LABEL = function (name)
                return FLESH.KES:write_entry(nil, {
                    protocol = FLESH.KES.bindings[FLESH.KES.bindings.Label.records[FLESH.host_layer]].records[FLESH.host_layer].state,
                    state = {name = name}}) end,
            TUPLE = function (items) -- TODO: this one isn't a tuple, but a constructor for it that creates environment for writing, like Sequence
                return FLESH.KES:write_entry(nil, { -- constructor
                    protocol = {unhandled = FLESH.artifact([[return function (self)
                        -- it's easier to do the lua way on lua side, though later I'll need to repalce it with Manifest that don't create another artifact like this
                        local items = self.state.items
                        local proc_items = table.create and table.create(#items) or {}
                        local labels = table.create and table.create(0,#items) or {}
                        for i,e in ipairs(items) do
                            local pl = {}
                            FIS.pending_labels = pl
                            local m = FLESH.KES:resolve(e)
                            proc_items[#proc_items+1] = FLESH.dispatch(m, nil, m.protocol)
                            for k,v in pairs(pl) do
                                labels[k] = #proc_items end end
                        return FLESH.KES:write_entry(nil,{
                            protocol = FLESH.KES.bindings[FLESH.KES.bindings.Tuple.records[FLESH.host_layer] ].records[FLESH.host_layer].state,
                            state = {items = proc_items, labels = labels}
                        })
                    end]])},--ref to manifest for running an evaluation (that would be Sequence or Artifact).
                    state = {items = items}}) end,
            SEQUENCE = function (prods, creturn) -- Sequence holds quoted stuff, so we are not doing any actual construction
                return FLESH.KES:write_entry(nil,{
                    protocol = {
                        unhandled = FLESH.artifact([[return function (self)
                            return FLESH.KES:write_entry(nil, {
                                protocol = FLESH.KES:resolve("Sequence").state,
                                state = {grounded = FIS.def_grounded or false, isolated = FIS.def_isolated or false, prods = self.state.prods, creturn = self.state.creturn, parent = FLESH.get_context()}
                            })
                        end]])},
                    state = {
                        prods = prods, creturn = creturn
                    }}) end,
            MEMBRANE = function (kind, content) 
                return FLESH.KES:write_entry(nil, {
                    protocol = FLESH.KES.bindings[FLESH.KES.bindings.Membrane.records[FLESH.host_layer]].records[FLESH.host_layer].state,
                    state = {kind = kind, content = content}}) end,
            NEGOTIATION = function (lterm, rterm) -- evaluation units
                return FLESH.KES:write_entry(nil, {
                    protocol = FLESH.KES.bindings[FLESH.KES.bindings.Negotiation.records[FLESH.host_layer]].records[FLESH.host_layer].state,
                    state = {lterm = lterm, rterm = rterm}}) end
        }

        local manifest = { -- manifest structure reference
            template = { 
                protocol = { -- always table
                    responders = {}, -- prio, find appropriate Label in front of manifest (maybe I should make this into tuple, that depicts the environment for the label in front of it)
                    handled = nil, -- not found appropriate Label in responders, do it if there is negotiation
                    unhandled = nil, -- not found appropriate Label in responders, do it anyways with (if no handled) or without negotioation. this rule exist to describle labels
                },
                state = { -- internal state of manifest, could be used by protocol above. represent 
            
        }}}

        FLESH:reset()
        return FLESH
    end
            
    return {
    _VERSION="0.0.1",
    newstate = newstate,
    manifest = manifest, -- subject for removal in favour of docs
    parse = (function ()
        local table_invert = function (t)
            local s={}
            for k,v in pairs(t) do
                s[v]=k
            end
            return s
        end

        -- Parser assets and constants
        local TOKENTYPE = { -- enumeration for tokenizer
            NUMBER = 0,
            STRING = 1,
            LABEL = 2,
            MEMBRANE_OPEN = 3,
            MEMBRANE_CLOSE = 4,
            FINISH_ELEMENT = 5,
            FINISH_ACTION = 6
        }

        local tokenname = table_invert(TOKENTYPE)

        -- Internal AST node creators (for parser output)
        --as state API matures, I should replace types with actual manifest creation commands from API.
        --so I have plans to make ast nodes obsolete
        --but this table will remain as interface that parser uses, I will just replace what those functions will do
        local AST = { -- what parser uses to make "AST"
            GAP = function () return {type = 0} end, -- part of language. helps in tracking gaps in tuples and sequences
            NUMBER = function (value) return {type = 1, value = value} end,
            STRING = function (value) return {type = 2, value = value} end,
            LABEL = function (name) return {type = 3, name = name} end,
            TUPLE = function (items) return {type = 4, items = items} end,
            SEQUENCE = function (prods, creturn) return {type = 5, prods = prods, creturn = creturn} end,
            MEMBRANE = function (kind, content) return {type = 6, kind = kind, content = content} end,
            NEGOTIATION = function (lterm,rterm) return {type = 7, lterm = lterm, rterm = rterm} end
        }
        
        -- Internal: Recursive descent parsers (one per non-terminal)
        local parse_term, parse_negotiation, parse_product, parse_sequence

        parse_term = function(tokens, pos)
            local tok
            if pos <= #tokens then
                tok = tokens[pos]
                if tok.type == TOKENTYPE.MEMBRANE_OPEN then -- handle membrane: isolated | dynamic | grounded
                    local kind = tok.value
                    local seq, new_pos = parse_sequence(tokens, pos + 1)
                    pos = new_pos
                    local concl = tokens[pos]
                    if (concl == nil) then -- TODO: make this mess unified, there are a lot of repetition
                        error(
                            "parse_term ERROR: Expected membrane_close '"..
                            string.sub(")}]",tok.value+1,tok.value+1)..
                            "', but got nothing. Membrane begins "..
                            " at line:"..tostring(tok.at.line)..
                            ", char:"..tostring(tok.at.char), 2)
                    elseif (concl.type ~= TOKENTYPE.MEMBRANE_CLOSE) then
                        error(
                            "parse_term ERROR: Expected membrane_close for some reason (probably parser bug, because it's implicitly checked), but got '"..
                            tokenname[concl.type]..
                            "' at line:"..tostring(concl.at.line)..
                            ", char:"..tostring(concl.at.char), 2)
                    elseif (concl.value ~= kind) then
                        error(
                            "parse_term ERROR: Bracket missmatch. Forgot to open with '"..
                            string.sub("({[",tok.value+1,tok.value+1)..
                            "' membrane? Expected this membrane to close with '"..
                            string.sub(")}]",tok.value+1,tok.value+1)..
                            "' at line:"..tostring(concl.at.line)..
                            ", char:"..tostring(concl.at.char), 2)
                    end
                    return AST.MEMBRANE(kind, seq), pos + 1
                elseif tok.type == TOKENTYPE.NUMBER then -- handle NUMBER
                    return AST.NUMBER(tok.value), pos + 1
                elseif tok.type == TOKENTYPE.STRING then -- handle ESCAPED_STRING
                    return AST.STRING(tok.value), pos + 1
                elseif tok.type == TOKENTYPE.LABEL then -- handle label
                    return AST.LABEL(tok.value), pos + 1
                elseif -- handle gap
                    -- the code below generates ast_gap, to help tracking gaps inside sequences or tuples
                    -- we can throw gap only if expeted term terminated by one of those 2 tokens
                    tok.type == TOKENTYPE.FINISH_ELEMENT or 
                    tok.type == TOKENTYPE.FINISH_ACTION then
                    return AST.GAP(), pos
                end
            end
            -- this could happen in cases like `blabla;` where after `;` there's eof or membrane_close
            -- this means that there's nothing we can use to create term, but higher parse expects something
            return nil, pos -- so while we're at it, we just tell higher up that no valid term found
        end
                
        parse_negotiation = function(tokens, pos) -- handle negotiation: term term //left associative 
            local term, new_pos = parse_term(tokens, pos)
            pos = new_pos
            if (term == nil) then return nil, pos end

            local tok = tokens[pos] -- slight optimization
            local node = term
            while 
                tok and (
                tok.type == TOKENTYPE.MEMBRANE_OPEN or 
                tok.type == TOKENTYPE.NUMBER or 
                tok.type == TOKENTYPE.STRING or 
                tok.type == TOKENTYPE.LABEL) do -- Check if next token is a term (not a delimiter)
                term, pos = parse_term(tokens, pos) -- previous check guarantees that parse_term won't return (nil, pos)
                tok = tokens[pos] -- we update tok
                node = AST.NEGOTIATION(node, term) -- Keep nesting leftwards
            end
            return node, pos
        end
        
        local check_token = function (tok, tt)
            return (tok ~= nil) and tok.type == tt
        end

        parse_product = function(tokens, pos) -- handle ?product: tuple | term
            local term, new_pos = parse_negotiation(tokens, pos)
            pos = new_pos
            if check_token(tokens[pos], TOKENTYPE.FINISH_ELEMENT) then -- it's a tuple
                -- there must be comma, but trailing one is optional. 
                -- meaning (5,) must be valid tuple with 1 element,
                -- while (5) is just the element
                local items = {term}
                repeat
                    pos = pos + 1
                    term, pos = parse_negotiation(tokens, pos)
                    if term then -- for the sake of trailing comma, there might be nil
                        table.insert(items, term)
                    end
                until not check_token(tokens[pos], TOKENTYPE.FINISH_ELEMENT)
                return AST.TUPLE(items), pos
            else -- it's not a tuple
                return term, pos -- could return (nil, pos) from parse_term and thats fine
            end
        end
        
        parse_sequence = function(tokens, pos) -- handle ?sequence: (product ";")* [creturn]
            local term, new_pos = parse_product(tokens, pos)
            pos = new_pos
            -- we could have no sequence at all, so first thing we check if there is sequence
            if check_token(tokens[pos], TOKENTYPE.FINISH_ACTION) then -- it's a sequence
                -- there must be semicolon, but trailing one sets creturn to nil. 
                -- meaning (5;) must be valid sequence with 1 element,
                -- while (5) is just the element,
                -- but if it's (5;5), last element conidered as return value on membrane finish
                local prod = {}
                local ret = term
                repeat
                    table.insert(prod, ret)
                    ret = nil
                    pos = pos + 1
                    term, pos = parse_product(tokens, pos)
                    if term then -- sometimes there might be not vaild term after semicolon
                        ret = term
                    end
                until not check_token(tokens[pos], TOKENTYPE.FINISH_ACTION)
                return AST.SEQUENCE(prod, ret), pos
            else -- it's not a sequence
                return term, pos -- could return (nil, pos) from parse_term and thats fine
            end
        end

        local tokenize = function(code)
            local tokens = {}
            local i = 1
            local line = 1
            local choff = 0
            while i <= #code do
                local c = code:sub(i, i)
                if c:match("%s") then  -- Skip whitespace
                    if c == "\n" then 
                        line = line + 1
                        choff = i
                    end
                    i = i + 1
                --elseif c == "0" and code:sub(i+1,i+1):lower() == "x" then -- Number Hex (syntax sugar. Removed in favour of Ada/Smalltalk responder)
                --    local hex = code:match("^0x%x+", i)
                --    table.insert(tokens, {type = TOKENTYPE.NUMBER, value = tonumber(hex), at = {char = i - choff, line = line}})
                --    i = i + #hex
                --elseif c == "0" and code:sub(i+1,i+1):lower() == "b" then -- Number Binary
                --    local bin = code:match("^0b[01]+", i)
                --    local val = tonumber(bin:sub(3), 2)
                --    table.insert(tokens, {type = TOKENTYPE.NUMBER, value = val, at = {char = i - choff, line = line}})
                --    i = i + #bin
                elseif c:match("%d") then -- Number Scientific/Basic
                    local num = code:match("^%d+%.?%d*[eE][+-]?%d+", i) or 
                                code:match("^%d+%.?%d*", i)
                    table.insert(tokens, {type = TOKENTYPE.NUMBER, value = tonumber(num), at = {char = i - choff, line = line}})
                    i = i + #num
                elseif c == '"' then  -- String
                    local value = {}
                    local i_start = i
                    i = i + 1  -- skip opening quote
                    
                    while i <= #code do
                        local ch = code:sub(i, i)
                        
                        if ch == '\\' then
                            -- Escape sequence
                            i = i + 1
                            if i > #code then
                              error("Unfinished escape sequence at end of string", 2)
                            end
                            local next = code:sub(i, i)

                            if next == 'n' then
                                table.insert(value, '\n')  -- Newline
                            elseif next == 't' then
                                table.insert(value, '\t')  -- Tab
                            elseif next == 'r' then
                                table.insert(value, '\r')  -- Carriage return
                            elseif next == '"' then
                                table.insert(value, '"')   -- Escaped quote
                            elseif next == '\\' then
                                table.insert(value, '\\')  -- Escaped backslash
                            else
                                -- Unknown escape: treat literally (or error)
                                table.insert(value, '\\')
                                table.insert(value, next)
                            end
                            i = i + 1
                        
                        elseif ch == '\n' then
                            -- Direct Newlines are whitespace even here
                            line = line + 1
                            choff = i  -- Reset char offset after newline
                            i = i + 1
                        elseif ch == '"' then
                            -- Closing quote
                            i = i + 1
                            break
                        else
                            -- Regular character
                            table.insert(value, ch)
                            i = i + 1
                        end
                    end

                    table.insert(tokens, {
                        type = TOKENTYPE.STRING, 
                        value = table.concat(value), 
                        at = {char = i_start - choff, line = line}
                    })
                elseif c:match("[a-zA-Z_]") then  -- CNAME label
                    local label = code:match("^[_a-zA-Z][_a-zA-Z0-9]*", i)
                    table.insert(tokens, {type = TOKENTYPE.LABEL, value = label, at = {char = i - choff, line = line}})
                    i = i + #label
                elseif c:match("^[+%-*/%%=<>!&|^~:@#%.`$]+$") then  -- SNAME label symbol
                    local sym = code:match("^[+%-*/%%=<>!&|^~:@#%.`$]+", i)
                    table.insert(tokens, {type = TOKENTYPE.LABEL, value = sym, at = {char = i - choff, line = line}})
                    i = i + #sym
                elseif c == "(" or c == "{" or c == "[" then  -- Open brackets
                    table.insert(tokens, {
                        type = TOKENTYPE.MEMBRANE_OPEN,
                        value = ({["("]=0,["{"]=1,["["]=2})[c], 
                        at = {char = i - choff, line = line}})
                    i = i + 1
                elseif c == ")" or c == "}" or c == "]" then  -- Close brackets
                    table.insert(tokens, {
                        type = TOKENTYPE.MEMBRANE_CLOSE, 
                        value = ({[")"]=0,["}"]=1,["]"]=2})[c], 
                        at = {char = i - choff, line = line}})
                    i = i + 1
                elseif c == "," then
                    table.insert(tokens, {type = TOKENTYPE.FINISH_ELEMENT, at = {char = i - choff, line = line}})
                    i = i + 1
                elseif c == ";" then
                    table.insert(tokens, {type = TOKENTYPE.FINISH_ACTION, at = {char = i - choff, line = line}})
                    i = i + 1
                else
                    error("Unexpected character: '" .. c .. "' at line:"..tostring(line)..", char:"..tostring(i - choff), 2)
                end
            end
            return tokens
        end
        return function (src)
            local tokens = tokenize(src)
            local ast, pos = parse_sequence(tokens, 1)
            if pos <= #tokens then
                error("Parse error: extra tokens after sequence", 2)
            end
            return ast
        end 
    end)() -- returns src's AST prepared for loading into NegI state via FLESH.load (and yes, it's a function constructor)
} end)()