_                      = require 'lodash'
shmock                 = require 'shmock'
ConfigurationGenerator = require '../src/configuration-generator'
ConfigurationUtilities = require '../src/configuration-utilities'

metadataRequestFlow    = require './data/metadata-request-flow.json'
metadataRequestFlow2    = require './data/metadata-request-flow-2.json'

nodeRegistry           = require './data/node-registry'


describe 'Configuring EngineOutput to insert metadata into messages', ->
  beforeEach (done) ->
    @meshblu = shmock done
    @searchRequest = @meshblu.post '/search/devices'

  afterEach (done) ->
    @meshblu.close done

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

    context 'generating configuration with devices that want metadata', ->
      beforeEach ->
        @searchHandler = @searchRequest
          .send
            uuid:
              $in: ['gimme-metadata', 'no-metadata-plz']
            'octoblu.flow.forwardMetadata': true
          .reply(201, [uuid: 'gimme-metadata'])

      beforeEach (done) ->
        @channelConfig.fetch.yields null
        options =
          flowData: metadataRequestFlow
          flowToken: 'some-token'
          deploymentUuid: 'the-deployment-uuid'

        @sut.configure options, (@error, @flowConfig, flowStopConfig) =>
          {@devicesThatWantMetadata} = @flowConfig['engine-output'].config
          done()

      it 'should configure engine-output with the uuids of devices that want metadata injected into their messages', ->
        expect(@devicesThatWantMetadata).to.deep.equal ['gimme-metadata']

    context 'generating a configuration for a different flow', ->
      beforeEach ->
        @searchHandler = @searchRequest
          .send
            uuid:
              $in: ['new-channel-as-device-overlord', 'metadata-luddite', 'fifth-element']
            'octoblu.flow.forwardMetadata': true
          .reply(201, [{uuid: 'new-channel-as-device-overlord'}, {uuid: 'fifth-element'}])

      beforeEach (done) ->
        @channelConfig.fetch.yields null
        options =
          flowData: metadataRequestFlow2
          flowToken: 'some-token'
          deploymentUuid: 'the-deployment-uuid'

        @sut.configure options, (@error, @flowConfig, flowStopConfig) =>
          {@devicesThatWantMetadata} = @flowConfig['engine-output'].config
          done()

      it 'should configure engine-output with the uuids of devices that want metadata injected into their messages', ->
        expect(@devicesThatWantMetadata).to.deep.equal ['new-channel-as-device-overlord', 'fifth-element']
