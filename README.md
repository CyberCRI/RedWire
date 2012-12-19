Bugs
====


TODO
====

- Asset storage
  - Temporary storage
  - Binary/object format
  - Tree layout

- Errors

- Examples
  - Angry birds
  - Multiplayer
  - Logging

- Restart sequence, destroy residuals, ...

- Tests
  - Functional/smoke tests (requires setup)

- Level Design
  - allow editor actions that activated in "design" mode?
    - move objects/graphics on the screen
  - view and controller actions that manipulate serializable data?
  - setup level by hand, save it as asset, and then have action "merge" to saved states when level loaded? 


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
- How should assets be accessed by actions and services?
  - As a shared map?
  - As parameters (eventually typed)?
  - As a tree?
- Would require.js bindings on actions be useful for internal libraries?
- Can an action call one function (such as stop()) from within another (like update())?
- How to handle foreach?
  - One action deal with multiple models?
  - A foreach action that loops on the model?
  - Composable actions- a single action is folded into a foreach action?
- Should action be able to create/remove other actions on the fly?

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
- Services can be used to capture/filter/debug/display meta info about I/O 
  - Otherwise they are not that useful!
  - Ideal service is a perfect proxy (not yet available)
- Require.JS bindings are nice for extenal libraries 
- Event handling
  - Actions that receive input can use handlers, through the handlers() indirection function, storing values in locals
  - Default handlers through signalEvent() that pushes an event into the end of a standard array, like locals.events
- Timing
  - Need global "time" info that refers to the game time
  - Need timeChanged() parameters
- Data types
  - Enum data type is useful
  - Custom data types are also useful (and converters could be provided later)
  - Should have these options: range, allowNull, default 
  - Algebraic data types would be the best