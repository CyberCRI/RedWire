Bugs
====


TODO
====

- Config set loading/saving

- Can we use javascript properties to do references and also for each loops on arrays?

- Declare child connections.
  - Choices: none, list, named, and fixed valued (choices from enum).

- Try to integrate sprite.js for animation


Later
=====

- Errors
  - Thrown exceptions in actions create errors
  - Error policies can be set by error type or tag (to avoid hiararchies)
  - Error policies include restart element that created error, restart whole branch, switch branch, ignore, bubble up (default)

- Examples
  - Angry birds
  - Multiplayer
  - Logging

- Restart sequence, destroy residuals, ...

- Tests
  - Functional/smoke tests (requires setup)

- Level Design
  - allow editor actions that are activated in "design" mode?
    - move objects/graphics on the screen
  - view and controller actions that manipulate serializable data?
  - setup level by hand, save it as asset, and then have action "merge" to saved states when level loaded? 


Questions
=========

- Errors
  - What can you do in response to an error?
    - Retry a certain number of times or for a certain length of time (i.e. server not responding)
      - Restart action, then bubble error after condition is met
    - Alert the user (i.e. "sorry, you'll need to try again later")
      - Switch actions
    - Try alternative means (i.e. use static data, interpolate based on previous info, ...)
      - Switch actions
    - Restart the process with different info (i.e. return to a "safe state")
      - Set model, then restart
    - Ignore it and move on (i.e. skip logging in, just play)
      - Stop action, go to next 
    - Combination of these approaches
  - Besides reporting, error handling should be orthagonal to actions themselves
    - Custom actions could be used (similar to try/catch)
      - Pros: Explicit, flexible (new actions could be made). 
      - Cons: Adds more levels to the tree
    - Or policies as functions
      - Pros: Reduces tree depth
      - Cons: How to combine policies? How to switch branches?
    - Or a combination (errors for restart, ignore, ...) and actions for switching branches
  - To report errors, reportWarning() and reportError() functions 
    - Can throw exceptions or just log info depending on how the error handling is configured
    - And assert() functions could take a function to evaluate. If assertions are set to be ignored than the test is not even run
- Action-action interactions 
  - need to explicitely start/stop them?
- Packaging
  - How to package models, function, and actions together?
    - Based on mixin or model-transformation?
  - How to use namespaces?
- Need to "clean up" in a destroy block?
  - This would be better done with associating resources (e.g. HTML elemnents) with owning actions
- How to include this into a full app?
- Classify in/out status of parameters?
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
- Should assets have a tree layout?
- Should whitespace be significant in Booyah format?
  - Pros: Looks pretty. Less verbose. Forces consistant indentation practices
  - Cons: Spaces vs. tabs. Editors may not show whitespace. No single line expressions. Confusing in some multi-line cases. 
- How to set aritrary values in an action?
  - Setting the model through an action can be easily done for a single parameter, but is harder to do for several
  - Sets of key, value pairs
    - Requires different algorithm to match
  - Arbitrary (extra) parameters 
    - Hard to match up the parameters
  - Have define calls in the model be part of the action layout.
  - Load/push/pop config sets
- Indirection
  - ** Through "pointers" or symbolic links from one part of the model to the other? **
    - reference() and dereference() functions?
  - Through tags that can be assigned or searched in the model?
  - Through model addresses? 
- How to load a level?
  - Bring in data (models, assets, config?)
  - Merge or temporily override values? (stack-based approach)
  - Notion of "scenes" that include actions as well?
- Multiplayer
  - How to debug?
  - How to join/leave/start/stop games?
  - How to synchronize models?
    - Label parts as synchronizable or not?
- Share code using GitHub?
  - Packages using namespace ending with user IDs that are pulled from github
  - GitHub API can't list forks, so the site would have to keep track of them
  - Would you have one single repository? Or merge several repositories?
- How to handle output bindings?
  - Output function
    - Pros: easy to use
    - Cons: what is the initial value?
  - Create blank value and refer to it
  - ** Model references to insert in an array **
    - What is a reference?
- Use {} for arrays and objects in action layout?
  - Or use [] to create implicit sequence and {} to create implicit parallel (but still requires labels?)
- Use LINQ or similar syntax to define mappings?
  - More flexible than simple function calling, since filters can be applied
  - http://hugoware.net/projects/jlinq (but not sure you can filter afterwards)
- Merge operations to avoid conflicts (based on reduce operations such as sum(), max(), etc.)
- Make server component in Clojure?


Findings
========

- Custom syntax is best, followed by XML
  - XML has trouble with lists
  - Custom format requires custom parser
- Default "parallel" behavoir is convienient
- Injecting parameters based on names reduces variable scoping
- Children can be named (labeled edge, JS object) or unnamed (unlabled edge, JS array)
  - Since an array is an object, always use the object form
- All actions are stopped at start
  - At program start, the root action is enabled
  - At start, the root can decide to disable some children
  - At stop, the subtree is stopped
- Actions can log their reasoning
  - logInfo, logWarning, ... 
  - Additionally, the return value can be logged by default
- Contracts (invariants) can be written to be called before and after each update call
- Unit tests can be phrased simply in terms of input -> output (at least for params)
- Services can be used to capture/filter/debug/display meta info about I/O 
  - Otherwise they are not that useful!
  - Services may need "hooks" into certain events such as assets loading in order to track them
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
- Type conversions 
  - Explicit, not implicit
  - Conversions can be specified in layout.
- Directions can be specified for actions, so that they are not run when going back in time
  - Forward, backward
- Parameters can be bound to several sources: constant, config (completely loaded before start), assets, model, and expressions composed of these sources
- Stop calls should be done in reverse order of node execution 

