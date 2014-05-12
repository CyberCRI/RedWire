angular.module('gamEvolve.game.boardNodes', [])


.factory 'boardNodes', (currentGame) ->

  openNodeKeys = {}

  isOpen = (node) ->
    if not node then return false
    else if node is currentGame.version.board then return true # Root node is always open
    else return openNodeKeys[node.$$hashKey] is true

  open = (node) ->
    if not node.$$hashKey
      console.error 'No $$hashKey found for node :', node
    else
      openNodeKeys[node.$$hashKey] = true

  close = (node) ->
    if not node.$$hashKey
      console.error 'No $$hashKey found for node :', node
    else
      openNodeKeys[node.$$hashKey] = false

  labelClicked: (node) =>
    return if node is currentGame.version.board # Ignore clicks on root node
    if isOpen(node)
      close(node)
    else
      open(node)

  isOpen: isOpen
  open: open
  close: close