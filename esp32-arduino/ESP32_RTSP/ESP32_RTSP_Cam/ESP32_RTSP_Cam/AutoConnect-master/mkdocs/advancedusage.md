## Summary

To make sketches work as you intended with AutoConnect, make sure you understand the implications of the setting parameters and configure AutoConnect. [AutoConnectConfig](apiconfig.md) allows you to incorporate settings into AutoConnect that coordinate control over WiFi connectivity and captive portal behavior.  
For advanced usages, the configuration settings and the Sketch examples are followings:

- [AutoConnect WiFi connection control](adconnection.md)
- [Captive portal control](adcpcontrol.md)
- [Authentication settings](adauthentication.md)
- [Credential accesses](adcredential.md)
- [Settings for customizing the page exterior](adexterior.md)
- [Settings and controls for network and WiFi](adnetwork.md)
- [Other operation settings and controls](adothers.md)

!!! note "Don't forget [**AutoConnect::config**](IT/github/tutorials/esp32-arduino/ESP32_RTSP/ESP32_RTSP_Cam/ESP32_RTSP_Cam/AutoConnect-master/mkdocs/api.md#config)"
    The configuration cannot be reflected by only changing the member variables of [AutoConnectConfig](apiconfig.md) settings. It will be reflected in the actual ones by [AutoConnect::config](IT/github/tutorials/esp32-arduino/ESP32_RTSP/ESP32_RTSP_Cam/ESP32_RTSP_Cam/AutoConnect-master/mkdocs/api.md#config) function. Don't forget to run the [AutoConnect::config](IT/github/tutorials/esp32-arduino/ESP32_RTSP/ESP32_RTSP_Cam/ESP32_RTSP_Cam/AutoConnect-master/mkdocs/api.md#config) after changing the AutoConnectConfig member variables.

    ```cpp hl_lines="6"
    AutoConnect portal;
    AutoConnectConfig config;

    void setup() {
      config.autoReconnect = true;
      portal.config(config);  // Don't forget.
      portal.begin();
    }
    ```
