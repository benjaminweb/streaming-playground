module Main where

import qualified Streaming.Prelude as S
import Streaming.Prelude (Stream, Of)
import Data.Char
import Data.IORef

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

main :: IO ()
main = putStrLn "Hello, Haskell!"
