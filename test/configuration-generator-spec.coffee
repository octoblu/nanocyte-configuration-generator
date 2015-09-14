ConfigurationGenerator = require '../src/configuration-generator'

describe 'ConfigurationGenerator', ->
  beforeEach ->
    @sut = new ConfigurationGenerator {a: 1, b: 2}

  it 'should exist', ->
    expect(@sut).to.exist

  describe '-> configure', ->
    it 'should exist', ->
      expect(@sut.configure).to.exist
