# ziggurat

![zig 0.14.1](https://img.shields.io/badge/zig-0.14.1-brightgreen)

Library for defining type constraints and assertions.

Inspired off of [this brainstorming thread](https://ziggit.dev/t/implementing-generic-concepts-on-function-declarations/1490).

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

-   array - asserts an array type value with length interval, child type info, and sentinel existence assertions.
-   bool - asserts a boolean type value.
-   float - asserts a float type value with a bit interval assertion.
-   int - asserts an integer type value with bit interval and signedness filter assertions.
-   optional - asserts an optional type value with a child type info filter assertion.
-   pointer - asserts a pointer type value with child type info filter, size filter, const qualifier presence, volatile qualifier presence, and sentinel existence assertions.
-   struct - asserts a struct type value with layout filter, field set, declaration set, and tuple type assertions.
-   type - asserts a type value.
-   vector - asserts a vector type value with child type info filter and length interval assertions.

#### Auxiliary

Intermediate and utility prototypes:

-   child - asserts on type values with a child type.
-   decl - asserts a type value contains a declaration.
-   exists - asserts an optional value is null or not null
-   field - asserts a type value contains a field of a parametric type.
-   filter - asserts a blacklist and/or whitelist of possible active tags of a union or enum.
-   info - asserts a type value blacklist and/or whitelist of potential type info tags.
-   interval - asserts a number value is within an inclusive range.
-   toggle - asserts a boolean value is either true or false.

#### Operator

Boolean operations for prototype evaluation results

-   conjoin - asserts all prototypes evaluate to true.
-   disjoin - asserts at least one prototype evaluates to true.
-   negate - asserts a prototype evaluates to false without an error.

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
