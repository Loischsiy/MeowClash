package main

import (
	"bytes"
	"net"
	"strconv"
	"strings"

	"gopkg.in/yaml.v3"
)

type outlineEndpointConfig struct {
	Type     string `yaml:"$type"`
	Endpoint string `yaml:"endpoint"`
	Secret   string `yaml:"secret"`
	Password string `yaml:"password"`
	Cipher   string `yaml:"cipher"`
	Method   string `yaml:"method"`
	Prefix   string `yaml:"prefix"`
}

type outlineTransportConfig struct {
	Type     string                 `yaml:"$type"`
	Endpoint string                 `yaml:"endpoint"`
	Secret   string                 `yaml:"secret"`
	Password string                 `yaml:"password"`
	Cipher   string                 `yaml:"cipher"`
	Method   string                 `yaml:"method"`
	Prefix   string                 `yaml:"prefix"`
	TCP      *outlineEndpointConfig `yaml:"tcp"`
	UDP      *outlineEndpointConfig `yaml:"udp"`
}

type outlineDynamicKey struct {
	Name       string                  `yaml:"name"`
	Transport  *outlineTransportConfig `yaml:"transport"`
	Server     string                  `yaml:"server"`
	ServerPort int                     `yaml:"server_port"`
	Port       int                     `yaml:"port"`
	Password   string                  `yaml:"password"`
	Secret     string                  `yaml:"secret"`
	Method     string                  `yaml:"method"`
	Cipher     string                  `yaml:"cipher"`
	Prefix     string                  `yaml:"prefix"`
	UDPPrefix  string                  `yaml:"udp-prefix"`
}

func unmarshalOutlineYAML(data []byte, doc *outlineDynamicKey) error {
	if err := yaml.Unmarshal(data, doc); err == nil {
		return nil
	} else if !bytes.Contains(data, []byte("<<:")) {
		return err
	}
	// Outline's docs show `<<: &shared` with an empty value, which gopkg.in/yaml.v3
	// rejects on `<<: *shared`. Strip bare merge lines and let tcpudp inherit
	// missing backend fields from the sibling section.
	lines := strings.Split(string(data), "\n")
	filtered := make([]string, 0, len(lines))
	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, "<<:") {
			rest := strings.TrimSpace(strings.TrimPrefix(trimmed, "<<:"))
			if strings.HasPrefix(rest, "&") || strings.HasPrefix(rest, "*") {
				continue
			}
		}
		filtered = append(filtered, line)
	}
	*doc = outlineDynamicKey{}
	return yaml.Unmarshal([]byte(strings.Join(filtered, "\n")), doc)
}

func parseOutlineDynamicConfig(data []byte) ([]map[string]any, bool) {
	var doc outlineDynamicKey
	if err := unmarshalOutlineYAML(data, &doc); err != nil {
		return nil, false
	}

	baseName := strings.TrimSpace(doc.Name)
	if baseName == "" {
		baseName = "Outline"
	}

	if doc.Transport != nil {
		switch strings.ToLower(strings.TrimSpace(doc.Transport.Type)) {
		case "shadowsocks":
			p, ok := buildOutlineSSProxy(baseName, outlineEndpointConfig{
				Type:     doc.Transport.Type,
				Endpoint: doc.Transport.Endpoint,
				Secret:   doc.Transport.Secret,
				Password: doc.Transport.Password,
				Cipher:   doc.Transport.Cipher,
				Method:   doc.Transport.Method,
				Prefix:   doc.Transport.Prefix,
			}, true)
			if !ok {
				return nil, false
			}
			return []map[string]any{p}, true

		case "tcpudp":
			if doc.Transport.TCP != nil && doc.Transport.UDP != nil {
				if doc.Transport.UDP.Endpoint == "" {
					doc.Transport.UDP.Endpoint = doc.Transport.TCP.Endpoint
				}
				if doc.Transport.UDP.Secret == "" && doc.Transport.UDP.Password == "" {
					doc.Transport.UDP.Secret = doc.Transport.TCP.Secret
					doc.Transport.UDP.Password = doc.Transport.TCP.Password
				}
				if doc.Transport.UDP.Cipher == "" && doc.Transport.UDP.Method == "" {
					doc.Transport.UDP.Cipher = doc.Transport.TCP.Cipher
					doc.Transport.UDP.Method = doc.Transport.TCP.Method
				}
				if doc.Transport.UDP.Type == "" {
					doc.Transport.UDP.Type = doc.Transport.TCP.Type
				}
			}
			var tcpProxy, udpProxy map[string]any
			var hasTCP, hasUDP bool
			if doc.Transport.TCP != nil && (doc.Transport.TCP.Type == "" || strings.EqualFold(doc.Transport.TCP.Type, "shadowsocks")) {
				tcpProxy, hasTCP = buildOutlineSSProxy(baseName, *doc.Transport.TCP, false)
			}
			if doc.Transport.UDP != nil && (doc.Transport.UDP.Type == "" || strings.EqualFold(doc.Transport.UDP.Type, "shadowsocks")) {
				udpProxy, hasUDP = buildOutlineSSProxy(baseName, *doc.Transport.UDP, true)
			}

			switch {
			case hasTCP && hasUDP:
				if sameSSBackend(tcpProxy, udpProxy) {
					tcpProxy["udp"] = true
					if udpPrefix, _ := udpProxy["prefix"].(string); udpPrefix != "" {
						tcpProxy["udp-prefix"] = udpPrefix
					}
					return []map[string]any{tcpProxy}, true
				}
				tcpProxy["name"] = baseName + " TCP"
				udpProxy["name"] = baseName + " UDP"
				if udpPrefix, _ := udpProxy["prefix"].(string); udpPrefix != "" {
					delete(udpProxy, "prefix")
					udpProxy["udp-prefix"] = udpPrefix
				}
				return []map[string]any{tcpProxy, udpProxy}, true

			case hasTCP:
				return []map[string]any{tcpProxy}, true

			case hasUDP:
				if udpPrefix, _ := udpProxy["prefix"].(string); udpPrefix != "" {
					delete(udpProxy, "prefix")
					udpProxy["udp-prefix"] = udpPrefix
				}
				return []map[string]any{udpProxy}, true
			}
		}
	}

	port := doc.ServerPort
	if port == 0 {
		port = doc.Port
	}
	cipher := firstNonEmpty(doc.Cipher, doc.Method)
	password := firstNonEmpty(doc.Password, doc.Secret)
	if doc.Server != "" && port > 0 && cipher != "" && password != "" {
		proxy := map[string]any{
			"name":     baseName,
			"type":     "ss",
			"server":   doc.Server,
			"port":     port,
			"cipher":   cipher,
			"password": password,
			"udp":      true,
		}
		if doc.Prefix != "" {
			proxy["prefix"] = doc.Prefix
		}
		if doc.UDPPrefix != "" {
			proxy["udp-prefix"] = doc.UDPPrefix
		}
		return []map[string]any{proxy}, true
	}

	return nil, false
}

func buildOutlineSSProxy(name string, cfg outlineEndpointConfig, udp bool) (map[string]any, bool) {
	host, portStr, err := net.SplitHostPort(strings.TrimSpace(cfg.Endpoint))
	if err != nil || host == "" {
		return nil, false
	}
	port, err := strconv.Atoi(portStr)
	if err != nil || port <= 0 {
		return nil, false
	}
	cipher := firstNonEmpty(cfg.Cipher, cfg.Method)
	password := firstNonEmpty(cfg.Secret, cfg.Password)
	if cipher == "" || password == "" {
		return nil, false
	}
	proxy := map[string]any{
		"name":     name,
		"type":     "ss",
		"server":   host,
		"port":     port,
		"cipher":   cipher,
		"password": password,
		"udp":      udp,
	}
	if cfg.Prefix != "" {
		proxy["prefix"] = cfg.Prefix
	}
	return proxy, true
}

func sameSSBackend(a, b map[string]any) bool {
	return a["server"] == b["server"] &&
		a["port"] == b["port"] &&
		a["cipher"] == b["cipher"] &&
		a["password"] == b["password"]
}

func firstNonEmpty(values ...string) string {
	for _, v := range values {
		if v != "" {
			return v
		}
	}
	return ""
}
