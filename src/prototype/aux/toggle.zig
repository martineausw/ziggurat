const std = @import("std");

const Prototype = @import("../Prototype.zig");
const info = @import("../aux/info.zig");

const ToggleError = error{
    InvalidArgument,
    AssertsTrue,
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
                        info.Error.InvalidArgument,
                        info.Error.RequiresType,
                        => ToggleError.InvalidArgument,
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
            fn onError(err: anyerror, prototype: Prototype, actual: anytype) void {
                switch (err) {
                    ToggleError.InvalidArgument,
                    => info_validator.onError(err, prototype, actual),

                    else => @compileError(std.fmt.comptimePrint("{s}.{s}: {s}", .{
                        prototype.name,
                        @errorName(err),
                        if (actual) "true" else "false",
                    })),
                }
            }
        }.onError,
    };
}

test ToggleError {}

test Params {
    const params: Params = null;

    _ = params;
}

test init {
    const toggle = init(null);

    _ = toggle;
}
