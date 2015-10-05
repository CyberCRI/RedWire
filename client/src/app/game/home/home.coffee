
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
            title: "Solar System"
            author: "rleblanc"
            screenshot: "universe.png"
            id: "469ca92b9fcffadc"
            description: "Visualize the solar system in movement"
          }
          {
            title: "Math & Move"
            author: "GuillaumeDukes"
            screenshot: "math.png"
            id: "71474ed84b2ddaa8"
            description: "Pilot your ship with equations"
          }
          {
            title: "Usine"
            author: "valgoun"
            screenshot: "dna.png"
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
            author: "Dioptre"
            screenshot: "colorCharge.png"
            id: "c117a625bbced8ac"
            description: "Form mesons and bosons in this unique puzzle game"
          }
          {
            title: "Hadronisation"
            author: "Dioptre"
            screenshot: "hadronisation.png"
            id: "9caa6b965a3008fb"
            description: "You slice strings, particles are produced, you gain points!"
          }
          {
            title: "Final State Shower"
            author: "Dioptre"
            screenshot: "shower.png"
            id: "7df2db1b4a6dd957"
            description: "Learn about Final State Radiation by playing a virtual bridge building game"
          }
        ]
      }
      {
        title: "Autism"
        games: [
          {
            title: "Blinkin'eye"
            author: "Dioptre"
            screenshot: "blinkinEye.png"
            id: "7c6b55c59f4038c1"
            description: "Can you resist the blinking eye?"
          }
          {
            title: "Hungry Animal Train"
            author: "Dioptre"
            screenshot: "hungryAnimals.png"
            id: "bf3d49f12b11f8c3"
            description: "Feed the animals coming down the train"
          }
          {
            title: "My Way"
            author: "Dioptre"
            screenshot: "myWay.png"
            id: "b14ed49c932dab87"
            description: "Program your robot to complete the puzzles"
          }
        ]
      }
      {
        title: "Arcade"
        games: [
          {
            title: "Stupendous Side-Scrolling Space Shooter"
            author: "micouz"
            screenshot: "spaceShooter.png"
            id: "31e02eb58a2ec860"
            description: "Endless bad guys in space"
          }
          {
            title: "King Pong"
            author: "mr_cool"
            screenshot: "pong.png"
            id: "039a51f4fa16f911"
            description: "2-player pong using the keyboard"
          }
          {
            title: "Asteroids"
            author: "micouz"
            screenshot: "asteroids.png"
            id: "3154c646c1a3796f"
            description: "Asteroids, mixed with the space shooter"
          }
        ]
      }
    ]
