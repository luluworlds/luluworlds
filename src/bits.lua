-- this code is from the bitop-lua library
-- credits go to https://github.com/NicholasMindieta
--
-- https://github.com/luluworlds/bitop-lua/blob/8146f0b323f55f72eacbb2a8310922d50ae75ddf/src/bitop/funcs.lua#L5-L54
-- https://github.com/RobloxEadmond/bitop-lua/blob/8146f0b323f55f72eacbb2a8310922d50ae75ddf/src/bitop/funcs.lua#L5-L54

local MOD = 2^32

local function memoize(f)
  local mt = {}
  local t = setmetatable({}, mt)
  function mt:__index(k)
    local v = f(k)
    t[k] = v
    return v
  end
  return t
end

local function make_bitop_uncached(t, m)
  local function bitop(a, b)
    local res,p = 0,1
    while a ~= 0 and b ~= 0 do
      local am, bm = a%m, b%m
      res = res + t[am][bm]*p
      a = (a - am) / m
      b = (b - bm) / m
      p = p*m
    end
    res = res + (a+b) * p
    return res
  end
  return bitop
end

local function make_bitop(t)
  local op1 = make_bitop_uncached(t, 2^1)
  local op2 = memoize(function(a)
    return memoize(function(b)
      return op1(a, b)
    end)
  end)
  return make_bitop_uncached(op2, 2^(t.n or 1))
end

local function bit_bxor(a, b)
    local bxor = make_bitop {[0]={[0]=0,[1]=1},[1]={[0]=1,[1]=0}, n=4}
    return bxor(a, b)
end

local function bit32_not(n)
    return (-1 - n) % MOD
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


