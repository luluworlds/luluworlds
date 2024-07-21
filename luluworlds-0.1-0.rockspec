package = "luluworlds"
rockspec_format = "3.0"
version = "0.1-0"
source = {
  url = "git+https://github.com/luluworlds/luluworlds.git",
  tag = "0.0-1"
}
description = {
  summary = "teeworlds network protocol library (client only for now)",
  detailed = "",
  license = "Zlib",
  homepage = "https://github.com/ChillerDragon/luluworlds.git",
  issues_url = "https://github.com/luluworlds/luluworlds/issues",
  maintainer = "ChillerDragon <chillerdragon@gmail.com>",
  labels = { "teeworlds", "ddnet", "ddracenetwork", "game", "client", "server", "protocol", "networking", "0.7" }
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
