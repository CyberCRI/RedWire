angular.module('gamEvolve.game.home', [])

.config ($stateProvider) ->
    $stateProvider.state 'home',
      url: '/'
      views:
        "main":
          controller: 'HomeCtrl'
          templateUrl: 'game/home/home.tpl.html'
      data:
        pageTitle: 'Home'

.controller 'HomeCtrl', ($scope, $state) ->

  $container = $('#ib-container')
  $articles = $container.children('article')
  timeout = null

  $articles.on 'mouseenter', ( event ) ->
    $article = $(this)
    clearTimeout(timeout)
    timeout = setTimeout( ->
      if $article.hasClass('active') then return false
      
      $articles.not( $article.removeClass('blur').addClass('active') ).removeClass('active').addClass('blur')
    , 65 )

  $container.on 'mouseleave', ( event ) ->
    clearTimeout( timeout )
    $articles.removeClass('active blur')
