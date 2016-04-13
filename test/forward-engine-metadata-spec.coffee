_ = require 'lodash'
nodeUuid = require 'node-uuid'

ConfigurationGenerator = require '../src/configuration-generator'
ConfigurationUtilities = require '../src/configuration-utilities'

sampleFlow = require './data/metadata-request-flow.json'
nodeRegistry = require './data/node-registry'

describe 'ConfigurationGenerator', ->
  beforeEach ->
    @request = get: sinon.stub().yields null, {}, nodeRegistry
    @channelConfig =
      fetch: sinon.stub().yields null
      get: sinon.stub().returns {}

  describe '->configure', ->
    beforeEach ->
      options =
        meshbluJSON:
          server: 'some-server'

      dependencies =
        request: @request
        channelConfig: @channelConfig

      @sut = new ConfigurationGenerator options, dependencies

    describe 'when called', ->
      beforeEach (done) ->
        @channelConfig.fetch.yields null
        options =
          flowData: sampleFlow
          flowToken: 'some-token'
          deploymentUuid: 'the-deployment-uuid'

        @sut.configure options, (@error, @flowConfig, @flowStopConfig) => done()

      it 'should call channelConfig.fetch', ->
        console.log JSON.stringify @flowConfig, null, 2
        expect(@flowConfig).to.be.true
