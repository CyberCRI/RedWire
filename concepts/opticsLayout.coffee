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
        bind: 
          doc: "detect clicks"
          from: 
            piece: "model('pieces')"
          select: 
            piece: "piece"
        children: 
          action: "watch"
          params:
            condition: "piece.buttonStatus"
          children:
            pressed: 
              setModel:
                selectedPiece: "linkTo(piece)"
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
          from: 
            piece: "model('pieces')"
          where: "piece.isActive"
          select: 
            piece: "piece"
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