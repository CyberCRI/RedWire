angular.module('gamEvolve.game.transformers', [
  'ui.bootstrap',
])
.controller 'TransformersListCtrl', ($scope, $dialog, currentGame) ->
  # Get the transformers object from the currentGame service, and keep it updated
  $scope.transformers = {}
  $scope.transformerNames = []

  # Bring currentGame into scope so we can watch it 
  updateTransformers = ->
    if currentGame.version?.transformers?
      $scope.transformers = currentGame.version.transformers
      $scope.transformerNames = _.keys(currentGame.version.transformers)
  $scope.currentGame = currentGame
  $scope.$watch("currentGame.localVersion", updateTransformers, true)

  $scope.remove = (transformerName) ->
    if window.confirm("Are you sure you want to delete this transformer?")
      delete currentGame.version.transformers[transformerName]

  $scope.add = () ->
    addTransformerDialog = $dialog.dialog
      backdrop: true
      dialogFade: true
      backdropFade: true
      backdropClick: false
      templateUrl: 'game/transformers/editTransformer.tpl.html'
      dialogClass: "large-modal"
      controller: 'EditTransformerDialogCtrl'
      resolve:
        # This object will be provided to the dialog as a dependency, and serves to communicate between the two
        transformer: ->
          {
            model:
              name: ""
              arguments: []
              body: ""
            done: (model) ->
              currentGame.version.transformers[model.name] = 
                args: model.arguments
                body: model.body

              addTransformerDialog.close()
            cancel: ->
              addTransformerDialog.close()
          }
    addTransformerDialog.open()

  $scope.edit = (transformerName) -> 
    transformer = currentGame.version.transformers[transformerName]
    editTransformerDialog = $dialog.dialog
      backdrop: true
      dialogFade: true
      backdropFade: true
      backdropClick: false
      templateUrl: 'game/transformers/editTransformer.tpl.html'
      dialogClass: "large-modal"
      controller: 'EditTransformerDialogCtrl'
      resolve:
        # This object will be provided to the dialog as a dependency, and serves to communicate between the two
        transformer: ->
          {
            model:
              name: transformerName
              arguments: transformer.args
              body: transformer.body
            done: (model) ->
              # Handle rename case
              if model.name isnt transformerName
                delete currentGame.version.transformers[transformerName]

              currentGame.version.transformers[model.name] = 
                args: model.arguments
                body: model.body

              editTransformerDialog.close()
            cancel: ->
              editTransformerDialog.close()
          }
    editTransformerDialog.open()

.controller 'EditTransformerDialogCtrl', ($scope, transformer) ->
  $scope.name = transformer.model.name
  $scope.arguments = for argument in transformer.model.arguments 
    { value: argument } 
  $scope.body = transformer.model.body

  $scope.addArgument = -> $scope.arguments.push({ value: "" })
  $scope.removeArgument = (index) -> $scope.arguments.splice(index, 1)

  # Reply with the new data
  $scope.done = -> transformer.done 
    name: $scope.name
    arguments: for argument in $scope.arguments
      argument.value
    body: $scope.body
  $scope.cancel = -> transformer.cancel() 
  $scope.aceLoaded = -> console.log("ace loaded")
