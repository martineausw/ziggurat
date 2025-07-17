# ziggurat

Zig 0.14.1 microlibrary to introduce type constraints.

Inspired off of [this brainstorming thread](https://ziggit.dev/t/implementing-generic-concepts-on-function-declarations/1490).

## About

The goal of ziggurat is to be able to comprehensibly define arbitrily complex type constraints for `anytype` parameters within function signatures to acheive a balance between flexibility and type safety, which sounds a bit naive now that I'm writing this.

In any case, this is an attempt at the ideas discussed in the brainstorming thread who are all far smarter than I am. This approach tries to rectify architectural shortcomings of the minimalist approach such as losing information on errors, which I haven't settled into a solution yet, as well as take inspiration from, dare I say, the quality of life features found in C++ or Typescript.

A primary caveat of the current implementation is laying down some axioms about types being handled without much of a justification other than "it feels right". For instance, encountering `comptime_int` and `u64` are treated the same when iterating through fields. And the rules that govern integers boil down to inclusive min and max values. Needless to say, this is dissatisfying as I believe there's a way to generalize further without introducing arbitrary axioms.

## Usage

### Closures

ziggurat makes generous use of closures. This is done by returning function pointers as a member access of struct definitions.

I justified this decision because the declarative seemed more sensible then an imperative approach, it was easier to wrap (ha) my head around, also I appreciate the aesthetics.

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

### Term Abstract Class

A `Term` is an abstract class that requires an `eval` function. `eval` is invoked by `Sign` and other `Term` instances.

```zig
const Term type = struct {
    eval: *const fn (value: anytype) bool,
    ...
}
```

### Term Implementation

`Int` is provided as an approximate example implementation of `Term`, though negligably different.

```zig
fn Int(expected_value_or_params: IntParams) Term {
    return struct {
        fn eval(actual_value: anytype) bool { ... }
        fn impl() Term { return .{ .eval = eval }; }
    }.impl();
}
```

The `impl` function is ultimately unnecessary in name and structure, but I am partial to it's comparmentalized nature.

### Parameters

`Term` implementations included in the library accept "parameters" as rules to check actual values against. Parameterized definitions of primitive type classes (e.g. `Int`, `Float`) are included in `parameters.zig` and are concretely defined.

```zig
const IntParams = struct {
    min: ?comptime_int = null,
    max: ?comptime_int = null,
};
```

The other available parameter types like `Fields` and `Filter` are only slightly more exotic.

If a `struct` is a set of field names, then `Fields` creates a subset of the original field names. Furthermore, the respective types are transformed to their appropriate counterpart (e.g. `u64` => `ex.IntParams`, `f128` => `ex.FloatParams`).

`Fields` accepts an aggregate type, such as a `struct`, and procedurally constructs a parameterized counterpart by iterating through its fields, treating it as a container of fields. This continues recursively until all parameteritiz-able types are defined.

## Goals

-   [ ] Tests
-   [ ] Traceable error output
-   [ ] Failure behavior configuration
-   [ ] Simplify

## Reflection

> "If you are the head that floats atop the ziggurat, then the stairs that lead to you must be infinite." (9:30)
>
> "The Mountain." _Adventure Time_, created by Pendleton Ward, season 6, episode 28, Frederator Studios, 2015

This is a crude attempt to enforce constraints on `anytype` parameters. The initial approach was seeded by the brainstorming thread (linked above) and it regrettably became more entangled overtime. I don't abhor the implementation, but as it exists in this moment I'm a little dissatisfied with it. There are many reasons for this feeling, but it boils down being faced with a fog that can only be navigated with experience or dispelled with time. This is to say, I imagine there's a sightly form that returns back to the elegant minimalism as posited in the thread, but it escapes me at this time.

The primary goal in setting out to write this library was to enjoy some syntactic sugar, remiscent of C++ black magic, afforded without conention by zigs comptime and meta-programming features. I'm realizing now as I'm writing that I've adopted many implicit secondary goals all of which are indulgent, which is as fun as is frustrating when having a nebulous idea of where you want to be with no interest in arriving there sensibly, hence the lack of tests and git history as of today.

At this moment, though, endless iteration in a vacuum isn't doing me any favors, so I'll be making improvements when the shortcomings surface practically as I integrate it in the project I imagined it to be used in.
