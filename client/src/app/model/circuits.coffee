angular.module('gamEvolve.model.circuits', [])

.factory "circuits", (currentGame, WillChangeLocalVersionEvent) ->
  WillChangeLocalVersionEvent.listen ->
    if not currentGame.version? then return

    # Check for consisteny regarding circuits and their layers
    circuitMetas = RW.listCircuitMeta(currentGame.version.circuits)
    for circuitMeta in circuitMetas
      # Each circuit should contain a layer for each of its contained circuits
      layers = currentGame.version.circuits[circuitMeta.type].io.layers
      # These circuit IDs are relative
      existingCircuitLayerIds = _.pluck(_.where(layers, { type: "circuit" }), "name")
      containedCircuitIds = _.chain(circuitMetas)
        .filter((otherCircuitMeta) -> RW.getParentCircuitId(otherCircuitMeta.id) is circuitMeta.id)
        .pluck("id")
        .map(RW.getChildCircuitId)
        .value()

      # Create circuit layers
      for circuitId in _.difference(containedCircuitIds, existingCircuitLayerIds)
        layers.push
          type: "circuit"
          name: circuitId

      # Remove useless circuit layers
      circuitIdsToRemove = _.difference(existingCircuitLayerIds, containedCircuitIds)
      layers = _.reject(layers, (layer) -> layer.name in circuitIdsToRemove)

      currentGame.version.circuits[circuitMeta.type].io.layers = layers

  return {
    currentCircuitMeta: new RW.CircuitMeta("main", "main")
    reset: -> @currentCircuitMeta = new RW.CircuitMeta("main", "main")
  }
