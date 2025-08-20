//! Auxiliary prototype *has_active_tag*.
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
const HasActiveTagError = error{
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
pub fn Of(comptime T: type) type {
    return struct {
        pub const Error = HasActiveTagError;

        pub const is_type_value = @"type".init;

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
                .name = @typeName(@This()),
                .eval = struct {
                    fn eval(actual: anytype) !bool {
                        _ = switch (@typeInfo(@TypeOf(actual))) {
                            inline .@"union", .@"enum" => {},
                            else => return HasActiveTagError.AssertsTypeValue,
                        };

                        // Checks active tag against blacklist
                        if (@field(params, @tagName(actual))) |param| {
                            if (!param) return HasActiveTagError.AssertsBlacklist;
                            return true;
                        }

                        // Checks remaining fields for active whitelist
                        inline for (std.meta.fields(Params)) |field| {
                            if (@field(params, field.name)) |value| {
                                if (value) return HasActiveTagError.AssertsWhitelist;
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
                            HasActiveTagError.AssertsTypeValue,
                            HasActiveTagError.AssertsWhitelistTypeInfo,
                            => comptime is_type_value.onError.?(
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

test HasActiveTagError {
    _ = HasActiveTagError.AssertsTypeValue catch void;
    _ = HasActiveTagError.AssertsBlacklist catch void;
    _ = HasActiveTagError.AssertsWhitelist catch void;
}

test Of {
    const T = union(enum) {
        bar: bool,
        zig: usize,
        zag: f128,
    };

    const t_validator = Of(T).init(.{
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

    const filter = Of(U).init(.{
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

    const filter = Of(U).init(.{
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

    const filter = Of(U).init(.{
        .a = true,
        .b = true,
        .c = null,
    });

    try std.testing.expectEqual(
        HasActiveTagError.AssertsWhitelist,
        comptime filter.eval(U{ .c = 0.0 }),
    );
}

test "fails blacklist assertion on tagged union" {
    const U = union(enum) {
        a: bool,
        b: usize,
        c: f128,
    };

    const filter = Of(U).init(.{
        .a = null,
        .b = null,
        .c = false,
    });

    try std.testing.expectEqual(
        HasActiveTagError.AssertsBlacklist,
        comptime filter.eval(U{ .c = 0.0 }),
    );
}
