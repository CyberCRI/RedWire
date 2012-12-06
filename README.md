Bugs
====


TODO
====

- Examples
  - Angry birds
  - Multiplayer
  - Logging

- Define blocks

- Assertions

- Sending signals
  - error: exceptions
  - done: return special value?
  - custom signals: ?

- Tests

Questions
=========

- Signals
  - How to handle errors?
    - Policies: abandon, retry, custom...
  - Does the DONE signal stop the action by default?
- Action-action interactions 
  - need to explicitely start/stop them?
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
- Streams


Findings
========

- Custom syntax is best, followed by XML
  - XML has trouble with lists
  - Custom format requires custom parser
- Default "parallel" behavoir is convient
- Injecting parameters based on names reduces variable scoping
- Children can be named (labeled edge, JS object) or unnamed (unlabled edge, JS array)


