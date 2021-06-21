local alloc = require 'std.alloc'

local M = {}


struct M.connslice {
  vals: &float
  indices: &uint
  size: uint
                   }

function M.connslice.metamethods.__for(body)
  return quote
    var _self = self
    for i = 0, _self.size do
      [body(`_self.vals[_self.indices[i]])]
    end
  end
end

function M.synthesize(options)
  assert(options.node_types, "must provide a list of game node_types")
  assert(type(options.node_types) == "table", "the game node_types list must be a table")
  assert(#options.node_types > 0, "must provide at least one game mechanic in the node_types table")
  assert(options.node_value_alpha, "must provide an alpha value for the node value EMA")
  assert(type(options.node_value_alpha) == "number" and options.node_value_alpha >= 0 and options.node_value_alpha <= 1, "the node value alpha must be a number between zero and one.")

  local n_node_types = #options.node_types

  local struct edgedata {
    conns: tuple(uint, uint)
    dir: uint8
                        }

  local terra normalize_edge_tuple(a: tuple(uint, uint)): tuple(uint, uint)
    if a._0 < a._1 then
      return {a._0, a._1}
    else
      return {a._1, a._0}
    end
  end
  
  local struct gamestate {
    kind_counts: &uint
    edgecount: uint
    edges: &edgedata
    connslices: &M.connslice
    node_states: &float
    node_output: &float
    node_count: uint
                         }

  -- level data structure:
  -- The number of types of node_types is fixed at compile time, and so not stored per level
  -- there is a list of how many nodes with each type of node_types there are.
  -- the total number of nodes isn't stored, because it is derivable from the previous list
  -- This is followed by a sequence of number of inputs to a given node, then a number of the IDs of each input.
  --
  local terra add_edge(edge: tuple(uint, uint), edges: &edgedata, edgecount: uint): uint
    var dir = edge._0 > edge._1
    if dir then
      for i = 0, edgecount do
        if edges[i].conns._0 == edge._1 && edges[i].conns._1 == edge._0 then
          edges[i].dir = edges[i].dir & 2
          return edgecount
        end
      end
      edges[edgecount] = {conns = normalize_edge_tuple(edge), dir = 2}
      return edgecount + 1
    else
      edges[edgecount] = {conns = normalize_edge_tuple(edge), dir = 1}
      return edgecount + 1
    end
  end
      

  terra gamestate:init(level: &uint)
    self.kind_counts = level
    var total_nodes = 0
    for i = 0, n_mechs do
      total_nodes = total_nodes + self.kind_counts[i]
    end
    self.node_states = alloc.alloc(float, total_nodes)
    self.node_output = alloc.alloc(float, total_nodes)
    self.connslices = alloc.alloc(M.connslice, total_nodes)
    self.edges = alloc.alloc(edgedata, total_nodes * (total_nodes - 1) / 2) --todo: make a smart re-sizing array.
    self.edgecount = 0
    self.node_count = total_nodes
    var links = level + n_node_types
    for i = 0, total_nodes do
      connslices[i] = { vals = self.node_states, indices = links + 1, size = @links }
      for j = 0, @links do
        var src, dst = links[1 + j], i
        --this nested scan hits quadratic performance, but n should be small enough, and I don't have a hashmap, so whatever.
        self.edgecount = add_edge({src, dst}, self.edges, self.edgecount)
      end
      links = links + @links + 1
    end
  end

  terra gamestate:update()
    var node_offs = 0
    escape
      for i = 1, n_mechs do
        emit quote
          for j = 0, self.kind_counts[i - 1] do
            self.node_output[node_offs + j] = [options.node_types.behavior](self.connslices[node_offs + j])
          end
          node_offs = node_offs + self.kind_counts[i - 1]
             end
      end
    end

    for i = 0, self.node_count do
      node_states[i] = node_states[i] * (1 - [float]([options.node_value_alpha])) + node_output[i] * [float]([options.node_value_alpha])
    end
  end

  terra gamestate:destroy()
    alloc.free(self.node_states)
    alloc.free(self.node_output)
    alloc.free(self.edges)
  end

  return gamestate
end
      
return M
