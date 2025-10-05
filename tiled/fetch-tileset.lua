return {
  version = "1.10",
  luaversion = "5.1",
  tiledversion = "1.11.2",
  name = "fetch-tileset",
  class = "",
  tilewidth = 16,
  tileheight = 16,
  spacing = 0,
  margin = 0,
  columns = 20,
  image = "../tiles/fetch-tileset.png",
  imagewidth = 320,
  imageheight = 320,
  objectalignment = "unspecified",
  tilerendersize = "tile",
  fillmode = "stretch",
  tileoffset = {
    x = 0,
    y = 0
  },
  grid = {
    orientation = "orthogonal",
    width = 16,
    height = 16
  },
  properties = {},
  wangsets = {},
  tilecount = 400,
  tiles = {
    {
      id = 0,
      properties = {
        ["collides"] = true,
        ["is_water"] = true
      }
    },
    {
      id = 100,
      type = "ground::grass"
    },
    {
      id = 102,
      type = "ground::dirt"
    },
    {
      id = 104,
      type = "ground::sand"
    },
    {
      id = 106,
      type = "ground::path"
    },
    {
      id = 108,
      type = "water",
      properties = {
        ["collides"] = true,
        ["height"] = -0.1,
        ["is_water"] = true
      }
    },
    {
      id = 110,
      type = "ground::clay"
    },
    {
      id = 140,
      type = "wall",
      properties = {
        ["collides"] = true,
        ["height"] = 1
      }
    },
    {
      id = 141,
      type = "wall",
      properties = {
        ["collides"] = true,
        ["height"] = 1
      }
    },
    {
      id = 142,
      type = "wall",
      properties = {
        ["collides"] = true,
        ["height"] = 1
      }
    },
    {
      id = 160,
      type = "rock",
      properties = {
        ["collides"] = true,
        ["height"] = 0.5
      }
    },
    {
      id = 161,
      type = "rock",
      properties = {
        ["collides"] = true,
        ["height"] = 0.5
      }
    },
    {
      id = 162,
      type = "rock"
    },
    {
      id = 163,
      type = "rock",
      properties = {
        ["collides"] = true,
        ["height"] = 0.5
      }
    },
    {
      id = 164,
      type = "rock",
      properties = {
        ["collides"] = true,
        ["height"] = 0.7
      }
    },
    {
      id = 165,
      type = "rock",
      properties = {
        ["collides"] = true,
        ["height"] = 0.5
      }
    },
    {
      id = 180,
      properties = {
        ["collides"] = true,
        ["height"] = 1
      }
    },
    {
      id = 183,
      properties = {
        ["collides"] = true,
        ["height"] = 0.5
      }
    }
  }
}
