# The ENIGMA Specification & Design Rationale
**Version:** 0.0.1 (Pre-Release)
**Authors:** Z_Z (MegadronA03)
**Status:** Draft

<div align="center">
<img src="NegI_Xi.svg" width="256" height="256"/>
</div>

## Confidence Level Legend
To facilitate feedback, every section is tagged with a confidence level:
*   **[STABLE]**: Functionality is implemented, tested, and unlikely to change significantly.
*   **[FLUID]**: Functionality works but implementation details or syntax might change.
*   **[THEORETICAL]**: Planned behavior that is not fully implemented or is currently a prototype.
*   **[UNKNOWN]**: Area of the design that needs significant research or external input.

---

## 1. Introduction & Philosophy
**[STABLE]**

ENIGMA (Epistemic Negotiation Interface for Gentchen Manifested Abstractions) is not a language in the traditional sense; it is a **semantic substrate**. It is designed to solve the "Ship of Theseus" problem in software: allowing a system to replace its components, semantics, and even its underlying runtime without losing its identity.

### 1.1 Core Philosophy
*   **Everything is a Negotiation**: There are no "function calls," only negotiations between Manifests.
*   **Context is a Resource**: State is not global; it is layered. Access to context is a capability, not a right.
*   **Transactional Evolution**: The system is designed to be append-only and self-redefining.

---

## 2. Design Principles & Ethos
**[STABLE]**
*This section defines the governing laws of ENIGMA's evolution. Any feature that violates these principles is considered a design error.*

The development of NegI and FINAL pursues these directions:

1.  **Extreme Transparency**: It can't answer "I don't know" on something it's using. Host code for authority is more useful than opaque error handling (e.g., Smalltalk's "I don't know").
2.  **Context Reshaping**: Nothing is welded to the floor. The user must be able to organize, clean, and restructure their workspace (`KES` layers) as they wish.
3.  **User Sovereignty**: The user is always right, as long as the host is capable of implementing their requests. Artificial constraints are pollution to the context.
4.  **Relativity is Absolute**: Hardware trusts physics and reality. But physics and reality can fail that hardware in accomplishing tasks.
5.  **Hygiene is Absolute**: Every mutation must be contained by default. After a "thought" (Sequence) is finished, its assumptions die with it, unless explicitly passed or delegated.
6.  **Can/Do vs Is/A**: Manifest state should only be compared via Protocols (how it is transformed), not directly. We care about what a thing *does*, not what it *is*.

---

## 3. The Complexity Model
**[STABLE]**

### 3.1 Simplicity vs. Emergence
On its own, NegI code is syntactically minimal. The parser generates roughly 8 types of nodes.
**Complexity in ENIGMA does not come from expressions; it comes from interactions.** The system exhibits **Emergent Behavior**. Simple rules (Negotiation, Layer Pushing, Protocol Dispatch) combine to create complex, resilient systems.

### 3.2 Divine Abstractions
ENIGMA operates on "Divine Abstractions." The user is not writing procedural instructions; they are invoking high-level concepts.

This leads to the fundamental rule of ENIGMA's memory management:
> **"Exit to the paradise is through oblivion."**

When a Sequence ends, its context is not just "cleaned up" — it is destroyed. The assumptions, temporary variables, and state of that "thought" cease to exist. The only way to reach the next step (Paradise) is to let the previous context die (Oblivion).

This enforces a strict discipline: **If you want it to survive, you must explicitly save it.**

---

## 4. The Architecture (FINAL)
**[STABLE]** for structure, **[FLUID]** for optimization.

### 4.1 FLESH (FINAL Local Environment Shared Handles)
The global environment and API container. It holds `KES` and the dispatch loop.

### 4.2 KES (Knowledge Environment State)
The memory manager. It implements a **Tree-based Scope Model** using a linear stack with shadowing.
*   **Layers**: Scopes/Stack frames. Can be `Dynamic`, `Grounded`, or `Isolated`.
*   **Bindings & Labels**: The addressable memory. `Bindings` are numeric IDs; `Labels` are string names.
*   **Relevance**: The mechanism determining which layers are currently visible.

**Rationale**: Why not a standard stack?
> A standard stack implies linear execution. ENIGMA needs to support branching context (grounding) and sandboxing (isolation) natively. KES allows the execution to "jump" back to an ancestor context or cut off access to it, enabling structural safety.

---

## 5. The Ontology (Standard Manifests)
These are the building blocks provided by the `FLESH` environment.

### 5.1 `Native` & `Artifact`
**[STABLE]**
*   **Role**: Bridge to the host platform (Lua).
*   **Protocol**: Defines how external code is executed.
*   **Rationale**: `Artifact` is the "executable" Manifest. It encapsulates host code inside a safety wrapper. This allows ENIGMA to redefine "execution" without rewriting the host.

### 5.2 `Protocol`
**[STABLE]** (Definition) / **[FLUID]** (Host Interop)
*   **Role**: The fundamental interface definition.
*   **Structural Checking**: Two manifests satisfy the same protocol check if they implement the same clauses performing equivalent operations.
*   **Rationale**: This allows for "Duck Typing" with enforcement. We don't care *what* the manifest is, only that it knows how to handle the specific negotiations.

### 5.3 `Sequence`
**[FLUID]**
*   **Role**: The primary execution block.
*   **Behavior**: A Sequence pushes a new Layer. Upon completion, the Layer is popped (destroyed). It does **not** automatically capture variables (closure).
*   **Rationale**: This forces explicit data flow. You cannot rely on implicit variable capture. This makes data dependencies strictly visible.

### 5.4 `Tuple`
**[FLUID]**
*   **Role**: Data container / Environment carrier.
*   **Behavior**: Unlike a Sequence, a Tuple is a "snapshotted" collection of references.
*   **Rationale**: If Sequence is the Verb (Action), Tuple is the Noun (Data). It is the mechanism for explicitly transferring state between isolated contexts.

### 5.5 `Membrane`
**[STABLE]**
*   **Role**: Control flow modifier / Scope Controller.
*   **Types**:
    *   `()` **Isolated**: Creates a sandbox. Cannot see outer context.
    *   `{}` **Dynamic**: Standard behavior.
    *   `[]` **Grounded**: Binds to a specific parent context.
*   **Rationale**: Membranes put "Capability" into the syntax. Security and scope are defined by the brackets used.

### 5.6 `Function` & `Contract`
**[THEORETICAL]**
*   **Role**: Specification and instantiation of safe, contained logic.
*   **Function**: A blueprint defining input labels and output protocols.
*   **Contract**: An instance of a Function binding a specific inputs and outputs.
*   **Mechanism**:
    1.  **Argument Binding**: Automatically assigns passed arguments to specific labels.
    2.  **Capability Check (`capcheck`)**: Verifies arguments satisfy the Contract before execution.
    3.  **Containment**: Unlike `Artifact`, a `Function` body runs purely within NegI logic.
*   **Example**:
    ```negi
    // "Define the Contract: Takes one input, returns one output"
    foo : Function((input,), output) = { // "'Function((input,), output)' is Contract Protocol definition"
        // "Contract instance's Sequence body"
        ;input + 1
    }
    ```
*   **Rationale**: Authority Containment.
    *   *Artifacts* are "Unsafe/Powerful": They can touch the hardware/OS.
    *   *Functions* are "Safe/Contained": They operate purely within the semantic graph.

### 5.7 `Mold` & `Structure`
**[THEORETICAL]**
*   **Role**: Specification and instantiation of safe, contained context.
*   **Mold**: A blueprint defining expected Manifests and their capabilities within Tuple.
*   **Contract**: An instance of a Mold binding a specific labels, protocols and order.

---

## 6. Execution Model (Negotiation)
**[STABLE]**

### 6.1 Adjacency is Application
In the syntax `A B`, `A` negotiates with `B`.
*   `A` acts as the "Left Term" (Context of Self).
*   `B` acts as the "Right Term" (Arg/Message).

### 6.2 Dispatch Logic
(refer to `FLESH.dispatch` logic in FINAL's lua implementation)

**Rationale**: This decouples "what happens" from "who is involved."

---

## 7. Syntactic Layer (NegI)
**[STABLE]**

*   **Lexer**: 8 Token Types.
*   **Parser**: Recursive Descent.
*   **AST**: Generated as Manifests directly.

**Rationale**: The syntax is minimal to reduce cognitive load. Complexity lives in the Semantics, not the Syntax.

---

## 8. Code examples

1. Sequence behaivours
```negi
a : 1;
b : [;a]; // "grounded"
print (b()); // "1"
{
    a : 55;
    print(b()); // "1"
    print a; // "55"
}();
print a; // "1, Sequence always drops the context no matter the kind"
a : 34;
print(b()); // "34"

a : 1;
b : {;a}; // "dynamic"
print (b()); // "1"
{
    a : 55;
    print(b()); // "55"
    print a; // "55"
}();
print a; // "1"

a : 1;
b : {;a};
print (b()); // "1"
{ // "isolated"
    a : 55;
    print(b()); // "1"
    print a; // "55"
}();
print a; // "1"
```

2. Passing state
```negi
factorial : Function((n : Number,), Number) = {
    pass () (n == 0 || (n == 1) then 1 else (n * factorial(n - 1,))); // "pass(where)(what) yes, it's monad. Not sure about ternary's 'then' and 'else' though" 
}
factorial (7,);
```

3. Binary search
```negi
stdtools load;
cli : CommandLineInterface;

binary_search : Function((arr : Array(Integer), target : Integer), Integer) = {
	low : 0;
	high : (arr length) - 1;
	loop { // "`loop` iterates until explicitly exited"
		mid : (low + high) / 2; // "some JS stuff here, don't like it, but I'll leave it for later, cuz // occupied"
        // "'if' is actually ternary in disguise that implicitly mutates context. It's also a monad btw. Needs refinement and probably could be raplced wwith ternary and indexing"
		if (arr(mid) == target) {
			pass () mid;
		} else {
		if (arr(mid) < target) {
			low : mid + 1;
		} else {
			high : mid - 1;
		};}
        // "loop at the end hides recursive context passing to itself"
	}; // "; here is necessary"
	-1 // "funky rust return, due to syntax consistency across braces"
};

cli log(binary_search([1, 3, 5, 7, 9], 7)); // "3"
```

---

## 9. Open Questions & Unknowns
**[UNKNOWN]** - *This section is specifically for feedback.*

1.  **Closure vs. Grounding**: Currently, Sequences do not capture context automatically. Is this too strict for practical programming? Should there be a syntax sugar for "Capture this Tuple into a Sequence"? This needs practical testing. My opinion on this is that Sequence nevere vapture it's dependencies, there's the Tuple for that.
2.  **Performance**: It's possible to compile those abstractions with optimizations via library, the problem is that it needs to be designed.

---

## 10. Potential & Future Directions
**[THEORETICAL]**

*   **Cognitive Architecture**: ENIGMA's layering resembles human "Context/Task" switching. It could serve as a model for AI cognitive architectures.
*   **Self-Hosting**: Because `Artifact` can compile code, ENIGMA can redefine its own parser and runtime. It is theoretically "The Last Language."
*   **Distributed Computing**: Since context is explicit, an Isolated Membrane could theoretically be serialized and executed on a remote machine seamlessly.