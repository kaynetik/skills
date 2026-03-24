# Practical Haskell -- reference

## Fibonacci stream (lazy)

```haskell
fibs :: [Integer]
fibs = 0 : 1 : zipWith (+) fibs (tail fibs)

fibAt :: Int -> Integer
fibAt n = fibs !! n
```

`!!` still walks the spine; for indexed access at scale, use structures suited to that access pattern.

## Strict loop with bang patterns

```haskell
{-# LANGUAGE BangPatterns #-}

strictSum :: [Int] -> Int
strictSum = go 0
  where
    go !acc []     = acc
    go !acc (x:xs) = go (acc + x) xs
```

## Strict constructor fields and UNPACK

```haskell
data Point = Point !Double !Double

data Vec3 = Vec3
  {-# UNPACK #-} !Double
  {-# UNPACK #-} !Double
  {-# UNPACK #-} !Double
```

`UNPACK` removes one layer of boxing when the field is strict and the type unpacks to unboxed representation; validate with Core and benchmarks.

## SPECIALIZE and INLINABLE

```haskell
genericSum :: (Num a) => [a] -> a
genericSum = foldl' (+) 0
{-# SPECIALIZE genericSum :: [Int] -> Int #-}
{-# SPECIALIZE genericSum :: [Double] -> Double #-}
{-# INLINABLE genericSum #-}
```

## Tail recursion vs naive recursion

```haskell
factorial :: Integer -> Integer
factorial n = go n 1
  where
    go 0 !acc = acc
    go m !acc = go (m - 1) (m * acc)
```

Naive `n * factorial (n-1)` on `Integer` can build large unevaluated products; strict accumulators avoid that pattern for this shape of problem.

## Useful GHC flags (non-exhaustive)

- `-O2`: strong optimizations; default for performance work.
- `-ddump-simpl`: simplified Core after optimization.
- `-fllvm` or native backend: platform-dependent; measure.
- `-prof` / `-fprof-auto`: profiling when investigating time and allocation.

Consult current GHC documentation for your version; flag names and defaults evolve.

## Further reading

- GHC User's Guide: optimization, profiling, rewrite rules, strictness.
- Simon Peyton Jones' talks and papers on lazy functional implementation (background for *why* Core and fusion look the way they do).
