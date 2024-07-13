local bit = require 'bitop.funcs'
local bit32 = require 'bitop.funcs'.bit32

local function bit_bxor(a, b)
    return bit.bxor(a, b)
end

local function bit32_not(n)
    return bit32.bnot(n)
end

-- https://stackoverflow.com/a/25594410

local function bit_or(a,b)
    local p,c=1,0
    while a+b>0 do
        local ra,rb=a%2,b%2
        if ra+rb>0 then c=c+p end
        a,b,p=(a-ra)/2,(b-rb)/2,p*2
    end
    return c
end

local function bit_and(a,b)
    local p,c=1,0
    while a>0 and b>0 do
        local ra,rb=a%2,b%2
        if ra+rb>1 then c=c+p end
        a,b,p=(a-ra)/2,(b-rb)/2,p*2
    end
    return c
end

-- https://stackoverflow.com/a/6026257
local function lshift(x, by)
  return x * 2 ^ by
end

local function rshift(x, by)
  return math.floor(x / 2 ^ by)
end

return { bit_or = bit_or, bit_not = bit32_not, bit_and = bit_and, lshift = lshift, rshift = rshift, bit_xor = bit_bxor }


