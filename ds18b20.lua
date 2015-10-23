--------------------------------------------------------------------------------
-- DS18B20 one wire module for NODEMCU
-- Yee-Ting Li
-- LICENSE: http://opensource.org/licenses/MIT
-- Yee-Ting Li <yee379@gmail.com>
-- based on: https://bigdanzblog.wordpress.com/2015/04/25/esp8266-and-ds18b20-transmitting-temperature-data/
--------------------------------------------------------------------------------

-- module name as parameter of require
local modname = ...
local M = {}
_G[modname] = M

-- local variables
local pin = 9           -- default pin dq is connected to
local sensors = {}      -- table of all sensors
local c_time = 1000000  -- conversion time required

-- Table module
local table = table
-- String module
local string = string
-- One wire module
local ow = ow
-- Timer module
local tmr = tmr

-- Limited to local environment
setmetatable( M, { __index = _G })
setfenv(1,M)


function setup(dq)
  
  if ( dq ~= nil ) then
    pin = dq
  end
  
  -- setup gpio pin for oneWire access
  ow.setup(pin)

  -- clear sensor table
  sensors = {}
  
  -- do search until addr is returned
  ow.reset_search(pin)
  repeat
    local addr = ow.search(pin)
    if( addr ~= nil ) then
      -- validate addr checksum
      local crc = ow.crc8(string.sub(addr,1,7))
      if (crc == addr:byte(8)) then
        -- ensure this is a DS18S20
        if ((addr:byte(1) == 0x10) or (addr:byte(1) == 0x28)) then
          local s = string.format("%02x%02x.%02x%02x.%02x%02x.%02x%02x",
              addr:byte(1),addr:byte(2),addr:byte(3),addr:byte(4), 
              addr:byte(5),addr:byte(6),addr:byte(7),addr:byte(8))
          print("found "..s)
          sensors[addr] = s
          end
      else
        print("error with addr CRC")
        end
      end
    tmr.wdclr()
  until(addr == nil) -- repeat
    
  -- if addr was never returned, abort
  if (table.getn(sensors) == nil) then error({msg='DS18B20 not found'}) end

  return sensors

end -- setup


function _read( addr )
  
  if ( ow.reset(pin) ~= 1 ) then error({msg='DS18B20 not present'}) end
  
  ow.select(pin, addr)        -- select DS18B20 for reading
  ow.write(pin,0xBE,1)        -- read scratchpad

  -- rx data from DS18B20
  local data = string.char(ow.read(pin))
  for i = 1, 8 do
      data = data .. string.char(ow.read(pin))
      end
  
  -- local d = string.format("data: %02X-%02X-%02X-%02X-%02X-%02X-%02X-%02X",
  --     data:byte(1),data:byte(2),data:byte(3), data:byte(4),
  --     data:byte(5),data:byte(6), data:byte(7),data:byte(8))
  -- print(d)

  -- validate data checksum
  crc = ow.crc8(string.sub(data,1,8))
  if (crc ~= data:byte(9)) then error({msg='DS18B20 data CRC failed'}) end

  -- compute and return temp
  local t = (data:byte(1) + data:byte(2) * 256) * 625
  local t1 = t / 10000
  local t2 = (t >= 0 and t % 10000) or (10000 - t % 10000)
  return t1..'.'..t2
  
  end -- function read

-- prepare the rom at addr for reading data, if addr is nil, then do a skip rom
function prepare( addr )

  if( addr == nil ) then skip = false end
  
  ow.reset(pin)               -- reset onewire interface
  
  if ( addr == nil ) then
    ow.skip(pin)              -- use skip rom to tell all devices to write
  else
    -- single use select
    ow.select(pin, addr)      -- select DS18B20
  end
  
  ow.write(pin, 0x44, 1)      -- store temp in scratchpad
  
  return true
  end -- prepare()

function read( addr )
  prepare( addr )
  tmr.delay(c_time)           -- wait for conversion of result
  return _read( addr )
  end -- read()

function readAll( skip )
  
  if( skip == nil ) then skip = false end
  
  if ( skip == true ) then
    prepare()
    tmr.delay(c_time)
    for k,s in pairs(sensors) do
      local t = _read( k )
      print(s..": "..t)
      end
  else
    for k,s in pairs(sensors) do
      local t = read( k, skip )
      print(s..": "..t)
      end
  end
  
  end -- function readAll


-- Return module table
return M