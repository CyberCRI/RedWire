angular.module('gamEvolve.model.users', [])

.factory 'users', ($http, $q) ->

    loggedUser: null,

    isUserLogged: ->
      @loggedUser?

    login: (username, password) ->
      deferred = $q.defer()
      promise = deferred.promise
      console.log 'Not implemented'
      promise