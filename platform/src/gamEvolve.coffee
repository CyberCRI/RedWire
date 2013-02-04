### 
  The algorithm is as follows:
    1. Get a static view of the model at the current time, and keep track of it
    2. Go though the layout from the top-down, recursively. For each:
      1. Check validity and error out otherwise
      2. Switch on block type:
        * If bind, execute query and store param bindings for lower items
        * If set, package with model bindings and add to execution list
        * If call, package with model bindings and add to execution list
        * If action: 
          1. Package with model bindings and add to execution list
          2. Run calculateActiveChildren() and continue with those recursively 
    3. For each active bound block:
      1. Run and gather output and error/success status
        * In case of error: Store error signal
        * In case of success: 
          1. Merge model changes with others. If conflict, nothing passes
          2. If DONE is signaled, store it
    4. Starting at parents of active leaf blocks:
      1. If signals are stored for children, call handleSignals() with them
      2. If more signals are created, store them for parents
###

# Declare the model namespace
model = 
  # Return an empty event list and the current data
  create: (pod = {}) -> return { events: [pod] }

  # TODO return time too
  getLastData: (m) -> return _.last(events)

  getDataAtEvent: (m, event) -> return m.events[event]

  makePatch: (m, pod) ->

  # TODO return time too
  applyPatches: (m, patch) ->





