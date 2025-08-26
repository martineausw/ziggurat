# ziggurat

![zig 0.14.1](https://img.shields.io/badge/zig-0.14.1-brightgreen)

Library for defining type constraints and assertions.

Inspired off of [this brainstorming thread](https://ziggit.dev/t/implementing-generic-concepts-on-function-declarations/1490).

```zig
const any_data: ziggurat.Prototype = .any(&.{
    .is_array(.{}),
    .is_vector(.{}),
    .is_pointer(.{ .size = .{ .slice = true } }),
})

pub fn wrapIndex(
    data: anytype,
    index: i128,
) ziggurat.sign(any_data)(@TypeOf(data))(usize) {
    return if (index < 0)
        getLen(data) - @as(usize, @intCast(@abs(index)))
    else
        @as(usize, @intCast(index));
}

pub fn at(
    data: anytype,
    index: i128,
) ziggurat.sign(any_data)(@TypeOf(data))(switch (@typeInfo(@TypeOf(data))) {
    inline .array, .vector => |info| info.child,

    .pointer => |info| switch (info.size) {
        .slice => info.child,
        else => unreachable,
    },

    else => unreachable,
}) {
    return switch (@typeInfo(@TypeOf(data))) {
        .pointer => |info| switch (info.size) {
            .slice => data[wrapIndex(data, index)],
            else => unreachable,
        },

        .array, .vector => data[wrapIndex(data, index)],

        else => unreachable,
    };
}
```

## About

The goal of ziggurat is to enable developers to comprehensibly define arbitrarily complex type constraints and assertions.

## Installation

### Remote

```bash
zig fetch --save git+https://github.com/martineausw/ziggurat.git#0.0.0
```

### Local

```bash
cd /path/to/clone/

git clone https://github.com/martineausw/ziggurat.git#0.0.0

cd /path/to/zig/project

zig fetch --save /path/to/clone/ziggurat/
```

## Usage

### Closures

ziggurat makes generous use of closures. This is done by returning function pointers as a member access of struct definitions.

I justify using closures as it lends itself to a declarative approach which appears more sensible than an imperative approach, in that it's easier to wrap (ha) my head around and favors type safety, also I appreciate the aesthetics.

```zig
fn foo() fn () void { // Returns signature of enclosed function
    return struct {
        fn bar() void {}
    }.bar; // Accesses `bar` function pointer.
}

const bar: *const fn () void = foo();

// These are all equivalent: bar() == foo()() == void

test "closure equality" {
    try std.testing.expectEqual(*const fn () void, @TypeOf(bar));
    try std.testing.expectEqual(bar, foo());
    try std.testing.expectEqual(void, @TypeOf(bar()));
    try std.testing.expectEqual(bar(), foo()());
}

```

That out of the way, hopefully this isn't terribly intimidating:

```zig
fn foo(actual_value: anytype) sign(some_prototype)(actual_value)(void) { ... }
```

### Prototype

Prototype requires an _eval_ function pointer.

```zig
const Prototype = struct {
    name: [:0]const u8,
    eval: *const fn (actual: anytype) anyerror!bool,
    onFail: ?*const fn (prototype: Prototype, actual: anytype) void = null,
    onError: ?*const fn (err: anyerror, prototype: Prototype, actual: anytype) void = null,
};
```

#### Implementing

Here is an example implementation of a prototype.

```zig
const int: Prototype = .{
    .eval = struct {
        fn eval(actual: anytype) !bool {
            return switch (@typeInfo(@TypeOf(actual))) {
                .int => true,
                else => false,
            };
        }
    }.eval,
};
```

Here's an implementation that only accepts odd integer values:

```zig
const odd_int: Prototype = .{
    .eval = struct {
        fn eval(actual: anytype) bool {
            return switch (@typeInfo(@TypeOf(actual))) {
                .comptime_int => @mod(actual, 2) == 1,
                .int => actual % 2 == 1,
                else => false,
            };
        }
    }.eval,
};
```

### Included

Intended to be used in _comptime_:

-   is_array - asserts an array type value with length interval, child type info, and sentinel existence assertions.
-   is_bool - asserts a boolean type value.
-   is_float - asserts a float type value with a bit interval assertion.
-   is_int - asserts an integer type value with bit interval and signedness filter assertions.
-   is_optional - asserts an optional type value with a child type info filter assertion.
-   is_pointer - asserts a pointer type value with child type info filter, size filter, const qualifier presence, volatile qualifier presence, and sentinel existence assertions.
-   is_struct - asserts a struct type value with layout filter, field set, declaration set, and tuple type assertions.
-   is_type - asserts a type value.
-   is_vector - asserts a vector type value with child type info filter and length interval assertions.

#### Ancillary

-   equals_bool
-   has_decl(s)
-   has_field(s)
-   has_tag
-   has_type_info
-   has_value
-   on_type
-   within_interval

#### Operator

Boolean operations for prototype evaluation results

-   all - asserts all prototypes evaluate to true.
-   any - asserts at least one prototype evaluates to true.
-   not - asserts a prototype evaluates to false without an error.
-   seq - applies indexable prototypes to respective indices of provided argument.

### Sign

_sign_ calls _eval_ on a given prototype and will call _onError_ or _onFail_ for error or false return values, respectively. Complex prototypes are intended to be composed using operators and auxiliary prototypes.

```zig
pub fn sign(prototype: Prototype) fn (actual: anytype) fn (comptime return_type: type) type {
    return struct {
        pub fn validate(actual: anytype) fn (comptime return_type: type) type {
            if (comptime prototype.eval(actual)) |result| {
                if (!result) if (prototype.onFail) |onFail|
                    comptime onFail(prototype, actual);
            } else |err| {
                if (prototype.onError) |onError|
                    comptime onError(err, prototype, actual);
            }

            return struct {
                pub fn returns(comptime return_type: type) type {
                    return return_type;
                }
            }.returns;
        }
    }.validate;
};
```
