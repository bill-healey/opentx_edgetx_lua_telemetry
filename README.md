# opentx_edgetx_lua_telemetry
Telemetry Screen LUA scripts for OpenTX and EdgeTX radios

Highly compact UI that shows quad battery level, RSSI, modes, and channels 1-7 in realtime.

Includes memory-efficient graphs with configurable data/plot rates.  Graphs use ring-buffers to minimize CPU requirements and the need for GC.
Config file will be written on first execution.  

Switches and UI can be configured via the file on the sdcard or via the UI by long-pressing up.

To install, copy to sdcard://scripts/telemetry

Todo/Potential feature list:
- Dynamically name graphs based on chosen telemetry signal
- Allow UI grid elements to be arranged via config rather than lua code
- Add activation ranges for all switches, not just beeper
- Group related configs
