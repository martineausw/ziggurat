# ziggurat

![zig 0.14.1](https://img.shields.io/badge/zig-0.14.1-brightgreen)

Microlibrary to introduce type constraints in zig 0.14.1.

Inspired off of [this brainstorming thread](https://ziggit.dev/t/implementing-generic-concepts-on-function-declarations/1490).

## About

The goal of ziggurat is to be able to comprehensibly define arbitrarily complex type constraints for `anytype` parameters within function signatures.

## Installation

### Remote repository

From terminal:

```
zig fetch --save git+https://github.com/martineausw/ziggurat.git
```

### Local directory

From terminal:

```
cd /path/to/clone/
git clone https://github.com/martineausw/ziggurat.git
zig fetch --save /path/to/clone/ziggurat/
```

## Usage

### Closures

ziggurat makes generous use of closures. This is done by returning function pointers as a member access of struct definitions.

I justify using closures as it lends itself to a declarative approach which appears more sensible than an imperative approach, in that it's easier to wrap (ha) my head around and favors type safety, also I appreciate the aesthetics.

```zig
fn foo() fn () void { // Returns signature of enclosed function
    return struct {
        fn bar() void {
            ...
        }
    }.bar; // Accesses `bar` function pointer.
}

const bar = foo(); // @as(fn () void, bar)

// These are all equivalent: bar() == foo()() == void
```

That out of the way, hopefully this isn't terribly intimidating:

```zig
fn foo(actual_value: anytype) sign(some_prototype)(actual_value)(void) { ... }
```

### `Prototype` Abstract

A `Prototype` is an abstract class that requires an `eval` function. `eval` is invoked by `sign` and other `Prototype` instances.

```zig
const Prototype = struct {
    name: [:0]const u8,
    eval: *const fn (actual: anytype) anyerror!bool,
    onFail: ?*const fn (prototype: Prototype, actual: anytype) void = null,
    onError: ?*const fn (err: anyerror, prototype: Prototype, actual: anytype) void = null,
};
```

#### Implementing `Prototype`

Here is an example implementation of a `Prototype` type.

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

Feel free to go crazy.

### `sign` Function

`sign` is a function invokes the evaluation of a `Prototype`. Complex `Prototype`s are intended to be composed into a single instance.

```zig
pub fn sign(prototype: Prototype) fn (actual: anytype) fn (comptime return_type: type) type {
    return struct {
        pub fn validate(actual: anytype) fn (comptime return_type: type) type {
            if (prototype.eval(actual)) |result| {
                if (!result) if (prototype.onFail) |onFail|
                    onFail(prototype, actual);
            } else |err| {
                if (prototype.onError) |onError|
                    onError(err, prototype, actual);
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
