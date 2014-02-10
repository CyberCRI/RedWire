
angular.module('gamEvolve.game.boardTree', [
  'ui.bootstrap'
  'gamEvolve.game.board.editEmitterDialog'
  'gamEvolve.game.board.editProcessorDialog'
  'gamEvolve.game.board.editSplitterDialog'
])

.directive 'boardTree', (currentGame, boardConverter) ->

    dnd =

      drag_check: (data) ->
        # No dropping in processors or emitters
        if data.r.attr('rel') in ['processor', 'emitter'] then return false

        # TODO: allow adding nodes before and after, not just inside
        result =
          after: false
          before: false
          inside: true
        return result

      drag_finish: (data) ->
        source = if 'processor-id' of data.o.attributes
            processor: data.o.attributes['processor-id'].nodeValue
            pins:
              in: {}
              out: {}
          else if 'switch-id' of data.o.attributes
            switch: data.o.attributes['switch-id'].nodeValue
            pins:
              in: {}
              out: {}
          else if 'emitter' of data.o.attributes
            emitter: {}
          else if 'splitter' of data.o.attributes
            splitter:
              from: ''
              bindTo: ''
              index: ''
          else
            throw new Error("Unknown element #{data.o} accepted for drag and drop")

        path = data.r.data('path')
        target = currentGame.getTreeNode(path)

        # If the target doesn't have children, it needs an empty list
        if not target.children? then target.children = []
        target.children.unshift source

    types =
      switch:
        icon:
          image: '/assets/images/switch.png'
      processor:
        valid_children: [] # Leaves in the tree
        icon:
          image: '/assets/images/processor.png'
      emitter:
        valid_children: [] # Leaves in the tree
        icon:
          image: '/assets/images/emitter.png'
      splitter:
        icon:
          image: '/assets/images/splitter.png'

    restrict: 'E'
    scope: {}
    controller: 'BoardCtrl'

    link: (scope, element) ->

      updateModel = ->
        treeJson = $.jstree._reference(element).get_json()[0]
        reverted = boardConverter.revert(treeJson)
        currentGame.version.board = reverted

      scope.updateTree = (board) ->
        $(element).jstree
          json_data:
            data: board
          dnd: dnd
          types:
            types: types
          core:
            html_titles: true
          plugins: ['themes', 'ui', 'json_data', 'dnd', 'types', 'wholerow', 'crrm']
        .bind "move_node.jstree", ->
          updateModel()

      $(element).on 'click', 'a[editChip]', (eventObject) ->
        clicked = $(eventObject.target)
        emitEditEvent = (path) ->
          scope.$emit 'editChipButtonClick', JSON.parse(path)
        if clicked.attr('editChip')
          emitEditEvent clicked.attr('editChip')
        else
          emitEditEvent $(clicked.parent()[0]).attr('editChip')

      $(element).on 'click', 'a[removeChip]', (eventObject) ->
        clicked = $(eventObject.target)
        emitRemoveEvent = (path) ->
          scope.$emit 'removeChipButtonClick', JSON.parse(path)
        if clicked.attr('removeChip')
          emitRemoveEvent clicked.attr('removeChip')
        else
          emitRemoveEvent $(clicked.parent()[0]).attr('removeChip')


.controller 'BoardCtrl', ($scope, $dialog, boardConverter, currentGame, gameHistory, gameTime) ->

    $scope.game = currentGame

    # When the board changes, update in scope
    updateBoard = ->
      if currentGame.version?.board
        $scope.updateTree( boardConverter.convert(currentGame.version.board) )
    $scope.$watch('game.version.board', updateBoard, true)

    # Update from gameHistory
    onUpdateGameHistory = ->
      if not gameHistory.data.frames[gameTime.currentFrameNumber]? then return
      newMemory = gameHistory.data.frames[gameTime.currentFrameNumber].memory
      if not _.isEqual($scope.memory, newMemory)
        $scope.memory = newMemory
    $scope.$watch('gameHistoryMeta', onUpdateGameHistory, true)

    showDialog = (templateUrl, controller, model, onDone) ->
      dialog = $dialog.dialog
        backdrop: true
        dialogFade: true
        backdropFade: true
        backdropClick: false
        templateUrl: templateUrl
        controller: controller
        resolve:
        # This object will be provided to the dialog as a dependency, and serves to communicate between the two
          liaison: ->
            {
            model: GE.cloneData(model)
            done: (newModel) ->
              onDone(newModel)
              dialog.close()
            cancel: ->
              dialog.close()
            }
      dialog.open()

    $scope.remove = (path) ->
      [parent, index] = getBoardParentAndKey(currentGame.version.board, path)
      parent.children.splice(index, 1) # Remove that child

    $scope.edit = (path) ->
      chip = currentGame.getTreeNode(path)
      # Determine type of chip
      if 'processor' of chip
        showDialog 'game/board/editBoardProcessorDialog.tpl.html', 'EditBoardProcessorDialogCtrl', chip, (model) ->
          _.extend(chip, model)
      else if 'switch' of chip
        showDialog 'game/board/editBoardProcessorDialog.tpl.html', 'EditBoardProcessorDialogCtrl', chip, (model) ->
          _.extend(chip, model)
      else if 'splitter' of chip
        showDialog 'game/board/editBoardSplitterDialog.tpl.html', 'EditBoardSplitterDialogCtrl', chip, (model) ->
          _.extend(chip, model)
      else if 'emitter' of chip
        showDialog 'game/board/editBoardEmitterDialog.tpl.html', 'EditBoardEmitterDialogCtrl', chip, (model) ->
          _.extend(chip, model)

    $scope.$on 'editChipButtonClick', (event, chipPath) ->
      $scope.edit(chipPath)

    $scope.$on 'removeChipButtonClick', (event, chipPath) ->
      $scope.remove(chipPath)