module Test.Main where

import Prelude
import Control.Alternative (empty, (<|>))
import Control.Monad.Aff (Aff, later', makeAff)
import Control.Monad.Aff.AVar (AVAR)
import Control.Monad.Aff.Console (CONSOLE)
import Control.Monad.Eff (Eff)
import Control.Monad.Eff.Class (liftEff)
import Control.Monad.Eff.Exception (error)
import Control.Monad.Eff.Ref (readRef, modifyRef, newRef, REF)
import Control.Monad.Eff.Timer (TIMER)
import Control.XStream (addListener, Stream, STREAM, fromArray, switchMapEff, bindEff, flattenEff, switchMap, delay, imitate, startWith, take, create', remember, flatten, throw, replaceError, fold, endWhen, last, drop, filter, mapTo, fromCallback, fromAff, periodic, never, createWithMemory, create)
import Data.Array (snoc)
import Data.Either (Either(Left, Right))
import Data.Monoid (mempty)
import Test.Unit (Test, test, suite, success, failure, timeout)
import Test.Unit.Assert (equal, expectFailure)
import Test.Unit.Console (TESTOUTPUT)
import Test.Unit.Main (runTest)

foreign import callback :: forall e. (Int -> Eff e Unit) -> Eff e Unit

arrayFromStream :: forall e a. Stream a -> Aff (ref :: REF, stream :: STREAM | e) (Array a)
arrayFromStream s = makeAff \reject resolve -> do
  ref <- newRef empty
  addListener
    { next: \a -> modifyRef ref $ flip snoc a
    , error: reject
    , complete: pure $ resolve =<< readRef ref
    }
    s

expectStream :: forall e a.
  (Eq a , Show a) => Array a -> Stream a -> Test (ref :: REF, stream :: STREAM, console :: CONSOLE | e)
expectStream xs a =
  equal xs =<< arrayFromStream a

main :: forall e.
  Eff
    ( console :: CONSOLE
    , timer :: TIMER
    , testOutput :: TESTOUTPUT
    , avar :: AVAR
    , ref :: REF
    , stream :: STREAM
    | e
    )
    Unit
main = runTest do
  suite "Factories" do
    test "create" do
      s <- liftEff $ create
        { start: \l -> do
            l.next 1
            l.complete unit
        , stop: \_ -> pure unit
        }
      expectStream [1] s
    test "create'" do
      s <- liftEff $ create' unit
      expectFailure "never emits" $ timeout 100 $ expectStream [0] s
    test "createWithMemory" do
      s <- liftEff $ createWithMemory
        { start: \l -> do
            l.next 1
            l.complete unit
        , stop: \_ -> pure unit
        }
      expectStream [1] s
    test "never" do
      expectFailure "never emits" $ timeout 100 $ expectStream [0] never
    test "mempty/Monoid mempty" do
      expectStream ([] :: Array Int) $ mempty
    test "empty/Plus empty" do
      expectStream ([] :: Array Int) $ empty
    test "throw" do
      expectFailure "should immediately fail" $ expectStream [0] $ throw $ error "throw"
    test "of/Applicative pure" do
      expectStream [1] $ pure 1
    test "fromArray" do
      expectStream [1,2,3] $ fromArray [1,2,3]
    test "periodic" do
      s <- liftEff $ take 3 <$> periodic 1
      expectStream [0,1,2] s
    test "merge/Alt <|> (alt)" do
      expectStream [1,2,3,4,5,6]
        $ fromArray [1,2]
        <|> fromArray [3,4]
        <|> fromArray [5,6]
    test "combine" do
      expectStream [[1,2,3]]
        $ (\a b c -> [a,b,c])
        <$> pure 1
        <*> pure 2
        <*> pure 3
    test "fromAff" do
      s <- liftEff $ fromAff $ makeAff \reject success -> callback success
      expectStream [1] s
    test "fromCallback" do
      s <- liftEff $ fromCallback callback
      expectStream [1] $ take 1 s
  suite "Methods and Operators" do
    test "map/Functor <$> (map)" do
      expectStream [1,2,3] $ (_ - 1) <$> fromArray [2,3,4]
    test "mapTo" do
      expectStream [1,1,1] $ mapTo 1 $ fromArray [1,2,3]
    test "filter" do
      expectStream [1,2] $ filter (_ < 3) $ fromArray [1,2,3]
    test "take" do
      expectStream [1,2] $ take 2 $ fromArray [1,2,3]
    test "drop" do
      expectStream [3] $ drop 2 $ fromArray [1,2,3]
    test "last" do
      expectStream [3] $ last $ fromArray [1,2,3]
    test "startWith" do
      expectStream [0,1,2,3] $ startWith 0 $ fromArray [1,2,3]
    test "endWhen" do
      expectStream [] $ endWhen (fromArray [1]) (fromArray [1,2,3])
    test "fold" do
      expectStream [0,1,3,6] $ fold (+) 0 $ fromArray [1,2,3]
    test "replaceError" do
      expectStream [1] $ replaceError (pure $ pure 1) $ throw $ error "throw"
    test "flatten" do
      expectStream [1,10,2,20,3,30] $ flatten $ (\x -> fromArray $ [x,x*10]) <$> fromArray [1,2,3]
    test "remember" do
      let s = remember $ fromArray [1,2,3]
      expectStream [1,2,3] s
      later' 10 $ expectStream [1,2,3] s
    test "imitate with regular Streams" do
      proxy <- liftEff $ create' unit
      let s1 = (_ * 10) <$> take 3 proxy
      s2 <- liftEff $ delay 1 $ startWith 1 $ (_ + 1) <$> s1
      result <- liftEff $ proxy `imitate` s2
      case result of
        Right _ -> expectStream [1, 11, 111, 1111] s2
        Left e -> failure $ show e
    test "imitate with a Memory Stream" do
      proxy <- liftEff $ create' unit
      let s1 = (_ * 10) <$> take 3 proxy
      let s2 = startWith 1 $ (_ + 1) <$> s1
      result <- liftEff $ proxy `imitate` s2
      case result of
        Right _ -> failure "this will blow up, thanks Andre"
        Left e -> success
  suite "Extras" do
    test "concat/Semigroup <> (append)" do
      expectStream [1,2,3,4,5,6] $ fromArray [1,2] <> fromArray [3,4] <> fromArray [5,6]
    test "delay" do
      s <- liftEff $ delay 10 $ fromArray [1,2,3]
      expectStream [1,2,3] s
    test "flattenConcurrently/flatMap/Bind~Monad >>= (bind)" do
      expectStream [1,2,2,3,3,4] $ fromArray [1,2,3] >>= (\x -> fromArray $ [x,x+1])
    test "switchMap" do
      expectStream [1,2,2,3,3,4] $ fromArray [1,2,3] `switchMap` (\x -> fromArray $ [x,x+1])
  suite "Effectful Operators" do
    test "flattenEff" do
      let s1 = (\x -> pure $ fromArray [x,x+1]) <$> fromArray [1,2,3]
      s2 <- liftEff $ flattenEff s1
      expectStream [1,2,2,3,3,4] $ s2
    test "bindEff" do
      s <- liftEff $ bindEff (fromArray [1,2,3]) $ (\x -> pure $ fromArray [x,x+1])
      expectStream [1,2,2,3,3,4] s
    test "switchMap" do
      s <- liftEff $ (fromArray [1,2,3]) `switchMapEff` (\x -> pure $ fromArray [x,x+1])
      expectStream [1,2,2,3,3,4] s
