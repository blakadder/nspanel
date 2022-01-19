# NSPanel Hacking
Sonoff NSPanel protocol and hacking information and Tasmota Berry driver.

NSPanel protocol [manual](https://blakadder.github.io/nspanel/)

Tasmota driver [`nspanel.be`](https://github.com/blakadder/nspanel/blob/main/nspanel.be)

[Installation and configuration for Tasmota](https://templates.blakadder.com/sonoff_NSPanel.html)

<a href="https://paypal.me/tasmotatemplates" target="_blank"><img src="https://img.shields.io/static/v1?logo=paypal&label=&message=donate&color=slategrey"></a>
<a href="https://ko-fi.com/S6S650JEK" target="_blank"><img src="https://img.shields.io/static/v1?logo=kofi&label=&message=buy%20me%20a%20coffee&color=FBAA19&labelColor=434B57"></a>

## Resources

* [sballano/nspanel_thermostat](sballano/nspanel_thermostat) - custom thermostat HMI
* [joBr99/nspanel-lovelance-ui](https://github.com/joBr99/nspanel-lovelance-ui) - custom HMI with HomeAssistant Lovelance UI Design
* [marcfager/nspanel-mf](https://github.com/marcfager/nspanel-mf) - custom HMI, includes home screen with weather data and clock, media player card, control of 8 lights (easily expandable), bootup screen and disable screen for alarm
* [TyzzyT/Sonoff-NSPanel-with-ESPHome](https://github.com/TyzzyT/Sonoff-NSPanel-with-ESPHome) - example ESPHome config

### UI
 - `eu-background.xcf` - Gimp format XCF file to help you layout your custom UI.  Set as the background image in Nextion Editor then use `vis <id>,0` to hide it.  It shows the section of the screen which is hidden by the bezel in the EU version.  The alignment marks take this in to account, so the centre intersection in the image is the centre of the screen on the real device.

## To-do List
- [ ] Home Assistant trigger discovery for scene widgets
- [ ] Home Assistant blueprint? for thermostat page 
