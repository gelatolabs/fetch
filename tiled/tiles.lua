return {
  version = "1.10",
  luaversion = "5.1",
  tiledversion = "1.11.2",
  name = "tiles",
  class = "",
  tilewidth = 16,
  tileheight = 16,
  spacing = 0,
  margin = 0,
  columns = 0,
  objectalignment = "unspecified",
  tilerendersize = "tile",
  fillmode = "stretch",
  tileoffset = {
    x = 0,
    y = 0
  },
  grid = {
    orientation = "orthogonal",
    width = 1,
    height = 1
  },
  properties = {},
  wangsets = {},
  tilecount = 6,
  tiles = {
    {
      id = 1,
      image = "../tiles/brown.png",
      width = 16,
      height = 16
    },
    {
      id = 3,
      image = "../tiles/brown.png",
      width = 16,
      height = 16
    },
    {
      id = 4,
      properties = {
        ["collides"] = true,
        ["height"] = 0.5
      },
      image = "../tiles/bush.png",
      width = 16,
      height = 16
    },
    {
      id = 5,
      image = "../tiles/dirt.png",
      width = 16,
      height = 16
    },
    {
      id = 14,
      properties = {
        ["collides"] = true,
        ["height"] = 0.5
      },
      image = "../tiles/rock.png",
      width = 16,
      height = 16
    },
    {
      id = 15,
      image = "../tiles/sand.png",
      width = 16,
      height = 16
    }
  }
}
