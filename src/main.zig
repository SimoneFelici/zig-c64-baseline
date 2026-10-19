// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! C64 VIC-II border and background colour cycling demo.
//! Uses the translated c64.h module for VIC struct type and color constants.

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
