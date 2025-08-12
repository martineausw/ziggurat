//! Auxillary prototype for filtering active tags.
const std = @import("std");
const Prototype = @import("../Prototype.zig");
const @"type" = @import("../type.zig");

/// Error set for filter.
const FilterError = error{
    InvalidArgument,
    /// Violates tag blacklist assertion.
    Banishes,
    /// Violates tag whitelist assertion.
    Requires,
};

/// Errors returned by `eval`.
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
                        _ = type_validator.eval(actual) catch |err|
                            return switch (err) {
                                @"type".Error.InvalidArgument => FilterError.InvalidArgument,
                            };

                        switch (@typeInfo(actual)) {
                            .@"union",
                            .@"enum",
                            => {},
                            else => return FilterError.InvalidArgument,
                        }

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
                    fn onError(err: anyerror, prototype: Prototype, actual: anytype) void {
                        switch (err) {
                            FilterError.InvalidArgument,
                            => type_validator.onError(err, prototype, actual),

                            FilterError.Banishes,
                            FilterError.Requires,
                            => @compileError(std.fmt.comptimePrint(
                                "{s}.{s}: {s}",
                                .{
                                    prototype.name,
                                    @errorName(err),
                                    @tagName(std.meta.activeTag(actual)),
                                },
                            )),
                        }
                    }
                }.onError,
            };
        }
    };
}

test FilterError {}

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
