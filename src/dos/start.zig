const root = @import("root");
const std = @import("std");

const dpmi = @import("dpmi.zig");
const FarPtr = @import("far_ptr.zig").FarPtr;
const safe = @import("safe.zig");
const system = @import("system.zig");

comptime {
    if (@hasDecl(root, "main")) @export(_start, .{ .name = "_start" });
}

// Initial stack pointer set by the linker script.
extern const _stack_ptr: opaque {};

fn _start() callconv(.Naked) noreturn {
    // Use the data segment to initialize the extended and stack segments.
    asm volatile (
        \\ mov %%ds, %%dx
        \\ mov %%dx, %%es
        \\ mov %%dx, %%ss
        :
        : [_] "{esp}" (&_stack_ptr)
        : "dx", "ds", "es", "ss"
    );

    // Initialize transfer buffer from stub info.
    const stub_info = dpmi.Segment.fromRegister("fs").farPtr().
        reader().readStruct(StubInfo) catch unreachable;
    system.transfer_buffer = .{
        .protected_mode_segment = .{
            .selector = stub_info.ds_selector,
        },
        .real_mode_segment = stub_info.ds_segment,
        .len = stub_info.min_keep,
    };

    load_and_call_hello() catch |e| std.debug.panic("{s}\r\n", .{@errorName(e)});
    load_and_call_hello() catch unreachable;
    load_and_call_hello() catch unreachable;

    std.os.exit(std.start.callMain());
}

const StubInfo = extern struct {
    magic: [16]u8,
    size: u16, // Number of bytes in structure.
    min_stack: u32, // Minimum amount of DPMI stack space.
    mem_handle: u32, // DPMI memory block handle.
    initial_size: u32, // Size of initial segment.
    min_keep: u16, // Amount of automatic real-mode buffer.
    ds_selector: u16, // DS selector (used for transfer buffer).
    ds_segment: u16, // DS segment (used for simulated calls).
    psp_selector: u16, // Program segment prefix selector.
    cs_selector: u16, // To be freed.
    env_size: u16, // Number of bytes in environment.
    basename: [8]u8, // Base name of executable.
    argv0: [16]u8, // Used only by the application.
    dpmi_server: [16]u8, // Not used by CWSDSTUB.
};

var far_hello: ?FarPtr = null;

fn load_and_call_hello() !void {
    if (far_hello == null) {
        const len = @ptrToInt(&_hello_end) - @ptrToInt(&_hello_start);
        const hello = @ptrCast([*]u8, &_hello_start)[0..len];
        const block = try dpmi.ExtMemBlock.alloc(len);
        const segment = block.createSegment(.Data);
        segment.write(hello);
        segment.setAccessRights(.Code);
        far_hello = segment.farPtr();
    }
    asm volatile ("lcall *(%[func])"
        : // No outputs
        : [func] "r" (&far_hello.?)
        : "memory"
    );
}

comptime {
    asm (@embedFile("hello.s"));
}

extern var _hello_start: opaque {};
extern var _hello_end: opaque {};
