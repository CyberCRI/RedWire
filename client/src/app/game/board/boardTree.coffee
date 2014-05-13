angular.module('gamEvolve.game.boardTree', [
  'ui.bootstrap'
  'gamEvolve.game.board.editEmitterDialog'
  'gamEvolve.game.board.editProcessorDialog'
  'gamEvolve.game.board.editSplitterDialog'
  'treeRepeat'
  'gamEvolve.game.boardLabel'
  'gamEvolve.model.chips'
  'gamEvolve.game.boardLabel'
])

.controller 'BoardTreeCtrl', ($scope, $dialog, currentGame, gameHistory, gameTime, treeDrag, chips, boardNodes) ->

  $scope.currentGame = currentGame
  $scope.treeDrag = treeDrag
  $scope.chips = chips
  $scope.boardNodes = boardNodes

  $scope.isPreviewedAsSource = (chip) ->
    return false unless chip
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

  showDialog = (templateUrl, controller, model, onDone) ->
    dialog = $dialog.dialog
      backdrop: true
      dialogFade: true
      backdropFade: true
      backdropClick: false
      templateUrl: templateUrl
      controller: controller
      dialogClass: "large-modal"
      resolve:
      # This object will be provided to the dialog as a dependency, and serves to communicate between the two
        liaison: ->
          {
          model: RW.cloneData(model)
          done: (newModel) ->
            onDone(newModel)
            dialog.close()
          cancel: ->
            dialog.close()
          }
    dialog.open()

  $scope.remove = (node, parent) ->
    if window.confirm("Are you sure you want to delete this chip?")
      index = parent.children.indexOf node
      parent.children.splice(index, 1) # Remove that child

  $scope.enter = (node) ->
    boardNodes.open(node) unless treeDrag.dropBefore

  $scope.drop = (source, target, sourceParent, targetParent) ->
    return if source is target
    return if source is currentGame.version.board # Ignore Main node DnD
    if treeDrag.dropBefore
      moveBeforeTarget(source, target, sourceParent, targetParent)
    else if chips.acceptsChildren(target)
      moveInsideTarget(source, target, sourceParent)
    else
      moveAfterTarget(source, target, sourceParent, targetParent)

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
    targetParent.children.splice targetIndex+1, 0, source

  # TODO Remove or move to right place
  # Update from gameHistory
  onUpdateGameHistory = ->
    if not gameHistory.data.frames[gameTime.currentFrameNumber]? then return
    newMemory = gameHistory.data.frames[gameTime.currentFrameNumber].memory
    if not _.isEqual($scope.memory, newMemory)
      $scope.memory = newMemory
  $scope.$watch('gameHistoryMeta', onUpdateGameHistory, true)