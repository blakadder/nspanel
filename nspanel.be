# Sonoff NSPanel Tasmota driver v0.47 | code by blakadder and s-hadinger
var mode = "NSPanel"
import persist
var devicename = tasmota.cmd("DeviceName")["DeviceName"]
persist.tempunit = tasmota.get_option(8) == 1 ? "F" : "C"
if persist.has("dim")  else   persist.dim = "1"  end
var loc = persist.has("loc") ? persist.loc : "North Pole"
var weather_interval = persist.has("weather_interval") ? persist.weather_interval : "60"
persist.save() # save persist file until serial bug fixed

  var widget = {
# 1 = toggle switch horizontal
# 2 = toggle switch double horizontal
# 3 = toggle switch triple horizontal
# 4 = toggle switch quad horizontal
# 6 = toggle switch vertical
# 7 = toggle switch double vertical
# 8 = toggle switch triple vertical
# 9 = toggle switch quad vertical
# 33 = RGB light strip
# 52 = CCT bulb
# 69 = RGB+CCT bulb
# leave empty brackets if you don't want a widget there
# ctype scene doesn't have an uiid
# index "name   ", "ctype", uiid | name max 8 characters, rest will be truncated)
  1: ["Index 1", "group", 1],
  2: ["Index 2", "group", 2],
  3: ["Index 3", "group", 3],
  4: ["Index 4", "group", 4],
  5: ["Index 5", "group", 33],
  6: ["Index 6", "device", 52],
  7: ["Index 7", "device", 69],
  8: ["Index 8", "scene"],
}

class NSPanel : Driver
  # set thermostat options
  static atc = { 
    "id":     "thermostat",
    "outlet": "0",  # outlet to use for trigger
    "etype":  "hot", # hot or cold
    "mirror":  false, # if true Tasmota will resend triggers as commands to keep the state on screen
  }

  static types = {
    '"switches":[{"outlet":':     0x87,
    "relation":   0x86,
    "ATC":      0x84,
    "index":    0x86,
    "params":     0x86,
    "wifiState":  0x85,
    "HMI_resources":0x86,
    "temp":     0x83,
    "year":     0x82,
    "weather":    0x81,
    "queryInfo":  0x80,
    "HMI_dimOpen":  0x87,
    "HMI_wallpaper":0x87,
  }
  static header = bytes('55AA') 

  var ser  # create serial port object
       
  # intialize the serial port, if unspecified Tx/Rx are GPIO 16/17
  def init(tx, rx)
    if !tx   tx = 16 end
    if !rx   rx = 17 end
    self.ser = serial(rx, tx, 115200, serial.SERIAL_8N1)
    tasmota.add_driver(self)
  end

  # determine type of message
  def findtype(value)
    import string
    for k:self.types.keys()
      if string.find(value, k) >= 0
        return self.types[k]
      end
    end
    return 0
  end

  def crc16(data, poly)
    if !poly  poly = 0xA001 end
    # CRC-16 MODBUS HASHING ALGORITHM
    var crc = 0xFFFF
    for i:0..size(data)-1
      crc = crc ^ data[i]
      for j:0..7
        if crc & 1
          crc = (crc >> 1) ^ poly
        else
          crc = crc >> 1
        end
      end
    end
    return crc
  end

  # encode using NSPanel protocol
  # input: payload:json string
  def encode(payload)
    var b = bytes()
    var nsp_type = self.findtype(payload)
    b += self.header
    b.add(nsp_type)       # add a single byte
    b.add(size(payload), 2)   # add size as 2 bytes, little endian
    b += bytes().fromstring(payload)
    var msg_crc = self.crc16(b)
    b.add(msg_crc, 2)       # crc 2 bytes, little endian
    return b
  end

  def split_55(b)
    var ret = []
    var s = size(b)   
    var i = s-2   # start from last-1
    while i > 0
      if b[i] == 0x55 && b[i+1] == 0xAA           
        ret.push(b[i..s-1]) # push last msg to list
        b = b[(0..i-1)]   # write the rest back to b
      end
      i -= 1
    end
    ret.push(b)
    return ret
  end

  # send a string payload (needs to be a valid json string)
  def send(payload)
    print("NSP: Sent =", payload)
    var payload_bin = self.encode(payload)
    self.ser.write(payload_bin)
    # print("NSP: Sent =", payload)
    log("NSP: NSPanel payload sent = " + str(payload_bin), 3)
  end

  # send a nextion payload
  def encodenx(payload)
    var b = bytes().fromstring(payload)
    b += bytes('FFFFFF')
    return b
  end

  def sendnx(payload)
    var payload_bin = self.encodenx(payload)
    self.ser.write(payload_bin)
    # print("NSP: Sent =", payload_bin)
    log("NSP: Nextion command sent = " + str(payload_bin), 3)
  end

  # sets time and date according to Tasmota local time
  def set_clock()
    var now = tasmota.rtc()
    var time_raw = now['local']
    var nsp_time = tasmota.time_dump(time_raw)
    var time_payload = '{"year":' + str(nsp_time['year']) + ',"mon":' + str(nsp_time['month']) + ',"day":' + str(nsp_time['day']) + ',"hour":' + str(nsp_time['hour']) + ',"min":' + str(nsp_time['min']) + ',"week":' + str(nsp_time['weekday']) + '}'
    log('NSP: Time and date synced with ' + time_payload, 3)
    self.send(time_payload)
  end

  # sync main screen power bars with tasmota POWER status
  def set_power()
    var ps = tasmota.get_power()
    for i:0..1
      if ps[i] == true
        ps[i] = "on"
      else 
        ps[i] = "off"
      end
    end
    var json_payload = '{\"switches\":[{\"outlet\":0,\"switch\":\"' + ps[0] + '\"},{\"outlet\":1,\"switch\":\"' + ps[1] +  '\"}]}'
    log('NSP: Switch state updated with ' + json_payload)
    self.send(json_payload)
  end  

  # draw widgets
  def draw()
    var i = 1
    while i < 9
      if size(widget[i]) > 1
        var wdgt = ""
        if widget[i][1] == "scene"
          wdgt = '{"HMI_resources":[{"index":' + str(i) + ',"ctype":"' + widget[i][1] + '","id":"' + str(i) + '"}]}'
        else
          wdgt = '{"HMI_resources":[{"index":' + str(i) + ',"ctype":"' + widget[i][1] + '","id":"' + str(i) + '","uiid":' + str(widget[i][2]) + '}]}'
        end
        var name = '{"relation":[{"ctype":"' + widget[i][1] + '","id":"' + str(i) + '","name":"' + widget[i][0][0..7] + '"}]}'
        self.send(wdgt)
        self.send(name)
      else
      self.send('{"index":' + str(i) + ',"type":"delete"}')
      end
      i += 1
    end
  end

# update weather forecast, since the provider doesn't support range I winged it with FeelsLike temperature
  def set_weather()
    import json
      var weather_icon = {
        "": 30,      # Unknown             
        "113": 1,    # Sunny      
        "116": 2,    # PartlyCloudy   
        "119": 2,    # Cloudy             
        "122": 7,    # VeryCloudy           
        "143": 11,   # Fog                 
        "176": 40,   # LightShowers     
        "179": 24,   # LightSleetShowers 
        "182": 24,   # LightSleet        
        "185": 24,   # LightSleet        
        "200": 42,   # ThunderyShowers  
        "227": 20,   # LightSnow  
        "230": 22,   # HeavySnow        
        "248": 11,   # Fog                 
        "260": 11,   # Fog                 
        "263": 40,   # LightShowers     
        "266": 40,   # LightRain      
        "281": 24,   # LightSleet        
        "284": 24,   # LightSleet        
        "293": 40,   # LightRain      
        "296": 40,   # LightRain      
        "299": 18,   # HeavyShowers      
        "302": 18,   # HeavyRain        
        "305": 18,   # HeavyShowers      
        "308": 18,   # HeavyRain        
        "311": 24,   # LightSleet        
        "314": 24,   # LightSleet        
        "317": 24,   # LightSleet        
        "320": 20,   # LightSnow  
        "323": 22,   # LightSnowShowers 
        "326": 22,   # LightSnowShowers 
        "329": 22,   # HeavySnow        
        "332": 22,   # HeavySnow        
        "335": 29,   # HeavySnowShowers   
        "338": 22,   # HeavySnow        
        "350": 24,   # LightSleet        
        "353": 24,   # LightSleet        
        "356": 18,   # HeavyShowers      
        "359": 18,   # HeavyRain        
        "362": 24,   # LightSleetShowers 
        "365": 24,   # LightSleetShowers 
        "368": 22,   # LightSnowShowers 
        "371": 29,   # HeavySnowShowers   
        "374": 24,   # LightSleetShowers 
        "377": 24,   # LightSleet        
        "386": 42,   # ThunderyShowers  
        "389": 42,   # ThunderyHeavyRain  
        "392": 42,   # ThunderySnowShowers
        "395": 29,   # HeavySnowShowers   
      }   
    var temp
    var tmin
    var tmax
    var cl = webclient()
    var url = "http://wttr.in/" + loc + '?format=j2'
    cl.set_useragent("curl/7.72.0")
    cl.set_follow_redirects(true)
    cl.begin(url)
    if cl.GET() == "200" || cl.GET() == 200
      var b = json.load(cl.get_string())

      if persist.tempunit == "F"
        temp = b['current_condition'][0]['temp_F']
        tmin = b['weather'][0]['mintempF']
        tmax = b['weather'][0]['maxtempF']
      else
        temp = b['current_condition'][0]['temp_C']
        tmin = b['weather'][0]['mintempC']
        tmax = b['weather'][0]['maxtempC']
      end

      var wttr = '{"HMI_weather":' + str(weather_icon[b['current_condition'][0]['weatherCode']]) + ',"HMI_outdoorTemp":{"current":' + temp + ',"range":" ' + tmin + ', ' + tmax + '"}}'
      self.send(wttr)
      log('NSP: Weather update for location: ' + b['nearest_area'][0]['areaName'][0]['value'] + ", "+ b['nearest_area'][0]['country'][0]['value'])
    else
      log('NSP: Weather update failed!', 3)
    end
  end

  # commands to populate an empty screen, should be executed when screen initializes
  def screeninit()
    # self.send('{"queryInfo":"version"}')
    self.send('{"HMI_ATCDevice":{"ctype":"device","id":"' + self.atc['id'] + '","outlet":' + self.atc['outlet'] + ',"etype":"' + self.atc['etype'] + '"}')
    self.send('{"relation":[{"ctype":"device","id":"panel","name":"' + devicename + '","online":true}]}')
    self.send('{"HMI_dimOpen":' + persist.dim + '}')
    self.set_clock()
    self.set_power()
    self.set_weather()
    self.draw()
    tasmota.cmd("State")
    tasmota.cmd("TelePeriod")
  end

  # read serial port and decode messages according to protocol used
  def every_100ms()
    if self.ser.available() > 0
    var msg = self.ser.read()   # read bytes from serial as bytes
    import string
      if size(msg) > 0
        print("NSP: Received Raw =", msg)
        if msg[0..1] == self.header
          mode = "NSPanel"
          var lst = self.split_55(msg)
          for i:0..size(lst)-1
            msg = lst[i]
              if self.atc['mirror'] == true
                if msg[2] == 0x84 self.ser.write(msg)   # resend messages with type 0x84 for thermostat page
                end
              end
            var j = size(msg) - 1
            while msg[j] != 0x7D
              msg = msg[0..-1]
              j -= 1
            end        
            msg = msg[5..j]
              if size(msg) > 2
                if msg == bytes('7B226572726F72223A307D') # don't publish {"error":0}
                else 
                var jm = string.format("{\"NSPanel\":%s}",msg.asstring())
                tasmota.publish_result(jm, "RESULT")
                end
              end
          end
        elif msg == bytes('000000FFFFFF88FFFFFF')
          log("NSP: Screen Initialized")   # print the message as string
          self.screeninit()
        else
          var jm = string.format("{\"NSPanel\":{\"Nextion\":\"%s\"}}",str(msg[0..-4]))
          tasmota.publish_result(jm, "RESULT")        end       
      end
    end
  end
end      

nsp=NSPanel()

tasmota.add_rule("power1#state", /-> nsp.set_power())
tasmota.add_rule("power2#state", /-> nsp.set_power())

# add NSPSend command to Tasmota
def nspsend(cmd, idx, payload, payload_json)
  # NSPSend2 sends Nextion commands
  if idx == 2
  var command = nsp.sendnx(payload)
  tasmota.resp_cmnd_done()
  # NSPSend sends NSPanel commands, requires valid payload
  else
  import json
  var command = nsp.send(json.dump(payload_json))
  tasmota.resp_cmnd_done()
  end
end

tasmota.add_cmd('NSPSend', nspsend)

# add NSPMode command to Tasmota
def modeselect(NSPMode, idx, payload)
  if payload == "1"
    nsp.sendnx('DRAKJHSUYDGBNCJHGJKSHBDN')
    tasmota.resp_cmnd_done()
    mode = "Nextion"
  elif payload == "0"
    nsp.sendnx('recmod=1')
    nsp.sendnx('recmod=1')
    mode = "NSPanel"
    tasmota.resp_cmnd_done()
  else
  tasmota.resp_cmnd_str('{"Mode":"' + mode + '"}')
  end
end

tasmota.add_cmd('NSPMode', modeselect)

# add NSPDim command to Tasmota
def dimopen(NSPDim, idx, payload)
  if payload == "0" || payload == "1"
    persist.dim = payload
    nsp.send('{"HMI_dimOpen":' + payload + '}')
    tasmota.resp_cmnd_done()
  else
    payload = str(persist.dim)
  end
  import string
  var jm = string.format("{\"NSPanel\":{\"Energy-saving\":%s}}",payload)
  tasmota.publish_result(jm, "RESULT")
end

tasmota.add_cmd('NSPDim', dimopen)

# add NSPLocation command to Tasmota
def setloc(NSPLocation, idx, payload)
  if size(payload) > 1
    persist.loc = payload
    tasmota.resp_cmnd_done()
    persist.save()
    loc = persist.loc
    nsp.set_weather()
  else
    payload = loc
  end
  import string
  var jm = string.format("{\"NSPanel\":{\"Location\":\"%s\"}}",payload)
  tasmota.publish_result(jm, "RESULT")
end

tasmota.add_cmd('NSPLocation', setloc)

# add NSPWInterval command to Tasmota
def setWInterval(NSPLocation, idx, p)
  var payload = int(p)
  if payload > 0
    persist.weather_interval = payload
    tasmota.resp_cmnd_done()
    persist.save()
    weather_interval = persist.weather_interval
    nsp.set_weather()
  else
    payload = weather_interval
  end
  import string
  var jm = string.format("{\"NSPanel\":{\"Weather Interval\":\"%d\"}}",payload)
  tasmota.publish_result(jm, "RESULT")
end

tasmota.add_cmd('NSPWInterval', setWInterval)

# set displayed indoor temperature to value:int
def set_temp(value)
  var temp_payload = '{"temperature":' + str(value) + ',"tempUnit":"' + persist.tempunit + '"}'
  log('NSP: Indoor temperature set with ' + temp_payload, 3)
  nsp.send(temp_payload)
end

tasmota.add_rule("Tele#ANALOG#Temperature1", set_temp) # rule to run set_temp on teleperiod

# set wifi icon status

def set_wifi(value)
  var rssi = (value-1)/20
  rssi = '{"wifiState":"connected","rssiLevel":' + str(rssi) + '}'
  log('NSP: Wi-Fi icon set with ' + rssi, 3)
  nsp.send(rssi)
end

def set_disconnect()
  nsp.send('{"wifiState":"nonetwork","rssiLevel":0}')
end

def sync_weather() # set weather every 60 minutes
  var interval = persist.has("weather_interval") ? int(persist.weather_interval) : 60
  nsp.set_weather()
  print("Weather forecast synced")
  tasmota.set_timer(interval*60*1000, sync_weather)
end

tasmota.cmd("Rule3 1") # needed until Berry bug fixed
tasmota.cmd("State")
tasmota.add_rule("Time#Minute", /-> nsp.set_clock()) # set rule to update clock every minute
tasmota.add_rule("Tele#Wifi#RSSI", set_wifi) # set rule to update wifi icon
tasmota.add_rule("wifi#disconnected", set_disconnect) # set rule to change wifi icon on disconnect
tasmota.add_rule("mqtt#disconnected", set_disconnect) # set rule to change wifi icon on disconnect
tasmota.add_rule("system#boot", /-> nsp.screeninit()) 
tasmota.add_rule("time#initialized", sync_weather)

tasmota.cmd("TelePeriod")
