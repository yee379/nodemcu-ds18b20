# nodemcu-ds18b20
Dallas/Maxim DS18B20 Temperature Sensor Lua module for NodeMCU

##Usage

Copy this module on NodeMCU device using [luatool.py](https://github.com/4refr0nt/luatool), then connect your temperature sensor and run:


```Lua
t = require('ds18b20')
t = setup(2) -- pin number
t = readAll()
```