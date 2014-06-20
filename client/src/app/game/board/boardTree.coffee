angular.module('gamEvolve.game.boardTree', [
  'ui.bootstrap'
  'gamEvolve.game.board.editEmitterDialog'
  'gamEvolve.game.board.editProcessorDialog'
  'gamEvolve.game.board.editSplitterDialog'
  'treeRepeat'
  'gamEvolve.game.boardLabel'
  'gamEvolve.model.chips'
  'gamEvolve.game.boardNodes'
  'gamEvolve.model.circuits'
])

.controller 'BoardTreeCtrl', ($scope, $modal, currentGame, gameHistory, gameTime, treeDrag, chips, boardNodes, circuits) ->
  $scope.currentGame = currentGame
  $scope.treeDrag = treeDrag
  $scope.chips = chips 
  $scope.boardNodes = boardNodes

  $scope.isPreviewedAsSource = (chip) ->
    return false unless chip
    return false if chips.isRoot(chip)
    isDraggedAsSource(chip) && !isDraggedOverItself()

  isDraggedAsSource = (chip) ->
    source = treeDrag.data?.node
    chip is source

  isDraggedOverItself = ->
    source = treeDrag.data?.node
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
        showDialog 'game/board/editBoardProcessorDialog.tpl.html', 'EditBoardProcessorDialogCtrl', chip, (model) ->
          _.extend(chip, model)
      when "processor"
        showDialog 'game/board/editBoardProcessorDialog.tpl.html', 'EditBoardProcessorDialogCtrl', chip, (model) ->
          _.extend(chip, model)
      when "emitter"
        showDialog 'game/board/editBoardEmitterDialog.tpl.html', 'EditBoardEmitterDialogCtrl', chip, (model) ->
          _.extend(chip, model)
      when "splitter"
        showDialog 'game/board/editBoardSplitterDialog.tpl.html', 'EditBoardSplitterDialogCtrl', chip, (model) ->
          _.extend(chip, model)

  $scope.mute = (node) ->
    node.muted = !node.muted
    currentGame.updateLocalVersion()

  showDialog = (templateUrl, controller, model, onDone) ->
    dialog = $modal.open
      backdrop: true
      dialogFade: true
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

  $scope.drop = (source, target, sourceParent, targetParent) ->
    return if source is target
    return if source is chips.getCurrentBoard() # Ignore Main node DnD
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
