package = "luaworlds"
version = "1.0-0"
source = {
  url = "git+https://github.com/ChillerDragon/luaworlds.git"
}
description = {
  summary = "teeworlds",
  detailed = "",
  homepage = "https://github.com/ChillerDragon/luaworlds.git",
  license = "MIT"
}
dependencies = {
  "lua >= 5.1, < 5.3",
  "bitop-lua >= 1.0",
  "luaposix >= 36.2.1",
  "lua-getch >= 0.0-4"
}
build = {
  type = "builtin",
  modules = {
    [ "client" ] = "client.lua"
  }
}
