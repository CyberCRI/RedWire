angular.module('gamEvolve.model.editorContext', [])

.factory "editorContext", ->
  currentCircuitMeta: new RW.CircuitMeta("main", "main")
  reset: -> @currentCircuitMeta = new RW.CircuitMeta("main", "main")
