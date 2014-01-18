editToolDialog = null

angular.module('gamEvolve.game.tools', [
  'ui.bootstrap',
])
.controller 'ToolsListCtrl', ($scope, $dialog) ->
  $scope.tools = [1..10]

  $scope.editTool = (tool) -> 
    console.log("picked tool #{tool}")
    editToolDialog = $dialog.dialog
      backdrop: true
      dialogFade: true
      backdropFade: true
      templateUrl: 'game/tools/editTool.tpl.html',
      controller: 'EditToolDialogCtrl'
    editToolDialog.open()

.controller 'EditToolDialogCtrl', ($scope) ->
  $scope.functionText = "hi"
  $scope.done = -> editToolDialog.close()
  $scope.aceLoaded = -> console.log("ace loaded")
