package = "luluworlds"
version = "0.1-0"
source = {
  url = "git+https://github.com/ChillerDragon/luluworlds.git"
}
description = {
  summary = "teeworlds",
  detailed = "",
  homepage = "https://github.com/ChillerDragon/luluworlds.git",
  license = "MIT"
}
dependencies = {
  "lua >= 5.1, < 5.5",
  "bitop-lua >= 1.0",
  "luaposix >= 36.2.1",
  "lua-getch >= 0.0-4",
  "luluman >= 2.0-0",
  "luasocket"
}
build = {
  type = "builtin",
  modules = {
    TeeworldsClient = "src/teeworlds_client.lua",
    connection = "src/connection.lua",
    Unpacker = "src/unpacker.lua"
  }
}
