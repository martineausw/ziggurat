const std = @import("std");

const Prototype = @import("../Prototype.zig");
const info = @import("info.zig");

const ExistsError = error{
    InvalidArgument,
    AssertsNotNull,
    AssertsNull,
};

pub const Error = ExistsError;

pub const info_validator = info.init(.{
    .optional = true,
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
                        => ExistsError.InvalidArgument,
                        else => unreachable,
                    };

                if (params) |param| {
                    if (param) {
                        if (actual) |_| {} else {
                            return ExistsError.AssertsNotNull;
                        }
                    } else {
                        if (actual) |_| {
                            return ExistsError.AssertsNull;
                        }
                    }
                }

                return true;
            }
        }.eval,
        .onError = struct {
            fn onError(err: anyerror, prototype: Prototype, actual: anytype) void {
                switch (err) {
                    ExistsError.InvalidArgument,
                    => info_validator.onError(err, prototype, actual),

                    else => @compileError(std.fmt.comptimePrint("{s}.{s}: {any}", .{
                        prototype.name,
                        @errorName(err),
                        actual,
                    })),
                }
            }
        }.onError,
    };
}

test ExistsError {}

test Params {
    const params: Params = null;

    _ = params;
}

test init {
    const exists: Prototype = init(null);

    _ = exists;
}
