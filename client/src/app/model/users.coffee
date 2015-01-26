angular.module('gamEvolve.model.users', [])

.factory 'loggedUser', ($http) ->

    profile: null

    isLoggedIn: -> @profile?

    isNotLoggedIn: -> not @isLoggedIn()

    logout: ->
      $http.post('/api/users/logout').then -> console.log 'Logging Out'
      @profile = null


.factory 'users', (loggedUser, $http, $q) ->

    logUser = (username, password) ->
      deferred = $q.defer()
      $http.post('/api/users/login', {username: username, password: password})
        .then ->
          $http.get('/api/users/me')
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

    restoreSession: ->
      $http.get('/api/users/me').then (response) ->
        loggedUser.profile = response.data unless response.status isnt 200

    findByEmail: (email) ->
      $http.get('/api/users/?{"email": "' + email + '"}')

    createAndLogin: (username, email, password) ->
      $http.post('/api/users', {username: username, email: email, password: password}).then ->
        logUser(username, password)


.run (users) ->
    users.restoreSession()