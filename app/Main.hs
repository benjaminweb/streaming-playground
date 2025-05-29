module Main where

import qualified Streaming.Prelude as S
import Streaming.Prelude (Stream, Of)
import Streaming
import Data.Char
import Data.IORef
import Control.Concurrent.Async

tut1 :: IO (Of Int ())
tut1 = S.sum $ S.take 3 (S.readLn :: Stream (Of Int) IO ())

tut2 :: IO ()
tut2 = S.stdoutLn $ S.map (map toUpper) $ S.take 2 S.stdinLn

-- creates stack overflow
tut3 :: IO ()
tut3 = mapM newIORef [1..10^8::Int] >>= mapM readIORef >>= mapM_ print

-- streaming variant
tut3' :: IO ()
tut3' = S.print $ S.mapM readIORef $ S.mapM newIORef $ S.each [1..10^8::Int]

-- :: IO ()
-- parallelising
tut4 = S.print $ S.mapM readIORef $ S.mapM newIORef $ S.each [1..10^8::Int]

ex1 :: IO ()
ex1 = S.print $ mapped S.toList $ chunksOf 2 $ S.each [1..10]

ex2 :: IO ()
ex2 = S.mapM_ Prelude.print $ mapped S.toList $ chunksOf 2 $ S.each [1..10]

-- concurrently process two
ex3 :: IO ()
ex3 = S.mapM_ (mapConcurrently (Prelude.print)) $ mapped S.toList $ chunksOf 2 $ S.each [1..10]


-- basic IO returning list of Int
--
-- >>> sum <$> simpleIO
-- 55
simpleIO :: IO [Int]
simpleIO = return [1..10]

-- produce stream from List using `S.yield`
-- 
-- >>> S.sum simpleIO'
-- [55 :> ()]
simpleIO' :: Stream (Of Int) [] ()
simpleIO' = mapM_ S.yield [1..10]

-- | produce stream but factoring out `S.yield`.
--   requires providing type signature on call, refer to doctest below
-- 
-- >>> S.sum (simpleIO2' S.yield :: Num a => Stream (Of a) [] ())
-- [55 :> ()]
simpleIO2' :: (Monad m, Num a) => (a -> m b) -> m ()
simpleIO2' f = mapM_ f [1,2,3,4,5,6,7,8,9,10]

main :: IO ()
main = putStrLn "Hello, Haskell!"
