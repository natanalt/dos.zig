const FarPtr = @import("../far_ptr.zig").FarPtr;

// TODO: Enforce descriptor usage rules with the type system.
//
// See: http://www.delorie.com/djgpp/doc/dpmi/descriptor-rules.html
pub const Segment = struct {
    selector: u16,

    pub const Type = enum {
        Code,
        Data,
    };

    pub fn alloc() Segment {
        // TODO: Check carry flag for error.
        const selector = asm volatile ("int $0x31"
            : [_] "={ax}" (-> u16)
            : [func] "{ax}" (@as(u16, 0)),
              [_] "{cx}" (@as(u16, 1))
        );
        return Segment{ .selector = selector };
    }

    pub fn farPtr(self: Segment) FarPtr {
        return .{ .segment = self.selector };
    }

    pub fn getBaseAddress(self: Segment) usize {
        var addr_high: u16 = undefined;
        var addr_low: u16 = undefined;
        // TODO: Check carry flag for error.
        asm ("int $0x31"
            : [_] "={cx}" (addr_high),
              [_] "={dx}" (addr_low)
            : [func] "{ax}" (@as(u16, 6)),
              [_] "{bx}" (self.selector)
        );
        return @as(usize, addr_high) << 16 | addr_low;
    }

    pub fn setAccessRights(self: Segment, seg_type: Segment.Type) void {
        // TODO: Represent rights with packed struct?
        // TODO: Is hardcoding the privilege level bad?
        const rights: u16 = switch (seg_type) {
            .Code => 0xc0fb, // 32-bit, ring 3, big, code, non-conforming, readable
            .Data => 0xc0f3, // 32-bit, ring 3, big, data, R/W, expand-up
        };
        // TODO: Check carry flag for error.
        asm volatile ("int $0x31"
            : // No outputs
            : [func] "{ax}" (@as(u16, 9)),
              [_] "{bx}" (self.selector),
              [_] "{cx}" (rights)
        );
    }

    pub fn setBaseAddress(self: Segment, addr: usize) void {
        // TODO: Check carry flag for error.
        asm volatile ("int $0x31"
            : // No outputs
            : [func] "{ax}" (@as(u16, 7)),
              [_] "{bx}" (self.selector),
              [_] "{cx}" (@truncate(u16, addr >> 16)),
              [_] "{dx}" (@truncate(u16, addr))
        );
    }

    pub fn setLimit(self: Segment, limit: usize) void {
        // TODO: Check carry flag for error.
        // TODO: Check that limit meets alignment requirements.
        asm volatile ("int $0x31"
            : // No outputs
            : [func] "{ax}" (@as(u16, 8)),
              [_] "{bx}" (self.selector),
              [_] "{cx}" (@truncate(u16, limit >> 16)),
              [_] "{dx}" (@truncate(u16, limit))
        );
    }
};
