_                      = require 'lodash'
debug                  = require('debug')('nanocyte-configuration-generator')
UUID                   = require 'uuid'
ChannelConfig          = require './channel-config'
MeshbluHttp            = require 'meshblu-http'
NodeRegistryDownloader = require './node-registry-downloader'
SimpleBenchmark        = require 'simple-benchmark'

# outside the class so cache is maintained
Downloader = new NodeRegistryDownloader

DEFAULT_REGISTRY_URL = 'https://s3-us-west-2.amazonaws.com/nanocyte-registry/latest/registry.json'
METRICS_DEVICE_ID    = 'f952aacb-5156-4072-bcae-f830334376b1'

VIRTUAL_NODES =
  'engine-input':
    config: {}
    data: {}
  'engine-output':
    config: {}
    data: {}
  'engine-update':
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
  'subscribe-devices':
    config: {}
    data: {}

class ConfigurationGenerator
  constructor: (options, dependencies={}) ->
    {
      @registryUrl
      @meshbluJSON
      @metricsDeviceId
    } = options

    @meshbluJSON ?= {}
    @registryUrl ?= DEFAULT_REGISTRY_URL
    @metricsDeviceId ?= METRICS_DEVICE_ID

    {@request, @channelConfig} = dependencies
    @request ?= require 'request'
    @benchmark = new SimpleBenchmark label: "nanocyte-configuration-generator-#{@meshbluJSON?.uuid}"
    @channelConfig ?= new ChannelConfig
      accessKeyId:     options.accessKeyId
      secretAccessKey: options.secretAccessKey

    @meshbluHttp = new MeshbluHttp @meshbluJSON

    Downloader.setOptions {@registryUrl}

  configure: (options, callback=->) =>
    {flowData, flowToken, deploymentUuid} = options

    @channelConfig.update (error) =>
      debug 'channelConfig.fetch', @benchmark.toString()
      return callback error if error?

      @_getNodeRegistry (error, nodeRegistry) =>
        debug 'getNodeRegistry', @benchmark.toString()
        return callback error if error?

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
        instanceMap = @_generateInstances flowData.links, flowConfig, nodeRegistry

        _.each instanceMap, (instanceConfig, instanceId) =>
          {config,data} = flowConfig[instanceConfig.nodeUuid]

          config = @_legacyConversion _.cloneDeep config # prevent accidental mutation
          config.templateOriginalMessage = instanceConfig.templateOriginalMessage
          getSetNodesConfig = @_mutilateGetSetNodes uuid: flowData.flowId, token: flowToken, config

          defaultConfig = {}
          if config.category == 'channel'
            channelApiMatch = @channelConfig.get config.type
            return callback new Error "Missing channel config for: #{config.type}" unless channelApiMatch?
            defaultConfig.channelApiMatch = channelApiMatch

          config = _.defaultsDeep defaultConfig, config, getSetNodesConfig

          flowConfig[instanceId] = {config: config, data: data}

        debug 'instanceMap', @benchmark.toString()

        links = @_buildLinks(flowData.links, instanceMap)
        debug 'buildLinks', @benchmark.toString()
        flowConfig.router.config = links

        flowConfig['engine-data'].config  = @_buildNodeMap instanceMap
        flowConfig['engine-pulse'].config = @_buildNodeMap instanceMap
        flowConfig['engine-debug'].config = @_buildNodeMap instanceMap
        flowConfig['engine-input'].config = @_buildMeshblutoNodeMap flowConfig, instanceMap
        flowConfig['subscribe-devices'].config = @_getSubscribeDevices flowNodes

        config = @_buildEngineOutputConfig {flowData, flowToken}

        flowConfig['engine-output'].config = config
        flowConfig['engine-update'].config = config

        flowConfig['engine-output'].config.nodeMap = @_buildNodeMap instanceMap

        flowStopConfig = _.cloneDeep flowConfig

        engineStopLinks = flowConfig['router']['config']['engine-stop']?.linkedTo
        engineStopLinks ?= []

        stopRouterConfig = _.pick flowConfig['router']['config'], 'engine-stop', 'engine-output', engineStopLinks...
        flowStopConfig['router']['config'] = stopRouterConfig
        debug 'calling back', @benchmark.toString()

        callback null, flowConfig, flowStopConfig

  _buildEngineOutputConfig: ({flowData, flowToken}, callback) =>
    _.defaults {uuid: flowData.flowId, token: flowToken}, @meshbluJSON

  _buildNodeMap: (flowNodeMap) =>
    _.mapValues flowNodeMap, (flowNode) =>
      nodeId: flowNode.nodeUuid

  _buildMeshblutoNodeMap: (flowConfig, instanceMap) =>
    inputInstances = _.where instanceMap, linkedToInput: true

    nodeMap = {}
    _.each inputInstances, (instance) =>
      nodeConfig = flowConfig[instance.nodeUuid]
      nodeMap[nodeConfig.config.uuid] ?= []

      alias = nodeConfig.config.alias
      aNodeMap = nodeId: instance.nodeUuid
      aNodeMap.alias = alias if alias?

      nodeMap[nodeConfig.config.uuid].push aNodeMap

    return nodeMap

  _generateInstances: (links, flowNodes, nodeRegistry) =>
    instanceMap = {}
    _.each flowNodes, (nodeConfig, nodeUuid) =>
      config = nodeConfig.config ? {}
      nanocyteConfig = config.nanocyte ? {}

      type = config.category
      type = config.type.replace('operation:', '') if type == 'operation'
      type = 'device' if @_isDevice config
      type = 'device-configure' if @_isDeviceConfigure config
      nodeFromRegistry = nodeRegistry[type] ? {}

      composedOf = _.cloneDeep(nodeFromRegistry.composedOf) ? {}

      linkedToData = _.detect composedOf, (value, key) =>
        value.linkedToData == true

      composedOf = @_addDebug(composedOf) if config.debug?

      transactionGroupId = @_generateTransactionGroupId() if linkedToData?

      _.each composedOf, (template, templateId) =>
        instanceId = @_generateInstanceId()
        composedConfig = _.cloneDeep template
        composedConfig.nodeUuid = nodeUuid
        composedConfig.templateId = templateId
        composedConfig.transactionGroupId = transactionGroupId if linkedToData?
        composedConfig.instanceId = instanceId
        composedConfig.eventType = config.eventType
        composedConfig.isDevice = @_isDevice config
        instanceMap[instanceId] = composedConfig

    return instanceMap

  _addDebug: (composedOf) =>
    composedOf = @_addInputDebug composedOf
    composedOf = @_addOutputDebug composedOf
    return composedOf

  _addInputDebug: (composedOf) =>
    composedOf = _.cloneDeep composedOf

    debugInput =
      type: "nanocyte-component-pass-through"
      debug: true
      linkedTo: []
      linkedToPrev: true

    composedOf['debug-input'] = debugInput

    composedOf

  _addOutputDebug: (composedOf) =>
    _.mapValues composedOf, (node) =>
      node.debug = true if node.linkedToNext
      node

  _getNodeRegistry: (callback) =>
    Downloader.update callback

  _getForwardMetadataTo: (deviceUuids, callback) =>
    query =
      uuid: $in: deviceUuids
      'octoblu.flow.forwardMetadata': true

    projection =
      uuid: true

    @meshbluHttp.search query, {projection}, (error, devices) =>
      return callback error if error?
      return callback null, _.map(devices, 'uuid')

  _getSubscribeDevices: (flowNodes) =>
    flowNodesByEventType = _.groupBy flowNodes, (node) =>
      return 'not-a-device' unless @_isDevice node
      return node.eventType || 'message'

    return {
      'broadcast.sent': @_getDeviceUuids(flowNodesByEventType['message'])
      'configure.sent': @_getDeviceUuids(flowNodesByEventType['configure'])
    }

  _getDeviceUuids: (flowNodes) =>
    # devices = _.where flowNodes, category: 'device'
    devices = _.filter flowNodes, @_isDevice
    _.pluck devices, 'uuid'

  _isDevice: (item) =>
    return true if item.meshblu?
    return true if item.class == 'device-flow'
    return true if item.class == 'device'
    return false

  _isDeviceConfigure: (item) =>
    @_isDevice(item) && item.eventType == 'configure'

  _buildLinks: (links, instanceMap) =>
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
        eventLinks = @_getEventLinks {config, nodeLinks, instanceMap} if config.isDevice
        linkedTo = @_getLinkedTo {nodeLinks, instanceMap} unless config.isDevice

      _.each config.linkedTo, (templateLinkId) =>
        _.each instanceMap, (data, key) =>
          if data.nodeUuid == config.nodeUuid && data.templateId == templateLinkId
            linkedTo.push key

      linkedTo.push 'engine-output' if config.linkedToOutput
      linkedTo.push 'engine-update' if config.linkedToUpdate
      linkedTo.push 'engine-pulse' if config.linkedToNext || config.linkedToPulse || config.linkedToOutput || config.linkedToUpdate
      linkedTo.push 'engine-data' if config.linkedToData
      linkedTo.push 'engine-debug' if config.debug

      result[instanceId] =
        eventLinks: eventLinks
        type: config.type
        linkedTo: linkedTo
        linkedToNext: config.linkedToNext

      result[instanceId].transactionGroupId = config.transactionGroupId if config.transactionGroupId?

    result['engine-output'] =
      type: 'engine-output'
      linkedTo: []
    result['engine-update'] =
      type: 'engine-update'
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

    return result

  _getEventLinks: ({config, nodeLinks, instanceMap}) =>
    eventLinks =
      'broadcast.sent': []
      'message.received': []
      'configure.sent': []

    _.each nodeLinks, (link) =>
      prevNanocytes = _.filter instanceMap, nodeUuid: link.to, linkedToPrev: true
      _.each prevNanocytes, (nanocyte) =>
        if config.eventType == 'configure'
          eventLinks['configure.sent'].push nanocyte.instanceId
        else
          eventLinks['broadcast.sent'].push nanocyte.instanceId
          eventLinks['message.received'].push nanocyte.instanceId

    return eventLinks

  _getLinkedTo: ({nodeLinks, instanceMap}) =>
    linkedTo = []
    linkUuids = _.pluck nodeLinks, 'to'
    _.each instanceMap, (data, key) =>
      if _.contains linkUuids, data.nodeUuid
        linkedTo.push key if data.linkedToPrev

    return linkedTo

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
    host ?= 'meshblu-http.octoblu.com:443'
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

  _generateFlowMetricId: =>
    UUID.v4()

  _generateInstanceId: =>
    UUID.v4()

  _generateNonce: =>
    UUID.v4()

  _generateTransactionGroupId: =>
    UUID.v4()

module.exports = ConfigurationGenerator
