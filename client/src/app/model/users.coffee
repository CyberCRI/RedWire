angular.module('gamEvolve.model.users', [])

.factory 'loggedUser', ->

    profile: null

    isLoggedIn: -> @profile?

    isNotLoggedIn: -> not @isLoggedIn()


.factory 'users', (loggedUser, $http, $q) ->

    logUser = (username, password) ->
      deferred = $q.defer()
      $http.post('/users/login', {username: username, password: password})
        .then ->
          $http.get('/users/me')
        ,
          ->
            deferred.reject('Error')
        .then (result) ->
          if result
            user = result.data
            loggedUser.profile = user
            deferred.resolve(user)
          else
            deferred.reject('Error')
      deferred.promise

    login: logUser

    logout: ->
      loggedUser.profile = null

    findByEmail: (email) ->
      $http.get('/users/?{"email": "' + email + '"}')

    createAndLogin: (username, email, password) ->
      $http.post('/users', {username: username, email: email, password: password}).then ->
        logUser(username, password)
