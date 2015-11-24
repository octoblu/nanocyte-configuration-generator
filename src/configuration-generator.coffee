_ = require 'lodash'
debug = require('debug')('nanocyte-configuration-generator')
NodeUuid = require 'node-uuid'
ChannelConfig = require './channel-config'
textCrypt = require './text-crypt'

DEFAULT_REGISTRY_URL = 'https://raw.githubusercontent.com/octoblu/nanocyte-node-registry/master/registry.json'
METRICS_DEVICE_ID = 'f952aacb-5156-4072-bcae-f830334376b1'

VIRTUAL_NODES =
  'engine-input':
    config: {}
    data: {}
  'engine-output':
    config: {}
    data: {}
  'engine-data':
    config: {}
    data: {}
  'engine-debug':
    config: {}
    data: {}
  'engine-pulse':
    config: {}
    data: {}
  'router':
    config: {}
    data: {}
  'engine-start':
    config: {}
    data: {}
  'engine-stop':
    config: {}
    data: {}

class ConfigurationGenerator
  constructor: (options, dependencies={}) ->
    {@registryUrl, @meshbluJSON, @metricsDeviceId} = options
    @registryUrl ?= DEFAULT_REGISTRY_URL
    @metricsDeviceId ?= METRICS_DEVICE_ID

    {@request, @channelConfig} = dependencies
    @request ?= require 'request'
    @channelConfig ?= new ChannelConfig
      accessKeyId:     options.accessKeyId
      secretAccessKey: options.secretAccessKey

  configure: (options, callback=->) =>
    {flowData, flowToken, userData, deploymentUuid} = options

    debug 'configuring flow...', flowData

    debug 'fetching registry'
    @channelConfig.fetch (error) =>
      return callback error if error?

      @_getNodeRegistry (error, nodeRegistry) =>
        return callback error if error?
        debug 'fetched registry', nodeRegistry

        flowMetricNode =
          id: @_generateFlowMetricId()
          category: 'flow-metrics'
          flowUuid: flowData.flowId
          deviceId: @metricsDeviceId
          deploymentUuid: deploymentUuid

        flowData.nodes ?= []
        flowData.nodes.push flowMetricNode

        flowNodes = _.indexBy flowData.nodes, 'id'

        flowConfig = _.mapValues flowNodes, (nodeConfig) =>
          nodeConfig.nanocyte ?= {}
          nodeConfig.nanocyte.nonce = @_generateNonce()

          config: nodeConfig
          data: {}

        flowConfig = _.assign flowConfig, _.cloneDeep(VIRTUAL_NODES)
        instanceMap = @_generateInstances flowData.links, flowConfig, nodeRegistry, userData

        _.each instanceMap, (instanceConfig, instanceId) =>
          {config,data} = flowConfig[instanceConfig.nodeUuid]

          config = @_legacyConversion _.cloneDeep config # prevent accidental mutation

          getSetConfig = @_mutilateGetSetNodes uuid: flowData.flowId, token: flowToken, config
          oauthConfig = @_ohThatOauth userData, config
          config = _.defaultsDeep {}, config, oauthConfig, getSetConfig

          flowConfig[instanceId] = {config: config, data: data}

        links = @_buildLinks(flowData.links, instanceMap)
        flowConfig.router.config = links

        flowConfig['engine-data'].config  = @_buildNodeMap instanceMap
        flowConfig['engine-pulse'].config = @_buildNodeMap instanceMap
        flowConfig['engine-debug'].config = @_buildNodeMap instanceMap
        flowConfig['engine-input'].config = @_buildMeshblutoNodeMap flowConfig, instanceMap
        flowConfig['engine-output'].config = _.extend {}, @meshbluJSON, uuid: flowData.flowId, token: flowToken

        flowStopConfig = _.cloneDeep flowConfig

        engineStopLinks = flowConfig['router']['config']['engine-stop']?.linkedTo
        engineStopLinks ?= []

        stopRouterConfig = _.pick flowConfig['router']['config'], 'engine-stop', 'engine-output', engineStopLinks...
        flowStopConfig['router']['config'] = stopRouterConfig

        callback null, flowConfig, flowStopConfig

  _buildNodeMap: (flowNodeMap) =>
    _.mapValues flowNodeMap, (flowNode) =>
      nodeId: flowNode.nodeUuid

  _buildMeshblutoNodeMap: (flowConfig, instanceMap) =>
    inputInstances = _.where instanceMap, linkedToInput: true

    nodeMap = {}
    _.each inputInstances, (instance) =>
      nodeConfig = flowConfig[instance.nodeUuid]
      nodeMap[nodeConfig.config.uuid] ?= []
      nodeMap[nodeConfig.config.uuid].push {nodeId: instance.nodeUuid}
    return nodeMap

  _generateInstances: (links, flowNodes, nodeRegistry, userData) =>
    instanceMap = {}
    _.each flowNodes, (nodeConfig, nodeUuid) =>
      config = nodeConfig.config ? {}
      nanocyteConfig = config.nanocyte ? {}

      type = config.category
      type = config.type.replace('operation:', '') if type == 'operation'
      nodeFromRegistry = nodeRegistry[type] ? {}

      composedOf = nodeFromRegistry.composedOf ? {}

      linkedToData = _.detect composedOf, (value, key) =>
        value.linkedToData == true

      transactionGroupId = @_generateTransactionGroupId() if linkedToData?

      _.each composedOf, (template, templateId) =>
        instanceId = @_generateInstanceId()
        composedConfig = _.cloneDeep template
        composedConfig.nodeUuid = nodeUuid
        composedConfig.templateId = templateId
        composedConfig.debug = config.debug
        composedConfig.transactionGroupId = transactionGroupId if linkedToData?

        instanceMap[instanceId] = composedConfig

    return instanceMap

  _getNodeRegistry: (callback) =>
    @request.get @registryUrl, json: true, (error, response, nodeRegistry) =>
      callback error, nodeRegistry

  _buildLinks: (links, instanceMap) =>
    debug 'building links with', links
    result = {}
    _.each instanceMap, (config, instanceId) =>
      nodeLinks = _.filter links, from: config.nodeUuid
      templateLinks = config.linkedTo
      linkedTo = []

      if config.linkedToInput
        result[config.nodeUuid] ?=
          type: 'engine-input'
          linkedTo: []
        result[config.nodeUuid].linkedTo.push instanceId

      if config.linkedFromStart
        result['engine-start'] ?=
          type: 'engine-start'
          linkedTo: []
        result['engine-start'].linkedTo.push instanceId

      if config.linkedFromStop
        result['engine-stop'] ?=
          type: 'engine-stop'
          linkedTo: []
        result['engine-stop'].linkedTo.push instanceId

      if config.linkedToNext
        linkUuids = _.pluck nodeLinks, 'to'
        _.each instanceMap, (data, key) =>
          if _.contains linkUuids, data.nodeUuid
            linkedTo.push key if data.linkedToPrev

      _.each config.linkedTo, (templateLinkId) =>
        _.each instanceMap, (data, key) =>
          if data.nodeUuid == config.nodeUuid && data.templateId == templateLinkId
            linkedTo.push key

      linkedTo.push 'engine-output' if config.linkedToOutput
      linkedTo.push 'engine-pulse' if config.linkedToNext || config.linkedToPulse || config.linkedToOutput
      linkedTo.push 'engine-data' if config.linkedToData
      linkedTo.push 'engine-debug' if config.debug

      result[instanceId] =
        type: config.type
        linkedTo: linkedTo

      result[instanceId].transactionGroupId = config.transactionGroupId if config.transactionGroupId?

    result['engine-output'] =
      type: 'engine-output'
      linkedTo: []
    result['engine-debug'] =
      type: 'engine-debug'
      linkedTo: []
    result['engine-pulse'] =
      type: 'engine-pulse'
      linkedTo: []
    result['engine-data'] =
      type: 'engine-data'
      linkedTo: []

    debug 'router config is', result

    return result

  _legacyConversion: (config) =>
    if config.type == 'operation:debounce'
      config.timeout = config.interval
      delete config.interval
    if config.type == 'operation:throttle'
      config.repeat = config.interval
      delete config.interval
    if config.type == 'operation:delay'
      config.fireOnce = true
      config.noUnsubscribe = true

    return config

  _mutilateGetSetNodes: (options, template) =>
    return {} unless template.type == 'operation:get-key' || template.type == 'operation:set-key'

    {uuid, token} = options

    bearerToken = new Buffer("#{uuid}:#{token}").toString('base64')

    {host,protocol,port} = @meshbluJSON
    host ?= 'meshblu.octoblu.com:443'
    if host == 'meshblu-messages.octoblu.com:443'
      host = 'meshblu.octoblu.com:443'
    port ?= 443
    protocol ?= 'http'
    protocol = 'https' if parseInt(port) == 443

    config =
      bodyEncoding: 'json'
      url: "#{protocol}://#{host}/v2/devices/#{uuid}"
      method: 'GET'
      headerKeys: [
        'Content-Type'
        'Authorization'
      ]
      headerValues: [
        'application/json'
        "Bearer #{bearerToken}"
      ]

    if template.type == 'operation:set-key'
      config.method = 'PATCH'
      config.bodyKeys =  [ 'data.{{msg.key}}' ]
      config.bodyValues = [ '{{msg.value}}' ]

    return config

  _ohThatOauth: (userData, template) =>
    userApiMatch = _.findWhere(userData.api, type: template.type)
    return {} unless userApiMatch?

    channelApiMatch = @channelConfig.get template.type
    return {} unless channelApiMatch?

    channelConfig = _.pick channelApiMatch,
      'bodyFormat'
      'followAllRedirects'
      'skipVerifySSL'
      'hiddenParams'
      'auth_header_key'
      'bodyParams'

    config = _.defaults {}, template, channelConfig

    if userApiMatch.token_crypt
      userApiMatch.secret = textCrypt.decrypt userApiMatch.secret_crypt
      userApiMatch.token  = textCrypt.decrypt userApiMatch.token_crypt

    config.apikey = userApiMatch.apikey

    userToken = userApiMatch.token ? userApiMatch.key

    userOAuth =
      access_token: userToken
      access_token_secret: userApiMatch.secret
      refreshToken: userApiMatch.refreshToken
      expiresOn: userApiMatch.expiresOn
      defaultParams: userApiMatch.defaultParams

    channelOauth =  channelApiMatch.oauth?[process.env.NODE_ENV]
    channelOauth ?= channelApiMatch.oauth
    channelOauth ?= {tokenMethod: channelApiMatch.auth_strategy}

    config.oauth = _.defaults {}, userOAuth, template.oauth, channelOauth

    if channelApiMatch.overrides
      config.headerParams = _.extend {}, template.headerParams, channelApiMatch.overrides.headerParams

    config.oauth.key ?= config.oauth.clientID
    config.oauth.key ?= config.oauth.consumerKey

    config.oauth.secret ?= config.oauth.clientSecret
    config.oauth.secret ?= config.oauth.consumerSecret

    return JSON.parse JSON.stringify config # removes things that are undefined

  _generateFlowMetricId: =>
    NodeUuid.v4()

  _generateInstanceId: =>
    NodeUuid.v4()

  _generateNonce: =>
    NodeUuid.v4()

  _generateTransactionGroupId: =>
    NodeUuid.v4()

module.exports = ConfigurationGenerator
