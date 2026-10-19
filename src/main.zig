pub const panic = @import("mos_panic");

const std = @import("std");
const c64 = @import("c64");

// Video
const VIC = c64.vic;

export fn main() void {
    VIC.bgcolor[0] = .black;
    _ = std.c.printf("Hello World!\n");
    VIC.bordercolor = .blue;
}
