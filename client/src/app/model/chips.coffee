angular.module('gamEvolve.model.chips', [])

.factory 'chips', (currentGame, circuits, gameConverter, GameVersionUpdatedEvent) ->

  GameVersionUpdatedEvent.listen (newVersion) ->
    for circuitId, circuit of newVersion.circuits
      gameConverter.removeHashKeys(circuit.board)

  types: [
    "switch"
    "processor"
    "emitter"
    "splitter"
    "circuit"
  ]

  # TODO: refactor calls to use getChipTypeAndName()
  getType: (chip) ->
    return "null" unless chip

    if "switch" of chip then "switch"
    else if "processor" of chip then "processor"
    else if "emitter" of chip then "emitter"
    else if "splitter" of chip then "splitter"
    else if "circuit" of chip then "circuit"
    else "Unknown"

  getChipCollection: (gameCode, chipType) ->
    switch chipType
      when "processor" then gameCode.processors
      when "circuit" then gameCode.circuits
      when "switch" then gameCode.switches
      when "transformer" then gameCode.transformers
      else throw new Error("No collection for chip '#{chipType}'")

  getChipTypeAndName: (chip) ->
    return "null" unless chip

    if "switch" of chip then ["switch", chip.switch]
    else if "processor" of chip then ["processor", chip.processor]
    else if "circuit" of chip then ["circuit", chip.circuit]
    else if "emitter" of chip then ["emitter", chip.comment]
    else if "splitter" of chip then ["splitter", chip.comment]
    else if "transformer" of chip then ["transformer", chip.transformer]
    else throw new Error("Unknown chip type for chip '#{JSON.stringify(chip)}'")

  acceptsChildren: (chip) ->
    return false unless chip
    if chip.switch or chip.processor or chip.splitter
      if not chip.children
        chip.children = []
      true
    else
      false

  hasChildren: (chip) ->
    return chip && chip.children && chip.children.length > 0

  isRoot: (chip) ->
    return chip is @getCurrentBoard()

  getCurrentBoard: -> currentGame.version?.circuits[circuits.currentCircuitMeta.type].board
