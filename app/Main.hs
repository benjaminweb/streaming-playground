module Main where

import qualified Streaming.Prelude as S
import Streaming.Prelude (Stream, Of)
import Streaming
import Data.Char
import Data.IORef
import Control.Concurrent.Async
import Data.Maybe (listToMaybe)
import Data.Time.Clock.System

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

simpleIO3 :: (Monad m, Num a) => (a -> m b) -> m [b]
simpleIO3 f = traverse f [1,2,3,4,5,6,7,8,9,10]

-- possibly easiest first step: https://github.com/valderman/selda/blob/ab9619db13b93867d1a244441bb4de03d3e1dadb/selda/src/Database/Selda/Compile.hs#L153
-- => create streaming variant of `nextResult`
--    calls `gNextResult` https://github.com/valderman/selda/blob/ab9619db13b93867d1a244441bb4de03d3e1dadb/selda/src/Database/Selda/SqlRow.hs#L58
--    which calls `next`
--    which is defined https://github.com/valderman/selda/blob/ab9619db13b93867d1a244441bb4de03d3e1dadb/selda/src/Database/Selda/SqlRow.hs#L29
--
--    do we need to use `Monad m => ResultReader (m ())`?
--
-- unclear:
--   o how does (:*:) work? and how does it can / need to be used with Streaming return types (if it's resembling a list type)?
--   o to be ctd.

-- grasp some basic streaming building blocks (we are abstracting the streaming library's specifics away)

single :: (Monad m, Num a) => (a -> m b) -> a -> m b
single f x = f x

-- >>>  S.sum $ two S.yield 22 23
-- 45 :> ()
two :: (Monad m, Num a, Monoid (m b)) => (a -> m b) -> a -> a -> m b
two f x y = f x `mappend` f y

-- >>> S.sum $ anyNo [22, 23]
-- 45 :> ()
anyNo :: (Monad m, Num a, Monoid (m b)) => (a -> m b) -> [a] -> m b
anyNo f (a:xs) = foldl (\acc x -> acc `mappend` f x) (f a) xs
anyNo _ [] = mempty


{- let's take the function we want to streamify
getRows :: Statement -> [[SQLData]] -> IO [[SQLData]]
getRows s acc = do
  res <- step s
  case res of
    Row -> do
      cs <- columns s :: IO [SQLData]
      getRows s (acc ++ [cs])
    _ -> do
      return $ acc
-}

-- | Let's rebuild it as a toy to play with…
-- 
-- >>> getRowsNaive ((take 22 $ repeat False) ++ [True]) []
-- [1752481033,1752481033,1752481033,1752481033,1752481033,1752481033,1752481033,1752481033,1752481033,1752481033,1752481033,1752481033,1752481033,1752481033,1752481033,1752481033,1752481033,1752481033,1752481033,1752481033,1752481033,1752481033]
getRowsNaive :: [Bool] -> [Int] -> IO [Int]
getRowsNaive yetDone acc = do
  case listToMaybe yetDone of
    Just True -> return acc
    _ -> do
        t <- fromIntegral . systemSeconds <$> getSystemTime
        getRowsNaive (drop 1 yetDone) (acc ++ [t])

-- | How could we stream just but a single element?
-- 
-- >>> S.print $ streamSingle S.yield
-- 1752483198
streamSingle :: (MonadIO m, Monad m, Num a, Monoid (m b)) => (a -> m b) -> (m b)
streamSingle f = do
  t <- liftIO $ fromIntegral . systemSeconds <$> getSystemTime
  f t

-- | How could we add a single element to an existing stream?
-- 
-- >>> S.sum $ streamNext False S.yield (S.yield (-99999999999))
-- -98247516591 :> ()
streamNext :: (MonadIO m, Monad m, Num a , Monoid (m b)) => Bool -> (a -> m b) -> m b -> m b
streamNext False f acc = do
  t <- liftIO $ fromIntegral . systemSeconds <$> getSystemTime
  acc `mappend` f t
streamNext True _ acc = acc

-- | How could we turn `getRowsNaive` into stream variant?
-- 
-- >>> S.toList $ streamRowsNaive S.yield ((take 22 $ repeat False) ++ [True]) mempty
-- [1752483783,1752483783,1752483783,1752483783,1752483783,1752483783,1752483783,1752483783,1752483783,1752483783,1752483783,1752483783,1752483783,1752483783,1752483783,1752483783,1752483783,1752483783,1752483783,1752483783,1752483783,1752483783] :> ()
streamRowsNaive :: (MonadIO m, Monad m, Num a, Monoid (m b)) => (a -> m b) -> [Bool] -> m b -> m b
streamRowsNaive f yetDone acc = do
  case listToMaybe yetDone of
    Just True -> acc
    _ -> do
        t <- liftIO $ fromIntegral . systemSeconds <$> getSystemTime
        streamRowsNaive f (drop 1 yetDone) (acc `mappend` f t)

-- | How do we transfer this to the original getRows variant?
-- 
-- >>> streamRows S.yield "foo bar" mempty
-- TBD
{-
streamRows :: (MonadIO m, Monad m, Monoid (m b)) => (a -> m b) -> Statement -> m b -> m b
streamRows f s acc = do
  res <- step s
  case res of
    Row -> do
      cs <- liftIO (columns s :: IO [SQLData])
      streamRows f s (acc `mappend` f cs)
    _ -> acc
-}

main :: IO ()
main = putStrLn "Hello, Haskell!"
