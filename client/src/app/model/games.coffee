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

    loadJson: (gameName) ->
      deferred = $q.defer()
      promise = deferred.promise
      $http.get("/json/games/#{gameName}.json")
        .error( (error) ->
          console.log 'games.loadJson()', error
          # showMessage(MessageType.Error, "Cannot load game files")
          deferred.reject error
        )
        .success( (result) ->
          game = {}
          for propertyName in @propertyNames
            game[propertyName] = JSON.stringify(result[propertyName], null, 2)
          deferred.resolve game
        )
      promise
