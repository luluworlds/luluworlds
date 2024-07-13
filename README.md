# luaworlds

A quickly hacked together teeworlds 0.7 client in lua with a bit of C sprinkled in.


This project kinda works on my machine. But it is super messy and incomplete.

```
sudo apt-get install luarocks
cd huffman
luarocks make

luarocks install bitop-lua
luarocks install luaposix
```

```
lua client.lua "connect localhost:8303"
```


## tests

```
lua spec/*.lua
```

