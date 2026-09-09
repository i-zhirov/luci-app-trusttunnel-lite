'use strict';
let m = require('luci.trusttunnel');
let api = m['luci.trusttunnel'];
let name = ARGV[0];
let args = length(ARGV[1]) ? json(ARGV[1]) : {};
let out = api[name].call({ args: args });
print(sprintf('%J', out));
