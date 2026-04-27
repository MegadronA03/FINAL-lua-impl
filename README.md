# NegI 
**Version:** 0.0.1 (PoC pre-alpha)
**Implementation status:** Boots (fixing critical bugs and finishing user environment)

<div align="center">
<img src="logo.svg" width="256" height="256"/>
</div>

## Description

NegI - (Negitiation Interface) or (Negated Identity) is not a language in the traditional sense; it is a **semantic substrate**. It is designed to solve the "Ship of Theseus" problem in software: allowing a system to replace its components, semantics, and even its underlying runtime without losing its identity.

## Running/Building
The `ophanim.lua` (backend name) is a 1 file library for Lua 5.5. You can either load it via `require` or just copy/paste the code. It only depends on lua core libraries, and even those can be removed. Personally, I'm testing on lua 5.5 binnary.

# 0.1.0 roadmap (finished PoC version)
1. Host representation. Lua have quite messy syntax and context, we need to nicely wrap this up inside some Manifest or Frame.
2. Just finish manifests (Especially Error, to check if we getting stuck in halt)
3. Tokens should keep track of current evaluated data by having access to the Host device (like Artifacts do), but here in PoC we just refere to it directly through FISH due to "it's convinient" and "that stuff is depandant on host"
4. User facing REPL
