--TODOs:
-- 1. Host representation. Lua have quite messy syntax and context, we need to nicely wrap this up inside some Manifest or Frame.
-- 2. Just finish manifests (Especially Error, to check if we getting stuck in halt)
-- 3. Tokens should keep track of current evaluated data by having access to the Host device (like Artifacts do), but here in PoC we just refere to it directly through FISH due to "it's convinient" and "that stuff is depandant on host"

return (function ()
    --Frontend: NegI - Negotiation Interface (the interface, what is developed, that's the front name)
    --Backend: OPHANIM - Ontological Polymorphic Host for Authority and Negotiation Interface Management (the substrate, NegI implementation)
    local pprint = require("pprint") -- remove after fixing problems
    -- This works more or less as ship of thesus, OPHANIM provides common interfaces for other manifests to communicate with each other in platform agnostic way
    local newstate = function () -- something similar to lua_newstate but for OPHANIM
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
        local FLESH = { -- stands for "Fixed Local Environment Shared Handles"
            FISH = { -- "Fixed Internal State Holder" - used by particular manifests to pass around some data. Could be avoided via KES, but those values are quite commonly used, so it will influence performance.
                -- probably reserved for parser tokens, but I might leave that up to Tokens themselves
            },
            KES = { -- "Knowledge Environment State" (considered finished, until bugs will be found)
                layers = {{d = 1,h = {r={},i={}},s = {a={},e={},r={}},c = {}}}, -- stack of references, string names ready for free (initial layer is preloaded)
                labels = {lb = {}, bl = {}}, -- BiMap<label: String, bind: Number> holds labeled refences, bimap/not in bindings - because it's an extension that exist only for the user
                bindings = {}, -- Array<bind: Number, {records: Map<layer_id: Integer, entry: Manifest>, order: BiMap<layer_id: Integer, order: Integer>}> holds references to data
                relevance = { -- tracks what currently available in active context
                    dl = {[1]=1}, -- Array<depth: Integer, layer_id: Integer> 
                    ld = {[1]=1}}, -- Map<layer_id: Integer, depth: Integer> stores which layers are relevent to current context, mostly used as Set<layer_id: Integer>
                isolations = { -- tracks to which layer unquotation should latch. basically ordered Set<depth: Integer>
                    ["od"] = {}, -- Array<order: Integer, depth: Integer> - we use this to iterate through them
                    ["do"] = {}}, -- Map<depth: Integer, order: Integer> - that the depths of those, also "do" key is the reason I hate keywords
                
                resolve = function (self, ref, framed) -- note that strings are names for indicies, "framed" is used by Frame to get data from current Frame
                    if (type(ref) ~= "string" and type(ref) ~= "number") then
                        error("OPHANIM: FLESH.KES:resolve - invalid argument, expected number or string", 2)
                    end
                    ref = (type(ref) == "number") and ref or self.labels.lb[ref] -- we override the table depending on what we resolving
                    local rt = self.bindings[ref]
                    if (rt == nil) then return end -- the environment don't know about this binding so we exit early, this line is optional
                    local m, fh -- data, from_here
                    if (#rt.order.ol > #self.relevance.dl) or framed then -- NOTE: records store changes per each layer, so this checks if it's effective to do vertical or horizontal search traversal
                        for d = #self.relevance.dl, framed and #self.relevance.dl or 1, -1 do -- inverse order, because we pick fresh ones, in order to hit early
                            local l = self.relevance.dl[d]
                            if rt.order.lo[l] then m = rt.records[l]; fh = (#self.layers == l); break end -- we do not use rt.records[e], because it may contain nil, due to "namespace" reservation
                        end
                    else
                        for o = #rt.order.ol, 1, -1 do -- inverse order, because we pick fresh ones, in order to hit early
                            local l = rt.order.ol[o]
                            if self.relevance.ld[l] then m = rt.records[l]; fh = (#self.layers == l); break end
                        end
                    end
                    return m, fh -- Manifest(lua table, that represnts it) and if this info from current layer
                end,
                push_layer = function (self, parent, isolated, context) -- adds new layer
                    --we make an exception for root layer, because there's nothing to isolate against
                    local not_root = (#self.layers > 0)
                    -- initial layer is preloaded, but I still add it if user decide to pop the root layer and there will be those who would like to do that for the fun of it (hi tsoding)
                    if (not_root and (type(parent) ~= "number")) then error("OPHANIM: FLESH.KES:push_layer - parent<number> expected, got "..type(parent), 2) end -- I also think that root layers should be definable if no parent specified
                    local l = { -- new layer data
                        d = ((parent and not_root) and self.layers[parent].d or 0) + 1, -- new layer depth
                        h = {r={},i={}}, -- those are hidden layers (r - relevance, i - isolation)
                        s = {a={},e={},r={}}, -- staged entries data: aliases(aka refs), entries and reserved aliases
                        c = context or {}} -- `c` is Set<reference: Number|String, exist: Boolean> references relvant to this context layer
                    if isolated then bimap_write(self.isolations, "od", #self.isolations.od+1, l.d) end -- isolated (external binding resolving, causes it to use resolving oblivious to effects from here)
                    for d = #self.relevance.dl, l.d, -1 do -- exclude all layers between parent and new layer via depth
                        l.h.r[#l.h.r+1] = self.relevance.dl[d] -- hide layers (we can ask depth form them directly)
                        bimap_write(self.relevance, "dl", d, nil) -- removing irrelevant layers
                        if self.isolations["do"][d] then -- check if there is isolation
                            l.h.i[#l.h.i+1] = d -- hide isolations (we can ask depth form them directly)
                            bimap_write(self.isolations, "do", d, nil) end end -- removing irrelevant isolations
                    self.layers[#self.layers+1] = l
                    bimap_write(self.relevance, "ld", #self.layers, l.d)
                    return #self.layers -- used if Sequence will define another Sequence
                end,
                pop_layer = function (self, frame) -- P.S. while push and pop suggest stack structure, this isn't purely just that due to parent detours
                    local l = self.layers[#self.layers]
                    local db = self.bindings
                    if self.isolations["do"][l.d] then bimap_write(self.isolations, "do", l.d, nil) end -- lift isolation sandbox (if there is any)
                    local hidden_layers = l.h -- there is always hidden entries
                    for _,e in ipairs(hidden_layers.r) do -- restoring hidden context relevance
                        bimap_write(self.relevance, "ld", e, self.layers[e].d) end
                    for i = #hidden_layers.i, 1, -1 do -- restoring hidden context isolations
                        bimap_write(self.isolations, "od", #self.isolations.od + 1, hidden_layers.i[i]) end
                    local frame_state = {labels = {lb={},bl={}}, bindings = {}}
                    local frame_entry = frame and function (self, b, rt)
                        frame_state.bindings[#frame_state.bindings+1] = {delta = rt.records[#self.layers]}
                        bimap_write(frame_state.labels, "bl", #frame_state.bindings, self.labels[b])
                    end or function (self, b, rt) end
                    for b,_ in pairs(self.layers[#self.layers].c) do -- removing references from bindings
                        local rt = db[b]
                        frame_entry(self, b, rt)
                        rt.records[#self.layers] = nil
                        if (rt.order.lo[#self.layers] == rt.order.ol[#rt.order.ol]) then
                            bimap_write(rt.order, "lo", #self.layers, nil)
                        else error("KES:pop_layer - invalid layer in unload transaction query. [Z_Z] Currently I'm thinking to keep it as user error or make code for handling this.", 2) end
                        if #rt.records <= 0 then db[b] = nil; bimap_write(self.labels, "bl", b, nil) end end
                    if (#self.layers > 0) then self.layers[#self.layers] = nil end -- removing layer
                    return frame and frame_state or nil 
                end,
                morph_layer = function (self, parent, isolated, context) -- push_layer, but just rebases current layer. for "pass" use. this is to remove migrate from pop_layer and rework context in push_layer
                    -- I also not sure if `pass` should keep previous context layer, which this function is implies to do, because `pass` created with explicit data transfer in mind, 
                    -- leaving something in context is implicit data transfer, which should be another explicit thing on it's own  (like snapshot into frames?)
                end,
                unquote_parent = function (self, parent) -- get parent of unquotation
                    local p_depth = (parent and self.layers[parent].d or 0) -- parent depth
                    local iso_depth_i, iso_depth = #self.isolations.od, nil
                    while ((self.isolations.od[iso_depth_i] or 0) > p_depth) do -- we check if layer definition was outside of isolation. also binary search could be applied here
                        iso_depth = self.isolations.od[iso_depth_i]
                        iso_depth_i = iso_depth_i - 1 end
                    if (iso_depth) then -- if dynamic defined outside isolation, then it shouldn't consider effect of isolation
                        return self.relevance.dl[iso_depth - 1] -- find parent of layer outside of isolation
                        --p_depth = (parent and (self.layers[parent].d) or 0) -- parent depth
                    else
                        return #self.layers 
                    end
                end,
                get_context = function (self) return #self.layers end, -- used by Membranes to memorize context for later use
                stage_resolve_id = function (self, ref) return self.layers[#self.layers].s.a[ref] end,
                stage_entry = function (self, data, stage_id) -- when `ref` is present, it updates info that references existing entry
                    local stage = self.layers[#self.layers].s
                    if stage_id and stage_id > #stage.e then error("FLESH.KES:stage_entry - stage_id points to undefined entry.", 2) end
                    if stage_id then -- explicit abscense of stage_id, will make a new entry
                        stage.e[stage_id].d = data
                        if stage.e[stage_id].r then
                            stage.r[stage.e[stage_id].r] = nil
                            stage.e[stage_id].r = nil end
                    else
                        stage_id = #stage.e+1
                        stage.e[stage_id] = {a={},r=nil,d=data} end -- a - aliases (holds both anonym bindings and label names), r - reserved (even nil might be the data, so we need to track this separately), d - data
                    return stage_id
                end,
                stage_alias = function (self, new_ref, stage_id)  -- when `ref` is present, it updates info that references existing entry
                    local stage = self.layers[#self.layers].s
                    if stage_id and stage_id > #stage.e then error("FLESH.KES:stage_alias - stage_id points to undefined entry.", 2) end
                    if stage_id then -- explicit abscense of stage_id, will make a new entry
                        stage.e[stage_id].a[#stage.e[stage_id].a +1] = new_ref
                    else
                        stage_id = #stage.e+1
                        stage.r[#stage.r +1] = stage_id
                        stage.e[stage_id] = {a={new_ref},r=#stage.r,d=nil} end -- a - aliases (holds both anonym bindings and label names), r - reserved (even nil might be the data, so we need to track this separately), d - data
                    stage.a[new_ref] = stage_id -- label can point only to one place, we don't discourage user from that
                    return stage_id
                end,
                stage_fill_reserve = function (self, data)
                    if (data and data.protocol) then
                        if (#data.protocol <= 0) then data = nil end -- somewhat hacky, but good enough for a `gap` check. Native might not like this
                    else data = nil end
                    local stage = self.layers[#self.layers].s
                    for _,i in ipairs(stage.r) do self:stage_entry(data, i) end
                end,
                commit = function (self, add_unnamed) -- apply staged changes
                    local stage = self.layers[#self.layers].s
                    local wue = add_unnamed and function (self, e)
                        e.b[#e.b+1] = self:write_entry(nil, e.d)
                    end or function (self, e) end
                    for _, e in ipairs(stage.e) do
                        e.b = {}
                        if (#e.a > 0) then for _, name in ipairs(e.a) do
                            e.b[#e.b+1] = self:write_entry(name, e.d) end
                        else wue(self, e) end end
                    local output = self.layers[#self.layers].s
                    self.layers[#self.layers].s = {a={},e={},r={}}
                    return output -- should be a map of entry -> binding, but for now it's fine
                end,
                write_entry = function (self, ref, m) -- reference : Number|String, [manifest: Any|Nil]
                    local db = self.bindings
                    if (type(ref) == "string") then 
                        bimap_write(self.labels, "lb", ref, self.labels.lb[ref] or (#db + 1))
                        ref = self.labels.lb[ref] 
                    else ref = ref or (#db + 1) end -- while it's discouraged to use directly, we provide necessary functionality for user
                    db[ref] = db[ref] or { records = {}, order = {ol = {}, lo = {}} }
                    db[ref].records[#self.layers] = m -- note that nil will reserve the place on layer
                    bimap_write(db[ref].order, "lo", #self.layers, #db[ref].order.lo + 1)
                    if not self.layers[#self.layers].c[ref] then -- if it's new binding for this context
                        self.layers[#self.layers].c[ref] = true
                    end return ref
                end, -- entry writes could only happen in current context
                direct_snapshot = function (self, layer_id, frame_state) -- THIS IS RAW AUTHORITY THAT VOIDS SECURITY GUARANTEES
                    frame_state = frame_state or {labels = {lb={},bl={}}, bindings = {}} -- when provided, pours effects directly
                    for b,_ in pairs(self.layers[layer_id].c) do
                        frame_state.bindings[#frame_state.bindings+1] = {delta = self.bindings[b].records[#self.layers]}
                        bimap_write(frame_state.labels, "bl", #frame_state.bindings, self.labels[b]) end
                    return frame_state end,
                inner_snapshot = function (self) -- used in Frame, in order to track writes
                    return self:direct_snapshot(#self.layers)
                end,
                view_snapshot = function (self, outer)
                    local frame_state = {labels = {lb={},bl={}}, bindings = {}}
                    for i = 1, #self.relevance.dl - (outer and 1 or 0) do -- we still will be traversing every layer, so it's recomended that user shouldn't use it
                        self:direct_snapshot(i,frame_state)
                    end
                    return frame_state
                end,
                env_snapshot = function (self, outer) -- same as view_snapshot, but provides in depth trace of context changes layer by layer
                    -- table with Frame manifests that inherit from each other
                    -- though I think I can provide an interface for KES access through special resolves per layers, instead of doing all of this
                    -- THIS IS AN AUTHORITY FOR DEBUGGER, THIS VIOLATES SECURITY GUARANTEES
                end,
                log_bindings = function (self, table_print)
                    for b,d in pairs(self.bindings) do
                        io.write((self.labels[b] or "<binding "..tostring(b)..">")..": ")
                        table_print(d.records)
                    end
                end,
                --binding_label_get = function (self, b) return self.labels.bl[b] end, -- Used by Frame to make label list. probably pe replaced by 'pop_layer' Frame return
            },
            dispatch = function (self, lterm, rterm, protocol) -- needs debugging
                --print("dispatch start")
                if lterm == nil then error("FLESH:dispatch - got nil, expected Manifest") return end
                protocol = protocol or lterm.protocol -- protocol argument is optional and here only for convinience, so I don't have to recreate manifest with transformed protocols
                if protocol then
                    if rterm then
                        if protocol.can then -- both "can" and "ask" may not be fulfilled unlike "can" or "get" or abscense of protocol clauses
                            --print("can?")
                            local label_p = self.NegI.Manifests.Label -- we use direct access, because this stuff will depend on furst record anyways
                            if self.capcheck(label_p, rterm) then 
                                local p = protocol.can[rterm.state.name]
                                return p and {protocol = p, state = lterm.state} or self.make.Error("OPHANIM: FLESH:dispatch Error: invalid `can` case") end end
                        if protocol.ask then -- `ask` clause exist solely for cases when Manifest need to handle arbitrary labels, like vector axis swizzling, field "modification" (the field might be abscent) and etc
                            --print("ask?")
                            local artifact_p = self.NegI.Manifests.Artifact -- currently it's tightly coupled, I'll need to slightly rework this
                            local label_p = self.NegI.Manifests.Label
                            local frame_p = self.NegI.Manifests.Frame
                            local clause = protocol.ask
                            if self.capcheck(label_p, rterm) then if self.capcheck(artifact_p, clause) then return clause.state.artifact(lterm, rterm)
                                else return self:dispatch(clause, self.make.Frame({self = lterm, arg = rterm})) end end end
                        if protocol.call then
                            --print("call?")
                            if rterm.protocol and rterm.protocol.get then rterm = self:dispatch(rterm, nil) end -- passive evaluation, because caller expect contents
                            local artifact_p = self.NegI.Manifests.Artifact
                            local frame_p = self.NegI.Manifests.Frame
                            local clause = protocol.call
                            return self.capcheck(artifact_p, clause) and
                                clause.state.artifact(lterm, rterm) or
                                self:dispatch(clause, self.make.Frame({self = lterm, arg = rterm})) -- needs some standartization on how this should be passed around, don't like hardcoded "self" and "arg"
                        elseif protocol.get then -- fallback to underlying manifest for an answer
                            --print("get.")
                            local artifact_p = self.NegI.Manifests.Artifact
                            local frame_p = self.NegI.Manifests.Frame
                            local clause = protocol.get
                            local fabk = self.capcheck(artifact_p, clause) and
                                clause.state.artifact(lterm) or self:dispatch(clause, lterm)
                            return self:dispatch(fabk, rterm)
                        else return self.make.Error("OPHANIM: FLESH:dispatch Error: rterm is outside of lterm protocol capability") end
                    elseif protocol.get then
                        --print("get explicit.")
                        local artifact_p = self.NegI.Manifests.Artifact
                        local clause = protocol.get
                        if self.capcheck(artifact_p, clause) then
                            return clause.state.artifact(lterm)
                        else return self:dispatch(clause, lterm) end
                    else return lterm end
                elseif rterm then return self.make.Error("OPHANIM: FLESH:dispatch Error: missing protocol")
                else return lterm end
            end,
            --env methods
            reset = function (self) end, -- inits defaults and other stuff
        }

        -- Artifact assumptions:
        -- on call it recieves 2 manifests (tabels, not KES IDs): self, arg
        -- on get it's just self (tables, not KES IDs)
        -- the return should return Manifest (tables, not KES IDs)

        --I need to make things clear:
        --Inside Manifest state is opaque host resource.

        FLESH.make = {} -- Manifest constructors

        FLESH.make.Manifest = function (protocol, state) -- protocols are still eager, but it's possible to do lazy clause access via "get" manifests (like quoted labels). here we just doing it via metatable because it's convinient, and I'm making a PoC, not final product yet
            local m = {protocol = protocol, state = state}
            
            if type(protocol) ~= "table" then 
                local frra = FLESH.KES:resolve(protocol) -- I do wonder if I should just pull from NegI.Manifests at this point

                if frra then -- convinence
                    m.protocol = frra.state
                else
                    setmetatable(m, { __index = function (t,k) -- lazy fetch, becuase some Manifests rely on that
                        local v = rawget(t,k)
                        if k == "protocol" then
                            setmetatable(t,nil)
                            v = FLESH.KES:resolve(v).state
                            t.protocol = v end -- should be fine after lifting metatable
                        return v end })end end
            return m
        end

        FLESH.NegI = {Manifests = {}} -- the NegI assets

        FLESH.NegI.Manifests.Artifact = { -- Artifact for handling external authority
            protocol = {
                can = {
                    ["in"] = {call = "stub"},
                    ["="] = {call = "stub"}}},
            state = {
                can = {
                    reload = {get = "stub"}},
                    introspect = {get = "stub"}, -- can't decide on a name yet, should return ingridients for cooking the authority in question
                call = "stub"}}
        
        local dcopy = function (t)
            -- I need to add function for explicit import/deep copy, because currently it's not sandboxed properly
            return t
        end

        local artifact_env = { -- it's an environment centered around debug tools and devlopment environment, so having all that stuff here is fine
            -- Lua Language Internals
            basic = basic,
            assert = assert, error = error, warn = warn,
            collectgarbage = collectgarbage,
            dofile = dofile, load = load, loadfile = loadfile,
            getmetatable = getmetatable, setmetatable = setmetatable,
            ipairs = ipairs, pairs = pairs,
            next = next, select = select, unpack = unpack or table.unpack,
            pcall = pcall, xpcall = xpcall,
            print = print,
            rawequal = rawequal, rawget = rawget, rawlen = rawlen, rawset = rawset,
            require = require,
            tonumber = tonumber, tostring = tostring,
            type = type,

            -- it's unlikely that those get modified. in some cases they might be abscent or not full
            table = dcopy(table),
            math = dcopy(math),
            string = dcopy(string),
            utf8 = dcopy(utf8),
            debug = dcopy(debug),
            coroutine = dcopy(coroutine),
            io = dcopy(io),
            os = dcopy(os),
            package = dcopy(package),
        
            -- The OPHANIM Substrate
            -- Artifacts MUST use this to interact with the system.
            FLESH = FLESH, 
        }

        FLESH.make.Artifact = function (chunk, chunkname, mode)
            chunkname = chunkname or "chunk"
            local a, e = load(chunk, "OPHANIM:"..chunkname, mode, artifact_env)
            if (e) then
                local error_p = FLESH.NegI.Manifests.Error
                if error_p then return FLESH.make.Manifest(
                    error_p.state, {desc = "Artifact: Failed to load "..chunkname.." due to host error: "..e})
                else print("in ```lua\n"..chunk.."\n```"); error("FLESH.make.Artifact - Artifact construction failed on NegI sys init due to host error:"..tostring(e), 2) end
            end
            ok, result = pcall(a)
            local callable_result = (type(a) == "function") or (getmetatable(a).__call)
            if (not callable_result) then
                if (not callable_result and ok) then result = "provided code is not callable!" end
                local error_p = FLESH.NegI.Manifests.Error
                if error_p then return FLESH.make.Manifest(
                    error_p.state, {desc = "Artifact: Failed to load "..chunkname.." due to host error: "..result})
                else print("in ```lua\n"..chunk.."\n```"); error("FLESH.make.Artifact - Artifact construction failed on NegI sys init due to host error:"..tostring(e), 2) end
            end
            return FLESH.make.Manifest(FLESH.NegI.Manifests.Artifact.state, {
                    chunk = chunk,
                    chunkname = chunkname,
                    mode = mode,
                    --env = env,
                    artifact = result})
        end

        FLESH.intentcheck = function(self, arg) -- State intent of manifests are matching?
            for i,e in pairs(self.state) do
                if (arg.protocol[i] ~= e) then
                    return false end end
            for i,e in pairs(self.state.can) do
                if (arg.protocol.can[i] ~= e) then
                    return false end end
            return true end

        FLESH.capcheck = function(self, arg) -- Even through fallbacks, is manifest implements this protocol?
            -- TODO: check protocol in flat form, we need to make sure clauses are reachable, not that there is inside chain some Manifest that satisfy intent.
            local fail = function () return arg.protocol.get and FLESH.capcheck(FLESH:dispatch(arg, nil)) or false end
            for i,e in pairs(self.state) do
                if (arg.protocol[i] ~= e) then
                    return fail() end end
            for i,e in pairs(self.state.can) do
                if (arg.protocol.can[i] ~= e) then
                    return fail() end end
            return true end

        --common between protocol manifests
        local capability_check = FLESH.make.Artifact([[return function (self, arg)
            return FLESH.make.Number(FLESH.capcheck(self, arg)) end]], "capcheck")
        
        FLESH.NegI.Manifests.Artifact.protocol.can["in"] = capability_check
        FLESH.NegI.Manifests.Artifact.protocol.can["="] = FLESH.make.Artifact([[return function (self, arg) end]])
        FLESH.NegI.Manifests.Artifact.state.can.reload = FLESH.make.Artifact([[return function (self)
            return FLESH.make.Artifact(self.state.chunk, self.state.chunkname, self.state.mode, self.state.env) end]])
        FLESH.NegI.Manifests.Artifact.state.can.introspect = FLESH.make.Artifact([[return function (self, arg) end]])
        FLESH.NegI.Manifests.Artifact.state.call = FLESH.make.Artifact([[return function(self, arg)
            local tunp = unpack or table.unpack
            return self.state.artifact(tunp(arg)) end]])

        FLESH.make.Frame = function (t)
            -- WARNING: the nested table is interface, but the content of it must be Manifests
            local s = {labels = {lb={},bl={}}, bindings = {}}
            --s.labels : BiMap<label: string, binding: number>
            --s.bindings : Array<bind: number, {parent: table, delta: number}|{delta: any}> -- for PoC it's enough, but I should later optimize it for memory, because inheriting lots of data would create lots of redundancy
            for k,v in pairs(t) do
                s.bindings[#s.bindings+1] = {delta = v} -- we adding data not inheriting data, so there's no parent
                if type(k) == "string" then -- I don't have plans on introducing numeric keys, because bindings already have these
                    bimap_write(s.labels, "lb", k, #s.bindings) end end
            return FLESH.make.Manifest("Frame", s)
        end

        FLESH.make.Error = function (desc) return FLESH.make.Manifest("Error", {desc = desc}) end -- this one should hold more info than currently it is. Prefereably it should be able to store an Error chain, this will be a common occurence in NegI.

        FLESH.make.Number = function (val)
            return (({
                number = function (num) return FLESH.make.Manifest(FLESH.NegI.Manifests.Number.state, num) end,
                boolean = function (bool) return bool and FLESH.NegI.Manifests["true"] or FLESH.NegI.Manifests["false"] end 
            })[type(val)] or (function (val) return FLESH.make.Error("invalid type (rework this error)") end))(val)
        end

        FLESH.make.String = function (val) 
            return (type(val) == "string") and 
                FLESH.make.Manifest(FLESH.NegI.Manifests.String.state, val) or 
                FLESH.make.Error("invalid type (rework this error)")
        end

        -- no implicit conversions, this is only between this specific implementation
        local make_trans_op = function (op)
            return FLESH.make.Artifact([[return function (self, arg)
                if (FLESH.capcheck({state = self.protocol},arg)) then -- 2nd value might have different protocol, I think I'll need to rework this into lua general value protocol check or something.
                    return FLESH:import(self.state ]]..op..[[ arg.state)
                else
                    return -- Error manifest
                end
            end]])
        end
        local make_trans = function (trans)
            return FLESH.make.Artifact([[return function (self)
                return FLESH:import(]]..trans..[[(self.state))
            end]])
        end
        local make_host_res_init = function (host_type)
            return FLESH.make.Artifact([[return function (self, arg)
                -- wrap host resource manifest
                if (type(arg) == "]]..host_type..[[") then return {protocol = self.state,state = arg} end
                if (FLESH.capcheck(self,arg)) then return arg end -- literal uses same protocol, so we just passing
                return -- Error manifest
            end]])
        end

        FLESH.Host = {}
        FLESH.Host.Types = { -- while it's a mapping table, OPHANIM fundamentally disagree with lua on type existance, so for example userdata can't be capchecked
            ["nil"] = FLESH.make.Manifest({},{}),
            boolean = FLESH.make.Manifest({
                    can = {
                        ["in"] = {call = capability_check},
                        ["="] = make_host_res_init("boolean")
                },{
                    can = {
                        ["|"] = {call = make_trans_op("or")},
                        ["&"] = {call = make_trans_op("and")},
                        ["~"] = {get = make_trans("not")},
                        ["=="] = {call = make_trans_op("==")},
                        ["~="] = {call = make_trans_op("~=")},
                        to = {
                            can = {
                                NegIManifest = {get = FLESH.make.Artifact("return function (self) return FLESH.make.Number(self.state) end")},
                    }}}
                }}),
            number = FLESH.make.Manifest({
                    can = {
                        ["in"] = {call = capability_check},
                        ["="] = make_host_res_init("number")
                },{
                    can = {
                        ["+"] = {call = make_trans_op("+")},
                        ["-"] = {call = make_trans_op("-")},
                        ["*"] = {call = make_trans_op("*")},
                        ["/"] = {call = make_trans_op("/")},
                        ["%"] = {call = make_trans_op("%")},
                        ["^"] = {call = make_trans_op("^")},
                        ["|"] = {call = make_trans_op("|")},
                        ["&"] = {call = make_trans_op("&")},
                        ["<<"] = {call = make_trans_op("<<")},
                        [">>"] = {call = make_trans_op(">>")},
                        ["=="] = {call = make_trans_op("==")},
                        ["~="] = {call = make_trans_op("~=")},
                        ["<"] = {call = make_trans_op("<")},
                        [">"] = {call = make_trans_op(">")},
                        ["<="] = {call = make_trans_op("<=")},
                        [">="] = {call = make_trans_op(">=")},
                        abs = {get = make_trans("math.abs")},
                        acos = {get = make_trans("math.acos")},
                        asin = {get = make_trans("math.asin")},
                        atan = {get = make_trans("math.atan")},
                        ceil = {get = make_trans("math.ceil")},
                        cos = {get = make_trans("math.cos")},
                        deg = {get = make_trans("math.deg")},
                        exp = {get = make_trans("math.exp")},
                        floor = {get = make_trans("math.floor")},
                        fmod = {get = make_trans("math.fmod")},
                        frexp = {get = make_trans("math.frexp")},
                        huge = {get = make_trans("math.huge")},  -- const
                        ldexp = {get = nil}, -- math.ldexp (m, e) - Returns m2e, where e is an integer.
                        log = {get = make_trans("math.log")},
                        max = {get = make_trans("math.max")},
                        maxinteger = {get = make_trans("math.maxinteger")}, -- const
                        min = {get = make_trans("math.min")},
                        mininteger = {get = make_trans("math.mininteger")}, -- const
                        modf = {get = nil}, -- Returns the integral part of x and the fractional part of x. Its second result is always a float.
                        pi = {get = make_trans("math.pi")}, -- const
                        rad = {get = make_trans("math.rad")},
                        --random = {get = make_trans("math.random")},
                        --randomseed = {call = nil}, -- [x, [y]]
                        sin = {get = make_trans("math.sin")},
                        sqrt = {get = make_trans("math.sqrt")},
                        tan = {get = make_trans("math.tan")},
                        tointeger = {get = make_trans("math.tointeger")},
                        type = {get = nil}, -- returns "integer" or "float" or fail
                        ult = {call = nil}, -- math.ult (m, n)
                        to = {
                            can = {
                                NegIManifest = {get = FLESH.make.Artifact("return function (self) return FLESH.make.Number(self.state) end")},
                                string = {get = FLESH.make.Artifact([[return function (self)
                                    return { -- UNFINISHED
                                        protocol = FLESH.KES:resolve(host_types.state.items[host_types.state.labels.string]).state,
                                        state = tostring(self.state)}
                                end]])
                    }}}}
                }}),
            string = FLESH.make.Manifest({
                    can = {
                        ["in"] = {call = capability_check},
                        ["="] = make_host_res_init("string")
                },{
                    can = {
                        ["+"] = {call = make_trans_op("..")},
                        ["=="] = {call = make_trans_op("==")},
                        ["~="] = {call = make_trans_op("~=")},
                        format = {call = FLESH.make.Artifact([[return function (self, arg)
                            -- check if arg is frame and go on
                        end]])},
                        size = {get = make_trans("string.len")},
                        lower = {get = make_trans("string.lower")},
                        upper = {get = make_trans("string.upper")},
                        reverse = {get = make_trans("string.reverse")},
                        to = {
                            can = {
                                NegIManifest = {get = FLESH.make.Artifact("return function (self) return FLESH.make.String(self.state) end")},
                                number = {get = FLESH.make.Artifact([[return function (self)
                                    return {
                                        protocol = FLESH.KES:resolve(host_types.state.items[host_types.state.labels.number]).state,
                                        state = tonumber(self.state)}
                                end]])}}}
                    }
                }}),
            userdata = nil, -- the lua lables it userdata, but basically it's a capability wildcard that OPHANIM can't use to check against userdata instance 
            ["function"] = FLESH.make.Manifest({
                    can = {
                    ["in"] = {call = capability_check},
                    ["="] = make_host_res_init("function")
                },{
                    can = {
                        dump = {get = make_trans("string.dump")}
                    },
                    call = FLESH.make.Artifact([[return function (self, arg)
                        local frame_p
                        return FLESH:import(self.state(table.unpack(args)))
                    end]])
                }}),
            thread = FLESH.make.Manifest({ -- 
                    can = {
                        ["in"] = {call = capability_check},
                        ["="] = make_host_res_init("thread")
                },{
                    can = {
                        close = {get = FLESH.make.Artifact([[]])},
                        isyieldable = {get = FLESH.make.Artifact([[]])},
                        resume = {get = FLESH.make.Artifact([[]])},
                        status = {get = FLESH.make.Artifact([[]])},
                        wrap = {get = FLESH.make.Artifact([[]])},
                    }
                }}),
            table = FLESH.make.Manifest({ -- this also somewhat capability wildcard, but the importer uses different protocol for table, if it's table isn't empty
                    can = {
                        ["in"] = {call = capability_check},
                        ["="] = make_host_res_init("table")
                },{
                    can = {
                        ["+"] = {call = make_trans_op("..")},
                        ["=="] = {call = make_trans_op("==")},
                        ["~="] = {call = make_trans_op("~=")},
                        size = {call = make_trans("#")},
                        to = {
                            can = {
                                NegIManifest = {get = FLESH.make.Artifact("return function (self) return FLESH.make.Number(self.state) end")},
                        }}
                    },
                    call = FLESH.make.Artifact([[return function (self, arg)
                        -- TODO: we somehow need to check if arg is a number or a manifest
                        return FLESH:import(self[arg.state]) -- we need to chanage the intent of import, so it would use this data
                    end]])
                }}),
            unknown = FLESH.make.Manifest({
                    can = {
                        ["in"] = {call = capability_check},
                        ["="] = FLESH.make.Artifact([[return function (self, arg) -- UNFINISHED
                            return {protocol = self.state,state = arg}
                        end]])
                },{}}),
        }

        

        FLESH.import = (function () 
            local value_mapping = function (self, o)
                return {
                    protocol = FLESH.Host.Types[type(o)].state, -- TODO: I need to rework the structure
                    state = o} end

            local gen_mt_protocol = function (self, mt)
                for k,v in pairs(mt) do
                    
                end
            end

            local mapping = {
                ["nil"] = (function () 
                    local instance = nil -- I should think on how I can integrate it
                    return function (self, o)
                        return instance
                end end)(),
                boolean = (function ()
                    local instances = {value_mapping(self, false), value_mapping(self, true)} -- we keep lua from creating new tables for finite amount of states, by just caching them
                    return function (self, o)
                        return instances[o and 2 or 1]
                end end)(),
                number = value_mapping,
                string = value_mapping,
                userdata = function (self, o)
                    local capability = getmetatable(o)
                    -- we generate capability mapping no matter the reason
                    return {protocol = gen_mt_protocol(self, o), state = o}
                end,
                ["function"] = value_mapping,
                thread = value_mapping,
                table = function (self, o)
                    local mt = getmetatable(o)
                    if mt then
                        return {protocol = gen_mt_protocol(self, mt), state = o} -- unfinished, since it doesn't handle default table behaivour
                    else
                        return value_mapping(self, o)
                    end
                end
            }

            return function (self, o) -- imports lua object "o" inside OPHANIM environment
                -- it should find OPHANIM's host knowledge and apply appropriate interface from it.
                local pif = mapping[type(o)]
                if pif then
                    return pif(self, o)
                else
                    -- at this point I should make Error constructors, preferrably that would have error codes
                end
            end end)()

        FLESH.Host.Frame = {
            meta = FLESH.make.Frame({
                name = FLESH:import("Lua 5.5"),
                version = FLESH:import("0.0.1")
            }),
            intrinsics = FLESH.make.Frame({
                types = FLESH.make.Frame(FLESH.Host.Types),
                concepts = nil,
            }),
            authority = FLESH.make.Frame({
                coroutine = nil,
                debug = nil,
                io = nil,
                os = nil,
                package = nil,
            }),  
        }

        --[[ -- since OPHANIM structured differently, lua interafec should be altered to fit the philosophy
        basic -- ???
        _G -- Host
        _VERSION -- Host
        assert -- Host
        collectgarbage -- Host
        dofile -- Host
        error -- Host
        getmetatable -- table, userdata
        ipairs -- table, userdata
        load -- Host
        loadfile -- Host
        next -- table, userdata
        pairs -- table, userdata
        pcall -- Host
        print -- Host (we don't have any other way to interact with lua console)
        rawequal -- lua types
        rawget -- table
        rawlen -- table, string
        rawset -- table
        require -- Host
        select -- function?
        setmetatable -- table, userdata
        tonumber -- string, number
        tostring -- lua types
        type -- lua types
        warn -- Host
        xpcall -- Host
        ]]

        FLESH.NegI.Manifests = { -- this is the core shared interface (or "corelib" if you'd like to call it like that), the abstract foundation for any logic that will come next. TODO: I need to move NegI protocols inside of it
            Native = FLESH.make.Manifest({ -- should represent state during introspection, to make it hostile
                ["in"] = {call = capability_check}},{
                can = { -- lua allows importing, but compiled/static languages have a possibility of not working out like that
                    import = {get = FLESH.make.Artifact("return function (self) return FLESH:import(self.state) end")}}
            }),
            Artifact = FLESH.NegI.Manifests.Artifact, -- Host authority descriptor, seek definition before this
            Error = FLESH.make.Manifest({ -- Error is always as valua
                ["in"] = {call = capability_check},
                ["="] = {call = FLESH.make.Artifact([[]])}},{
                can = {
                    name = {get = FLESH.make.Artifact([[]])}, 
                    desc = {get = FLESH.make.Artifact([[return function (self)
                        return FLESH.make.String(tostring(self.state.desc))
                    end]])}, 
                    caller = {get = FLESH.make.Artifact([[]])},
                    trace = {get = FLESH.make.Artifact([[]])},
                },    
            }),
            Token = FLESH.make.Manifest({["in"] = {call = capability_check}},{ -- adds metainfo that's used by `Error`s, so you can read the exact place of where your code failed
                can = {
                    token = {can = {
                        root = {get = FLESH.make.Artifact([[]])}, -- references root Token from where it is
                        parent = {get = FLESH.make.Artifact([[]])}, -- return parent Token (probably won't add this, because I don't store that)
                        element = {get = FLESH.make.Artifact([[]])}, -- text representation of Token
                        id = {get = nil}, -- it's id (probably will remove it)
                        position = {get = nil}, -- position relative to root Token text representation
                        content = {get = nil}, -- return Frame with it's child Tokens (probably won't add this, because I store that in opaque non-uniform states)
                    }}
                },
                get = FLESH.make.Artifact([[return function (self) return self.state.token end]]), -- fallback to standard token operation
            }),
            Manifest = FLESH.make.Manifest({ -- Protocol for directly constructing Manifests
                can = {
                    ["in"] = {call = capability_check}, -- capability_check is shared artifact 
                    ["="] = {call = FLESH.make.Artifact([[return function (self, arg) 
                        
                        --we take Frame from arg
                        --make manifest for the KES with actual lua tables
                        --store it inside KES (of course)
                        --add lua metatable so I won't have to chain KES accesses
                        --return new manifest's reference

                    end]])},
                    },
                },{}),-- thats "any" type, there's nothing to check, because everything is a Manifest
            Protocol = FLESH.make.Manifest({ -- Protocol for new Protocols
                    can = {
                        of = {call = FLESH.make.Artifact([[]])}, -- will return the protocol of some Manifest that could be used to check other Manifests 
                        ["in"] = {call = capability_check}, -- capability_check is shared artifact
                        ["="] = {call = FLESH.make.Artifact([[]])}
                    },
                    call = FLESH.make.Artifact([[]]), -- artifact for creating new protocol manifests
                },{
                    ["in"] = capability_check
                }),
            ["//"] = FLESH.make.Manifest({
                call = FLESH.make.Artifact("return function (self, arg) return { protocol = { call = FLESH.make.Artifact(\"return function (self, arg) return arg end\")}} end")},{}),
            pass = FLESH.make.Manifest({ -- TODO: explicitly ends Sequence with appropriate data. monad where first is to where and 2nd is data
                call = FLESH.make.Artifact([[return function (self, arg)
                    
                end]])
            },{}),
            ["false"] = FLESH.make.Manifest("Number",0), -- sugar
            ["true"] = FLESH.make.Manifest("Number",1), -- sugar
            gap = FLESH.make.Manifest({},{}), -- it's fine, that's how it should be
            Number = FLESH.make.Manifest({},{}), -- need to make generic host agnostic number representation (maybe even Rational out of 2 BigIntegers or just BigInteger to not conflate these 2 for the compilation process)
            String = FLESH.make.Manifest({},{}), -- some languages might have to emulate this
            Label = FLESH.make.Manifest({ -- it's job is to represent a get query from KES to load manifests
                can = {
                    ["in"] = {call = capability_check},
                    ["="] = {call = FLESH.make.Artifact([[]])}
                }},{
                    can = {
                        [":"] = {get = FLESH.make.Artifact([[return function (self)
                            FLESH.KES:stage_alias(self.state.name)
                            return { 
                                protocol = { call = FLESH.make.Artifact("return function (self, arg) return arg end")},
                                state = self.state.name }end]])},
                        ["name"] = {get = FLESH.make.Artifact([[return function (self)
                            return {
                                protocol = FLESH.NegI.Manifests.String.state,
                                state = self.state.name}
                        end]])},
                    },
                    get = FLESH.make.Artifact([[return function (self) 
                        local m, _ = FLESH.KES:resolve(self.state.name)
                        return m or FLESH.NegI.Manifests.gap
                    end]])
            }),
            Frame = FLESH.make.Manifest({
                can = {
                    ["in"] = {call = capability_check},
                    ["="] = {call = FLESH.make.Artifact([[]])}
                }},{
                    can = {
                        ["+"] = {call = FLESH.make.Artifact([[]])},
                        ["*"] = {call = FLESH.make.Artifact([[]])},
                        delta = {get = FLESH.make.Artifact([[]])},
                        load = {get = FLESH.make.Artifact([[return function (self)
                            local labels, bindings = self.state.labels, self.state.bindings
                            for i,e in pairs(bindings) do
                                FLESH.KES:stage_alias(labels.bl[i] or i, FLESH.KES:stage_entry(e.parent and e.parent[e.delta] or e.delta)) -- sometimes, user will want to load Frame inside a Frame.
                            end
                        end]])},
                        ["."] = {get = FLESH.make.Artifact([[return function (self) --TODO
                            --self.state.labels
                        end]])},
                    },
                    call = FLESH.make.Artifact([[return function (self, arg) 
                        local num_p = FLESH.NegI.Manifests.Number
                        if (FLESH.capcheck(num_p, arg)) then

                        elseif (FLESH.capcheck({state = self.protocol}, arg) and arg) then -- slicing in python style

                        else

                        end
                    end]])
            }),
            Sequence = FLESH.make.Manifest({
                can = {
                    ["in"] = {call = capability_check},
                    ["="] = {call = FLESH.make.Artifact([[]])}
                }},{
                    can = {
                        prods = {get = FLESH.make.Artifact([[]])}, -- in order to get raw data, @ must be used
                        creturn = {get = FLESH.make.Artifact([[]])}, -- in order to get raw data, @ must be used
                        introspect = {get = FLESH.make.Artifact([[]])}
                    },
                    call = FLESH.make.Artifact([[return function (self, arg)
                        local prods = self.state.prods
                        local frame_p = FLESH.NegI.Manifests.Frame
                        if (FLESH.capcheck(frame_p, arg)) then FLESH:dispatch(arg,nil,arg.protocol.can.load) end
                        for i,e in ipairs(prods) do
                            if (e.protocol.get) then
                                e = FLESH:dispatch(e, nil)
                                FLESH.KES:stage_fill_reserve(e)
                                FLESH.KES:commit() end end
                        return FLESH:dispatch(self.state.creturn, nil)
                    end]])
            }),
            Membrane = FLESH.make.Manifest({ -- represent the layers and how they affect environment
                ["in"] = {call = capability_check},
                ["="] = {call = FLESH.make.Artifact([[]])}
            },{
                get = FLESH.make.Artifact([[return function (self)
                    local parent = self.state.quoted and FLESH.KES:unquote_parent(self.state.parent) or self.state.parent
                    FLESH.KES:push_layer(parent, self.state.contain)
                    local output = FLESH:dispatch(self.state.content)
                    FLESH.KES:pop_layer()
                    return output
                end]]),
            }), -- I think I should make distinction between Membranes, though parent Manifest with inherited capabilities will be here
            Make = FLESH.make.Manifest({ -- aka [] or grounded (because push_layer will be grounded by default)
                ["in"] = {call = capability_check},
                ["="] = {call = FLESH.make.Artifact([[]])}
            },{
                get = FLESH.make.Artifact([[return function (self)
                    return FLESH:dispatch(FLESH.make.Manifest(FLESH.NegI.Manifests.Membrane.state, {
                        parent = FLESH.KES:get_context(),
                        contain = false,
                        quoted = false,
                        content = self.state}))
                end]])
            }),
            Quote = FLESH.make.Manifest({ -- aka {} or dynamic (because it will shift parent within isolation)
                ["in"] = {call = capability_check},
                ["="] = {call = FLESH.make.Artifact([[]])}
            },{
                get = FLESH.make.Artifact([[return function (self)
                    return FLESH.make.Manifest(FLESH.NegI.Manifests.Membrane.state, {
                        parent = FLESH.KES:get_context(),
                        contain = false,
                        quoted = true,
                        content = self.state})
                end]])
            }),
            Contain = FLESH.make.Manifest({ -- aka () or isolated
                ["in"] = {call = capability_check},
                ["="] = {call = FLESH.make.Artifact([[]])}
            },{
                get = FLESH.make.Artifact([[return function (self)
                    return FLESH:dispatch(FLESH.make.Manifest(FLESH.NegI.Manifests.Membrane.state, {
                        parent = FLESH.KES:get_context(),
                        contain = true,
                        quoted = false,
                        content = self.state}))
                end]])
            }),
            Negotiation = FLESH.make.Manifest({
                can = {
                    ["in"] = {call = capability_check},
                    ["="] = {call = FLESH.make.Artifact([[]])}
                }},{
                    bindings = {

                    },
                    get = FLESH.make.Artifact([[return function (self)
                        -- resolve terms: we hold references in state, not data
                        local lt = self.state.lterm
                        local rt = self.state.rterm

                        return FLESH:dispatch(lt, rt)
                    end]])
            }),
        }

        FLESH.KES:write_entry("NegI", FLESH.make.Frame(FLESH.NegI.Manifests))

        FLESH.NegI.parse = (function ()
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

            local AST_METADATA = function (node, pos)
                return FLESH.make.Manifest(FLESH.NegI.Token.state,{})
            end

            -- Internal AST node creators (for parser output)
            local AST = { -- refactoring the Sequence generator for parser
                GAP = function () 
                    return FLESH.NegI.Manifests.gap -- we don't have anything on here
                end,
                NUMBER = function (value)
                    return {
                        protocol = FLESH.NegI.Manifests.Number.state,
                        state = value} end,
                STRING = function (value)
                    return {
                        protocol = FLESH.NegI.Manifests.String.state,
                        state = value} end,
                LABEL = function (name)
                    return {
                        protocol = FLESH.NegI.Manifests.Label.state,
                        state = {name = name}} end,
                FRAME = function (items) -- TODO: this one isn't a frame, but a frame constructor, that creates environment for writing, like Sequence
                    return { -- constructor
                        protocol = {get = FLESH.make.Artifact([[return function (self)
                            -- it's easier to do the lua way on lua side, though later I'll need to repalce it with Manifest that don't create another artifact like this
                            -- TODO: rework under `labels` and `bindings`
                            local items = self.state.items
                            local labels = table.create and {lb=table.create(0,#items),bl=table.create(0,#items)} or {lb={},bl={}}
                            --FLESH.KES:push_layer(FLESH.KES:get_context(), true)
                            for i,m in ipairs(items) do FLESH.KES:stage_fill_reserve(FLESH:dispatch(m)) end
                            FLESH.KES:commit(true) -- this could be used mid Sequence, this emergently allow to shuffle labels around
                            return {
                                protocol = FLESH.NegI.Manifests.Frame.state,
                                state = FLESH.KES:inner_snapshot()} -- this might be slower, compared to just poping a Frame from layer, but as long as it works without hacks, I'm satisfied
                        end]])},--ref to manifest for running an evaluation (that would be Sequence or Artifact).
                        state = {items = items}} end,
                SEQUENCE = function (prods, creturn) -- Sequence holds quoted stuff, so we are not doing any actual construction
                    return {
                        protocol = FLESH.NegI.Manifests.Sequence.state,
                        state = {prods = prods, creturn = creturn}} end,
                MEMBRANE = function (kind, content) 
                    return { -- TODO: rework is pending
                        protocol = FLESH.NegI.Manifests[({"Contain", "Quote", "Make"})[kind+1]].state,
                        state = content} end,
                NEGOTIATION = function (lterm, rterm) -- evaluation units
                    return {
                        protocol = FLESH.NegI.Manifests.Negotiation.state,
                        state = {lterm = lterm, rterm = rterm}} end
            }

            -- Internal: Recursive descent parsers (one per non-terminal)
            local parse_term, parse_negotiation, parse_product, parse_sequence

            parse_term = function(tokens, pos)
                local tok
                if pos <= #tokens then
                    tok = tokens[pos]
                    if tok.type == TOKENTYPE.MEMBRANE_OPEN then -- handle membrane: contain | quote | make
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
                        -- the code below generates ast_gap, to help tracking gaps inside sequences or frames
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

            parse_product = function(tokens, pos) -- handle ?product: frame | term
                local term, new_pos = parse_negotiation(tokens, pos)
                pos = new_pos
                if check_token(tokens[pos], TOKENTYPE.FINISH_ELEMENT) then -- it's a frame
                    -- there must be comma, but trailing one is optional. 
                    -- meaning (5,) must be valid frame with 1 element,
                    -- while (5) is just the element
                    local items = {term}
                    repeat
                        pos = pos + 1
                        term, pos = parse_negotiation(tokens, pos)
                        if term then -- for the sake of trailing comma, there might be nil
                            table.insert(items, term)
                        end
                    until not check_token(tokens[pos], TOKENTYPE.FINISH_ELEMENT)
                    return AST.FRAME(items), pos
                else -- it's not a frame
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
                    --elseif c == "0" and code:sub(i+1,i+1):lower() == "x" then -- Number Hex (syntax sugar. Removed in favour of Ada/Smalltalk style "can" keys)
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

        

        local manifest = { -- manifest structure reference ()
            template = {
                protocol = { -- always table
                    can = {}, -- prio, find appropriate Label in front of manifest (maybe I should make this into frame, that depicts the environment for the label in front of it)
                    call = nil, -- not found appropriate Label in can, do it if there is negotiation
                    get = nil, -- not found appropriate Label in can, do it anyways with (if no call) or without negotioation. this rule exist to describle labels
                    ask = nil, -- default case for "can", can work with call but it's heavily advised to not use with call, otherwise it will cause confusion)
                },
                state = { -- internal state of manifest, could only be used by protocol it's bundled with.
            
        }}}

        FLESH:reset()
        return FLESH
    end
            
    return {
    _VERSION="0.0.1",
    newstate = newstate,
} end)()

--[[
Function : Manifest = [ // "Artifact substitution in form of Sequence that expects specific arguments"
    protocol : [
        can : [
            in : [call : Protocol in,],
            = : [call : Artifact = "",] // "adds arguments, turning it into contract"
        ],
    ],
    state : [
        can : [
            = : Artifact = "", // "assign a body"
            arg : Artifact = "", // "get arguments"
            ret : Artifact = "", // "get output"
        ],
    ]
];
Structure : Manifest = [ // "Mold generator to check if Frame fits in it for `what` classification properties"
    protocol : [
        can : [
            in : [call : Protocol in,],
            = : [call : Artifact = "",] // "adds Frame with protocols, turning it into struct"
        ],
    ],
    state : [
        can : [
            in : [call : Artifact = "",], // "checks if passed Frame content matches it's own protocol template"
            template : [get : Artifact = "",] // "get the Frame we checking against"
        ],
    ]
];
]]