local f = require 'feather'
local cond = require 'std.cond'
local Messages = require 'feather.messages'

local M = {}

M.graphnode = f.template {
  pos = f.required,
  radius = f.required,
  fill = `[f.Color]{0}
}


function M.synthesize(options)
  assert(options.node_types, "must provide a list of node types")
  assert(type(options.node_types) == "table", "the node types list must be a table")
  assert(#options.node_types > 0, "must provide at least one node type in the node types table")

  local alternatives = f.If (bind kind == 1) {
    options.node_types[1].appearance {
      pos = bind pos,
      radius = bind radius,
      fill = bind fill
                                    }
                                           }
  for i = 2, #options.node_types do
    alternatives = alternatives :ElseIf (bind kind == [i]) {
      options.node_types[i].appearance {
        pos = bind pos,
        radius = bind radius,
        fill = bind fill
                                      }
                                                           }
  end
  
  local node = f.template {
    pos = f.required,
    radius = f.required,
    kind = f.required,
    fill = f.required,
    onleftclick = f.requiredevent(),
    onrightclick = f.requiredevent()
  } {
    alternatives,
    f.mousearea {
      pos = bind pos,
      ext = bind f.vec3(radius, radius, 0),
      mousedown = bindevent (me: Messages.MouseEvent)
        if me:Button() == Messages.MouseButton.L then
          onleftclick()
        elseif me:Button() == Messages.MouseButton.R then
          onrightclick()
        end
      end
    }
  }

  local link = f.template {
    points = f.required,
    direction = f.required
  } {
    f.If (bind direction == 3) {
      f.line {
        points = bind points,
        color = bind f.Color {0xff008800}
      }
    } :Else {
      f.let {
        midpoint = bind (points._0 + points._1) / 2
      } {
        f.line {
          points = bind {points._0, midpoint},
          color = bind f.Color {cond(direction == 1, 0xff008800, 0xff880000)}
        }
        f.line {
          points = bind {midpoint, points._1},
          color = bind f.Color {cond(direction == 2, 0xff880000, 0xff008800)}
        }
      }
    }
  }


  return {
    node = node,
    link = link
  }
end

return M
