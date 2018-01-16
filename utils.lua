function round(num, numDecimalPlaces)
  return string.format("%."..(numDecimalPlaces or 0) .. "f", num)
end

function map_to_range(v, omin, omax, nmin, nmax)
  local r = v
  r = r - omin
  r = r * (nmax / omax)
  r = r + nmin
  return r
end
