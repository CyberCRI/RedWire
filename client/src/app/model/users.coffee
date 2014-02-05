angular.module('gamEvolve.model.users', [])

.factory 'loggedUser', ->

    profile: null

    isLoggedIn: -> @profile?

    isNotLoggedIn: -> not @isLoggedIn()


.factory 'users', (loggedUser, $http, $q) ->

    login: (username, password) ->
      deferred = $q.defer()
      $http.post('/users/login', {username: username, password: password})
        .then ->
          $http.get('/users/me')
        ,
          ->
            deferred.reject('Error')
        .then (result) ->
          user = result.data
          loggedUser.profile = user
          deferred.resolve(user)
      deferred.promise

    logout: ->
      loggedUser.profile = null

    findByEmail: (email) ->
      $http.get('/users/?{"email": "' + email + '"}')