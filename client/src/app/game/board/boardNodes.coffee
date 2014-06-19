angular.module('gamEvolve.game.boardNodes', [])


.factory 'boardNodes', (currentGame, chips, ProcessorRenamedEvent, SwitchRenamedEvent) ->

  ProcessorRenamedEvent.listen (event) ->
    renameChips(currentGame.version.circuits[editorContext.currentCircuitMeta.type].board, 'processor', event.oldName, event.newName)

  SwitchRenamedEvent.listen (event) ->
    renameChips(currentGame.version.circuits[editorContext.currentCircuitMeta.type].board, 'switch', event.oldName, event.newName)

  renameChips = (chip, chipType, oldName, newName) ->
    if chip[chipType] is oldName
      chip[chipType] = newName
    angular.forEach(chip.children, (child) -> renameChips(child, chipType, oldName, newName))

  openNodeKeys = {}

  isOpen = (node) ->
    if not node then return false
    else if node is chips.getCurrentBoard() then return true # Root node is always open
    else return openNodeKeys[node.$$hashKey] is true

  open = (node) ->
    if node.$$hashKey
      openNodeKeys[node.$$hashKey] = true

  close = (node) ->
    if node.$$hashKey
      openNodeKeys[node.$$hashKey] = false

  labelClicked: (node) =>
    return if node is chips.getCurrentBoard() # Ignore clicks on root node
    if isOpen(node)
      close(node)
    else
      open(node)

  isOpen: isOpen
  open: open
  close: close