BEGIN {
  tohex["A"] = 10;
  tohex["B"] = 11;
  tohex["C"] = 12;
  tohex["D"] = 13;
  tohex["E"] = 14;
  tohex["F"] = 15;
  tohex["a"] = 10;
  tohex["b"] = 11;
  tohex["c"] = 12;
  tohex["d"] = 13;
  tohex["e"] = 14;
  tohex["f"] = 15;
}

function decode_hex(str) {
  n = 0;
  len = length(str);
  for (i = 1; i <= len; i++)
    {
      c = substr (str, i, 1);
      if (c >= "0" && c <= "9")
	n = n * 16 + (c - "0");
      else
	n = n * 16 + tohex[c];
    }
  return n;
}

function decode_big5(big5) {
  b0 = int(big5 / 256);
  b1 = big5 % 256;
# (0xFF - 0xA1 + 0x7F - 0x40) = 157
# (0xA1 - (0x7F - 0x40)) = 98
# (0xC9 - 0xA1) * (0xFF - 0xA1 + 0x7F - 0x40) = 6280
  if (b1 < 127)
    idx = (b0 - 161) * 157 + (b1 - 64);
  else
    idx = (b0 - 161) * 157 + (b1 - 98);
  if (b0 >= 201)
    idx -= 6280;
  b0 = int(idx / 94) + 33;
  b1 = (idx % 94) + 33;
  return (b0 * 256 + b1)
}

{
  big5 = decode_hex($1);
  code = decode_big5(big5);
  printf "0x%04X %s\n", code, $2;
}

    
