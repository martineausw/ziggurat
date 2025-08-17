# ziggurat

![zig 0.14.1](https://img.shields.io/badge/zig-0.14.1-brightgreen)

Microlibrary to introduce type constraints in zig 0.14.1.

Inspired off of [this brainstorming thread](https://ziggit.dev/t/implementing-generic-concepts-on-function-declarations/1490).

## About

The goal of ziggurat is to enable developers to comprehensibly define arbitrarily complex type constraints and assertions.

## Installation

### Remote repository

```bash
zig fetch --save git+https://github.com/martineausw/ziggurat.git
```

### Local directory

```bash
cd /path/to/clone/

# either start
git clone https://github.com/martineausw/ziggurat.git # via HTTPS
git clone git@github.com:martineausw/ziggurat.git # via SSH
# either end

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

### Prototype abstract

Prototype requires an `eval` function pointer.

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

### Included prototypes

Intended to be used in comptime:

-   array - to assert an array type value with length interval, child type info, and sentinel existence assertions.
-   bool - to assert a boolean type value.
-   float - to assert a float type value with a bit interval assertion.
-   int - to assert an integer type value with bit interval and signedness filter assertions.
-   optional - to assert an optional type value with a child type info filter assertion.
-   pointer - to assert a pointer type value with child type info filter, size filter, const qualifier presence, volatile qualifier presence, and sentinel existence assertions.
-   struct - to assert a struct type value with layout filter, field set, declaration set, and tuple type assertions.
-   type - to assert a type value.
-   vector - to assert a vector type value with child type info filter and length interval assertions.

#### Auxiliary prototypes

Intermediate and utility prototypes:

-   child - to assert on type values with a child type.
-   decl - to assert a type value contains a declaration.
-   exists - to assert an optional value is null or not null
-   field - to assert a type value contains a field of a parametric type.
-   filter - to assert a blacklist and/or whitelist of possible active tags of a union or enum.
-   info - to assert a type value blacklist and/or whitelist of potential type info tags.
-   interval - to assert a number value is within an inclusive range.
-   toggle - to assert a boolean value is either true or false.

#### Operator prototypes

Boolean operations for prototype evaluation results

-   conjoin - to assert all prototypes evaluate to true.
-   disjoin - to assert at least one prototype evaluates to true.
-   negate - to assert a prototype evaluates to false without an error.

### Sign function

`sign` calls `eval` on a given prototype and will call `onError` or `onFail` for error or false return values, respectively. Complex prototypes are intended to be composed using operators and auxiliary prototypes.

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
