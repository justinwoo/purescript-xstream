module Control.XStream
  ( Listener
  , Producer
  , Stream
  , Subscription
  , STREAM
  , EffS
  , addListener
  , removeListener
  , subscribe
  , cancelSubscription
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
  , fromCallback
  , fromAff
  , fromArray
  , imitate
  , last
  , mapTo
  , never
  , periodic
  , shamefullySendNext
  , shamefullySendError
  , shamefullySendComplete
  , startWith
  , switchMap
  , switchMapEff
  , remember
  , replaceError
  , take
  , throw
  ) where

import Prelude
import Control.Alt (class Alt)
import Control.Monad.Aff (cancel, runAff, Aff)
import Control.Monad.Eff (Eff, kind Effect)
import Control.Monad.Eff.Class (liftEff)
import Control.Monad.Eff.Console (CONSOLE, log)
import Control.Monad.Eff.Exception (error, Error, try, message)
import Control.Monad.Eff.Ref (REF, readRef, writeRef, newRef)
import Control.Monad.Eff.Timer (TIMER)
import Control.Plus (class Plus)
import Data.Either (Either)
import Data.Function.Uncurried (Fn2, Fn3, runFn2, runFn3)
import Data.Maybe (Maybe(Just, Nothing))
import Data.Monoid (class Monoid)

foreign import data Stream :: Type -> Type

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

instance monoidStream :: Monoid (Stream a) where
  mempty = _empty

instance plusStream :: Plus Stream where
  empty = _empty

foreign import data STREAM :: Effect
foreign import data Subscription :: Type

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

removeListener :: forall e a. Listener e a -> Stream a -> EffS e Unit
removeListener l s =
  runFn2 _removeListener l s

-- | To cancel a `subscription` use `cancelSubscription`.
subscribe :: forall e a. Listener e a -> Stream a -> EffS e Subscription
subscribe l s =
  runFn2 _subscribe l s

cancelSubscription :: forall e. Subscription -> EffS e Unit
cancelSubscription = _cancelSubscription

-- | Like `bind`/`>>=`, but for effects.
bindEff :: forall e a b. Stream a -> (a -> EffS e (Stream b)) -> EffS e (Stream b)
bindEff s effP = runFn2 _flatMapEff s effP

delay :: forall e a. Int -> Stream a -> EffS (timer :: TIMER | e) (Stream a)
delay = runFn2 _delay

drop :: forall a. Int -> Stream a -> Stream a
drop = runFn2 _drop

endWhen :: forall a b. Stream b -> Stream a -> Stream b
endWhen s1 s2 = runFn2 _endWhen s1 s2

filter :: forall a. (a -> Boolean) -> Stream a -> Stream a
filter p s = runFn2 _filter s p

fold :: forall a b. (b -> a -> b) -> b -> Stream a -> Stream b
fold p x s = runFn3 _fold p x s

imitate :: forall e a. Stream a -> Stream a -> EffS e (Either Error Unit)
imitate s1 s2 = try $ runFn2 _imitate s1 s2

last :: forall a. Stream a -> Stream a
last s = _last s

mapTo :: forall a b. b -> Stream a -> Stream b
mapTo v s = runFn2 _mapTo s v

startWith :: forall a. a -> Stream a -> Stream a
startWith x s = runFn2 _startWith s x

-- | Like `bind`/`>>=`, but switches to the latest emitted source using `flatten`.
switchMap :: forall a b. Stream a -> (a -> Stream b) -> Stream b
switchMap s p = runFn2 _flatMapLatest s p

-- | Like `bindEff`, but switches to the lattest emitted source using `flatten`.
switchMapEff :: forall e a b. Stream a -> (a -> EffS e (Stream b)) -> EffS e (Stream b)
switchMapEff s effP = runFn2 _flatMapLatestEff s effP

replaceError :: forall a. (Error -> Stream a) -> Stream a -> Stream a
replaceError p s = runFn2 _replaceError s p

take :: forall a. Int -> Stream a -> Stream a
take = runFn2 _take

-- | Hacky 'hidden' method for sending `next` to a Stream like with Subjects.
-- | This may only work with streams created with `create'`.
shamefullySendNext :: forall e a. a -> Stream a -> EffS e Unit
shamefullySendNext = runFn2 _shamefullySendNext

shamefullySendError :: forall e a. Error -> Stream a -> EffS e Unit
shamefullySendError = runFn2 _shamefullySendError

shamefullySendComplete :: forall e a. Unit -> Stream a -> EffS e Unit
shamefullySendComplete = runFn2 _shamefullySendComplete

-- | create a `Stream` from a callback
fromCallback :: forall e a b. ((a -> EffS e Unit) -> EffS e b) -> EffS e (Stream a)
fromCallback cb =
  create
    { start: \l -> void $ cb l.next
    , stop: const $ pure unit
    }

-- | create a `Stream` from an Aff
fromAff :: forall a e. Aff (stream :: STREAM, ref :: REF | e) a -> Eff (stream :: STREAM, ref :: REF | e) (Stream a)
fromAff aff = do
  ref <- newRef Nothing
  create
    { start: \l -> do
        canceler <- runAff
          l.error
          (\a -> do
            l.next a
            l.complete unit)
          aff
        liftEff $ writeRef ref $ Just canceler
    , stop: \_ -> do
        mRef <- readRef ref
        case mRef of
          Just c -> void $ runAff (const $ pure unit) (const $ pure unit) $ cancel c (error "Unsubscribed")
          Nothing -> pure unit
    }

foreign import _addListener :: forall e a. Fn2 (Listener e a) (Stream a) (EffS e Unit)
foreign import _removeListener :: forall e a. Fn2 (Listener e a) (Stream a) (EffS e Unit)
foreign import _subscribe :: forall e a. Fn2 (Listener e a) (Stream a) (EffS e Subscription )
foreign import _cancelSubscription :: forall e. Subscription -> EffS e Unit
foreign import _combine :: forall a b c. Fn3 (a -> b -> c) (Stream a) (Stream b) (Stream c)
foreign import _concat :: forall a. Fn2 (Stream a) (Stream a) (Stream a)
foreign import _delay :: forall e a. Fn2 Int (Stream a) (EffS (timer :: TIMER | e) (Stream a))
foreign import _drop :: forall a. Fn2 Int (Stream a) (Stream a)
foreign import _empty :: forall a. Stream a
foreign import _endWhen :: forall a b. Fn2 (Stream a) (Stream b) (Stream a)
foreign import _filter :: forall a. Fn2 (Stream a) (a -> Boolean) (Stream a)
foreign import _flatMap :: forall a b. Fn2 (Stream a) (a -> Stream b) (Stream b)
foreign import _flatMapEff :: forall e a b. Fn2 (Stream a) (a -> EffS e (Stream b)) (EffS e (Stream b))
foreign import _flatMapLatest :: forall a b. Fn2 (Stream a) (a -> Stream b) (Stream b)
foreign import _flatMapLatestEff :: forall e a b. Fn2 (Stream a) (a -> EffS e (Stream b)) (EffS e (Stream b))
foreign import _fold :: forall a b. Fn3 (b -> a -> b) b (Stream a) (Stream b)
foreign import _imitate :: forall e a. Fn2 (Stream a) (Stream a) (EffS e Unit)
foreign import _last :: forall a. Stream a -> Stream a
foreign import _map :: forall a b. Fn2 (a -> b) (Stream a) (Stream b)
foreign import _mapTo :: forall a b. Fn2 (Stream a) b (Stream b)
foreign import _merge :: forall a. Fn2 (Stream a) (Stream a) (Stream a)
foreign import _of :: forall a. a -> Stream a
foreign import _startWith :: forall a. Fn2 (Stream a) a (Stream a)
foreign import _replaceError :: forall a. Fn2 (Stream a) (Error -> Stream a) (Stream a)
foreign import _take :: forall a. Fn2 Int (Stream a) (Stream a)
foreign import create :: forall e a. Producer e a -> EffS e (Stream a)
-- | for creating a `Stream` without a producer. Used for `imitate`.
foreign import create' :: forall e a. EffS e (Stream a)
foreign import createWithMemory :: forall e a. Producer e a -> EffS e (Stream a)
foreign import flatten :: forall a. Stream (Stream a) -> Stream a
foreign import flattenEff :: forall e a. Stream (Eff e (Stream a)) -> EffS e (Stream a)
foreign import fromArray :: forall a. Array a -> Stream a
foreign import never :: forall a. Stream a
foreign import periodic :: forall e. Int -> EffS (timer :: TIMER | e) (Stream Int)
foreign import remember :: forall a. Stream a -> Stream a
foreign import throw :: forall a. Error -> Stream a
foreign import unsafeLog :: forall e a. a -> EffS e Unit
foreign import _shamefullySendNext :: forall e a. Fn2 a (Stream a) (EffS e Unit)
foreign import _shamefullySendError :: forall e a. Fn2 Error (Stream a) (EffS e Unit)
foreign import _shamefullySendComplete :: forall e a. Fn2 Unit (Stream a) (EffS e Unit)
