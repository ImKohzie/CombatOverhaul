#!/usr/bin/env python3
"""Run BalanceSim outside Roblox with the Luau CLI (dev tool).

Usage: python3 tools/run_balance.py <path-to-luau-binary>
Builds a temporary Luau script that shims the few Roblox globals
BalanceConfig uses, then prints the TTK matrix.
"""
import os, re, subprocess, sys, tempfile

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
luau = sys.argv[1] if len(sys.argv) > 1 else "luau"

def load(rel):
    with open(os.path.join(root, rel)) as f:
        return f.read()

balance = load("src/shared/Config/BalanceConfig.luau")
balance = re.sub(r"local Types = require\([^)]*\)\n", "", balance)
balance = balance.replace("--!strict", "--!nonstrict")
sim = load("src/shared/BalanceSim.luau").replace("--!strict", "--!nonstrict")

ids = ["Bastion", "Voltline", "OldGuard", "Sovereign", "Rampage", "NightwingGoblin",
       "Argent", "Graven", "Rime", "Swarm", "Echo", "Umbra"]
script = f"""
Vector3 = {{ new = function(x, y, z) return {{ X = x, Y = y, Z = z }} end }}
local BalanceConfig = (function()
{balance}
end)()
local BalanceSim = (function()
{sim}
end)()
BalanceSim.run(BalanceConfig, {{ {", ".join('"%s"' % i for i in ids)} }}, print)
"""
# strip type-only syntax the plain VM would reject is unnecessary: Luau CLI understands types
with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as f:
    f.write(script)
    path = f.name
sys.exit(subprocess.call([luau, path]))
