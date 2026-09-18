# hl-gc-guard

A single shared, mutex-protected, reentrant guard around HashLink's process-global
`hl.Gc.enable(bool)` flag.

## Why

`hl.Gc.enable(bool)` sets one process-global native flag (`gc_is_active` in HashLink's
`src/gc.c`) with no reentrancy and no getter. Code that does
`hl.Gc.enable(false); riskyAllocation(); hl.Gc.enable(true);` around a hot allocation is only
safe if **every** such span in the process shares the same reentrancy counter -- otherwise two
independent guards (even in different libraries) will re-enable the GC out from under each
other the moment they nest or run concurrently on different threads.

## Usage

```haxe
hlgcguard.HlGcGuard.disable();
try {
    riskyAllocation();
    hlgcguard.HlGcGuard.restore();
} catch (e:Dynamic) {
    hlgcguard.HlGcGuard.restore(); // Haxe has no `finally` -- always restore before rethrowing
    throw e;
}
```

Every library sharing a process (application code, SideWinder, haxe-injection, hxwell, etc.)
should call into this exact class rather than maintaining its own independent counter.
