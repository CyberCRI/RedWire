action: "inSequence"
params: 
  loop: true
children: [
    action: "showIntroScreen"
    # ...
  ,
    action: "while"
    params:
      condition: "not(model('levelComplete'))"
    children: [
        doc: "detect clicks"
        bind: 
          piece: "eachOf(model('pieces'))"
        children: 
          action: "watch"
          params:
            condition: "param('piece').buttonStatus"
          children:
            pressed: 
              setModel:
                selectedPiece: "linkTo(param('piece'))"
      ,
        action: "computeLightPath"
        params:
          path: "model('lightPath')"
          pieces: "model('pieces')"
          boardSize: "config('boardSize')"
      ,
        action: "watch"
        params:
          condition: "isPieceHit(model('targetPiece').get())"
        children:
          true: setModel: levelComplete: true
      ,
        setModel:
          sprites: []
      ,
        call:
          function: "clearCanvas"
          arguments: ["config('canvasName')"]
      ,
        bind:
          piece: eachOf(modelRef("pieces"))
        children:
          action: "drawPiece"
          params: { sprite: insert(model("sprites")) }
      ,
        bind: 
          sprites: "model('sprites')"
        children: [
            action: "drawLight"
          ,
            action: "drawControls" 
            params: { "model('controls')" }
          ,
            action: "drawSprites"
            params: { canvas: "config('canvasName')" }
        ]
    ]
  ,
    action: "showEnding"
    # ...
]