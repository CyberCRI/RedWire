describe "A suite", ->
  it "contains spec with an expectation", ->
    expect(true).toBe(true)

  it "can also fail", ->
    expect(1 + 1).toBe(3)