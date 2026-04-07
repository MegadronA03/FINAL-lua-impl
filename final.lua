```lua
--TODOs:
-- 1. Make Negi parser manifest and move existing parser code there. Currently it's nodes are all disconnected and just exist in main context, which just looks like some kid didn't put back toys inside a box.
-- 2. Tuple load and Tuple context. This is the last major issue that keep me from testing phase.
-- 2.1 Tuple keep mutations only if passed explicitly after pop_layer. The main difficulty of this is sometimes Tuple keeps mutations and sometimes don't?
-- 2.2 Tuple should work simmilarly like KES layers, "store" parent and delta from parent Tuple.
-- 3. Host representation. Lua have quite messy syntax and context, we need to nicely wrap this up inside some Manifest or Tuple.
-- 4. Rework dynamic membrane as delayed behaivour: rework push_layer into always grounded. grounded - immediate, dynamic - verb, isolated - contained.

return (function ()
    --Frontend: NegI - Negotiation Interface (the interface)
    --Backend: FINAL - Framework for Intent Negotiation and Authority Logic (or Final Is Not A Language) (the substrate)

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
            FISH = { -- "FINAL Internal State Holder" - used by particular manifests to pass around some data. Could be avoided via KES, but those values are quite commonly used, so it will influence performance.
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
                    local m, c
                    if #rt.order.ol > #self.relevance.dl then -- NOTE: records store changes per each layer, so this checks if it's effective to do vertical or horizontal search traversal
                        for i = #self.relevance.dl, 1, -1 do -- inverse order, because we pick fresh ones, in order to hit early
                            local e = self.relevance.dl[i]
                            if rt.order.lo[e] then m = rt.records[e]; c = (#self.layers == e); break end -- we do not use rt.records[e], because it may contain nil, due to "namespace" reservation
                        end
                    else
                        for i = #rt.order.ol, 1, -1 do -- inverse order, because we pick fresh ones, in order to hit early
                            local e = rt.order.ol[i]
                            if self.relevance.ld[e] then m = rt.records[e]; c = (#self.layers == e); break end
                        end
                    end
                    if type(ref) == "string" and not partial then -- we assume that labels store actual indicies, labels are intentionally alias for indicies
                        return self:resolve(m)
                    end
                    return m, c -- Manifest(lua table, that represnts it) or nil (or binding, if partial selected)
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
                        for i = #self.relevance.dl, l.d, -1 do -- exclude all layers between parent and new layer via depth
                            l.s.r[#l.s.r+1] = self.relevance.dl[i] -- add shadowed layers (we can ask depth form them directly)
                            bimap_write(self.relevance, "dl", i, nil) end -- removing irrelevant layers
                        if iso_depth then -- if crossing or sealing isolations
                        for i = #self.isolations.od, self.isolations["do"][iso_depth], -1 do -- iso_depth is calculated anyways, but I think I need to reorganize this code
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
                            if (rt.order.lo[#self.layers] == rt.order.ol[#rt.order.ol]) then
                                bimap_write(rt.order, "lo", #self.layers, nil) else
                                error("KES:pop_layer - invalid layer in unload transaction query. [Z_Z] Currently I'm thinking to keep it as user error or make code for handling this.", 2) end
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
            KES_v2 = { -- "Knowledge Environment State" (considered finished, until bugs will be found)
                layers = {{d = 1,c = {}}}, -- stack of references, string names ready for free (initial layer is preloaded)
                labels = {lb = {}, bl = {}}, -- BiMap<label: String, bind: Number> holds labeled refences, bimap/not in bindings - because it's an extension that exist only for the user
                bindings = {}, -- Array<bind: Number, {records: Map<layer_id: Integer, entry: Manifest>, order: BiMap<layer_id: Integer, order: Integer>}> holds references to data
                relevance = { -- tracks what currently available in active context
                    dl = {[1]=1}, -- Array<depth: Integer, layer_id: Integer> 
                    ld = {[1]=1}}, -- Map<layer_id: Integer, depth: Integer> stores which layers are relevent to current context, mostly used as Set<layer_id: Integer>
                isolations = { -- tracks where grounded layer must be used. basically ordered Set<depth: Integer>
                    ["od"] = {}, -- Array<order: Integer, depth: Integer> 
                    ["do"] = {}}, -- Map<depth: Integer, order: Integer> "this is the reason I hate keywords"

                resolve = function (self, ref) -- note that strings are names for indicies
                    if (type(ref) ~= "string" and type(ref) ~= "number") then
                        error("FINAL: FLESH.KES:resolve - invalid argument, expected number or string", 2)
                    end
                    ref = (type(ref) == "number") and ref or self.labels.lb[ref] -- we override the table depending on what we resolving
                    local rt = self.bindings[ref]
                    if (rt == nil) then return end -- the environment don't know about this binding so we exit early, this line is optional
                    local m, fh -- data, from_here
                    if #rt.order.ol > #self.relevance.dl then -- NOTE: records store changes per each layer, so this checks if it's effective to do vertical or horizontal search traversal
                        for d = #self.relevance.dl, 1, -1 do -- inverse order, because we pick fresh ones, in order to hit early
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
                push_layer = function (self, parent, grounded, isolated, context) -- I need to remodel how parent is retrieved, otherwise making always grounded will break isolations, because dynamic will always have a parent of nearest isolation, besially it's time for a FISH update
                    --we make an exception for root layer, because there's nothing to isolate against
                    local l
                    if (#self.layers > 0) then -- initial layer is preloaded, but I still add it if user decide to pop the root layer and there will be those who would like to do that for the fun of it (hi tsoding)
                        if (type(parent) ~= "number") then error("FINAL: FLESH.KES:push_layer - parent<number> expected for explicit grounded, got "..type(parent), 2) end -- I also think that root layers should be definable if no parent specified
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
                        for i = #self.relevance.dl, l.d, -1 do -- exclude all layers between parent and new layer via depth
                            l.s.r[#l.s.r+1] = self.relevance.dl[i] -- add shadowed layers (we can ask depth form them directly)
                            bimap_write(self.relevance, "dl", i, nil) end -- removing irrelevant layers
                        if iso_depth then -- if crossing or sealing isolations
                        for i = #self.isolations.od, self.isolations["do"][iso_depth], -1 do -- iso_depth is calculated anyways, but I think I need to reorganize this code
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
                            local db = self.bindings
                            local rt = db[i]
                            rt.records[#self.layers] = nil
                            if (rt.order.lo[#self.layers] == rt.order.ol[#rt.order.ol]) then
                                bimap_write(rt.order, "lo", #self.layers, nil)
                            else error("KES:pop_layer - invalid layer in unload transaction query. [Z_Z] Currently I'm thinking to keep it as user error or make code for handling this.", 2) end
                            if #rt.records <= 0 then db[i] = nil; bimap_write(self.labels, "bl", i, nil) end end end
                    if (#self.layers > 0) then self.layers[#self.layers] = nil end -- removing layer
                    return migrate and self.layers[#self.layers + 1].c or nil -- for tail calls it's preferably to return lifted context
                end,
                get_context = function (self) return #self.layers end, -- used by Sequence to memorise context for later use
                write_entry = function (self, ref, m) -- reference : Number|String, [manifest: Any|Nil]
                    local db = self.bindings
                    if (type(ref) == "string") then 
                        bimap_write(self.labels, "lb", ref, self.labels.lb[ref] or (#db + 1))
                        ref = self.labels.lb[ref] 
                    else ref = ref or (#db + 1) end
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
                        c[i] = self.bindings[i].records[layer_id] end
                    return c end,
                inner_snapshot = function (self) -- used in tuple, in order to track writes
                    return self.direct_snapshot(#self.layers)
                end,
                cview_snapshot = function (self, outer)
                    local c = {}
                    for i = #self.relevance.dl, 1, -1 do
                        local e = self.relevance.dl[i]
                        for i,_ in pairs(self.layers[e].c) do
                            c[i] = c[i] or self.bindings[i].records[e] end end
                    return c
                end,
                binding_label_get = function (self, b) return self.labels.bl[b] end, -- Used by Tuple to make label list.
            },
            dispatch = function (self, lterm, rterm, protocol)
                if lterm == nil then return end
                if rterm and rterm.protocol and rterm.protocol.unhandled then
                    return self:dispatch(rterm, nil, rterm.protocol) -- unhandled exectuion
                end
                if protocol then
                    if rterm then
                        if protocol.responders then
                            local label_p = self.KES.bindings[self.KES.bindings.Label.records[self.host_layer]].records[self.host_layer] -- we use direct access, because this stuff will depend on furst record anyways
                            if self.capcheck(label_p, rterm) then return {protocol = protocol.responders[rterm.state.name], state = lterm.state} end end
                        if protocol.handled then
                            local artifact_p = self.KES.bindings[self.KES.bindings.Artifact.records[self.host_layer]].records[self.host_layer]
                            local tuple_p = self.KES.bindings[self.KES.bindings.Tuple.records[self.host_layer]].records[self.host_layer]
                            local hanc = self.KES:resolve(protocol.unhandled)
                            if self.capcheck(artifact_p, hanc) then
                                return hanc.state.artifact(lterm, rterm)
                            else return self:dispatch(hanc, {
                                protocol = tuple_p.state,
                                state = {items = {lterm, rterm}, labels = {"self", "arg"}}}, hanc.protocol) end end-- needs some standartization on how this should be passed around, don't like hardcoded "self" and "arg"
                        if protocol.unhandled then -- fallback to underlying manifest for an answer
                            local artifact_p = self.KES.bindings[self.KES.bindings.Artifact.records[self.host_layer]].records[self.host_layer]
                            local tuple_p = self.KES.bindings[self.KES.bindings.Tuple.records[self.host_layer]].records[self.host_layer]
                            local unhc = self.KES:resolve(protocol.unhandled)
                            local fabk
                            if self.capcheck(artifact_p, unhc) then
                                fabk = unhc.state.artifact(lterm)
                            else fabk = self:dispatch(unhc, lterm, unhc.protocol) end
                            return self:dispatch(fabk, rterm, fabk.protocol)
                        else return {
                            protocol = self.KES.bindings[self.KES.bindings.Error.records[self.host_layer]].records[self.host_layer].state,
                            state = {desc = "ENIMGA: FLESH:dispatch Error: rterm is outside of lterm protocol response capability"}} end
                    elseif protocol.unhandled then
                            local artifact_p = self.KES.bindings[self.KES.bindings.Artifact.records[self.host_layer]].records[self.host_layer]
                            local unhc = self.KES:resolve(protocol.unhandled)
                            if self.capcheck(artifact_p, unhc) then
                                return unhc.state.artifact(lterm)
                            else return self:dispatch(unhc, lterm, unhc.protocol) end
                        else return lterm end
                elseif lterm.protocol then return self:dispatch(lterm, rterm, lterm.protocol) 
                elseif rterm then return {
                    protocol = self.KES.bindings[self.KES.bindings.Error.records[self.host_layer]].records[self.host_layer].state,
                    state = {desc = "ENIMGA: FLESH:dispatch Error: missing protocol"}}
                else return lterm end
            end,
            --env methods
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

        --I need to make things clear
        --Manifest can only store references to stuff inside it's state
        --meaning if it's related to user modifyable storage, we store KES label or binding (refer to Tuple)
        --if something different getting stored, it's host resources, that user can only interact with it via protocol
        --which means yes, state itself is opaque host resource


        FLESH.make = {}

        local a_stubs = {FLESH.KES:write_entry(),FLESH.KES:write_entry(),FLESH.KES:write_entry(),FLESH.KES:write_entry()}
        FLESH.KES:write_entry("Artifact", { -- Artifact for handling external authority
            protocol = {
                responders = {
                    ["in"] = {handled = a_stubs[1]},
                    ["="] = {handled = a_stubs[2]}}},
            state = {
                responders = {
                    reload = {unhandled = a_stubs[3]}},
                handled = a_stubs[4]}})

        FLESH.make.Artifact = function (chunk, chunkname, mode, env)
            local plfmt = { __index = function (s,i) -- we make lazy fetch on Artifact, because we have a metacircular situation
                local v = rawget(s,i)
                if i ~= "protocol" then return v end
                if type(v) ~= "table" then
                    v = FLESH.KES:resolve(v).state
                    rawset(s,i,v) 
                    setmetatable(s, nil) end 
                return v end}
            chunkname = chunkname or "chunk"
            local a, e = load(chunk, "FINAL:"..chunkname, mode, env) 
            if (a) then a, e = pcall(a) end
            if (e) then
                local em = {
                    protocol = "Error", 
                    state = {desc = "Artifact: Failed to load "..chunkname.." due to host error: "..e}}
                setmetatable(em, plfmt)
                return em end
            local am = {
                protocol = FLESH.KES.bindings[FLESH.KES.bindings.Artifact.records[FLESH.host_layer] ].records[FLESH.host_layer].state,
                state = {
                    chunk = chunk,
                    chunkname = chunkname,
                    mode = mode,
                    env = env,
                    artifact = a}} end

        FLESH.intentcheck = function(self, arg) -- State intent of manifests are matching?
            for i,e in pairs(self.state) do
                if (arg.protocol[i] ~= e) then
                    return false end end
            for i,e in pairs(self.state.responders) do
                if (arg.protocol.responders[i] ~= e) then
                    return false end end
            return true end

        FLESH.capcheck = function(self, arg) -- Even through fallbacks, is manifest implements this protocol?
            -- TODO: check protocol in flat form, we need to make sure clauses are reachable, not that there is inside chain some Manifest that satisfy intent.
            local fail = function () return arg.protocol.unhandled and FLESH.capcheck(FLESH:dispatch(arg, nil, arg.protocol)) or false end
            for i,e in pairs(self.state) do
                if (arg.protocol[i] ~= e) then
                    return fail() end end
            for i,e in pairs(self.state.responders) do
                if (arg.protocol.responders[i] ~= e) then
                    return fail() end end
            return true end

        --common between protocol manifests
        local capability_check = FLESH.KES:write_entry(a_stubs[1], FLESH.make.Artifact([[return function (self, arg)
            return FLESH.capcheck(self, arg) and FLESH.KES:resolve("true") or FLESH.KES:resolve("false") end]], "capcheck"))

        FLESH.KES:write_entry(a_stubs[2], FLESH.make.Artifact([[return function (self, arg) end]])) -- should make artifact creation off state, table, Tuple and string
        FLESH.KES:write_entry(a_stubs[3], FLESH.make.Artifact([[return function (self)
            return FLESH.make.Artifact(self.state.chunk, self.state.chunkname, self.state.mode, self.state.env) end]]))
        FLESH.KES:write_entry(a_stubs[4], FLESH.make.Artifact([[return function(self, arg)
            local tunp = unpack or table.unpack
            return self.state.artifact(tunp(arg)) end]]))

        local p_artifact = function (...) return FLESH.KES:write_entry(nil, FLESH.make.Artifact(...)) end

        local host_name = FLESH.KES:write_entry() -- we reserve space for the host name 

        FLESH.KES:write_entry("Native", { -- should represent state during introspection, to make it hostile
            protocol = {
                ["in"] = {handled = capability_check}},
            state = {
                responder = {
                    name = {unhandled = host_name}}}}) -- it's later constructed a string with "Lua 5.5"

        FLESH.KES:write_entry("Error", { -- Error "as value"
            protocol = {
                ["in"] = {handled = capability_check},
                ["="] = {handled = p_artifact([[]])}},
            state = {
                responders = {
                    name = {unhandled = p_artifact([[]])}, 
                    desc = {unhandled = p_artifact([[return function (self)
                        return { -- UNFINISHED
                            protocol = FLESH.KES:resolve("String").state,
                            state = tostring(self.state.desc)}
                    end]])}, 
                    caller = {unhandled = p_artifact([[]])},
                    trace = {unhandled = p_artifact([[]])},
                },    

            }
        })

        FLESH.KES:write_entry("Token", { -- adds parser data to values
            protocol = {["in"] = {handled = capability_check}},
            state = {
                responders = {
                    token = {responders = {
                        root = {unhandled = p_artifact([[]])}, -- references root Token from where it is
                        parent = {unhandled = p_artifact([[]])}, -- return parent Token (probably won't add this, because I don't store that)
                        element = {unhandled = p_artifact([[]])}, -- text representation of Token
                        id = {unhandled = nil}, -- it's id (probably will remove it)
                        position = {unhandled = nil}, -- position relative to root Token text representation
                        content = {unhandled = nil}, -- return Tuple with it's child Tokens (probably won't add this, because I store that in opaque non-uniform states)
                    }}
                },
                unhandled = p_artifact([[return function (self) return self.state.token end]]), -- fallback to standard token operation
        }})

        -- no implicit conversions, this is only between this specific implementation
        local make_trans_op = function (op)
            return p_artifact([[return function (self, arg)
                if (FLESH.capcheck({state = self.protocol},arg)) then -- 2nd value might have different protocol, I think I'll need to rework this into lua general value protocol check or something.
                    return FLESH:import(self.state ]]..op..[[ arg.state)
                else
                    return -- Error manifest
                end
            end]])
        end
        local make_trans = function (trans)
            return p_artifact([[return function (self)
                return FLESH:import(]]..trans..[[(self.state))
            end]])
        end
        local make_host_res_init = function (host_type)
            return p_artifact([[return function (self, arg)
                -- wrap host resource manifest
                if (FLESH.capcheck(self,arg)) then return arg end -- literal uses same protocol, so we just passing
                if (type(arg) == "]]..host_type..[[") then return {protocol = self.state,state = arg}} end
                return -- Error manifest
            end]])
        end

        FLESH.make.Tuple = function (t)
            local s = {labels = {}, items = {}}
            for i,e in pairs(t) do
                s.items[#s.items+1] = e
                if type(k) == "string" then
                    s.labels[k] = #s.items
                end
            end
            return {protocol = FLESH.KES:resolve("Tuple").state, state = s}
        end

        FLESH.make.Error = function (desc)
            return {
                protocol = FLESH.KES.bindings[FLESH.KES.bindings.Error.records[FLESH.host_layer] ].records[FLESH.host_layer].state,
                state = {desc = desc}}end

        local host_protocols = FLESH.make.Tuple({ -- while it's a mapping table, FINAL fundamentally disagree with lua on type existance, so for example userdata can't be capchecked
            ["nil"] = FLESH.KES:write_entry(nil, {protocol = {},state = {}}),
            boolean = FLESH.KES:write_entry(nil, {protocol = {
                    responders = {
                        ["in"] = {handled = capability_check},
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
            number = FLESH.KES:write_entry(nil, {protocol = {
                    responders = {
                        ["in"] = {handled = capability_check},
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
                                string = {unhandled = p_artifact([[return function (self)
                                    return { -- UNFINISHED
                                        protocol = FLESH.KES:resolve(host_types.state.items[host_types.state.labels.string]).state,
                                        state = tostring(self.state)}
                                end]])}}}
                    }
                }}),
            string = FLESH.KES:write_entry(nil, {protocol = {
                    responders = {
                        ["in"] = {handled = capability_check},
                        ["="] = make_host_res_init("string")}},
                state = {
                    responders = {
                        ["+"] = {handled = make_trans_op("..")},
                        ["=="] = {handled = make_trans_op("==")},
                        ["~="] = {handled = make_trans_op("~=")},
                        format = {handled = p_artifact([[return function (self, arg)
                            -- check if arg is tuple and go on
                        ]])},
                        size = {unhandled = make_trans("string.len")},
                        lower = {unhandled = make_trans("string.lower")},
                        upper = {unhandled = make_trans("string.upper")},
                        reverse = {unhandled = make_trans("string.reverse")},
                        to = {
                            responders = {
                                number = {unhandled = p_artifact([[return function (self)
                                    return {
                                        protocol = FLESH.KES:resolve(host_types.state.items[host_types.state.labels.number]).state,
                                        state = tonumber(self.state)}
                                end]])}}}
                    }
                }}),
            userdata = nil, -- the lua lables it userdata, but basically it's a capability wildcard that FINAL can't use to check against userdata instance 
            ["function"] = FLESH.KES:write_entry(nil, {protocol = {
                    responders = {
                    ["in"] = {handled = capability_check},
                    ["="] = make_host_res_init("function")}},
                state = {
                    responders = {
                        dump = {unhandled = p_artifact([[]])}
                    },
                    handled = p_artifact([[return function (self, arg)
                        local tuple_p
                        return FLESH:import(self.state(table.unpack(args)))
                    end]])
                }}),
            thread = FLESH.KES:write_entry(nil, {protocol = {
                    responders = {
                        ["in"] = {handled = capability_check},
                        ["="] = make_host_res_init("thread")}},
                state = {
                    responders = {
                        close = {unhandled = p_artifact([[]])},
                        isyieldable = {unhandled = p_artifact([[]])},
                        resume = {unhandled = p_artifact([[]])},
                        status = {unhandled = p_artifact([[]])},
                        wrap = {unhandled = p_artifact([[]])},
                    }
                }}),
            table = FLESH.KES:write_entry(nil, {protocol = { -- this also somewhat capability wildcard, but the importer uses different protocol for table, if it's table isn't empty
                    responders = {
                        ["in"] = {handled = capability_check},
                        ["="] = p_artifact([[return function (self, arg)
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
                    handled = p_artifact([[return function (self, arg)
                        -- TODO: we somehow need to check if arg is a number or a manifest
                        return FLESH:import(self[arg.state]) -- we need to chanage the intent of import, so it would use this data
                    end]])
                }}),
            unknown = FLESH.KES:write_entry(nil, {protocol = {
                    responders = {
                        ["in"] = {handled = capability_check},
                        ["="] = p_artifact([[return function (self, arg) -- UNFINISHED
                            return {protocol = self.state,state = arg}
                        end]])}},
                state = {}}),
        })

        

        FLESH.import = (function () 
            local value_mapping = function (self, o)
                return {
                    protocol = host.protocols[type(o)].state, -- I need to rework the structure
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

            return function (self, o) -- imports lua object "o" inside FINAL environment
                -- it should find FINAL's host knowledge and apply appropriate interface from it.
                
                local pif = mapping[type(o)]
                if pif then
                    return pif(self, o)
                else
                    -- at this point I should make Error constructors, preferrably that would have error codes
                end
            end end)()

        local host_tuple = FLESH.make.Tuple({
            meta = FLESH.KES:write_entry(nil, FLESH.make.Tuple({
                name = FLESH.KES:write_entry(nil, FLESH:import("Lua 5.5")),
                version = FLESH.KES:write_entry(nil, FLESH:import("0.0.1"))
            })),
            intrinsics = FLESH.KES:write_entry(nil, FLESH.make.Tuple({
                types = nil,
                concepts = nil,
            })),
            authority = FLESH.KES:write_entry(nil, FLESH.make.Tuple({
                coroutine = nil,
                debug = nil,
                io = nil,
                os = nil,
                package = nil,
            })),  
        })

        --[[ -- since FINAL structured differently, lua interafec should be altered to fit the philosophy
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

        FLESH.KES:write_entry("Protocol", { -- Protocol for new Protocols
            protocol = {
                responders = {
                    --of = {handled = p_artifact([[]])}, -- no matter how sweet it looks, we literally can't do that
                    ["in"] = {handled = capability_check}, -- capability_check is shared artifact
                    ["="] = {handled = p_artifact([[]])}
                },
                handled = p_artifact([[]]), -- artifact for creating new protocol manifests
            },
            state = {
                ["in"] = capability_check
            }
        })
        FLESH.KES:write_entry("Manifest", { -- Protocol for directly constructing Manifests
            protocol = {
                responders = {
                    ["in"] = {handled = capability_check}, -- capability_check is shared artifact 
                    ["="] = {handled = p_artifact([[return function (self, arg) 
                    
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
            handled = p_artifact("return function (self, arg) return { protocol = { handled = p_artifact(\"return function (self, arg) return arg end\")}} end")}})
        FLESH.KES:write_entry("gap", {protocol = {}, state = {}})
        


        FLESH.KES:write_entry("Number", FLESH.KES:resolve(host_types.state.items[host_types.state.labels.number]))
        FLESH.KES:write_entry("String", FLESH.KES:resolve(host_types.state.items[host_types.state.labels.string]))
        FLESH.KES:write_entry("Label", { -- it's job is just labeling manifests
            protocol = {
                ["in"] = {handled = capability_check},
                ["="] = {handled = p_artifact([[]])}
            },
            state = {
                responders = {
                    [":"] = {unhandled = p_artifact([[return function (self)
                        FISH.pending_labels[self.state.name] = true
                        return { protocol = { handled = p_artifact("return function (self, arg) return arg end")} }end]])},
                    ["name"] = {unhandled = p_artifact([[return function (self)
                        return {
                            protocol = FLESH.KES.bindings[FLESH.KES.bindings.String.records[FLESH.host_layer] ].records[FLESH.host_layer].state,
                            state = self.state.name}
                    end]])},
                },
                unhandled = p_artifact([[return function (self) 
                    return FLESH.KES:resolve(self.state.name)
                end]])
            }
        })
        FLESH.KES:write_entry("Tuple", {
            protocol = {
                ["in"] = {handled = capability_check},
                ["="] = {handled = p_artifact([[]])}
            },
            state = {
                responders = {
                    ["+"] = {handled = p_artifact([[]])},
                    ["*"] = {handled = p_artifact([[]])},
                    load = {unhandled = p_artifact([[return function (self)
                        local labels, items = self.state.labels, self.state.items
                        if labels then
                            if items then
                                for i,e in pairs(labels) do
                                    FISH.pending_labels[i] = true -- items[e]... FISH.pending_labels can't sustain this, I need different interface for passing pending context effects. I also have same problem in membranes
                                end end end end]])},
                    ["."] = {unhandled = p_artifact([[return function (self) --TODO
                        self.state.labels
                    end]])},
                },
                handled = p_artifact([[return function (self, arg) 
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
                ["in"] = {handled = capability_check},
                ["="] = {handled = p_artifact([[]])}
            },
            state = {
                responders = {
                    prods = {unhandled = p_artifact([[]])}, -- in order to get raw data, @ must be used
                    creturn = {unhandled = p_artifact([[]])}, -- in order to get raw data, @ must be used
                    introspect = {unhandled = p_artifact([[]])}
                },
                handled = p_artifact([[return function (self, arg)
                    local prods = self.state.prods
                    FLESH.KES:push_layer(self.state.parent, self.state.grounded, self.state.isolated, FLESH.FISH.tail_context or table.create(0, #prods))
                    local pl = {}
                    FISH.pending_labels = pl
                    local tuple_p = FLESH.KES.bindings[FLESH.KES.bindings.Tuple.records[FLESH.host_layer] ].records[FLESH.host_layer]
                    if (FLESH.capcheck(tuple_p, arg)) then FLESH:dispatch(arg,nil,arg.protocol.responders.load) end
                    for i,e in pairs(FISH.pending_labels) do FLESH.KES:write_entry() end
                    for i,e in ipairs(prods) do
                        local s = FLESH.KES:resolve(e)
                        pl = {}
                        FISH.pending_labels = pl
                        FISH.def_grounded, FISH.def_isolated = false, false
                        if (s.protocol.unhandled) then s = FLESH:dispatch(s, nil, s.protocol) end
                        for i,e in pairs(pl) do FLESH.KES:write_entry(i, s) end
                    end
                    FISH.pending_labels = {} 
                    local s = FLESH.KES:resolve(self.state.creturn)
                    --FLESH.FISH.tail_context = FLESH.KES.layers[#FLESH.KES.layers]
                    if (s.protocol.unhandled) then s = FLESH:dispatch(s, nil, s.protocol) end -- no TCO due to inderection
                    FLESH.KES:pop_layer()
                    return s
                end]])
            }
        })
        FLESH.KES:write_entry("Membrane", { -- controls effect(or context layer mutations) propogation of current context layer relative to other context layers
            protocol = {
                ["in"] = {handled = capability_check},
                ["="] = {handled = p_artifact([[]])}
            },
            state = {
                unhandled = p_artifact([[return function (self) -- do consider that this is definition of something, meaning it paints
                    local content = FLESH.KES:resolve(self.state.content)
                    --if content and content.state then
                        if (self.state.kind == 2) then -- grounded
                            -- store context, where this membrane was defined
                            FISH.def_grounded = true -- should have probably done direct Sequence manipulation, instead of using FISH, but on other side I should add handled clause to sequence for specifying what mode to use
                        elseif (self.state.kind == 1) then -- dynamic (or wrapper)
                            -- neutral, inherit active behaviour. If user desire default behaviour
                        elseif (self.state.kind == 0) then -- isolated
                            FISH.def_isolated = true
                            -- outer implicit mutation from inner is restricted at definition context layer
                        else
                            return {
                                protocol = FLESH.assets.protocols.Error,
                                state = {
                                    desc = "Membrane: Invalid kind"
                            }}
                        end-- end
                    return FLESH:dispatch(content, nil, content.protocol)
                end]]),
            }
        })
        FLESH.KES:write_entry("Negotiation", {
            protocol = {
                ["in"] = {handled = capability_check},
                ["="] = {handled = p_artifact([[]])}
            },
            state = {
                bindings = {
                    
                },
                unhandled = p_artifact([[return function (self)
                    -- resolve terms: we hold references in state, not data
                    local lt = FLESH.KES:resolve(self.state.lterm)
                    local rt = FLESH.KES:resolve(self.state.rterm)
                    
                    return FLESH:dispatch(lt, rt, lt.protocol)
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
                    protocol = {unhandled = p_artifact([[return function (self)
                        -- it's easier to do the lua way on lua side, though later I'll need to repalce it with Manifest that don't create another artifact like this
                        local items = self.state.items
                        local proc_items = table.create and table.create(#items) or {}
                        local labels = table.create and table.create(0,#items) or {}
                        for i,e in ipairs(items) do
                            local pl = {}
                            FISH.pending_labels = pl
                            local m = FLESH.KES:resolve(e)
                            proc_items[#proc_items+1] = FLESH:dispatch(m, nil, m.protocol)
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
                        unhandled = p_artifact([[return function (self)
                            return FLESH.KES:write_entry(nil, {
                                protocol = FLESH.KES:resolve("Sequence").state,
                                state = {grounded = FISH.def_grounded or false, isolated = FISH.def_isolated or false, prods = self.state.prods, creturn = self.state.creturn, parent = FLESH.get_context()}
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

        local manifest = { -- manifest structure reference ()
            template = { 
                protocol = { -- always table
                    responders = {}, -- prio, find appropriate Label in front of manifest (maybe I should make this into tuple, that depicts the environment for the label in front of it)
                    handled = nil, -- not found appropriate Label in responders, do it if there is negotiation
                    unhandled = nil, -- not found appropriate Label in responders, do it anyways with (if no handled) or without negotioation. this rule exist to describle labels
                },
                state = { -- internal state of manifest, could only be used by protocol it's bundled with.
            
        }}}

        FLESH:reset()
        return FLESH
    end
            
    return {
    _VERSION="0.0.1",
    newstate = newstate,
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

--[[
Function : Manifest = [
    protocol : [
        responders : [
            in : [handled : Protocol in,],
            = : [handled : Artifact = "",] // "adds arguments, turning it into contract"
        ],
    ],
    state : [
        responders : [
            = : Artifact = "", // "assign a body"
            arg : Artifact = "", // "get arguments"
            ret : Artifact = "", // "get output"
        ],
    ]
];
Structure : Manifest = [
    protocol : [
        responders : [
            in : [handled : Protocol in,],
            = : [handled : Artifact = "",] // "adds Tuple with protocols, turning it into struct"
        ],
    ],
    state : [
        responders : [
            in : [handled : Artifact = "",], // "checks if passed Tuple content matches it's own protocol template"
            template : [unhandled : Artifact = "",] // "get the Tuple we checking against"
        ],
    ]
];
]]
```