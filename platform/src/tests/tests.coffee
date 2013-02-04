# Get alias for the global scope
globals = @

describe "gamEvolve", ->
  beforeEach ->
    @addMatchers 
      toDeeplyEqual: (expected) -> _.isEqual(@actual, expected)
      toBeEmpty: (expected) -> expected.length == 0

  it "sandboxes a function call", ->
    globals.testFunction = (x) -> 
      x.a = 1
      throw new Error("error")
    testObj = {}
    GE.sandboxFunctionCall("testFunction", [testObj])
    expect(testObj.a).toBe(1)

  describe "runSteps", ->
    it "calls functions", ->
      # make test function to spy on
      globals.testFunction = jasmine.createSpy()

      layout = 
        call: "testFunction"
        params: [1, 2]

      GE.runStep(null, null, layout)

      expect(globals.testFunction).toHaveBeenCalledWith(1, 2)

    it "calls actions", ->
      isCalled = false

      actions = 
        doNothing: 
          paramDefs:
            x: 1
            y: "z"
          update: ->
            isCalled = true
            expect(arguments.length).toEqual(0)
            expect(@params).toDeeplyEqual
              x: 2
              y: "z"

      layout = 
        action: "doNothing"
        params: 
          x: 2
          y: "z"

      GE.runStep(null, actions, layout)
      expect(isCalled).toBeTruthy()

    it "calls children of actions", ->
      timesCalled = 0

      actions = 
        doNothing: 
          paramDefs: {}
          update: -> timesCalled++

      layout = 
        action: "doNothing"
        params: {}
        children: [
          {
            action: "doNothing"
            params: {}
          },
          {
            action: "doNothing"
            params: {}
          }
        ]

      GE.runStep(null, actions, layout)
      expect(timesCalled).toEqual(3)

