//! Auxillary prototype for filtering active tags.
const std = @import("std");
const Prototype = @import("../Prototype.zig");
const @"type" = @import("../type.zig");

/// Error set for filter.
const FilterError = error{
    ExpectsTypeValue,
    /// Violates tag blacklist assertion.
    Banishes,
    /// Violates tag whitelist assertion.
    Requires,
};

/// Error set for filter.
pub const Error = FilterError;

pub const type_validator = @"type".init;

/// Filter type with given Params consisting of `?bool` fields named after
/// its corresponding union or enum definitions.
pub fn Filter(comptime Params: type) type {
    switch (@typeInfo(Params)) {
        .@"struct" => {},
        else => unreachable,
    }

    return struct {
        pub fn init(params: Params) Prototype {
            return .{
                .name = "Filter",
                .eval = struct {
                    fn eval(actual: anytype) !bool {
                        _ = switch (@typeInfo(@TypeOf(actual))) {
                            inline .@"union", .@"enum" => {},
                            else => return FilterError.ExpectsTypeValue,
                        };

                        // Checks active tag against blacklist
                        if (@field(params, @tagName(actual))) |param| {
                            if (!param) return FilterError.Banishes;
                            return true;
                        }

                        // Checks remaining fields for active whitelist
                        inline for (std.meta.fields(Params)) |field| {
                            if (@field(params, field.name)) |value| {
                                if (value) return FilterError.Requires;
                            }
                        }
                        return true;
                    }
                }.eval,
                .onError = struct {
                    fn onError(
                        err: anyerror,
                        prototype: Prototype,
                        actual: anytype,
                    ) void {
                        switch (err) {
                            FilterError.ExpectsTypeValue,
                            FilterError.RequiresTypeInfo,
                            => comptime type_validator.onError.?(
                                err,
                                prototype,
                                actual,
                            ),

                            else => @compileError(std.fmt.comptimePrint(
                                "{s}.{s}: {s}",
                                .{
                                    prototype.name,
                                    @errorName(err),
                                    @typeName(actual),
                                },
                            )),
                        }
                    }
                }.onError,
            };
        }
    };
}

test FilterError {
    _ = FilterError.ExpectsTypeValue catch void;
    _ = FilterError.Banishes catch void;
    _ = FilterError.Requires catch void;
}

test Filter {
    const T = union(enum) {
        bar: bool,
        zig: usize,
        zag: f128,
    };
    _ = T;

    const Params = struct {
        bar: ?bool = null,
        zig: ?bool = null,
        zag: ?bool = null,
    };

    const t_validator = Filter(Params).init(.{
        .bar = null,
        .zig = null,
        .zag = null,
    });

    _ = t_validator;
}

test "passes whitelist filter assertions on tagged union" {
    const U = union(enum) {
        a: bool,
        b: usize,
        c: f128,
    };

    const Params = struct {
        a: ?bool,
        b: ?bool,
        c: ?bool,
    };

    const filter = Filter(Params).init(.{
        .a = true,
        .b = true,
        .c = null,
    });

    try std.testing.expectEqual(
        true,
        comptime filter.eval(U{ .a = false }),
    );

    try std.testing.expectEqual(
        true,
        comptime filter.eval(U{ .b = 0 }),
    );
}

test "passes blacklist filter assertions on tagged union" {
    const U = union(enum) {
        a: bool,
        b: usize,
        c: f128,
    };

    const Params = struct {
        a: ?bool,
        b: ?bool,
        c: ?bool,
    };

    const filter = Filter(Params).init(.{
        .a = null,
        .b = null,
        .c = false,
    });

    try std.testing.expectEqual(
        true,
        comptime filter.eval(U{ .a = false }),
    );

    try std.testing.expectEqual(
        true,
        comptime filter.eval(U{ .b = 0 }),
    );
}

test "fails whitelist assertion on tagged union" {
    const U = union(enum) {
        a: bool,
        b: usize,
        c: f128,
    };

    const Params = struct {
        a: ?bool,
        b: ?bool,
        c: ?bool,
    };

    const filter = Filter(Params).init(.{
        .a = true,
        .b = true,
        .c = null,
    });

    try std.testing.expectEqual(
        FilterError.Requires,
        comptime filter.eval(U{ .c = 0.0 }),
    );
}

test "fails blacklist assertion on tagged union" {
    const U = union(enum) {
        a: bool,
        b: usize,
        c: f128,
    };

    const Params = struct {
        a: ?bool,
        b: ?bool,
        c: ?bool,
    };

    const filter = Filter(Params).init(.{
        .a = null,
        .b = null,
        .c = false,
    });

    try std.testing.expectEqual(
        FilterError.Banishes,
        comptime filter.eval(U{ .c = 0.0 }),
    );
}
