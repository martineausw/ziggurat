//! `Prototype` implementations for common types
const std = @import("std");

/// Asserts array type within parameters:
///
/// - `child`, type info filter assertion.
/// - `len`, type info interval assertion.
/// - `sentinel`, type info value assertion.
pub const Array = @import("prototypes/array.zig");

/// Asserts float type within parameters:
///
/// - `bits`, type info interval assertion
pub const Float = @import("prototypes/float.zig");

/// Asserts int type within parameters:
///
/// - `bits`, type info interval assertion
/// - `signedness`, type info field assertion
pub const Int = @import("prototypes/int.zig");

/// Asserts optional type within parameters.
///
/// - `child`, type info filter assertion.
pub const Optional = @import("prototypes/optional.zig");

/// Asserts pointer type within parameters.
///
/// - `child`, type info filter assertion.
/// - `is_const`, type info value assertion.
/// - `is_volatile`, type info value assertion.
/// - `sentinel`, type info value assertion.
pub const Pointer = @import("prototypes/pointer.zig");

/// Asserts vector type within parameters.
///
/// - `child`, type info filter assertion.
/// - `len`, type info interval assertion.
pub const Vector = @import("prototypes/vector.zig");

test {
    std.testing.refAllDecls(@This());
}
