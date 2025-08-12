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

test FilterError {
    _ = FilterError.Disallowed catch void;
    _ = FilterError.Unexpected catch void;
}

test Error {
    _ = Error.InvalidType catch void;
    _ = Error.Disallowed catch void;
    _ = Error.Unexpected catch void;
}

test type_validator {
    _ = try type_validator.eval(usize);
    _ = try type_validator.eval(bool);
    _ = try type_validator.eval(@Vector(3, f128));
    _ = try type_validator.eval([]const u8);
    _ = try type_validator.eval(struct {});
    _ = try type_validator.eval(union {});
    _ = try type_validator.eval(enum {});
    _ = try type_validator.eval(error{});
}

test Filter {
    const FooParams = struct {
        bar: ?bool = null,
        zig: ?bool = null,
        zag: ?bool = null,
    };

    const Foo = union(enum) {
        bar: bool,
        zig: usize,
        zag: f128,
    };

    const params: FooParams = .{
        .bar = true,
        .zig = true,
    };
    const actual_foo: Foo = .{
        .bar = true,
    };

    const FooFilter = Filter(FooParams);

    const foo_validator = FooFilter.init(params);

    _ = try foo_validator.eval(actual_foo);
}
