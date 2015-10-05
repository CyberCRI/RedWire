angular.module('gamEvolve.game.boardNodes', [])


.factory 'boardNodes', (currentGame, chips, circuits, ProcessorRenamedEvent, SwitchRenamedEvent, WillChangeLocalVersionEvent) ->

  ProcessorRenamedEvent.listen (event) ->
    renameChips(currentGame.version.circuits[circuits.currentCircuitMeta.type].board, 'processor', event.oldName, event.newName)

  SwitchRenamedEvent.listen (event) ->
    renameChips(currentGame.version.circuits[circuits.currentCircuitMeta.type].board, 'switch', event.oldName, event.newName)

  WillChangeLocalVersionEvent.listen -> updateChipPaths()

  # If the chip already has a hash key, return it. Else create a new one 
  getOrMakeHashKey = (chip) ->
    if "$$hashKey" not of chip then chip.$$hashKey = _.uniqueId("hash") 
    return chip.$$hashKey 

  # Create map of chips to their paths 
  updateChipPaths = ->
    recursiveUpdate = (path, chip) ->
      chip.path = path
      for childIndex, childChip of chip.children
        childPath = RW.appendToArray(path, childIndex)
        recursiveUpdate(childPath, childChip)

    recursiveUpdate([], chips.getCurrentBoard())

  renameChips = (chip, chipType, oldName, newName) ->
    if chip[chipType] is oldName
      chip[chipType] = newName
    angular.forEach(chip.children, (child) -> renameChips(child, chipType, oldName, newName))

  openNodeKeys = {}

  isOpen = (node) ->
    if not node then return false
    else if node is chips.getCurrentBoard() then return true # Root node is always open
    else return openNodeKeys[getOrMakeHashKey(node)] is true

  open = (node) ->
    openNodeKeys[getOrMakeHashKey(node)] = true

  close = (node) ->
    openNodeKeys[getOrMakeHashKey(node)] = false

  labelClicked: (node) =>
    return if node is chips.getCurrentBoard() # Ignore clicks on root node
    if isOpen(node)
      close(node)
    else
      open(node)

  isOpen: isOpen
  open: open
  close: close

  getChipPath: (node) => node.path
