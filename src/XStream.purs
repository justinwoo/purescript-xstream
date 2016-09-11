module Control.XStream
  ( Listener
  , Producer
  , Stream
  , STREAM
  , EffS
  , addListener
  , bindEff
  , create
  , create'
  , createWithMemory
  , defaultListener
  , delay
  , drop
  , endWhen
  , filter
  , flatten
  , flattenEff
  , fold
  , fromArray
  , imitate
  , last
  , mapTo
  , never
  , periodic
  , startWith
  , remember
  , replaceError
  , take
  , throw
  ) where

import Prelude
import Control.Alt (class Alt)
import Control.Monad.Eff (Eff)
import Control.Monad.Eff.Console (CONSOLE, log)
import Control.Monad.Eff.Exception (Error, message)
import Control.Monad.Eff.Timer (TIMER)
import Control.Plus (class Plus)
import Data.Function.Uncurried (Fn2, Fn3, runFn2, runFn3)

foreign import data Stream :: * -> *

instance functorStream :: Functor Stream where
  map = runFn2 _map

instance applyStream :: Apply Stream where
  apply = runFn3 _combine id

instance applicativeStream :: Applicative Stream where
  pure = _of

instance bindStream :: Bind Stream where
  bind = runFn2 _flatMap

instance monadStream :: Monad Stream

instance semigroupStream :: Semigroup (Stream a) where
  append = runFn2 _concat

instance altStream :: Alt Stream where
  alt = runFn2 _merge

instance plusStream :: Plus Stream where
  empty = _empty

foreign import data STREAM :: !

type EffS e a = Eff (stream :: STREAM | e) a

type Listener e a =
  { next :: a -> EffS e Unit
  , error :: Error -> EffS e Unit
  , complete :: Unit -> EffS e Unit
  }

type Producer e a =
  { start :: Listener e a -> EffS e Unit
  , stop :: Unit -> EffS e Unit
  }

defaultListener :: forall e a. Listener (console :: CONSOLE | e) a
defaultListener =
  { next: unsafeLog
  , error: message >>> log
  , complete: pure
  }

addListener :: forall e a. Listener e a -> Stream a -> EffS e Unit
addListener l s =
  runFn2 _addListener l s

bindEff :: forall e a b. Stream a -> (a -> EffS e (Stream b)) -> EffS e (Stream b)
bindEff s effP = runFn2 _flatMapEff s effP

delay :: forall e a. Int -> Stream a -> EffS (timer :: TIMER | e) (Stream a)
delay i s = runFn2 _delay i s

drop :: forall a. Int -> Stream a -> Stream a
drop i s = runFn2 _drop s i

endWhen :: forall a b. Stream b -> Stream a -> Stream b
endWhen s1 s2 = runFn2 _endWhen s1 s2

filter :: forall a. (a -> Boolean) -> Stream a -> Stream a
filter p s = runFn2 _filter s p

fold :: forall a b. Stream a -> (b -> a -> b) -> b -> Stream b
fold s p x = runFn3 _fold s p x

imitate :: forall e a. Stream a -> Stream a -> EffS e Unit
imitate s1 s2 = runFn2 _imitate s1 s2

last :: forall a. Stream a -> Stream a
last s = _last s

mapTo :: forall a b. b -> Stream a -> Stream b
mapTo v s = runFn2 _mapTo s v

startWith :: forall a. a -> Stream a -> Stream a
startWith x s = runFn2 _startWith s x

replaceError :: forall a. (Error -> Stream a) -> Stream a -> Stream a
replaceError p s = runFn2 _replaceError s p

take :: forall a. Int -> Stream a -> Stream a
take i s = runFn2 _take s i

foreign import _addListener :: forall e a. Fn2 (Listener e a) (Stream a) (EffS e Unit)
foreign import _combine :: forall a b c. Fn3 (a -> b -> c) (Stream a) (Stream b) (Stream c)
foreign import _concat :: forall a. Fn2 (Stream a) (Stream a) (Stream a)
foreign import _delay :: forall e a. Fn2 Int (Stream a) (EffS (timer :: TIMER | e) (Stream a))
foreign import _drop :: forall a. Fn2 (Stream a) Int (Stream a)
foreign import _empty :: forall a. Stream a
foreign import _endWhen :: forall a b. Fn2 (Stream a) (Stream b) (Stream a)
foreign import _filter :: forall a. Fn2 (Stream a) (a -> Boolean) (Stream a)
foreign import _flatMap :: forall a b. Fn2 (Stream a) (a -> Stream b) (Stream b)
foreign import _flatMapEff :: forall e a b. Fn2 (Stream a) (a -> EffS e (Stream b)) (EffS e (Stream b))
foreign import _fold :: forall a b. Fn3 (Stream a) (b -> a -> b) b (Stream b)
foreign import _imitate :: forall e a. Fn2 (Stream a) (Stream a) (EffS e Unit)
foreign import _last :: forall a. Stream a -> Stream a
foreign import _map :: forall a b. Fn2 (a -> b) (Stream a) (Stream b)
foreign import _mapTo :: forall a b. Fn2 (Stream a) b (Stream b)
foreign import _merge :: forall a. Fn2 (Stream a) (Stream a) (Stream a)
foreign import _of :: forall a. a -> Stream a
foreign import _startWith :: forall a. Fn2 (Stream a) a (Stream a)
foreign import _replaceError :: forall a. Fn2 (Stream a) (Error -> Stream a) (Stream a)
foreign import _take :: forall a. Fn2 (Stream a) Int (Stream a)
foreign import create :: forall e a. Producer e a -> EffS e (Stream a)
-- | for creating a `Stream` without a producer. Used for `imitate`.
foreign import create' :: forall e a. Unit -> EffS e (Stream a)
foreign import createWithMemory :: forall e a. Producer e a -> EffS e (Stream a)
foreign import flatten :: forall a. Stream (Stream a) -> Stream a
foreign import flattenEff :: forall e a. Stream (Eff e (Stream a)) -> EffS e (Stream a)
foreign import fromArray :: forall a. Array a -> Stream a
foreign import never :: forall a. Stream a
foreign import periodic :: forall e. Int -> EffS (timer :: TIMER | e) (Stream Int)
foreign import remember :: forall a. Stream a -> Stream a
foreign import throw :: forall a. Error -> Stream a
foreign import unsafeLog :: forall e a. a -> EffS e Unit
