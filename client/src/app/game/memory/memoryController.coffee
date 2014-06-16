WAIT_TIME = 2000


saveExpandedNodes = (node) ->
  field: node.field
  type: node.type
  expanded: node.expanded
  children: if node.childs then (saveExpandedNodes(child) for child in node.childs) else null

restoreExpandedNodes = (node, save) ->
  # Don't bother expanding if the this isn't the same node
  if node.field isnt save.field or node.type isnt save.type then return 

  if save.expanded then node.expand(false) 
  if not node.childs or not save.children then return

  for index of node.childs
    if index >= save.children.length then return # Don't go past the end
    restoreExpandedNodes(node.childs[index], save.children[index]) 


angular.module('gamEvolve.game.memory', [])

.controller 'MemoryCtrl', ($scope, gameHistory, gameTime, currentGame, editorContext) ->
  $scope.gameHistoryMeta = gameHistory.meta 
  $scope.gameTime = gameTime

  onEditorChange = -> $scope.$apply(onUpdateMemoryEditor)

  editor = new jsoneditor.JSONEditor $("#memoryEditor")[0],
    change: _.debounce(onEditorChange, WAIT_TIME)
    name: "memory"

  # Update from gameHistory
  onUpdateMemoryModel = ->
    if not gameHistory.data.frames[gameTime.currentFrameNumber]? then return 

    memoryModel = 
      if gameTime.currentFrameNumber is 0
        currentGame.getCurrentCircuitData().memory
      else
        gameHistory.data.frames[gameTime.currentFrameNumber].memory[editorContext.currentCircuitMeta.id]

    if _.isEqual(memoryModel, editor.get()) then return 

    save = saveExpandedNodes(editor.node)

    # Clone so that the editor doesn't modify our recorded data directly
    editor.set(RW.cloneData(memoryModel))

    restoreExpandedNodes(editor.node, save)

  $scope.$watch('gameHistoryMeta', onUpdateMemoryModel, true)
  $scope.$watch((-> editorContext.currentCircuitMeta), onUpdateMemoryModel)
  $scope.$watch('gameTime.currentFrameNumber', onUpdateMemoryModel)

  # Write back to gameHistory
  onUpdateMemoryEditor = ->
    if not gameHistory.data.frames[gameTime.currentFrameNumber]? then return 

    # Update the frame memory
    newMemory = RW.cloneData(editor.get())
    gameHistory.data.frames[gameTime.currentFrameNumber].circuits[editorContext.currentCircuitMeta.id].memory = newMemory
    gameHistory.meta.version++

    # If we are on the first frame, update the game memory as well
    if gameTime.currentFrameNumber == 0 
      currentGame.getCurrentCircuitData().memory = newMemory
      currentGame.updateLocalVersion()
