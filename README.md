# NegI 
**Version:** 0.0.0
**Implementation status:** Not working

<div align="center">
<img src="logo.svg" width="256" height="256"/>
</div>

## Description

NegI - (Negitiation Interface) or (Negated Identity) is not a language in the traditional sense; it is a **semantic substrate**. It is designed to solve the "Ship of Theseus" problem in software: allowing a system to replace its components, semantics, and even its underlying runtime without losing its identity.

## Running/Building
The `ophanim.lua` (backend name) is a 1 file library for Lua 5.5. You can either load it via `require` or just copy/paste the code. It only depends on lua core libraries, and even those can be removed.

# 0.0.1 roadmap (working PoC version)
1. Make Negi Frame manifest and move existing parser code there. Currently it's nodes are all disconnected and just exist in main context, which just looks like some kid didn't put back toys inside a box.
2. Host representation. Lua have quite messy syntax and context, we need to nicely wrap this up inside some Manifest or Frame.
3. Just finish manifests (Especially Error, to check if we getting stuck in halt)
4. Tokens should keep track of current evaluated data by having access to the Host device (like Artifacts do), but here in PoC we just refere to it directly through FISH due to "it's convinient" and "that stuff is depandant on host"
