angular.module('gamEvolve.game.boardTree', [
  'ui.bootstrap'
  'gamEvolve.game.board.editEmitterDialog'
  'gamEvolve.game.board.editChipPinsDialog'
  'gamEvolve.game.board.editSplitterDialog'
  'treeRepeat'
  'gamEvolve.game.boardLabel'
  'gamEvolve.model.chips'
  'gamEvolve.game.boardNodes'
  'gamEvolve.model.circuits'
])

.controller 'BoardTreeCtrl', ($scope, $modal, currentGame, gameHistory, gameTime, treeDrag, chips, boardNodes, circuits, dndHelper, games) ->
  $scope.currentGame = currentGame
  $scope.treeDrag = treeDrag
  $scope.chips = chips 
  $scope.boardNodes = boardNodes

  $scope.isGameLoaded = -> $scope.currentGame.version?

  # Because object identity is used to identify nodes, we need to use the local drag objects if possible
  $scope.getDraggedData = ->
    if treeDrag.data then treeDrag.data else dndHelper.getDraggedData()

  $scope.isPreviewedAsSource = (chip) ->
    return false unless chip
    return false if chips.isRoot(chip)
    isDraggedAsSource(chip) && !isDraggedOverItself()

  isDraggedAsSource = (chip) ->
    source = $scope.getDraggedData()?.node
    chip is source

  isDraggedOverItself = ->
    source = $scope.getDraggedData()?.node
    target = treeDrag.lastHovered
    source is target or isFirstChildOf(source, target)

  isFirstChildOf = (chip, suspectedParent) ->
    chip is suspectedParent?.children?[0]

  isDraggedAsTarget = (chip) ->
    target = treeDrag.lastHovered
    chip is target

  $scope.isPreviewedAsTarget = (chip) ->
    return false unless chip
    isDraggedAsTarget(chip) && !isDraggedOverItself()

  $scope.allowDrop = (source) ->
    return false if chips.isRoot(source)
    chipType = chips.getType source
    return chipType in chips.types

  $scope.edit = (chip) ->
    switch chips.getType(chip) # Type of dialog depends on type of chip
      when "switch"
        showDialog 'game/board/editBoardChipPinsDialog.tpl.html', 'EditBoardChipPinsDialogCtrl', chip, (model) ->
          _.extend(chip, model)
      when "processor"
        showDialog 'game/board/editBoardChipPinsDialog.tpl.html', 'EditBoardChipPinsDialogCtrl', chip, (model) ->
          _.extend(chip, model)
      when "emitter"
        showDialog 'game/board/editBoardEmitterDialog.tpl.html', 'EditBoardEmitterDialogCtrl', chip, (model) ->
          _.extend(chip, model)
      when "splitter"
        showDialog 'game/board/editBoardSplitterDialog.tpl.html', 'EditBoardSplitterDialogCtrl', chip, (model) ->
          _.extend(chip, model)
      when "circuit"
        # Rename id -> comment and back again
        newChip = _.extend({}, chip, { comment: chip.id })
        showDialog 'game/board/editBoardChipPinsDialog.tpl.html', 'EditBoardChipPinsDialogCtrl', newChip, (model) ->
          newModel = _.extend({}, model, { id: model.comment })
          if chip.id isnt model.comment
            # Rename circuit layer
            parentCircuit = currentGame.version.circuits[circuits.currentCircuitMeta.type] 
            circuitLayer = _.findWhere(parentCircuit.io.layers, { name: chip.id })
            if circuitLayer then circuitLayer.name = newModel.id

          _.extend(chip, newModel)

  $scope.mute = (node) ->
    node.muted = !node.muted
    currentGame.updateLocalVersion()

  $scope.switchCircuit = (circuitNode) ->
    if circuits.currentCircuitMeta.id
      # We are in a circuit instance, so load a new instance
      circuits.currentCircuitMeta = new RW.CircuitMeta(RW.makeCircuitId(circuits.currentCircuitMeta.id, circuitNode.id), circuitNode.circuit)
    else
      circuits.currentCircuitMeta = new RW.CircuitMeta(null, circuitNode.circuit)

  $scope.listOtherCircuitTypes = ->
    if not currentGame.version? then return []

    circuitType for circuitType of currentGame.version.circuits when circuitType isnt circuits.currentCircuitMeta.type

  $scope.moveChipToCircuit = (node, parent, circuitType) ->
    index = parent.children.indexOf(node)
    parent.children.splice(index, 1) # Remove that child

    destinationCircuit = currentGame.version.circuits[circuitType]
    destinationCircuit.board.children.push(node)

    currentGame.updateLocalVersion()

  showDialog = (templateUrl, controller, model, onDone) ->
    dialog = $modal.open
      backdrop: "static"
      templateUrl: templateUrl
      controller: controller
      size: "lg"
      resolve:
      # This object will be provided to the dialog as a dependency, and serves to communicate between the two
        liaison: ->
          {
          model: RW.cloneData(model)
          done: (newModel) ->
            onDone(newModel)
            currentGame.updateLocalVersion()
            dialog.close()
          cancel: ->
            dialog.close()
          }

  $scope.remove = (node, parent) ->
    if window.confirm("Are you sure you want to delete this chip?")
      index = parent.children.indexOf node
      parent.children.splice(index, 1) # Remove that child
      currentGame.updateLocalVersion()

  $scope.enter = (node) ->
    boardNodes.open(node) unless treeDrag.dropBefore

  $scope.drop = (dragData, target, targetParent) ->
    source = dragData.node
    sourceParent = dragData.parent
    return if source is target
    return if source is chips.getCurrentBoard() # Ignore Main node DnD
    
    if not dndHelper.dragIsFromSameWindow(dragData)
      # Copy chip dependencies
      copiedChipCount = dndHelper.copyChip(dragData.gameId, dragData.versionId, dragData.node)
      # Record mixing of game
      games.recordMix(dndHelper.getDraggedGameId(dragData))

    # IDs must be unique for this parent, like for ciruits
    if "id" of source 
      siblings = if treeDrag.dropBefore 
          targetParent.children
        else if chips.acceptsChildren(target) 
          target.children
        else 
          targetParent.children

      # Keep trying new names until one fits
      existingIds = _.pluck(siblings, "id")
      nextId = source.id
      nextIndex = 2
      while nextId in existingIds
        nextId = "#{source.id} #{nextIndex}"
        nextIndex++
      source.id = nextId

    # Put the dropped node into the right place
    if treeDrag.dropBefore
      moveBeforeTarget(source, target, sourceParent, targetParent)
    else if chips.acceptsChildren(target)
      moveInsideTarget(source, target, sourceParent)
    else
      moveAfterTarget(source, target, sourceParent, targetParent)
    
    currentGame.updateLocalVersion()

  moveBeforeTarget = (source, target, sourceParent, targetParent) ->
    removeSourceFromParent(source, sourceParent)
    targetIndex = targetParent.children.indexOf(target)
    targetParent.children.splice targetIndex, 0, source

  removeSourceFromParent = (source, parent) ->
    if parent
      for child, i in parent.children
        if child is source
          parent.children.splice i, 1
          break

  moveInsideTarget = (source, target, sourceParent) ->
    removeSourceFromParent(source, sourceParent)
    target.children.unshift source
    boardNodes.open(target) # Make sure user can see added node

  moveAfterTarget = (source, target, sourceParent, targetParent) ->
    removeSourceFromParent(source, sourceParent)
    targetIndex = targetParent.children.indexOf(target)
    targetParent.children.splice targetIndex + 1, 0, source
