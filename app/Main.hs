module Main where

import qualified Streaming.Prelude as S
import Streaming.Prelude (Stream, Of)
import Data.Char

tut1 :: IO (Of Int ())
tut1 = S.sum $ S.take 3 (S.readLn :: Stream (Of Int) IO ())

tut2 :: IO ()
tut2 = S.stdoutLn $ S.map (map toUpper) $ S.take 2 S.stdinLn

main :: IO ()
main = putStrLn "Hello, Haskell!"
