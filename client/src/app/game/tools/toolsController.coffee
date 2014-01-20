angular.module('gamEvolve.game.tools', [
  'ui.bootstrap',
])
.controller 'ToolsListCtrl', ($scope, $dialog, currentGame) ->
  # Get the tools object from the currentGame service, and keep it updated
  $scope.tools = {}
  $scope.toolNames = []

  # Bring currentGame into scope so we can watch it 
  updateTools = ->
    if currentGame.version?.tools?
      $scope.tools = currentGame.version.tools
      $scope.toolNames = _.keys(currentGame.version.tools)
  $scope.currentGame = currentGame
  $scope.$watch('currentGame', updateTools, true)

  $scope.removeTool = (toolName) ->
    delete currentGame.version.tools[toolName]

  $scope.addTool = () ->
    addToolDialog = $dialog.dialog
      backdrop: true
      dialogFade: true
      backdropFade: true
      templateUrl: 'game/tools/editTool.tpl.html'
      controller: 'EditToolDialogCtrl'
      resolve:
        # This object will be provided to the dialog as a dependency, and serves to communicate between the two
        tool: ->
          {
            model:
              name: ""
              arguments: []
              body: ""
            done: (model) ->
              currentGame.version.tools[model.name] = 
                args: model.arguments
                body: model.body

              addToolDialog.close()
            cancel: ->
              addToolDialog.close()
          }
    addToolDialog.open()

  $scope.editTool = (toolName) -> 
    tool = currentGame.version.tools[toolName]
    editToolDialog = $dialog.dialog
      backdrop: true
      dialogFade: true
      backdropFade: true
      templateUrl: 'game/tools/editTool.tpl.html'
      controller: 'EditToolDialogCtrl'
      resolve:
        # This object will be provided to the dialog as a dependency, and serves to communicate between the two
        tool: ->
          {
            model:
              name: toolName
              arguments: tool.args
              body: tool.body
            done: (model) ->
              # Handle rename case
              if model.name isnt toolName
                delete currentGame.version.tools[toolName]

              currentGame.version.tools[model.name] = 
                args: model.arguments
                body: model.body

              editToolDialog.close()
            cancel: ->
              editToolDialog.close()
          }
    editToolDialog.open()

.controller 'EditToolDialogCtrl', ($scope, tool) ->
  $scope.name = tool.model.name
  $scope.arguments = for argument in tool.model.arguments 
    { value: argument } 
  $scope.body = tool.model.body

  $scope.addArgument = -> $scope.arguments.push({ value: "" })
  $scope.removeArgument = (index) -> $scope.arguments.splice(index, 1)

  # Reply with the new data
  $scope.done = -> tool.done 
    name: $scope.name
    arguments: for argument in $scope.arguments
      argument.value
    body: $scope.body
  $scope.cancel = -> tool.cancel() 
  $scope.aceLoaded = -> console.log("ace loaded")
