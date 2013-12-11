angular.module('gamEvolve.model.games', [])

.factory 'games', ($http, $q) ->

    propertyNames: [
      'actions'
      'assets'
      'layout'
      'model'
      'processes'
      'services'
      'tools'
    ]

    current: null

    getCurrent: -> @current

    loadJson: (gameName) ->
      deferred = $q.defer()
      promise = deferred.promise
      propertyNames = @propertyNames
      service = @
      $http.get("/assets/games/#{gameName}.json")
        .error( (error) ->
          # TODO Where does this line go ? showMessage(MessageType.Error, "Cannot load game files")
          deferred.reject error
        )
        .success( (game) ->
          for propertyName in propertyNames
            game[propertyName] = JSON.stringify(game[propertyName], null, 2)
          service.current = game
          deferred.resolve game
        )
      promise

    # For saving a new game created from scratch (no parent)
#    saveGameAction =
#      name: "Save"
#      execute: (game, loggedUser) ->
