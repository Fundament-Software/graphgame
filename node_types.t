local engine = require 'engine'
local feather = require 'feather'
local display = require 'display'

local function colored_circle(color)
  return display.graphnode {
    feather.circle {
      pos = bind pos,
      ext = bind [feather.vec2](radius, radius),
      outline = bind [f.Color]{[color]},
      fill = bind fill,
      innerRadius = bind radius * 0.9
    }
  }
end

local M = {
  average = {
    behavior = terra (inputs: engine.connslice)
      var sum = 0f
      for x in inputs do
        sum = sum + x
      end
      return sum / inputs.size
    end,
    appearance = colored_circle(0xffff2222)
  },
  max = {
    behavior = terra (inputs: engine.connslice)
      var max = 0f
      for x in inputs do
        if x > max then
          max = x
        end
      end
      return max
    end,
    appearance = colored_circle(0xff22ff22)
  },
  min = {
    behavior = terra (inputs: engine.connslice)
      var min = 1f
      for x in inputs do
        if x < min then
          min = x
        end
      end
      return min
    end,
    appearance = colored_circle(0xff2222ff)
    
  }

  
}

return M
