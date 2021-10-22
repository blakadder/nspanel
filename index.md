# NSPanel Protocol 
```
55 AA [type] [payload length] [00] [payload] [crc] [crc]
```

| JSON Payload                                                              | Action and options<BR>`%b` = binary 0 or 1,`%d` = number, `%s` = string                                                                                                                                          | Notes                                                                                                    | Type |
|---------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------|------|
| `{"queryInfo":"version"}`                                                 | Query screen version                                                                                                                                                                                             |                                                                                                          | 80   |
| `{"queryInfo":"factory"}`                                                 | Enter factory test mode                                                                                                                                                                                          |                                                                                                          | 80   |
| `{"tempUnit":%b}`                                                         | Set displayed temperature unit<BR>`0` = °C<BR>`1` = °F                                                                                                                                                           |                                                                                                          | 83   |
| `{"temperature":%d,"humidity":%d,"tempUnit":%d}`                          | Set room temperature<BR>temperature `%d` = up to 5 characters, decimals are ignored but can be in the parameter                                                                                                  | humidity isn't displayed<BR>temperature can be up to 5 characters<B>5th character overwrites the unit | 83   |
| `{"HMI_dimOpen":%b}`                                                      | Set screen saver<BR>`0` = screen always on<BR>`1` = screen off                                                                                                                                                   |                                                                                                          | 87   |
| `{"wifiState":"%s","rssiLevel":%d}`                                       | Set wifi icon<BR>`%s` = connecting; disconnect; pairing; nonetwork<BR>RssiLevel `%d` = 0 – 4                                                                                                                       | if using higher number draws other picture resources                                                     | 85   |
| `{"year":1970,"mon":1,"day":1,"hour":2,"min":0,"week":4}`<BR>`{"year":2021,"mon":10,"day":12,"hour":23,"min":22,"week":2}` | Set time and date    | Every entry must respect the range for its type, f.e. month cannot be higher than 12 | 82   |

### Thermostat screen control
Typical payloads
```json
{"ATCEnable":0,"ATCMode":0,"ATCExpect0":27}
{"ATCMode":1,"ATCExpect1":29}
{"ATCEnable":1}
```  
  
  |                                                              | Action and options<BR>`%b` = binary 0 or 1,`%d` = number, `%s` = string                                                                                                                                          | Notes                                                                                                    | Type |
|---------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------|------|
| `"ATCEnable":%b`                                                        | Thermostat screen toggle<BR>`0` = off<BR>`1` = off | Same payload is received when using the toggle on the screen | 84   |
| `"ATCMode":%b`                                                          | Thermostat screen mode icons<BR>`0` = manual<BR>`1` = auto | Same payload is received when using the toggle on the screen | 84   |
| `"ATCExpect0":%d`                                                       | Thermostat screen temperature for manual mode | Same payload is received when using the toggle on the screen | 84   |
| `"ATCExpect1":%d`                                                       | Thermostat screen temperature for auto mode | Same payload is received when using the toggle on the screen | 84   |
  
### Activate thermostat page
Original payload to activate thermostat screen
```json
{"HMI_ATCDevice":{"ctype":"device","id":"1001383218","outlet":0,"etype":"hot"}}
```
  
  |                                                              | Action and options<BR>`%b` = binary 0 or 1,`%d` = number, `%s` = string                                                                                                                                          | Notes                                                                                                    | Type |
|---------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------|------|
  | `"id":"%s"` | `%s` = identification string| 84   |
| `"outlet":%b` | `%b` = relay used to control thermostat<BR>&emsp;`0` = Relay1<BR>&emsp;`1` = Relay2 | Does not matter without original firmware| 84   |
| `"etype":"%s"` | `%s` = `hot` or `cold` | Draws different icon on the page | 84   |
  
On success Nextion returns `{"ctype":"device","id":"%s","resourcetype":"ATC"}`

### Set weather forecast display

Typical payload
```json
{"HMI_weather":7,"HMI_outdoorTemp":{"current":5,"range":"-3,8"}}
```
  
|                                                              | Action and options<BR>`%b` = binary 0 or 1,`%d` = number, `%s` = string                                                                                                                                          | Notes                                                                                                    | Type |
|---------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------|------|
|   `"HMI_weather":%d`      | 1   =   sunny   <BR>2   =   sun+cloud   <BR>7   =   cloud+blue cloud    <BR>11  =   cloud+fog <BR>15  =   cloud rain lightning    <BR>20  =   cloud+snowflake <BR>22  =   cloud + 3 snowflakes    <BR>22  =   cloud + 5 ice crystals  <BR>22  =   cloud + rain + snow <BR>30  =   red thermostat  <BR>31  =   blue thermostat <BR>32  =   wind    <BR>40  =   rainy cloud <BR> | Icons repeat under different numbers. When using a non-existing number Nextion returns `{"error":2}` | 81   |
|   `"HMI_outdoorTemp":%d`      | `%d` = Set outdoor temperature | 5 characters max, 5th character overwrites the unit on the display | 81   |
|   `"range":"%s"`      | `%s` = set temperature range using comma separated values, 5 characters max (example: `-3,8`)  | Range string can be anything but the display will still show °C/°F after each entry                         | 81   |
