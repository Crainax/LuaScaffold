package.path='src/?.lua;'..package.path
local Refs=require 'scaffold.handle_refs'
local native_count,fail_ref,fail_unref=0,false,false
local ledger=Refs.new({
    handle_ref=function()assert(not fail_ref,'ref failure');native_count=native_count+1 end,
    handle_unref=function()assert(not fail_unref,'unref failure');native_count=native_count-1 end,
})
local function balanced(n)
    local s=ledger.snapshot()
    assert(s.active==n and native_count==n and s.refs-s.unrefs==n)
end
-- Independent backend counter, repeated handle reuse, and two owners of one handle.
for i=1,1000 do
    ledger.ref('unit',42);ledger.ref('unit',42);ledger.ref('effect',43)
    balanced(3)
    ledger.unref('effect',43);ledger.unref('unit',42);balanced(1)
    ledger.unref('unit',42);balanced(0)
end
assert(ledger.snapshot().refs==3000 and ledger.snapshot().kinds.unit.peak==2)
local detached=ledger.snapshot();detached.kinds.unit.active=99;balanced(0)
assert(not pcall(ledger.unref,'unit',42));balanced(0)
assert(ledger.snapshot().errors==1)
fail_ref=true;assert(not pcall(ledger.ref,'unit',42));balanced(0);fail_ref=false
ledger.ref('unit',42);fail_unref=true
assert(not pcall(ledger.unref,'unit',42));balanced(1) -- failure must not falsely report zero
fail_unref=false;ledger.unref('unit',42);balanced(0)
assert(ledger.snapshot().errors==3)
assert(not pcall(require('scaffold.context').local_call,function()ledger.ref('unit',42)end))
balanced(0)
-- Missing cleanup is observable; snapshot does not reset/hide the outstanding ref.
ledger.ref('trigger',44);assert(ledger.snapshot().active==1);balanced(1)
ledger.unref('trigger',44);balanced(0)
print('HANDLE REFS PASS repeated reuse, multiple owners, detached snapshots, missing/double release, native failures and local-domain rejection')
