angular.module('gamEvolve.game.boardNodes', [])


.factory 'boardNodes', (currentGame, ProcessorRenamedEvent, SwitchRenamedEvent, editorContext) ->

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
    else if node is currentGame.version?.circuits[editorContext.currentCircuitMeta.type].board then return true # Root node is always open
    else return openNodeKeys[node.$$hashKey] is true

  open = (node) ->
    if node.$$hashKey
      openNodeKeys[node.$$hashKey] = true

  close = (node) ->
    if node.$$hashKey
      openNodeKeys[node.$$hashKey] = false

  labelClicked: (node) =>
    return if node is currentGame.version?.circuits[editorContext.currentCircuitMeta.type].board # Ignore clicks on root node
    if isOpen(node)
      close(node)
    else
      open(node)

  isOpen: isOpen
  open: open
  close: close