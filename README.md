# ziggurat

![zig 0.14.1](https://img.shields.io/badge/zig-0.14.1-brightgreen)

Microlibrary to introduce type constraints in zig 0.14.1.

Inspired off of [this brainstorming thread](https://ziggit.dev/t/implementing-generic-concepts-on-function-declarations/1490).

## About

The goal of ziggurat is to be able to comprehensibly define arbitrarily complex type constraints for `anytype` parameters within function signatures.

The essence of the library is within `contract.zig` and all other parts can be considered supplemental which are most likely to change. `contract.zig` stands to change if effective generalizations are discovered in service of reducing complexity or if deemed necessary for a better developer experience.

Given with how the `Term` is defined, the library may also have applications writing tests.

### Remarks

In any case, this is an attempt at the ideas discussed in the brainstorming thread who are all far smarter than I am. This approach tries to rectify architectural shortcomings of the minimalist approach such as losing information on errors, which I haven't settled into a solution yet, as well as take inspiration from, dare I say, the quality of life features found in C++ or Typescript.

A primary caveat of the current implementation is laying down some axioms about types being handled without much of a justification other than "it feels right". For instance, encountering `comptime_int` and `u64` are treated the same when iterating through fields. And the rules that govern integers boil down to inclusive min and max values. Needless to say, this is dissatisfying as I believe there's a way to generalize further without introducing arbitrary axioms.

## Usage

### Closures

ziggurat makes generous use of closures. This is done by returning function pointers as a member access of struct definitions.

I justify using closures as it lends itself to a declarative approach which appears more sensible than an imperative approach, in that it's easier to wrap (ha) my head around and favors type safety, also I appreciate the aesthetics.

```zig
fn foo() fn () void { // returns signature of enclosed function
    return struct {
        fn bar() void {
            ...
        }
    }.bar // member accesing of function pointer
}

const bar = foo(); // @as(fn () void, bar)

// These are all equivalent: bar() == foo()() == void
```

That out of the way, hopefully this isn't terribly intimidating:

```zig
fn foo(actual_value: anytype) Sign(some_term)(actual_value)(void) { ... }
```

### Contract

The contract concept is the heart of what ziggurat is and made up of two parts found in `contract.zig`:

-   `Term` abstract type
-   `Sign` function.

The other source included in the library are practical "proof-of-concepts" to give a starting point, thus may freely be omitted if deemed insufficient for any given use case. In most cases, I suspect changes to the library will center around these supplementary proof-of-concepts, unless effective generalizations work their way up to the contract level.

### Term Abstract Class

A `Term` is an abstract class that requires an `eval` function. `eval` is invoked by `Sign` and other `Term` instances.

```zig
const Term type = struct {
    name: [:0]const u8,
    eval: *const fn (actual: anytype) anyerror!bool,
    onFail: ?*const fn (term: Term, actual: anytype) void = null,
    onError: ?*const fn (err: anyerror, term: Term, actual: anytype) void = null,
}
```

#### Implementation Examples

Here is an example implementation of a `Term` type.

```zig
const Int: Term = .{
    .eval = struct {
        fn eval(actual: anytype) !bool {
            return switch (@typeInfo(@TypeOf(actual))) {
                .int => true,
                else => false,
            };
        }
    }.eval
}
```

Here's an implementation that only accepts odd integer values:

```zig
const OddInt: Term = .{
    .eval = struct {
        fn eval(actual: anytype) bool {
            return switch (@typeInfo(@TypeOf(actual))) {
                .comptime_int => @mod(actual, 2) == 1,
                .int => actual % 2 == 1,
                else => false,
            }
        }
    }.eval
}
```

Feel free to go crazy.

### Sign Function

`Sign` is a function invokes the evaluation of a `Term`. Complex `Term`s are intended to be composed into a single instance.

```zig
pub fn Sign(term: Term) fn (actual: anytype) fn (comptime return_type: type) type {
    return struct {
        fn validate(actual: anytype) fn (comptime return_type: type) type {
            const result = term.eval(actual);
            if (result) {
                // on pass
            } else {
                // on fail
            }
            return struct {
                fn returns(comptime ret_type: type) type {
                    return ret_type;
                }
            }.returns;
        }
    }.validate;
}

```

### Params

`params.zig` is an attempt to automate away some boilerplate through arbitrary assumptions about how I intend to utilize the content in `terms.zig`.

`Term` implementations included in the library accept "parameters" as rules to check actual values against. Parameterized definitions of primitive type classes (e.g. `Int`, `Float`) are included in `params` are concretely defined.

```zig
const IntParams = struct {
    min: ?comptime_int = null,
    max: ?comptime_int = null,
};
```

The other available parameter types like `Fields` and `Filter` are only slightly more exotic.

If a `struct` is a set of field names, then `Fields` creates a subset of the original field names. Furthermore, the respective types are transformed to their appropriate counterpart (e.g. `u64` ⇒ `ex.IntParams`, `f128` ⇒ `ex.FloatParams`).

`Fields` accepts an aggregate type, such as a `struct`, and procedurally constructs a parameterized counterpart by iterating through its fields, treating it as a container of fields. This continues recursively until all parameteritiz-able types are defined.
