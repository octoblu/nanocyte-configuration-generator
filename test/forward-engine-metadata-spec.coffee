_ = require 'lodash'
nodeUuid = require 'node-uuid'

ConfigurationGenerator = require '../src/configuration-generator'
ConfigurationUtilities = require '../src/configuration-utilities'

metadataRequestFlow = require './data/metadata-request-flow.json'
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
          uuid: 'user-uuid'
          token: 'user-token'

      dependencies =
        request: @request
        channelConfig: @channelConfig

      @sut = new ConfigurationGenerator options, dependencies

    describe 'when called', ->
      beforeEach (done) ->
        @channelConfig.fetch.yields null
        options =
          flowData: metadataRequestFlow
          flowToken: 'some-token'
          deploymentUuid: 'the-deployment-uuid'

        @sut.configure options, (@error, @flowConfig, flowStopConfig) =>
          @engineOutputConfig = @flowConfig['engine-output'].config
           done()

      it 'should call channelConfig.fetch', ->
        console.log JSON.stringify @engineOutputConfig, null, 2
        expect(@flowConfig).to.be.true
