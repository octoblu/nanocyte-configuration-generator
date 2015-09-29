_ = require 'lodash'
nodeUuid = require 'node-uuid'

ConfigurationGenerator = require '../src/configuration-generator'
sampleFlow = require './data/sample-flow.json'

describe 'ConfigurationGenerator', ->
  beforeEach ->
    @UUID = require 'node-uuid'
    sinon.stub @UUID, 'v4'
    @request = get: sinon.stub()
    @channelConfig =
      fetch: sinon.stub()
      get: sinon.stub()

  afterEach ->
    @UUID.v4.restore()

  describe '->configure', ->
    beforeEach ->
      options =
        meshbluJSON:
          server: 'some-server'

      dependencies =
        UUID: @UUID
        request: @request
        channelConfig: @channelConfig

      @sut = new ConfigurationGenerator options, dependencies

    describe 'when called', ->
      beforeEach (done) ->
        nodeRegistry =
          "trigger":
            "composedOf":
              "Trigger":
                "type": "nanocyte-node-trigger"
                "linkedToInput": true
                "linkedToNext": true
          "debug":
            "composedOf":
              "Debug":
                "type": "nanocyte-node-debug"
                "linkedToPrev": true
          "interval":
            "composedOf":
              "Interval-1":
                "type": "nanocyte-node-interval"
                "linkedToInput": true
                "linkedToNext": true
          "device":
            "composedOf":
              "pass-through":
                "type": "nanocyte-component-pass-through"
                "linkedToInput": true
                "linkedToNext": true
          "channel":
            "composedOf":
              "pass-through":
                "type": "nanocyte-component-channel"
                "linkedToPrev": true
                "linkedToNext": true

        githubConfig = require './data/github-channel.json'
        @request.get.yields null, {}, nodeRegistry
        @channelConfig.fetch.yields null
        @channelConfig.get.withArgs('channel:github').returns githubConfig
        @UUID.v4.onCall(0).returns 'node-trigger-instance'
        @UUID.v4.onCall(1).returns 'node-debug-instance'
        @UUID.v4.onCall(2).returns 'node-interval-instance'
        @UUID.v4.onCall(3).returns 'node-device-instance'
        @UUID.v4.onCall(4).returns 'node-channel-instance'

        userData =
          api:
            [
              "authtype": "oauth"
              "token": "6387e3547c75a4e5804957319e37b7b0346097dc"
              "channelid": "532a258a50411e5802cb8053"
              "_id": "55fc50d1aed35f0f0009b9c3"
              "type": "channel:github"
              "uuid": "e56842b0-5e2e-11e5-8abf-b33a470ad64b"
            ]

        options =
          userData: userData
          flowData: sampleFlow
          flowToken: 'some-token'

        @sut.configure options, (@error, @flowConfig) => done()

      it 'should call request.get', ->
        expect(@request.get).to.have.been.calledWith(
          'https://raw.githubusercontent.com/octoblu/nanocyte-node-registry/master/registry.json'
          json: true
        )

      it 'should return a flow configuration with keys for all the nodes in the flow', ->
        expect(_.keys @flowConfig).to.have.deep.same.members [
          '8a8da890-55d6-11e5-bd83-1349dc09f6d6'
          '8e74a6c0-55d6-11e5-bd83-1349dc09f6d6'
          '2cf457d0-57eb-11e5-99ea-11ac2aafbb8d'
          'f607eed0-631b-11e5-9887-75e2edd7c9c8'
          '9d8e9920-663b-11e5-82a3-c3248b467ade'
          'node-trigger-instance'
          'node-debug-instance'
          'node-interval-instance'
          'node-device-instance'
          'node-channel-instance'
          'engine-data'
          'engine-debug'
          'engine-input'
          'engine-output'
          'engine-pulse'
          'router'
          'engine-start'
          'engine-stop'
        ]

      it 'should set the uuid and token of meshblu-output and merge meshbluJSON', ->
        expect(@flowConfig['engine-output'].config).to.deep.equal
          uuid: sampleFlow.flowId
          token: 'some-token'
          server: 'some-server'

      it 'should set engine-debug', ->
        expect(@flowConfig['engine-debug'].config).to.deep.equal
          "node-debug-instance":
            nodeId: "8e74a6c0-55d6-11e5-bd83-1349dc09f6d6"
          "node-interval-instance":
            nodeId: "2cf457d0-57eb-11e5-99ea-11ac2aafbb8d"
          "node-trigger-instance":
            nodeId: "8a8da890-55d6-11e5-bd83-1349dc09f6d6"
          "node-device-instance":
            nodeId: "f607eed0-631b-11e5-9887-75e2edd7c9c8"
          "node-channel-instance":
            nodeId: "9d8e9920-663b-11e5-82a3-c3248b467ade"

      it 'should set engine-data', ->
        expect(@flowConfig['engine-data'].config).to.deep.equal
          "node-debug-instance":
            nodeId: "8e74a6c0-55d6-11e5-bd83-1349dc09f6d6"
          "node-interval-instance":
            nodeId: "2cf457d0-57eb-11e5-99ea-11ac2aafbb8d"
          "node-trigger-instance":
            nodeId: "8a8da890-55d6-11e5-bd83-1349dc09f6d6"
          "node-device-instance":
            nodeId: "f607eed0-631b-11e5-9887-75e2edd7c9c8"
          "node-channel-instance":
            nodeId: "9d8e9920-663b-11e5-82a3-c3248b467ade"

      it 'should set engine-pulse', ->
        expect(@flowConfig['engine-pulse'].config).to.deep.equal
          "node-debug-instance":
            nodeId: "8e74a6c0-55d6-11e5-bd83-1349dc09f6d6"
          "node-interval-instance":
            nodeId: "2cf457d0-57eb-11e5-99ea-11ac2aafbb8d"
          "node-trigger-instance":
            nodeId: "8a8da890-55d6-11e5-bd83-1349dc09f6d6"
          "node-device-instance":
            nodeId: "f607eed0-631b-11e5-9887-75e2edd7c9c8"
          "node-channel-instance":
            nodeId: "9d8e9920-663b-11e5-82a3-c3248b467ade"

      it 'should set engine-input', ->
        expect(@flowConfig['engine-input'].config).to.deep.equal
          '37f0a74a-2f17-11e4-9617-a6c5e4d22fb7':
            [{nodeId: '8a8da890-55d6-11e5-bd83-1349dc09f6d6'}]
          '37f0a966-2f17-11e4-9617-a6c5e4d22fb7':
            [{nodeId: '2cf457d0-57eb-11e5-99ea-11ac2aafbb8d'}]
          'c0e0955e-6ab4-4182-8d56-1c8c35a5106d':
            [{nodeId: 'f607eed0-631b-11e5-9887-75e2edd7c9c8'}]

      it 'should set node-trigger-instance', ->
        expect(@flowConfig['node-trigger-instance'].config).to.deep.equal {
          "id": "8a8da890-55d6-11e5-bd83-1349dc09f6d6",
          "resourceType": "flow-node",
          "payloadType": "date",
          "once": false,
          "name": "Trigger",
          "class": "trigger",
          "helpText": "Send a static message. Can also be triggered from other flows",
          "category": "operation",
          "uuid": "37f0a74a-2f17-11e4-9617-a6c5e4d22fb7",
          "type": "operation:trigger",
          "defaults": {
            "payloadType": "date",
            "once": false
          },
          "input": 0,
          "output": 1,
          "formTemplatePath": "/pages/node_forms/button_form.html",
          "logo": "https://ds78apnml6was.cloudfront.net/operation/trigger.svg",
          "inputLocations": [],
          "outputLocations": [],
          "x": 609.9398803710938,
          "y": 517.0806884765625,
          "needsConfiguration": false,
          "needsSetup": false
        }

      it 'should set the flow links on the router', ->
        links =
          '2cf457d0-57eb-11e5-99ea-11ac2aafbb8d':
            type: 'engine-input'
            linkedTo: ['node-interval-instance']
          '8a8da890-55d6-11e5-bd83-1349dc09f6d6':
            type: 'engine-input'
            linkedTo: ['node-trigger-instance']
          'f607eed0-631b-11e5-9887-75e2edd7c9c8':
            type: "engine-input"
            linkedTo: ['node-device-instance']
          'node-trigger-instance':
            type: 'nanocyte-node-trigger'
            linkedTo: ['node-debug-instance', 'engine-pulse']
          'node-debug-instance':
            type: 'nanocyte-node-debug'
            linkedTo: ['engine-debug']
          'node-interval-instance':
            type: 'nanocyte-node-interval'
            linkedTo: ['node-debug-instance', 'engine-pulse']
          'node-device-instance':
            type: 'nanocyte-component-pass-through'
            linkedTo: ['engine-pulse']
          'node-channel-instance':
            linkedTo: ['engine-pulse']
            type: 'nanocyte-component-channel'
          'engine-output':
            type: 'engine-output'
            linkedTo: []
          'engine-data':
            type: 'engine-data'
            linkedTo: []
          'engine-debug':
            type: 'engine-debug'
            linkedTo: []
          'engine-pulse':
            type: 'engine-pulse'
            linkedTo: []

        expect(@flowConfig.router.config).to.deep.equal links

      it 'should configure the debug node with the proper config', ->
        origNodeConfig = _.findWhere sampleFlow.nodes, id: '8e74a6c0-55d6-11e5-bd83-1349dc09f6d6'
        expect(@flowConfig['8e74a6c0-55d6-11e5-bd83-1349dc09f6d6'].config).to.deep.equal origNodeConfig

      it 'should configure the debug node with default data', ->
        expect(@flowConfig['8e74a6c0-55d6-11e5-bd83-1349dc09f6d6'].data).to.deep.equal {}

      it 'should set node-channel-instance', ->
        expect(@flowConfig['node-channel-instance'].config).to.deep.equal {
          "id": "9d8e9920-663b-11e5-82a3-c3248b467ade",
          "resourceType": "flow-node",
          "channelid": "532a258a50411e5802cb8053",
          "channelActivationId": "55fc50d1aed35f0f0009b9c3",
          "uuid": "e56842b0-5e2e-11e5-8abf-b33a470ad64b",
          "name": "Github",
          "type": "channel:github",
          "category": "channel",
          "online": true,
          "useStaticMessage": true,
          "nodeType": {
            "_id": "53c9b839f400e177dca325c8",
            "category": "channel",
            "categories": [
              "Social"
            ],
            "description": "",
            "documentation": "https://developer.github.com/v3/",
            "helpText": "GitHub is a web-based Git repository hosting service, that is the best place to share code with friends, co-workers, classmates, and complete strangers. Also offers distributed revision control and source code management functionalities to fork projects, send pull requests, and monitor development.",
            "enabled": true,
            "name": "Github",
            "skynet": {
              "type": "channel",
              "subtype": "Github"
            },
            "channelid": "532a258a50411e5802cb8053",
            "type": "channel:github"
          },
          "class": "channel-github",
          "defaults": {
            "channelid": "532a258a50411e5802cb8053",
            "channelActivationId": "55fc50d1aed35f0f0009b9c3",
            "uuid": "e56842b0-5e2e-11e5-8abf-b33a470ad64b",
            "name": "Github",
            "type": "channel:github",
            "category": "channel",
            "online": true,
            "useStaticMessage": true,
            "nodeType": {
              "_id": "53c9b839f400e177dca325c8",
              "category": "channel",
              "categories": [
                "Social"
              ],
              "description": "",
              "documentation": "https://developer.github.com/v3/",
              "helpText": "GitHub is a web-based Git repository hosting service, that is the best place to share code with friends, co-workers, classmates, and complete strangers. Also offers distributed revision control and source code management functionalities to fork projects, send pull requests, and monitor development.",
              "enabled": true,
              "name": "Github",
              "skynet": {
                "type": "channel",
                "subtype": "Github"
              },
              "channelid": "532a258a50411e5802cb8053",
              "type": "channel:github"
            }
          },
          "input": 1,
          "output": 1,
          "helpText": "GitHub is a web-based Git repository hosting service, that is the best place to share code with friends, co-workers, classmates, and complete strangers. Also offers distributed revision control and source code management functionalities to fork projects, send pull requests, and monitor development.",
          "formTemplatePath": "/pages/node_forms/channel_form.html",
          "logo": "https://ds78apnml6was.cloudfront.net/channel/github.svg",
          "inputLocations": [],
          "outputLocations": [],
          "x": 239.47897338867188,
          "y": 228.071044921875,
          "headerParams": {},
          "urlParams": {},
          "queryParams": {},
          "bodyParams": {},
          "url": "https://:hostname/setup/api/settings/authorized-keys",
          "method": "POST",
          "needsConfiguration": false,
          "needsSetup": false,
          "oauth": {
            "clientID": "development-client-id",
            "clientSecret": "development-client-secret",
            "callbackURL": "http://localhost:8080/api/oauth/github/callback",
            "tokenMethod": "access_token_query",
            "key": "development-client-id",
            "secret": "development-client-secret",
            "access_token": "6387e3547c75a4e5804957319e37b7b0346097dc"
          },
          "bodyFormat": "json"
        }

  describe '-> _buildLinks', ->
    beforeEach ->
      @sut = new ConfigurationGenerator {}, {UUID: @UUID, request: @request, channelConfig: {}}

    describe 'when one node is linked to another', ->
      beforeEach ->
        links = [
          from: 'some-node-uuid'
          to: 'some-other-node-uuid'
        ]

        flowConfig =
          'some-node-uuid':
            config:
              id: 'some-node-uuid'
              category: 'some-thing'
          'some-other-node-uuid':
            config:
              id: 'some-other-node-uuid'
              category: 'some-other-thing'

        nodeRegistry =
          'some-thing':
            type: 'nanocyte-node-fluff'
            composedOf:
              'fluff-1':
                type: 'nanocyte-node-fluff'
                linkedToNext: true
          'some-other-thing':
            type: 'nanocyte-node-fluff'
            composedOf:
              'fluff-1':
                type: 'nanocyte-node-fluff'
                linkedToPrev: true


        @UUID.v4.onCall(0).returns 'some-node-instance-uuid'
        @UUID.v4.onCall(1).returns 'some-other-node-instance-uuid'
        @result = @sut._buildLinks links, @sut._generateInstances(links, flowConfig, nodeRegistry, {})

      it 'should set the flow links on the router', ->
        links =
          'some-node-instance-uuid':
            type: 'nanocyte-node-fluff'
            linkedTo: ['some-other-node-instance-uuid', 'engine-pulse']
          'some-other-node-instance-uuid':
            type: 'nanocyte-node-fluff'
            linkedTo: []
          'engine-output':
            type: 'engine-output'
            linkedTo: []
          'engine-data':
            type: 'engine-data'
            linkedTo: []
          'engine-debug':
            type: 'engine-debug'
            linkedTo: []
          'engine-pulse':
            type: 'engine-pulse'
            linkedTo: []

        expect(@result).to.deep.equal links

    describe 'when a different node is linked to another', ->
      beforeEach ->
        links = [
          from: 'some-other-node-uuid'
          to: 'yet-some-other-node-uuid'
        ]

        flowConfig =
          'some-other-node-uuid':
            config:
              category: 'some-node'
              id: 'some-other-node-uuid'
          'yet-some-other-node-uuid':
            config:
              category: 'nanocyte-node-tuff'
              id: 'some-other-node-uuid'

        nodeRegistry =
          'some-node':
            composedOf:
              'tuff-2':
                type: 'nanocyte-node-tuff'
                linkedToNext: true
          'nanocyte-node-tuff':
            composedOf:
              'tuff-2':
                type: 'nanocyte-node-tuff'
                linkedToPrev: true

        @UUID.v4.onCall(0).returns 'some-other-node-instance-uuid'
        @UUID.v4.onCall(1).returns 'yet-some-other-node-instance-uuid'
        @result = @sut._buildLinks links, @sut._generateInstances(links, flowConfig, nodeRegistry, {})

      it 'should set the flow links on the router', ->
        links =
          'some-other-node-instance-uuid':
            type: 'nanocyte-node-tuff'
            linkedTo: ['yet-some-other-node-instance-uuid', 'engine-pulse']
          'yet-some-other-node-instance-uuid':
            type: 'nanocyte-node-tuff'
            linkedTo: []
          'engine-output':
            type: 'engine-output'
            linkedTo: []
          'engine-data':
            type: 'engine-data'
            linkedTo: []
          'engine-debug':
            type: 'engine-debug'
            linkedTo: []
          'engine-pulse':
            type: 'engine-pulse'
            linkedTo: []

        expect(@result).to.deep.equal links

    describe 'when one node is linked to two nodes', ->
      beforeEach ->
        links = [
          from: 'some-node-uuid'
          to: 'some-other-node-uuid'
        ,
          from: 'some-node-uuid'
          to: 'another-node-uuid'
        ]

        flowConfig =
          'some-node-uuid':
            config:
              id: 'some-node-uuid'
              category: 'some-thing'
          'some-other-node-uuid':
            config:
              id: 'some-other-node-uuid'
              category: 'some-other-thing'
          'another-node-uuid':
            config:
              id: 'another-node-uuid'
              category: 'another-thing'

        nodeRegistry =
          'some-thing':
            type: 'nanocyte-node-fluff'
            composedOf:
              'fluff-1':
                type: 'nanocyte-node-fluff'
                linkedToNext: true
          'some-other-thing':
            type: 'nanocyte-node-fluff'
            composedOf:
              'fluff-1':
                type: 'nanocyte-node-fluff'
                linkedToPrev: true
          'another-thing':
            type: 'nanocyte-node-fluff'
            composedOf:
              'fluff-1':
                type: 'nanocyte-node-fluff'
                linkedToPrev: true


        @UUID.v4.onCall(0).returns 'some-node-instance-uuid'
        @UUID.v4.onCall(1).returns 'some-other-node-instance-uuid'
        @UUID.v4.onCall(2).returns 'another-node-instance-uuid'
        @result = @sut._buildLinks links, @sut._generateInstances(links, flowConfig, nodeRegistry, {})

      it 'should set the flow links on the router', ->
        links =
          'some-node-instance-uuid':
            type: 'nanocyte-node-fluff'
            linkedTo: ['some-other-node-instance-uuid', 'another-node-instance-uuid', 'engine-pulse']
          'some-other-node-instance-uuid':
            linkedTo: []
            type: 'nanocyte-node-fluff'
          'another-node-instance-uuid':
            linkedTo: []
            type: 'nanocyte-node-fluff'
          'engine-output':
            type: 'engine-output'
            linkedTo: []
          'engine-data':
            type: 'engine-data'
            linkedTo: []
          'engine-debug':
            type: 'engine-debug'
            linkedTo: []
          'engine-pulse':
            type: 'engine-pulse'
            linkedTo: []

        expect(@result).to.deep.equal links

    describe 'when two nodes are linked to two nodes', ->
      beforeEach ->
        links = [
          from: 'some-node-uuid'
          to: 'some-other-node-uuid'
        ,
          from: 'some-node-uuid'
          to: 'another-node-uuid'
        ,
          from: 'some-different-node-uuid'
          to: 'some-other-node-uuid'
        ,
          from: 'some-different-node-uuid'
          to: 'another-node-uuid'
        ]

        flowConfig =
          'some-node-uuid':
            config:
              id: 'some-node-uuid'
              category: 'some-thing'
          'some-other-node-uuid':
            config:
              id: 'some-other-node-uuid'
              category: 'some-other-thing'
          'some-different-node-uuid':
            config:
              id: 'some-different-node-uuid'
              category: 'different-thing'
          'another-node-uuid':
            config:
              id: 'another-node-uuid'
              category: 'another-thing'

        nodeRegistry =
          'some-thing':
            type: 'nanocyte-node-fluff'
            composedOf:
              'fluffy-1':
                type: 'nanocyte-node-fluff'
                linkedToNext: true
          'some-other-thing':
            type: 'nanocyte-node-stuff'
            composedOf:
              'stuffy-1':
                type: 'nanocyte-node-stuff'
                linkedToPrev: true
          'different-thing':
            type: 'nanocyte-node-ruff'
            composedOf:
              'ruffy-1':
                type: 'nanocyte-node-ruff'
                linkedToNext: true
          'another-thing':
            type: 'nanocyte-node-buff'
            composedOf:
              'buffy-1':
                type: 'nanocyte-node-buff'
                linkedToPrev: true

        @UUID.v4.onCall(0).returns 'some-node-instance-uuid'
        @UUID.v4.onCall(1).returns 'some-other-node-instance-uuid'
        @UUID.v4.onCall(2).returns 'some-different-node-instance-uuid'
        @UUID.v4.onCall(3).returns 'another-node-instance-uuid'
        @result = @sut._buildLinks links, @sut._generateInstances(links, flowConfig, nodeRegistry, {})

      it 'should set the flow links on the router', ->
        links =
          'some-node-instance-uuid':
            type: 'nanocyte-node-fluff'
            linkedTo: ['some-other-node-instance-uuid', 'another-node-instance-uuid', 'engine-pulse']
          'some-other-node-instance-uuid':
            type: 'nanocyte-node-stuff'
            linkedTo: []
          'some-different-node-instance-uuid':
            type: 'nanocyte-node-ruff'
            linkedTo: ['some-other-node-instance-uuid', 'another-node-instance-uuid', 'engine-pulse']
          'another-node-instance-uuid':
            linkedTo: []
            type: 'nanocyte-node-buff'
          'engine-output':
            type: 'engine-output'
            linkedTo: []
          'engine-data':
            type: 'engine-data'
            linkedTo: []
          'engine-debug':
            type: 'engine-debug'
            linkedTo: []
          'engine-pulse':
            type: 'engine-pulse'
            linkedTo: []

        expect(@result).to.deep.equal links

    describe 'when one node is linked to a virtual node', ->
      beforeEach ->
        links = []

        flowConfig =
          'some-node-uuid':
            config:
              id: 'some-node-uuid'
              category: 'something'

        nodeRegistry =
          'something':
            type: 'nanocyte-node-debug'
            composedOf:
              'debug-1':
                linkedToOutput: true
                type: 'nanocyte-node-debug'

        @UUID.v4.onCall(0).returns 'some-node-instance-uuid'
        @result = @sut._buildLinks links, @sut._generateInstances(links, flowConfig, nodeRegistry, {})

      it 'should set the flow links on the router', ->
        links =
          'some-node-instance-uuid':
            type: 'nanocyte-node-debug'
            linkedTo: ['engine-output', 'engine-pulse']
          'engine-output':
            type: 'engine-output'
            linkedTo: []
          'engine-data':
            type: 'engine-data'
            linkedTo: []
          'engine-debug':
            type: 'engine-debug'
            linkedTo: []
          'engine-pulse':
            type: 'engine-pulse'
            linkedTo: []

        expect(@result).to.deep.equal links

    describe 'when debug is set to true', ->
      beforeEach ->
        links = []

        flowConfig =
          'some-node-uuid':
            config:
              id: 'some-node-uuid'
              debug: true
              category: 'something'

        nodeRegistry =
          'something':
            type: 'nanocyte-node-bar'
            composedOf:
              'bar-1':
                type: 'nanocyte-node-bar'

        @UUID.v4.onCall(0).returns 'some-node-instance-uuid'
        @result = @sut._buildLinks links, @sut._generateInstances(links, flowConfig, nodeRegistry, {})

      it 'should set the flow links on the router', ->
        links =
          'some-node-instance-uuid':
            type: 'nanocyte-node-bar'
            linkedTo: ['engine-debug']
          'engine-output':
            type: 'engine-output'
            linkedTo: []
          'engine-data':
            type: 'engine-data'
            linkedTo: []
          'engine-debug':
            type: 'engine-debug'
            linkedTo: []
          'engine-pulse':
            type: 'engine-pulse'
            linkedTo: []

        expect(@result).to.deep.equal links

    describe 'when linkedToOutput', ->
      beforeEach ->
        links = []

        flowConfig =
          'some-node-uuid':
            config:
              id: 'some-node-uuid'
              category: 'something'

        nodeRegistry =
          'something':
            type: 'nanocyte-node-bar'
            composedOf:
              'bar-1':
                type: 'nanocyte-node-bar'
                linkedToOutput: true

        @UUID.v4.onCall(0).returns 'some-node-instance-uuid'
        @result = @sut._buildLinks links, @sut._generateInstances(links, flowConfig, nodeRegistry, {})

      it 'should set the flow links on the router', ->
        links =
          'some-node-instance-uuid':
            type: 'nanocyte-node-bar'
            linkedTo: ['engine-output', 'engine-pulse']
          'engine-output':
            type: 'engine-output'
            linkedTo: []
          'engine-data':
            type: 'engine-data'
            linkedTo: []
          'engine-debug':
            type: 'engine-debug'
            linkedTo: []
          'engine-pulse':
            type: 'engine-pulse'
            linkedTo: []

        expect(@result).to.deep.equal links

    describe 'when linkedToPulse', ->
      beforeEach ->
        links = []

        flowConfig =
          'some-node-uuid':
            config:
              id: 'some-node-uuid'
              category: 'something'

        nodeRegistry =
          'something':
            type: 'nanocyte-node-bar'
            composedOf:
              'bar-1':
                type: 'nanocyte-node-bar'
                linkedToPulse: true

        @UUID.v4.onCall(0).returns 'some-node-instance-uuid'
        @result = @sut._buildLinks links, @sut._generateInstances(links, flowConfig, nodeRegistry, {})

      it 'should set the flow links on the router', ->
        links =
          'some-node-instance-uuid':
            type: 'nanocyte-node-bar'
            linkedTo: ['engine-pulse']
          'engine-output':
            type: 'engine-output'
            linkedTo: []
          'engine-data':
            type: 'engine-data'
            linkedTo: []
          'engine-debug':
            type: 'engine-debug'
            linkedTo: []
          'engine-pulse':
            type: 'engine-pulse'
            linkedTo: []

        expect(@result).to.deep.equal links

    describe 'when linkedToData', ->
      beforeEach ->
        links = []

        flowConfig =
          'some-node-uuid':
            config:
              id: 'some-node-uuid'
              category: 'something'

        nodeRegistry =
          'something':
            type: 'nanocyte-node-save-me'
            composedOf:
              'save-me-1':
                type: 'nanocyte-node-save-me'
                linkedToData: true


        @UUID.v4.onCall(0).returns 'some-node-instance-uuid'

        @result = @sut._buildLinks links, @sut._generateInstances(links, flowConfig, nodeRegistry, {})

      it 'should set the flow links on the router', ->
        links =
          'some-node-instance-uuid':
            type: 'nanocyte-node-save-me'
            linkedTo: ['engine-data']
          'engine-output':
            type: 'engine-output'
            linkedTo: []
          'engine-data':
            type: 'engine-data'
            linkedTo: []
          'engine-debug':
            type: 'engine-debug'
            linkedTo: []
          'engine-pulse':
            type: 'engine-pulse'
            linkedTo: []

        expect(@result).to.deep.equal links

    describe 'when linkedToNext', ->
      beforeEach ->
        links = [
          from: 'some-trigger-uuid'
          to: 'some-throttle-uuid'
        ,
          from: 'some-throttle-uuid'
          to: 'some-debug-uuid'
        ]

        flowConfig =
          'some-trigger-uuid':
            config:
              id: 'some-trigger-uuid'
              category: 'trigger'
          'some-throttle-uuid':
            config:
              id: 'some-throttle-uuid'
              category: 'throttle'
          'some-debug-uuid':
            config:
              id: 'some-debug-uuid'
              debug: true
              category: 'debug'

        nodeRegistry =
          'trigger':
            type: 'nanocyte-node-trigger'
            composedOf:
              'trigger-1':
                type: 'nanocyte-node-trigger'
                linkedToInput: true
                linkedToNext: true
          'throttle':
            type: 'nanocyte-node-throttle'
            composedOf:
              'throttle-push-1':
                type: 'nanocyte-node-throttle-push'
                linkedToData: true
                linkedToPrev: true
              'throttle-pop-1':
                type: 'nanocyte-node-throttle-pop'
                linkedTo: ['throttle-emit-1']
                linkedToInput: true
                linkedToData: true
              'throttle-emit-1':
                type: 'nanocyte-node-throttle-emit'
                linkedToInput: true
                linkedToNext: true
          'debug':
            type: 'nanocyte-node-debug'
            composedOf:
              'debug-1':
                type: 'nanocyte-node-debug'
                linkedToPrev: true

        @UUID.v4.onCall(0).returns 'trigger-instance-uuid'
        @UUID.v4.onCall(1).returns 'throttle-push-instance-uuid'
        @UUID.v4.onCall(2).returns 'throttle-pop-instance-uuid'
        @UUID.v4.onCall(3).returns 'throttle-emit-instance-uuid'
        @UUID.v4.onCall(4).returns 'debug-instance-uuid'

        @result = @sut._buildLinks links, @sut._generateInstances(links, flowConfig, nodeRegistry, {})

      it 'should set the flow links on the router', ->
        links =
          'some-trigger-uuid':
            type: 'engine-input'
            linkedTo: ['trigger-instance-uuid']
          'trigger-instance-uuid':
            type: 'nanocyte-node-trigger'
            linkedTo: ['throttle-push-instance-uuid', 'engine-pulse']
          'some-throttle-uuid':
            type: 'engine-input'
            linkedTo: ['throttle-pop-instance-uuid', 'throttle-emit-instance-uuid']
          'throttle-push-instance-uuid':
            type: 'nanocyte-node-throttle-push'
            linkedTo: ['engine-data']
          'throttle-pop-instance-uuid':
            type: 'nanocyte-node-throttle-pop'
            linkedTo: ['throttle-emit-instance-uuid', 'engine-data']
          'throttle-emit-instance-uuid':
            type: 'nanocyte-node-throttle-emit'
            linkedTo: ['debug-instance-uuid', 'engine-pulse']
          'debug-instance-uuid':
            type: 'nanocyte-node-debug'
            linkedTo: ['engine-debug']
          'engine-output':
            type: 'engine-output'
            linkedTo: []
          'engine-data':
            type: 'engine-data'
            linkedTo: []
          'engine-debug':
            type: 'engine-debug'
            linkedTo: []
          'engine-pulse':
            type: 'engine-pulse'
            linkedTo: []

        expect(@result).to.deep.equal links

    describe 'when linkedToStart and linkedToStop', ->
      beforeEach ->
        links = [
          from: 'some-interval-uuid'
          to: 'some-debug-uuid'
        ]

        flowConfig =
          'some-interval-uuid':
            config:
              id: 'some-interval-uuid'
              category: 'interval'

          'some-debug-uuid':
            config:
              id: 'some-debug-uuid'
              debug: true
              category: 'debug'

        nodeRegistry =
          'interval':
            type: 'nanocyte-node-interval'
            composedOf:
              'interval-1':
                type: 'nanocyte-node-interval'
                linkedToNext: true
                linkedToInput: true
              'interval-start':
                type: 'nanocyte-node-interval-start'
                linkedFromStart: true
              'interval-stop':
                type: 'nanocyte-node-interval-stop'
                linkedFromStop: true
          'debug':
            composedOf:
              'debug-1':
                type: 'nanocyte-node-debug'
                linkedToPrev: true

        @UUID.v4.onCall(0).returns 'interval-instance-uuid'
        @UUID.v4.onCall(1).returns 'interval-start-instance-uuid'
        @UUID.v4.onCall(2).returns 'interval-stop-instance-uuid'
        @UUID.v4.onCall(3).returns 'debug-instance-uuid'

        @result = @sut._buildLinks links, @sut._generateInstances(links, flowConfig, nodeRegistry, {})

      it 'should set the flow links on the router', ->
        links =
          'engine-start':
            type: 'engine-start'
            linkedTo: ['interval-start-instance-uuid']
          'engine-stop':
            type: 'engine-stop'
            linkedTo: ['interval-stop-instance-uuid']
          'some-interval-uuid':
            type: 'engine-input'
            linkedTo: ['interval-instance-uuid']
          'interval-instance-uuid':
            type: 'nanocyte-node-interval'
            linkedTo: ['debug-instance-uuid','engine-pulse']
          'interval-start-instance-uuid':
            type: 'nanocyte-node-interval-start'
            linkedTo: []
          'interval-stop-instance-uuid':
            type: 'nanocyte-node-interval-stop'
            linkedTo: []
          'debug-instance-uuid':
            linkedTo: ["engine-debug"]
            type: "nanocyte-node-debug"
          'engine-output':
            type: 'engine-output'
            linkedTo: []
          'engine-data':
            type: 'engine-data'
            linkedTo: []
          'engine-debug':
            type: 'engine-debug'
            linkedTo: []
          'engine-pulse':
            type: 'engine-pulse'
            linkedTo: []

        expect(@result).to.deep.equal links

  describe '-> _buildNodeMap', ->
    beforeEach ->
      @sut = new ConfigurationGenerator {}, {UUID: @UUID, channelConfig: {}}

    describe 'when one node is linked to another', ->
      beforeEach ->
        links = [
          from: 'some-node-uuid'
          to: 'some-other-node-uuid'
        ]

        flowConfig =
          'some-node-uuid':
            config:
              id: 'some-node-uuid'
              category: 'nanocyte-node-cruft'
          'some-other-node-uuid':
            config:
              id: 'some-other-node-uuid'
              category: 'nanocyte-node-fluff'

        nodeRegistry =
          'nanocyte-node-cruft':
            composedOf:
              'cruft-1':
                type: 'nanocyte-node-cruft'
                linkedToNext: true
          'nanocyte-node-fluff':
            composedOf:
              'fluff-1':
                type: 'nanocyte-node-fluff'
                linkedToPrev: true

        @UUID.v4.onCall(0).returns 'some-node-instance-uuid'
        @UUID.v4.onCall(1).returns 'some-other-node-instance-uuid'
        @result = @sut._buildNodeMap @sut._generateInstances(links, flowConfig, nodeRegistry, {})

      it 'should build the node map', ->
        nodeMap =
          'some-node-instance-uuid':
            nodeId: 'some-node-uuid'
          'some-other-node-instance-uuid':
            nodeId: 'some-other-node-uuid'
        expect(@result).to.deep.equal nodeMap

  describe '-> _buildMeshblutoNodeMap', ->
    describe 'when two of the same input node', ->
      beforeEach ->
        flow =
          'device-instance-1-uuid':
            config:
              uuid: 'device-uuid'
          'device-instance-2-uuid':
            config:
              uuid: 'device-uuid'

        instanceMap =
          'device-instance-1':
            nodeUuid: 'device-instance-1-uuid'
            linkedToInput: true
          'device-instance-2':
            nodeUuid: 'device-instance-2-uuid'
            linkedToInput: true

        @sut = new ConfigurationGenerator {}, {channelConfig: {}}
        @result = @sut._buildMeshblutoNodeMap flow, instanceMap

      it 'should send back a map linking both devices to the same uuid', ->
        expect(@result['device-uuid']).to.deep.contain.same.members [
          {nodeId: 'device-instance-1-uuid'}
          {nodeId: 'device-instance-2-uuid'}
        ]
