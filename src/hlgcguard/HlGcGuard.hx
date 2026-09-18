package hlgcguard;

#if hl
/**
	`hl.Gc.enable(bool)` is a single, process-global, non-reentrant, non-atomic flag with no
	getter (`gc_is_active` is a plain `static bool` in HashLink's own `src/gc.c`). Any
	disable-do-allocation-re-enable span must go through a counted, mutex-protected guard rather
	than calling `hl.Gc.enable` directly, or two such spans -- same thread nested, or concurrent
	on different threads -- will stomp on each other: whichever finishes first calls
	`hl.Gc.enable(true)` and re-enables the GC globally, even while another caller is still
	mid-allocation under the false assumption that it is still protected.

	This class exists specifically because `gc_is_active` is **process-global**: it is not
	enough for each library in a process to have its own independent depth counter (each did,
	historically -- see below). Two *different* counters don't know about each other, so the
	exact same race reappears one level up: library A's guard finishes first and re-enables the
	GC while library B's own (separately-tracked) guarded section is still executing. The only
	way to make this safe when several independently-versioned libraries can be concurrently
	active in one process is for all of them to share the *same* counter -- this class.

	Extracted from HaxeStackPlatform (see that project's CLAUDE.md, HASHLINK-SIGSEGV-AUDIT-S1 and
	HLC-BOOT-MIGRATION-GC-SIGSEGV-S1), which independently accumulated four structurally
	identical copies of this exact class (`sidewinder.util.HlGcGuard` in the SideWinder fork,
	`hx.injection.HlGcGuard` in the haxe-injection fork, a copy in the hxwell fork, and
	`core.HlGcGuard` in PlatformUI's own source) precisely because each library wanted to avoid a
	source dependency on the others. This package has zero dependencies of its own so every one
	of those libraries (and any application code) can depend on it directly instead of
	duplicating the class.
**/
class HlGcGuard {
	static var _mutex = new sys.thread.Mutex();
	static var _depth:Int = 0;

	public static function disable():Void {
		_mutex.acquire();
		_depth++;
		if (_depth == 1) hl.Gc.enable(false);
		_mutex.release();
	}

	public static function restore():Void {
		_mutex.acquire();
		if (_depth > 0) _depth--;
		if (_depth == 0) hl.Gc.enable(true);
		_mutex.release();
	}

	/** Test-only: current reentrancy depth. Never read for any production decision -- exists
		solely so a regression test can assert the counter itself behaves correctly (nested
		disable/restore only reaches 0, and only re-enables the GC, at the true outermost call)
		without needing to observe `hl.Gc`'s own internal flag, which has no getter. */
	public static function depthForTest():Int return _depth;
}
#end
