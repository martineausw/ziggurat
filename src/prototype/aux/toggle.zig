const std = @import("std");

const Prototype = @import("../Prototype.zig");
const info = @import("../aux/info.zig");

/// Error set for toggle.
const ToggleError = error{
    /// `actual` requires bool type info.
    RequiresTypeInfo,
    /// `actual` is false.
    AssertsTrue,
    /// `actual` is true.
    AssertsFalse,
};

pub const Error = ToggleError;

pub const info_validator = info.init(.{
    .bool = true,
});

pub const Params = ?bool;

pub fn init(params: Params) Prototype {
    return .{
        .name = "Toggle",
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = info_validator.eval(@TypeOf(actual)) catch |err|
                    return switch (err) {
                        info.Error.RequiresTypeInfo,
                        => ToggleError.RequiresTypeInfo,
                        else => unreachable,
                    };

                if (params) |param| {
                    if (param) {
                        if (!actual) {
                            return ToggleError.AssertsTrue;
                        }
                    } else {
                        if (actual) {
                            return ToggleError.AssertsFalse;
                        }
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
                    ToggleError.ExpectsTypeValue,
                    ToggleError.RequiresTypeInfo,
                    => info_validator.onError.?(err, prototype, actual),

                    else => @compileError(
                        std.fmt.comptimePrint("{s}.{s}: {s}", .{
                            prototype.name,
                            @errorName(err),
                            if (actual) "true" else "false",
                        }),
                    ),
                }
            }
        }.onError,
    };
}

test ToggleError {
    _ = ToggleError.RequiresTypeInfo catch void;
    _ = ToggleError.AssertsTrue catch void;
    _ = ToggleError.AssertsFalse catch void;
}

test Params {
    const params: Params = null;

    _ = params;
}

test init {
    const toggle = init(null);

    _ = toggle;
}

test "passes toggle assertions" {
    const is_null = init(null);
    const is_true = init(true);
    const is_false = init(false);

    try std.testing.expectEqual(true, is_null.eval(true));
    try std.testing.expectEqual(true, is_null.eval(false));
    try std.testing.expectEqual(true, is_true.eval(true));
    try std.testing.expectEqual(true, is_false.eval(false));
}

test "fails toggle false assertion" {
    const is_false = init(false);

    try std.testing.expectEqual(
        ToggleError.AssertsFalse,
        is_false.eval(true),
    );
}

test "fails toggle true assertion" {
    const is_true = init(true);

    try std.testing.expectEqual(
        ToggleError.AssertsTrue,
        is_true.eval(false),
    );
}
