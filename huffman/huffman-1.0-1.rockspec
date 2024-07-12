package = "huffman"
version = "1.0-1"
source = {
   url = "." -- not online yet!
}
build = {
   type = "builtin",
   modules = {
      huffman = "huffman.c"
   }
}
