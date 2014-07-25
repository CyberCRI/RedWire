angular.module('gamEvolve.model.circuits', [])

.factory "circuits", (currentGame, WillChangeLocalVersionEvent) ->
  # Check for consisteny regarding circuits and their layers or channels
  enforceConsistentCircuitEntries = (type) ->
    circuitMetas = RW.listCircuitMeta(currentGame.version.circuits)
    for circuitMeta in circuitMetas
      # Each circuit should contain a entry for each of its contained circuits
      entries = currentGame.version.circuits[circuitMeta.type].io[type]
      # These circuit IDs are relative
      existingCircuitentryIds = _.pluck(_.where(entries, { type: "circuit" }), "name")
      containedCircuitIds = _.chain(circuitMetas)
        .filter((otherCircuitMeta) -> RW.getParentCircuitId(otherCircuitMeta.id) is circuitMeta.id)
        .pluck("id")
        .map(RW.getChildCircuitId)
        .value()

      # Create circuit entries
      for circuitId in _.difference(containedCircuitIds, existingCircuitentryIds)
        entries.push
          type: "circuit"
          name: circuitId

      # Remove useless circuit entries
      circuitIdsToRemove = _.difference(existingCircuitentryIds, containedCircuitIds)
      entries = _.reject(entries, (entry) -> entry.name in circuitIdsToRemove)

      currentGame.version.circuits[circuitMeta.type].io[type] = entries

  WillChangeLocalVersionEvent.listen ->
    if not currentGame.version? then return
  
    enforceConsistentCircuitEntries("layers")
    enforceConsistentCircuitEntries("channels")

  return {
    currentCircuitMeta: new RW.CircuitMeta("main", "main")
    reset: -> @currentCircuitMeta = new RW.CircuitMeta("main", "main")
  }
