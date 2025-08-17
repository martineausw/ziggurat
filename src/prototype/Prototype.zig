//! Evaluates values to guide control flow and type reasoning.

const Error = error{UnimplementedError};

/// Name to be used for messages.
name: [:0]const u8,

/// Evaluates `actual`, returns an error or `false` on failure.
eval: *const fn (actual: anytype) anyerror!bool = struct {
    fn eval(actual: anytype) anyerror!bool {
        _ = actual;
        return Error.UnimplementedError;
    }
}.eval,

/// Callback triggered by `Sign` when `eval` returns an error.
onError: ?*const fn (
    err: anyerror,
    prototype: @This(),
    actual: anytype,
) void = null,

/// Callback triggered by `Sign` when `eval` returns `false`.
onFail: ?*const fn (prototype: @This(), actual: anytype) void = null,
