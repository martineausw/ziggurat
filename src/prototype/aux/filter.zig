//! Auxiliary prototype *filter*.
//!
//! Asserts an *actual* active tag of a union value or enum value to
//! optionally respect a blacklist and/or whitelist of tags.
//!
//! See also:
//! - [`std.builtin.Type.Union`](#std.builtin.Type.Union)
//! - [`std.builtin.Type.Enum`](#std.builtin.Type.Enum)
const std = @import("std");
const Prototype = @import("../Prototype.zig");
const @"type" = @import("../type.zig");

/// Error set for filter.
const FilterError = error{
    /// *actual* is not a union or enum type.
    ///
    /// See also: [`ziggurat.prototype.type`](#root.prototype.type)
    AssertsTypeValue,
    /// *actual* has an active tag that belongs to blacklist.
    AssertsBlacklist,
    /// *actual* has an active tag that does not belong to whitelist.
    AssertsWhitelist,
};

/// Filter type with given Params consisting of `?bool` fields named after
/// its derived union or enum fields.
///
/// - *null* is no assertion.
/// - *true* asserts tag belongs to the whitelist.
/// - *false* asserts tag belongs to the blacklist.
pub fn Filter(comptime T: type) type {
    return struct {
        pub const Error = FilterError;

        pub const type_validator = @"type".init;

        pub const Params =
            switch (@typeInfo(T)) {
                .@"union", .@"enum" => @Type(.{ .@"struct" = .{
                    .layout = .auto,
                    .backing_integer = null,
                    .fields = fields: {
                        var fields: [std.meta.fields(T).len]std.builtin.Type.StructField = undefined;

                        for (0..std.meta.fields(T).len) |i| {
                            fields[i] = .{
                                .name = std.meta.fields(T)[i].name,
                                .type = ?bool,
                                .default_value_ptr = &@as(?bool, null),
                                .is_comptime = false,
                                .alignment = @alignOf(?bool),
                            };
                        }

                        break :fields &fields;
                    },
                    .decls = &[0]std.builtin.Type.Declaration{},
                    .is_tuple = false,
                } }),
                else => @panic("type must be a tagged union or enum"),
            };

        pub fn init(params: Params) Prototype {
            return .{
                .name = "Filter",
                .eval = struct {
                    fn eval(actual: anytype) !bool {
                        _ = switch (@typeInfo(@TypeOf(actual))) {
                            inline .@"union", .@"enum" => {},
                            else => return FilterError.AssertsTypeValue,
                        };

                        // Checks active tag against blacklist
                        if (@field(params, @tagName(actual))) |param| {
                            if (!param) return FilterError.AssertsBlacklist;
                            return true;
                        }

                        // Checks remaining fields for active whitelist
                        inline for (std.meta.fields(Params)) |field| {
                            if (@field(params, field.name)) |value| {
                                if (value) return FilterError.AssertsWhitelist;
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
                            FilterError.AssertsTypeValue,
                            FilterError.AssertsWhitelistTypeInfo,
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
    _ = FilterError.AssertsTypeValue catch void;
    _ = FilterError.AssertsBlacklist catch void;
    _ = FilterError.AssertsWhitelist catch void;
}

test Filter {
    const T = union(enum) {
        bar: bool,
        zig: usize,
        zag: f128,
    };

    const t_validator = Filter(T).init(.{
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

    const filter = Filter(U).init(.{
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

    const filter = Filter(U).init(.{
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

    const filter = Filter(U).init(.{
        .a = true,
        .b = true,
        .c = null,
    });

    try std.testing.expectEqual(
        FilterError.AssertsWhitelist,
        comptime filter.eval(U{ .c = 0.0 }),
    );
}

test "fails blacklist assertion on tagged union" {
    const U = union(enum) {
        a: bool,
        b: usize,
        c: f128,
    };

    const filter = Filter(U).init(.{
        .a = null,
        .b = null,
        .c = false,
    });

    try std.testing.expectEqual(
        FilterError.AssertsBlacklist,
        comptime filter.eval(U{ .c = 0.0 }),
    );
}
