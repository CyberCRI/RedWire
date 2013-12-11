angular.module('gamEvolve.model.users', [])

.factory 'loggedUser', ->

    loggedUser: null

    set: (user) -> @loggedUser = user

    get: -> @loggedUser

    isLogged: -> @loggedUser?

.factory 'users', (loggedUser, $http, $q) ->

    login: (username, password) ->
      deferred = $q.defer()
      promise = deferred.promise
      $http.post('/users/login', {username: username, password: password})
        .then -> $http.get('/users/me')
        .then (result) ->
          user = result.data
          loggedUser.set user
          deferred.resolve(user)
      promise