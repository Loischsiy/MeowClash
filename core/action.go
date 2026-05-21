package main

import (
	"encoding/json"
	"unsafe"

	"github.com/metacubex/mihomo/constant"
)

type Action struct {
	Id     string      `json:"id"`
	Method Method      `json:"method"`
	Data   interface{} `json:"data"`
}

type ActionResult struct {
	Id       string         `json:"id"`
	Method   Method         `json:"method"`
	Data     interface{}    `json:"data"`
	Code     int            `json:"code"`
	Port     int64          `json:"port"`
	Callback unsafe.Pointer `json:"-"`
}

func (result ActionResult) Json() ([]byte, error) {
	data, err := json.Marshal(result)
	return data, err
}

func (result ActionResult) success(data interface{}) {
	result.Code = 0
	result.Data = data
	result.send()
}

func (result ActionResult) error(data interface{}) {
	result.Code = -1
	result.Data = data
	result.send()
}

func handleAction(action *Action, result ActionResult) {
	dataStr, dataIsStr := action.Data.(string)
	switch action.Method {
	case initClashMethod:
		if !dataIsStr {
			result.error("invalid data type")
			return
		}
		result.success(handleInitClash(dataStr))
		return
	case getIsInitMethod:
		result.success(handleGetIsInit())
		return
	case forceGcMethod:
		handleForceGc()
		result.success(true)
		return
	case shutdownMethod:
		result.success(handleShutdown())
		return
	case validateConfigMethod:
		if !dataIsStr {
			result.error("invalid data type")
			return
		}
		result.success(handleValidateConfig([]byte(dataStr)))
		return
	case convertSubscriptionMethod:
		if !dataIsStr {
			result.error("invalid data type")
			return
		}
		result.success(handleConvertSubscription([]byte(dataStr)))
		return
	case updateConfigMethod:
		if !dataIsStr {
			result.error("invalid data type")
			return
		}
		result.success(handleUpdateConfig([]byte(dataStr)))
		return
	case setupConfigMethod:
		if !dataIsStr {
			result.error("invalid data type")
			return
		}
		result.success(handleSetupConfig([]byte(dataStr)))
		return
	case getProxiesMethod:
		result.success(handleGetProxies())
		return
	case changeProxyMethod:
		if !dataIsStr {
			result.error("invalid data type")
			return
		}
		handleChangeProxy(dataStr, func(value string) {
			result.success(value)
		})
		return
	case getTrafficMethod:
		result.success(handleGetTraffic())
		return
	case getTotalTrafficMethod:
		result.success(handleGetTotalTraffic())
		return
	case resetTrafficMethod:
		handleResetTraffic()
		result.success(true)
		return
	case asyncTestDelayMethod:
		if !dataIsStr {
			result.error("invalid data type")
			return
		}
		handleAsyncTestDelay(dataStr, func(value string) {
			result.success(value)
		})
		return
	case getConnectionsMethod:
		result.success(handleGetConnections())
		return
	case closeConnectionsMethod:
		result.success(handleCloseConnections())
		return
	case resetConnectionsMethod:
		result.success(handleResetConnections())
		return
	case getConfigMethod:
		if !dataIsStr {
			result.error("invalid data type")
			return
		}
		config, err := handleGetConfig(dataStr)
		if err != nil {
			result.error(err)
			return
		}
		result.success(config)
		return
	case getCoreVersionMethod:
		result.success(constant.Version)
		return
	case closeConnectionMethod:
		if !dataIsStr {
			result.error("invalid data type")
			return
		}
		result.success(handleCloseConnection(dataStr))
		return
	case getExternalProvidersMethod:
		result.success(handleGetExternalProviders())
		return
	case getExternalProviderMethod:
		if !dataIsStr {
			result.error("invalid data type")
			return
		}
		result.success(handleGetExternalProvider(dataStr))
	case updateGeoDataMethod:
		if !dataIsStr {
			result.error("invalid data type")
			return
		}
		var params = map[string]string{}
		err := json.Unmarshal([]byte(dataStr), &params)
		if err != nil {
			result.success(err.Error())
			return
		}
		geoType := params["geo-type"]
		geoName := params["geo-name"]
		handleUpdateGeoData(geoType, geoName, func(value string) {
			result.success(value)
		})
		return
	case updateExternalProviderMethod:
		if !dataIsStr {
			result.error("invalid data type")
			return
		}
		handleUpdateExternalProvider(dataStr, func(value string) {
			result.success(value)
		})
		return
	case sideLoadExternalProviderMethod:
		if !dataIsStr {
			result.error("invalid data type")
			return
		}
		var params = map[string]string{}
		err := json.Unmarshal([]byte(dataStr), &params)
		if err != nil {
			result.success(err.Error())
			return
		}
		providerName := params["providerName"]
		data := params["data"]
		handleSideLoadExternalProvider(providerName, []byte(data), func(value string) {
			result.success(value)
		})
		return
	case startLogMethod:
		handleStartLog()
		result.success(true)
		return
	case stopLogMethod:
		handleStopLog()
		result.success(true)
		return
	case startListenerMethod:
		result.success(handleStartListener())
		return
	case stopListenerMethod:
		result.success(handleStopListener())
		return
	case getCountryCodeMethod:
		if !dataIsStr {
			result.error("invalid data type")
			return
		}
		handleGetCountryCode(dataStr, func(value string) {
			result.success(value)
		})
		return
	case getMemoryMethod:
		handleGetMemory(func(value string) {
			result.success(value)
		})
		return
	case setStateMethod:
		if !dataIsStr {
			result.error("invalid data type")
			return
		}
		handleSetState(dataStr)
		result.success(true)
	case crashMethod:
		result.success(true)
		handleCrash()
	default:
		nextHandle(action, result)
	}
}
