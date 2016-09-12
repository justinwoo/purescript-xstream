module Control.XStream
  ( Listener
  , Producer
  , MemoryStream
  , Stream
  , STREAM
  , EffS
  , class XStream
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
  , fromAff
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
import Control.Monad.Aff (cancel, runAff, Aff)
import Control.Monad.Eff (Eff)
import Control.Monad.Eff.Class (liftEff)
import Control.Monad.Eff.Console (CONSOLE, log)
import Control.Monad.Eff.Exception (error, Error, try, message)
import Control.Monad.Eff.Ref (REF, readRef, writeRef, newRef)
import Control.Monad.Eff.Timer (TIMER)
import Control.Plus (class Plus)
import Data.Either (Either)
import Data.Function.Uncurried (Fn2, Fn3, runFn2, runFn3)
import Data.Maybe (Maybe(Just, Nothing))

foreign import data Stream :: * -> *
foreign import data MemoryStream :: * -> *

class XStream a

instance xstreamStream :: XStream (Stream a)

instance xstreamMemoryStream :: XStream (MemoryStream a)

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

instance functorMemoryStream :: Functor MemoryStream where
  map = runFn2 _map

instance applyMemoryStream :: Apply MemoryStream where
  apply = runFn3 _combine id

instance applicativeMemoryStream :: Applicative MemoryStream where
  pure = _of

instance bindMemoryStream :: Bind MemoryStream where
  bind = runFn2 _flatMap

instance monadMemoryStream :: Monad MemoryStream

instance semigroupMemoryStream :: Semigroup (MemoryStream a) where
  append = runFn2 _concat

instance altMemoryStream :: Alt MemoryStream where
  alt = runFn2 _merge

instance plusMemoryStream :: Plus MemoryStream where
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

addListener :: forall e a s. XStream (s a) => Listener e a -> s a -> EffS e Unit
addListener l s =
  runFn2 _addListener l s

bindEff :: forall e a b s. XStream (s a) => s a -> (a -> EffS e (Stream b)) -> EffS e (Stream b)
bindEff s effP = runFn2 _flatMapEff s effP

delay :: forall e a s. XStream (s a) => Int -> s a -> EffS (timer :: TIMER | e) (Stream a)
delay i s = runFn2 _delay i s

drop :: forall a s. XStream (s a) => Int -> s a -> s a
drop i s = runFn2 _drop s i

endWhen :: forall a b s. (XStream (s a), XStream (s b)) => s b -> s a -> s b
endWhen s1 s2 = runFn2 _endWhen s1 s2

filter :: forall a. (a -> Boolean) -> Stream a -> Stream a
filter p s = runFn2 _filter s p

fold :: forall a b s. (XStream (s a), XStream (s b)) => s a -> (b -> a -> b) -> b -> MemoryStream b
fold s p x = runFn3 _fold s p x

imitate :: forall e a. Stream a -> Stream a -> EffS e (Either Error Unit)
imitate s1 s2 = try $ runFn2 _imitate s1 s2

last :: forall a s. XStream (s a) => s a -> s a
last s = _last s

mapTo :: forall a b s. (XStream (s a), XStream (s b)) => b -> s a -> s b
mapTo v s = runFn2 _mapTo s v

startWith :: forall a s. XStream (s a) => a -> s a -> MemoryStream a
startWith x s = runFn2 _startWith s x

replaceError :: forall a. (Error -> Stream a) -> Stream a -> Stream a
replaceError p s = runFn2 _replaceError s p

take :: forall a. Int -> Stream a -> Stream a
take i s = runFn2 _take s i

fromAff :: forall a e. Aff (stream :: STREAM, ref :: REF | e) a -> Eff (stream :: STREAM, ref :: REF | e) (Stream a)
fromAff aff = do
  ref <- newRef Nothing
  create
    { start: \l -> do
        canceler <- runAff l.error l.next aff
        liftEff $ writeRef ref $ Just canceler
        l.complete unit
    , stop: \_ -> do
        mRef <- readRef ref
        case mRef of
          Just c -> void $ runAff (const $ pure unit) (const $ pure unit) $ cancel c (error "Unsubscribed")
          Nothing -> pure unit
    }

foreign import _addListener :: forall e a s. XStream (s a) => Fn2 (Listener e a) (s a) (EffS e Unit)
foreign import _combine :: forall a b c s. (XStream (s a), XStream (s b), XStream (s c)) => Fn3 (a -> b -> c) (s a) (s b) (s c)
foreign import _concat :: forall a s. XStream (s a) => Fn2 (s a) (s a) (s a)
foreign import _delay :: forall e a s. XStream (s a) => Fn2 Int (s a) (EffS (timer :: TIMER | e) (Stream a))
foreign import _drop :: forall a s. XStream (s a) => Fn2 (s a) Int (s a)
foreign import _empty :: forall a s. XStream (s a) => s a
foreign import _endWhen :: forall a b s. XStream (s a) => Fn2 (s a) (s b) (s a)
foreign import _filter :: forall a s. XStream (s a) => Fn2 (s a) (a -> Boolean) (s a)
foreign import _flatMap :: forall a b s. XStream (s a) => Fn2 (s a) (a -> s b) (s b)
foreign import _flatMapEff :: forall e a b s. XStream (s a) => Fn2 (s a) (a -> EffS e (Stream b)) (EffS e (Stream b))
foreign import _fold :: forall a b s. XStream (s a) => Fn3 (s a) (b -> a -> b) b (MemoryStream b)
-- | imitate explicitly does not work with `MemoryStream`s
foreign import _imitate :: forall e a. Fn2 (Stream a) (Stream a) (EffS e Unit)
foreign import _last :: forall a s. XStream (s a) => s a -> s a
foreign import _map :: forall a b s. XStream (s a) => Fn2 (a -> b) (s a) (s b)
foreign import _mapTo :: forall a b s. XStream (s a) => Fn2 (s a) b (s b)
foreign import _merge :: forall a s. XStream (s a) => Fn2 (s a) (s a) (s a)
foreign import _of :: forall a s. XStream (s a) => a -> s a
foreign import _startWith :: forall a s. XStream (s a) => Fn2 (s a) a (MemoryStream a)
foreign import _replaceError :: forall a s. XStream (s a) => Fn2 (s a) (Error -> s a) (s a)
foreign import _take :: forall a s. XStream (s a) => Fn2 (s a) Int (s a)
foreign import create :: forall e a. Producer e a -> EffS e (Stream a)
-- | for creating a `Stream` without a producer. Used for `imitate`.
foreign import create' :: forall e a. Unit -> EffS e (Stream a)
foreign import createWithMemory :: forall e a. Producer e a -> EffS e (MemoryStream a)
foreign import flatten :: forall a s. XStream (s a) => s (s a) -> Stream a
foreign import flattenEff :: forall e a s. XStream (s a) => Stream (Eff e (s a)) -> EffS e (Stream a)
foreign import fromArray :: forall a. Array a -> Stream a
foreign import never :: forall a. Stream a
foreign import periodic :: forall e. Int -> EffS (timer :: TIMER | e) (Stream Int)
foreign import remember :: forall a s. XStream (s a) => s a -> MemoryStream a
foreign import throw :: forall a. Error -> Stream a
foreign import unsafeLog :: forall e a. a -> EffS e Unit
