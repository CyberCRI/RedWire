Bugs
====


TODO
====

- Asset storage
  - Temporary storage
  - Binary/object format
  - Tree layout

- Replace "onchanged" with array of conditions for update?

- Streams (Sevices)
  - Communicate through models
  - Can gather events outside of the event loop
  - An action can be wired to different models (e.g. fading music player vs. immediate sound clip player)
  - All communication logs which action did it
  - Examples
    - Canvas
    - Sound
    - Network
    - SVG
    - HTML events
  - Using the HTTP service may be done by creating subactions
  - Rephrase asset loading as service?

- Examples
  - Angry birds
  - Multiplayer
  - Logging

- Errors

- Tests
  - Functional/smoke tests (requires setup)

- Restart sequence, destroy residuals, ...

- Level Design
  - view and controller actions that manipulate serializable data?
  - editor actions activated in "design" mode?

- Creating and destroying sub-actions


Questions
=========

- Signals
  - How to handle errors?
    - Policies: abandon, retry, custom...
  - Does the DONE signal stop the action by default?
- Action-action interactions 
  - need to explicitely start/stop them?
- Need for "suspended" action?
  - Could just kill it, since data will stay in place
- Composed actions
  - Explicitely declare free parameters?
    - Pros: clear dependencies
    - Cons: computer can find depencies by itself, easier refactoring
  - How to package models as well?
    - Based on mixin or model-transformation?
- Definition blocks
  - Explicit or exist for any block?
- Need to "clean up" in a destroy block?
  - This would be better done with associating resources (e.g. HTML elemnents) with owning actions
- How to include this into a full app?
- Need syntax sugar to only run "update" on changes? 
- Classify in/out status of parameters?
- Type conversions - explicit, implicit, or forbidden?
- Is there not the need to parameterize an action tree by other actions (template method pattern)?
  - If no, good!

Findings
========

- Custom syntax is best, followed by XML
  - XML has trouble with lists
  - Custom format requires custom parser
- Default "parallel" behavoir is convienient
- Injecting parameters based on names reduces variable scoping
- Children can be named (labeled edge, JS object) or unnamed (unlabled edge, JS array)
- All actions are stopped at start
  - At program start, the root action is enabled
  - At start, the root can decide to disable some children
  - At stop, the subtree is stopped
- Actions can log their reasoning
  - The return value is logged by default
- Contracts (invariants) can be written to be called before and after each update call
- Update can be split into different steps:
  - contract
  - onModelChange
  - contract
- Unit tests can be phrased simply in terms of input -> output (at least for params)
