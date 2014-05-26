angular.module('gamEvolve.game.transformers', [
  'ui.bootstrap',
])
.controller 'TransformersListCtrl', ($scope, $modal, currentGame) ->
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
      currentGame.updateLocalVersion()

  $scope.add = () ->
    addTransformerDialog = $modal.open
      backdrop: "static"
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
              currentGame.updateLocalVersion()

              addTransformerDialog.close()
            cancel: ->
              addTransformerDialog.close()
          }

  $scope.edit = (transformerName) -> 
    transformer = currentGame.version.transformers[transformerName]
    editTransformerDialog = $modal.open
      backdrop: "static"
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

              currentGame.updateLocalVersion()
              editTransformerDialog.close()
            cancel: ->
              editTransformerDialog.close()
          }

.controller 'EditTransformerDialogCtrl', ($scope, transformer) ->
  # Need to put 2-way data binding under an object
  $scope.exchange = {}
  $scope.exchange.name = transformer.model.name
  $scope.exchange.arguments = for argument in transformer.model.arguments 
    { value: argument } 
  $scope.exchange.body = transformer.model.body

  $scope.addArgument = -> $scope.exchange.arguments.push({ value: "" })
  $scope.removeArgument = (index) -> $scope.exchange.arguments.splice(index, 1)

  # Reply with the new data
  $scope.done = -> transformer.done 
    name: $scope.exchange.name
    arguments: for argument in $scope.exchange.arguments
      argument.value
    body: $scope.exchange.body
  $scope.cancel = -> transformer.cancel() 
