angular.module('gamEvolve.game.tools', [
  'ui.bootstrap',
])
.controller 'ToolsListCtrl', ($scope, $dialog) ->
  $scope.tools = [1..10]

  dialog = null
  $scope.editTool = (tool) -> 
    console.log("picked tool #{tool}")
    dialog = $dialog.dialog
      backdrop: true
      dialogFade: true
      backdropFade: true
      templateUrl: 'game/tools/editTool.tpl.html',
      controller: 'EditToolDialogCtrl'
    dialog.open()

.controller 'EditToolDialogCtrl', ($scope) ->
