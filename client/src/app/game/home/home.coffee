
angular.module('gamEvolve.game.home', [])

.config ($stateProvider) ->
    $stateProvider.state 'home',
      url: '/'
      views:
        "main":
          controller: 'HomeCtrl'
          templateUrl: 'game/home/home.tpl.html'
      data:
        pageTitle: 'Welcome to RedWire'

.controller 'HomeCtrl', ($scope, games, $state) ->
    $scope.sections = [
      {
        title: "GLASS - Game Lab Summer School"
        games: [
          {
            title: "Univers"
            author: "TODO"
            screenshot: "universe.png"
            id: "469ca92b9fcffadc"
            description: "Visualize the solar system in movement"
          }
          {
            title: "Math & Move"
            author: "TODO"
            screenshot: "math.png"
            id: "71474ed84b2ddaa8"
            description: "Pilot your ship with equations"
          }
          {
            title: "Usine"
            author: "TODO"
            screenshot: ""
            id: "d38bc3ee23af8aa5"
            description: "Typing game with DNA"
          }
        ]
      }
      {
        title: "Quantum Physics"
        games: [
          {
            title: "Color Charge"
            author: "TODO"
            screenshot: "colorCharge.png"
            id: "c117a625bbced8ac"
            description: "Form mesons and bosons in this unique puzzle game"
          }
          {
            title: "Hadronization"
            author: "TODO"
            screenshot: ""
            id: "9caa6b965a3008fb"
            description: "Break links to form quarks"
          }
          {
            title: "Final State Shower"
            author: "TODO"
            screenshot: ""
            id: "7df2db1b4a6dd957"
            description: "Smash particles together to help the scientist cross the bridge"
          }
        ]
      }
      {
        title: "Autism"
        games: [
          {
            title: "Blinkin'eye"
            author: "TODO"
            screenshot: "blinkinEye.png"
            id: "7c6b55c59f4038c1"
            description: "Can you resist the blinking eye?"
          }
          {
            title: "Hungry Animal Train"
            author: "TODO"
            screenshot: ""
            id: "bf3d49f12b11f8c3"
            description: "Feed the animals coming down the train"
          }
          {
            title: "My Way"
            author: "TODO"
            screenshot: ""
            id: ""
            description: "Program a robot"
          }
        ]
      }
    ]
