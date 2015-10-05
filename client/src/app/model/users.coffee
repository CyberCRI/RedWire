angular.module('gamEvolve.model.users', [])

.factory 'loggedUser', ($http, ChangedLoginEvent) ->

    profile: null

    isLoggedIn: -> @profile?

    isNotLoggedIn: -> not @isLoggedIn()

    login: (profile) ->
      @profile = profile
      ChangedLoginEvent.send()

    logout: ->
      @profile = null
      ChangedLoginEvent.send()


.factory 'users', (loggedUser, $http, $q) ->

    login = (username, password) ->
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
            loggedUser.login(user)
            deferred.resolve(user)
          else
            deferred.reject('Error')
      deferred.promise

    logUser: login

    logout: ->
      $http.post('/api/users/logout').then -> console.log 'Logging Out'
      loggedUser.logout()

    restoreSession: ->
      $http.get('/api/users/me').then (response) ->
        loggedUser.profile = response.data unless response.status isnt 200

    findByEmail: (email) ->
      $http.get('/api/users/?{"email": "' + email + '"}')

    createAndLogin: (username, email, password) ->
      $http.post('/api/users', {username: username, email: email, password: password}).then ->
        login(username, password)


.run (users) ->
    users.restoreSession()
