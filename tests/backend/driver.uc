'use strict';
let m = require('luci.trusttunnel');
let api = m['luci.trusttunnel'];
let name = ARGV[0];
let args = length(ARGV[1]) ? json(ARGV[1]) : {};
let out = api[name].call({ args: args });
// checked_at is a "now" timestamp: normalize it so the golden comparison
// is not time-dependent. null stays null (no fetch happened).
if (type(out) == 'object' && 'checked_at' in out && out.checked_at != null)
	out.checked_at = 0;
print(sprintf('%J', out));
