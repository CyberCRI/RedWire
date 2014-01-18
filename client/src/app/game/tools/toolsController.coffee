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
      resolve:
        tool: ->
          {
            model:
              arguments: ["a", "b"]
              body: "hello"
            done: (model) ->
              editToolDialog.close()
            cancel: ->
              editToolDialog.close()
          }
    editToolDialog.open()

.controller 'EditToolDialogCtrl', ($scope, tool) ->
  $scope.arguments = for argument in tool.model.arguments 
    { value: argument } 
  $scope.body = tool.model.body

  $scope.addArgument = -> $scope.arguments.push({ value: "" })
  $scope.removeArgument = (index) -> $scope.arguments.splice(index, 1)

  # Reply with the new data
  $scope.done = -> tool.done 
    arguments: for argument in $scope.arguments
      argument.value
    body: $scope.body
  $scope.cancel = -> tool.cancel() 
  $scope.aceLoaded = -> console.log("ace loaded")
