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

.controller 'MemoryCtrl', ($scope, gameHistory, gameTime, currentGame, circuits) ->
  $scope.gameHistoryMeta = gameHistory.meta 
  $scope.gameTime = gameTime

  onEditorChange = -> $scope.$apply(onUpdateMemoryEditor)

  editor = new JSONEditor $("#memoryEditor")[0],
    change: _.debounce(onEditorChange, WAIT_TIME)
    name: "memory"
    history: false
    search: false
    modes: ["tree", "code", "text"]

  # Update from gameHistory
  onUpdateMemoryModel = ->
    if not gameHistory.data.frames[gameTime.currentFrameNumber]? then return 

    memoryModel = 
      if gameTime.currentFrameNumber is 0
        # Get the initial data for the circuit type
        currentGame.version.circuits[circuits.currentCircuitMeta.type].memory
      else
        # Get the current data for the circuit instance
        if circuits.currentCircuitMeta.id?
          gameHistory.data.frames[gameTime.currentFrameNumber].memory[circuits.currentCircuitMeta.id]
        else 
          # No data to edit
          # TODO: disable the editor
          {} 

    if _.isEqual(memoryModel, editor.get()) then return 

    # Editor.node won't exist outside of "tree" view
    if editor.node? then save = saveExpandedNodes(editor.node)

    # Clone so that the editor doesn't modify our recorded data directly
    editor.set(RW.cloneData(memoryModel))

    # Editor.node won't exist outside of "tree" view
    if editor.node? then restoreExpandedNodes(editor.node, save)

  $scope.$watch('gameHistoryMeta', onUpdateMemoryModel, true)
  $scope.$watch((-> circuits.currentCircuitMeta), onUpdateMemoryModel)
  $scope.$watch('gameTime.currentFrameNumber', onUpdateMemoryModel)

  # Write back to gameHistory
  onUpdateMemoryEditor = ->
    if not gameHistory.data.frames[gameTime.currentFrameNumber]? then return 

    newMemory = RW.cloneData(editor.get())

    # Update the frame memory
    if circuits.currentCircuitMeta.id?
      gameHistory.data.frames[gameTime.currentFrameNumber].memory[circuits.currentCircuitMeta.id] = newMemory
      gameHistory.meta.version++

    # If we are on the first frame, update the game memory as well
    if gameTime.currentFrameNumber == 0 and circuits.currentCircuitMeta.type?
      currentGame.version.circuits[circuits.currentCircuitMeta.type].memory = newMemory
      currentGame.updateLocalVersion()
