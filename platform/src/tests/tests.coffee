# Get alias for the global scope
globals = @

describe "gamEvolve", ->
  beforeEach ->
    @addMatchers 
      toDeeplyEqual: (expected) -> _.isEqual(@actual, expected)
      toBeEmpty: () -> @actual.length == 0

  describe "patches", ->
    it "can remove value from array", ->
      a = 
        v: [10..15]
      b = 
        v: [10, 12, 13, 14, 15] # Missing 11

      patches = GE.makePatches(a, b)
      patchResult = GE.applyPatches(patches, a)

      expect(patchResult).toDeeplyEqual(b)

  describe "model", ->
    it "can be created empty", ->
      model = new GE.Model()
      expect(model.version).toEqual(0)
      expect(model.data).toDeeplyEqual({})

    it "can be created with data", ->
      model = new GE.Model({a: 1, b: 2})
      expect(model.version).toEqual(0)
      expect(model.data).toDeeplyEqual({a: 1, b: 2})

    it "can be patched", ->
      # Create old data, new data, and the patches between
      oldData = 
        a: 1
        b: 
          b1: true
          b2: "hi"
      newData = 
        b: 
          b1: true
          b2: "there"
        c: 
          bob: "is cool"
      patches = GE.makePatches(oldData, newData)

      # Create model objects of the data
      oldModel = new GE.Model(oldData)
      newModel = oldModel.applyPatches(patches)

      # The new model and the old model should still both be valid and different
      expect(oldModel.version).toEqual(0)
      expect(oldModel.data).toDeeplyEqual(oldData)
      expect(newModel.version).toEqual(1)
      expect(newModel.data).toDeeplyEqual(newData)

    it "rejects conflicting patches", ->
      # Create old data, new data, and the patches between
      oldData = 
        a: 1
      newDataA = 
        a: 2 
      newDataB = 
        b: 3
      patchesA = GE.makePatches(oldData, newDataA)
      patchesB = GE.makePatches(oldData, newDataB)

      # Create model objects of the data
      oldModel = new GE.Model(oldData)
      expect(-> oldModel.applyPatches(_.flatten([patchesA, patchesB]))).toThrow()

    it "can be retrieved at a given version", ->
      v0 = 
        a: 0
      v1 =
        a: 1
      v2 = 
        a: 2

      model = new GE.Model(v0).setData(v1).setData(v2)

      expect(model.clonedData()).toDeeplyEqual(v2)
      expect(model.version).toBe(2)

      expect(model.atVersion(1).clonedData()).toDeeplyEqual(v1)
      expect(model.atVersion(1).version).toBe(1)

      expect(model.atVersion(0).clonedData()).toDeeplyEqual(v0)
      expect(model.atVersion(0).version).toBe(0)


  describe "visitNode()", ->
    it "calls actions", ->
      isCalled = false

      actions = 
        doNothing: 
          paramDefs:
            x: 
              direction: "in" 
              default: "1"
            y: 
              direction: "in"
              default: "'z'"
          update: ->
            isCalled = true
            expect(arguments.length).toEqual(0)
            expect(@params).toDeeplyEqual
              x: 2
              y: "z"

      layout = 
        action: "doNothing"
        params: 
          in: 
            x: "1 + 1"

      constants = new GE.NodeVisitorConstants
        actions: actions
        evaluator: GE.makeEvaluator()
      GE.visitNode(layout, constants, {})
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

      constants = new GE.NodeVisitorConstants
        actions: actions
      GE.visitNode(layout, constants, {})
      expect(timesCalled).toEqual(3)

    it "evaluates parameters for actions", ->
      oldModel = 
        a: 1
        b: 10
        c: 20

      assets = { image: new Image() }

      actions = 
        adjustModel: 
          paramDefs:
            x: 
              direction: "inout"
            y: 
              direction: "inout"
            z:
              direction: "out"
            d: 
              default: "2"
            e: {}
          update: ->
            @params.x++
            @params.y--
            @params.z = 30
            expect(@params.d).toBe(2)
            expect(@params.e).toBe(assets.image)

      layout = 
        action: "adjustModel"
        params:
          in:  
            x: "model.a"
            y: "model.b"
            e: "assets.image"
          out:
            "model.a": "params.x"
            "model.b": "params.y"
            "model.c": "params.z"

      constants = new GE.NodeVisitorConstants 
        modelData: oldModel, 
        assets: assets
        actions: actions
        evaluator: GE.makeEvaluator()
      results = GE.visitNode(layout, constants, {})
      newModel = GE.applyPatches(results.modelPatches, oldModel)

      # The new model should be changed, but the old one shouldn't be
      expect(oldModel.a).toBe(1)
      expect(oldModel.b).toBe(10)
      expect(oldModel.c).toBe(20)
      expect(newModel.a).toBe(2)
      expect(newModel.b).toBe(9)
      expect(newModel.c).toBe(30)

    it "sends to model and services", ->
      oldModel = 
        a: 
          a1: 1
        b: 10
        c: "hi"

      oldServiceData = 
        s: 
          a: -1

      layout = 
        send: 
          "model.a.a1": 2
          "model.b": "model.c"
          "services.s.a": -5

      constants = new GE.NodeVisitorConstants
        modelData: oldModel
        serviceData: oldServiceData
        evaluator: GE.makeEvaluator()
      results = GE.visitNode(layout, constants, {})
      newModel = GE.applyPatches(results.modelPatches, oldModel)
      newServiceData = GE.applyPatches(results.servicePatches, oldServiceData)

      # The new model and services should be changed, but the old ones shouldn't be
      expect(oldModel.a.a1).toBe(1)
      expect(oldModel.b).toBe(10)
      expect(oldServiceData.s.a).toBe(-1)

      expect(newModel.a.a1).toBe(2)
      expect(newModel.b).toBe("hi")
      expect(newServiceData.s.a).toBe(-5)

    it "checks and adjusts activation", ->
      models = [
        {
          activeChild: 0
          child0TimesCalled: 0
          child1TimesCalled: 0
        }
      ]

      actions = 
        nextOnDone: 
          paramDefs: 
            activeChild: 
              direction: "inout"
              default: 0
          listActiveChildren: -> 
            expect(@children).toDeeplyEqual(["0", "2nd"])
            return [@children[@params.activeChild]]
          handleSignals: ->
            expect(@children).toDeeplyEqual(["0", "2nd"])
            if @signals[@children[@params.activeChild]] == GE.signals.DONE 
              @params.activeChild++
            if @params.activeChild >= @children.length - 1
              return GE.signals.DONE
        reportDone:
          paramDefs:
            timesCalled: 
              direction: "inout"
          update: -> 
            @params.timesCalled++
            return GE.signals.DONE

      layout = 
        action: "nextOnDone"
        params: 
          in:
            activeChild: "model.activeChild"
          out: 
            "model.activeChild": "params.activeChild"
        children: [
          {
            action: "reportDone"
            params: 
              in:
                timesCalled: "model.child0TimesCalled"
              out:
                "model.child0TimesCalled": "params.timesCalled"
          },
          {
            name: "2nd"
            action: "reportDone"
            params: 
              in:
                timesCalled: "model.child1TimesCalled"
              out:
                "model.child1TimesCalled": "params.timesCalled"
          }
        ]

      constants = new GE.NodeVisitorConstants
        modelData: models[0]
        actions: actions
        evaluator: GE.makeEvaluator()
      results = GE.visitNode(layout, constants, {})
      models[1] = GE.applyPatches(results.modelPatches, models[0])

      expect(models[1].child0TimesCalled).toBe(1)
      expect(models[1].child1TimesCalled).toBe(0)
      expect(models[1].activeChild).toBe(1)
      
      constants = new GE.NodeVisitorConstants
        modelData: models[1]
        actions: actions
        evaluator: GE.makeEvaluator()
      results = GE.visitNode(layout, constants, {})
      models[2] = GE.applyPatches(results.modelPatches, models[1])

      expect(models[2].child0TimesCalled).toBe(1)
      expect(models[2].child1TimesCalled).toBe(1)
      expect(models[2].activeChild).toBe(2)

    it "binds across constant arrays", ->
      people = [
        { first: "bill", last: "bobson" }
        { first: "joe", last: "johnson" }
      ]

      actions = 
        getName: 
          paramDefs:
            name: 
              direction: "in" 
            index: 
              direction: "in"
          update: -> 
            expect(@params.index).toEqual(if @params.name is "bill" then "0" else "1")

      spyOn(actions.getName, "update").andCallThrough()

      layout = 
        foreach:
          from: people
          bindTo: "person"
          index: "personIndex"
        children: [
          { 
            action: "getName"
            params: 
              in: 
                name: "bindings.person.first"
                index: "bindings.personIndex"
          }
        ]

      constants = new GE.NodeVisitorConstants
        actions: actions
        evaluator: GE.makeEvaluator()
      GE.visitNode(layout, constants, {})

      expect(actions.getName.update).toHaveBeenCalled()

    it "binds across model arrays", ->
      oldModel = 
        people: [
          { first: "bill", last: "bobson" }
          { first: "joe", last: "johnson" }
        ]

      actions = 
        changeName: 
          paramDefs:
            newName: 
              direction: "in" 
            toChange: 
              direction: "out"
            index: 
              direction: "in"
          update: -> 
            expect(@params.index).toEqual(if @params.newName is "bill" then "0" else "1")
            @params.toChange = @params.newName

      layout = 
        foreach:
          from: "model.people"
          bindTo: "person"
          index: "personIndex"
        children: [
          { 
            action: "changeName"
            params: 
              in: 
                newName: "bindings.person.first"
                index: "bindings.personIndex"
              out:
                "bindings.person.last": "params.toChange"
          }
        ]

      constants = new GE.NodeVisitorConstants
        modelData: oldModel
        actions: actions
        evaluator: GE.makeEvaluator()
      results = GE.visitNode(layout, constants, {})
      newModel = GE.applyPatches(results.modelPatches, oldModel)

      expect(newModel.people[0].last).toBe("bill")
      expect(newModel.people[1].last).toBe("joe")

    it "communicates with services", ->
      oldServiceData = 
        serviceA: 
          a: 1

      actions = 
        incrementServiceData: 
          paramDefs:
            service:
              direction: "inout"
          update: -> 
            expect(@params.service.a).toBe(1)
            @params.service.a++

      layout = 
        action: "incrementServiceData"
        params:
          in:
            service: "services.serviceA"
          out:
            "services.serviceA": "params.service"

      constants = new GE.NodeVisitorConstants
        serviceData: oldServiceData
        actions: actions
        evaluator: GE.makeEvaluator()
      results = GE.visitNode(layout, constants, {})
      newServiceData = GE.applyPatches(results.servicePatches, oldServiceData)

      expect(newServiceData.serviceA.a).toBe(2)

  describe "stepLoop()", ->
    it "sends output data directly to services", ->
      services = 
        myService:
          establishData: jasmine.createSpy()

      outputServiceData = 
        myService:
          a = 1

      modelPatches = GE.stepLoop 
        services: services
        outputServiceData: outputServiceData

      expect(services.myService.establishData).toHaveBeenCalledWith(outputServiceData.myService, {})
      expect(modelPatches).toBeEmpty()

    it "sends service input data to visitNode()", ->
      services = 
        myService:
          establishData: jasmine.createSpy()

      inputServiceData = 
        myService:
          a: 1

      actions = 
        incrementServiceData: 
          paramDefs:
            service:
              direction: "inout"
          update: -> 
            expect(@params.service.a).toBe(1)
            @params.service.a++

      layout = 
        action: "incrementServiceData"
        params:
          in: 
            service: "services.myService"
          out: 
            "services.myService": "params.service" 

      modelPatches = GE.stepLoop 
        node: layout
        actions: actions 
        services: services
        inputServiceData: inputServiceData
        evaluator: GE.makeEvaluator()

      expect(services.myService.establishData).toHaveBeenCalledWith({ a: 2 }, {})
      expect(modelPatches).toBeEmpty()

    it "gathers service input data, visits nodes, uses tools, and gives output to services", ->
      services = 
        myService:
          provideData: -> return { a: 1 }
          establishData: jasmine.createSpy()

      spyOn(services.myService, "provideData").andCallThrough()

      tools = {
        testTool: (arg1, arg2) -> return {_1: arg1, _2: arg2};
      }

      actions = 
        incrementServiceData: 
          paramDefs:
            service: 
              direction: "inout"
          update: -> 
            expect(@tools.testTool(@params.service.a, 2)._1).toBe(1)
            @params.service.a++

      layout = 
        action: "incrementServiceData"
        params:
          in:
            service: "services.myService"
          out:
            "services.myService": "params.service"

      modelPatches = GE.stepLoop 
        node: layout
        actions: actions 
        tools: tools
        services: services
        evaluator: GE.makeEvaluator()

      expect(services.myService.provideData).toHaveBeenCalledWith({})
      expect(services.myService.establishData).toHaveBeenCalledWith({ a: 2 }, {})
      expect(modelPatches).toBeEmpty()

    it "rejects conflicting patches", ->
      # Create old data, new data, and the patches between
      oldData = 
        a: 0

      services = 
        myService:
          provideData: -> return { a: 0 }
          establishData: jasmine.createSpy()

      actions = 
        group:
          paramDefs: {}
          update: ->
        setDataTo: 
          paramDefs:
            in: 
              value: null
            out:
              var: null
          update: -> @params.var = @params.value

      layoutA = 
        action: "group"
        children: [
          {
            action: "setDataTo"
            params:
              in:
               value: 1
              out:
                "model.a": "params.var"
          },
          {
            action: "setDataTo"
            params:
              in:
               value: 2
              out:
                "model.a": "params.var"
          }
        ]

      expect(-> GE.stepLoop 
        node: layoutA
        modelData: oldData
        actions: actions 
        evaluator: GE.makeEvaluator()
      ).toThrow()
      
      layoutB = 
        action: "group"
        children: [
          {
            action: "setDataTo"
            params:
             in:
               value: 2
              out:
                "services.myService.a": "params.var"
          },
          {
            action: "setDataTo"
            params:
             in:
               value: 2
              out:
                "services.myService.a": "params.var"
          }
        ]

      expect(-> GE.stepLoop 
        node: layoutB 
        actions: actions 
        services: services
        evaluator: GE.makeEvaluator()
      ).toThrow()

  describe "sandbox", ->
    it "evaluates expressions", ->
      evaluator = GE.makeEvaluator()
      expect(evaluator("a = 1")).toEqual(1)
      expect(evaluator("a + 1")).toEqual(2)

    it "does not pollute", ->
      evaluator = GE.makeEvaluator()
      expect(evaluator("typeof(GE)")).toEqual("undefined")
      expect(evaluator("a = 1")).toEqual(1)

      evaluator2 = GE.makeEvaluator()
      expect(evaluator2("typeof(a)")).toEqual("undefined")
