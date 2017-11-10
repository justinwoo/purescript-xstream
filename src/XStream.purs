module Control.XStream
  ( Listener
  , Producer
  , Stream
  , Subscription
  , STREAM
  , EffS
  , EffProducer
  , EffListener
  , adaptListener
  , addListener
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
import Control.Monad.Eff (Eff, kind Effect)
import Control.Monad.Eff.Console (CONSOLE, log)
import Control.Monad.Eff.Exception (Error, message, try)
import Control.Monad.Eff.Timer (TIMER)
import Control.Monad.Eff.Uncurried (EffFn1, EffFn2, mkEffFn1, runEffFn1, runEffFn2)
import Control.Plus (class Plus)
import Data.Either (Either)
import Data.Function.Uncurried (Fn2, Fn3, runFn2, runFn3)
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
  { next :: a -> Eff e Unit
  , error :: Error -> Eff e Unit
  , complete :: Unit -> Eff e Unit
  }

type EffListener e a =
  { next :: EffFn1 e a Unit
  , error :: EffFn1 e Error Unit
  , complete :: EffFn1 e Unit Unit
  }

type Producer e a =
  { start :: Listener e a -> Eff e Unit
  , stop :: Unit -> Eff e Unit
  }

type EffProducer e a =
  { start :: EffFn1 e (EffListener e a) Unit
  , stop :: EffFn1 e Unit Unit
  }

defaultListener :: forall e a. Listener (console :: CONSOLE | e) a
defaultListener =
  { next: runEffFn1 unsafeLog
  , error:  message >>> log
  , complete: pure
  }

addListener :: forall e a. Listener e a -> Stream a -> Eff e Unit
addListener l s =
   _addListener' (adaptListener l) s
   where
     _addListener' = runEffFn2 _addListener

-- | To cancel a `subscription` use `cancelSubscription`.
subscribe :: forall e a. Listener e a -> Stream a -> Eff e Subscription
subscribe l s =
  _subscribe' (adaptListener l) s
  where
    _subscribe' = runEffFn2 _subscribe

cancelSubscription :: forall e. Subscription -> Eff e Unit
cancelSubscription = runEffFn1 _cancelSubscription

-- | Like `bind`/`>>=`, but for effects.
bindEff :: forall e a b. Stream a -> (a -> Eff e (Stream b)) -> Eff e (Stream b)
bindEff s effP = runEffFn2 _flatMapEff (mkEffFn1 effP) s

delay :: forall e a. Int -> Stream a -> Eff (timer :: TIMER | e) (Stream a)
delay = runEffFn2 _delay

drop :: forall a. Int -> Stream a -> Stream a
drop = runFn2 _drop

endWhen :: forall a b. Stream b -> Stream a -> Stream b
endWhen s1 s2 = runFn2 _endWhen s1 s2

filter :: forall a. (a -> Boolean) -> Stream a -> Stream a
filter p s = runFn2 _filter s p

fold :: forall a b. (b -> a -> b) -> b -> Stream a -> Stream b
fold p x s = runFn3 _fold p x s

imitate :: forall e a. Stream a -> Stream a -> Eff e (Either Error Unit)
imitate s1 s2 = try $ runEffFn2 _imitate s1 s2

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
switchMapEff :: forall e a b. Stream a -> (a -> Eff e (Stream b)) -> Eff e (Stream b)
switchMapEff s effP = runEffFn2 _flatMapLatestEff (mkEffFn1 effP) s

replaceError :: forall a. (Error -> Stream a) -> Stream a -> Stream a
replaceError p s = runFn2 _replaceError s p

take :: forall a. Int -> Stream a -> Stream a
take = runFn2 _take

-- | Hacky 'hidden' method for sending `next` to a Stream like with Subjects.
-- | This may only work with streams created with `create'`.
shamefullySendNext :: forall e a. a -> Stream a -> Eff e Unit
shamefullySendNext = runEffFn2 _shamefullySendNext

shamefullySendError :: forall e a. Error -> Stream a -> Eff e Unit
shamefullySendError = runEffFn2 _shamefullySendError

shamefullySendComplete :: forall e a. Unit -> Stream a -> Eff e Unit
shamefullySendComplete = runEffFn2 _shamefullySendComplete

create :: forall e a. Producer e a -> Eff e (Stream a)
create p =
  _create' p'
  where
    p' =
      { start: mkEffFn1 (\l -> p.start (reverseListener l))
      , stop: mkEffFn1 p.stop
      }
    _create' = runEffFn1 _create

create' :: forall e a. Eff e (Stream a)
create' = runEffFn1 __create unit

createWithMemory :: forall e a. Producer e a -> Eff e (Stream a)
createWithMemory p =
  _createWithMemory' p'
  where
    p' =
      { start: mkEffFn1 (\l -> p.start (reverseListener l))
      , stop: mkEffFn1 p.stop
      }
    _createWithMemory' = runEffFn1 _createWithMemory

-- | create a `Stream` from a callback
fromCallback :: forall e a b. ((a -> Eff e Unit) -> Eff e b) -> Eff e (Stream a)
fromCallback cb =
  create $
    { start: \l -> void $ cb l.next
    , stop: const $ pure unit
    }

periodic :: forall e. Int -> Eff (timer :: TIMER | e) (Stream Int)
periodic = runEffFn1 _periodic

flattenEff :: forall e a. Stream (Eff e (Stream a)) -> Eff e (Stream a)
flattenEff = runEffFn1 _flattenEff

foreign import _addListener :: forall e a. EffFn2 e (EffListener e a) (Stream a) Unit
foreign import _subscribe :: forall e a. EffFn2 e (EffListener e a) (Stream a) Subscription
foreign import _cancelSubscription :: forall e. EffFn1 e Subscription Unit
foreign import _combine :: forall a b c. Fn3 (a -> b -> c) (Stream a) (Stream b) (Stream c)
foreign import _concat :: forall a. Fn2 (Stream a) (Stream a) (Stream a)
foreign import _delay :: forall e a. EffFn2 (timer :: TIMER | e) Int (Stream a) (Stream a)
foreign import _drop :: forall a. Fn2 Int (Stream a) (Stream a)
foreign import _empty :: forall a. Stream a
foreign import _endWhen :: forall a b. Fn2 (Stream a) (Stream b) (Stream a)
foreign import _filter :: forall a. Fn2 (Stream a) (a -> Boolean) (Stream a)
foreign import _flatMap :: forall a b. Fn2 (Stream a) (a -> Stream b) (Stream b)
foreign import _flatMapEff :: forall e a b. EffFn2 e (EffFn1 e a (Stream b)) (Stream a) (Stream b)
foreign import _flatMapLatest :: forall a b. Fn2 (Stream a) (a -> Stream b) (Stream b)
foreign import _flatMapLatestEff :: forall e a b. EffFn2 e (EffFn1 e a (Stream b)) (Stream a) (Stream b)
foreign import _fold :: forall a b. Fn3 (b -> a -> b) b (Stream a) (Stream b)
foreign import _imitate :: forall e a. EffFn2 e (Stream a) (Stream a) Unit
foreign import _last :: forall a. Stream a -> Stream a
foreign import _map :: forall a b. Fn2 (a -> b) (Stream a) (Stream b)
foreign import _mapTo :: forall a b. Fn2 (Stream a) b (Stream b)
foreign import _merge :: forall a. Fn2 (Stream a) (Stream a) (Stream a)
foreign import _of :: forall a. a -> Stream a
foreign import _startWith :: forall a. Fn2 (Stream a) a (Stream a)
foreign import _replaceError :: forall a. Fn2 (Stream a) (Error -> Stream a) (Stream a)
foreign import _take :: forall a. Fn2 Int (Stream a) (Stream a)
foreign import _create :: forall e a. EffFn1 e (EffProducer e a) (Stream a)
-- | for creating a `Stream` without a producer. Used for `imitate`.
foreign import __create :: forall e a. EffFn1 e Unit (Stream a)
foreign import _createWithMemory :: forall e a. EffFn1 e (EffProducer e a) (Stream a)
foreign import flatten :: forall a. Stream (Stream a) -> Stream a
foreign import _flattenEff :: forall e a. EffFn1 e (Stream (Eff e (Stream a))) (Stream a)
foreign import fromArray :: forall a. Array a -> Stream a
foreign import never :: forall a. Stream a
foreign import _periodic :: forall e. EffFn1 (timer :: TIMER | e) Int (Stream Int)
foreign import remember :: forall a. Stream a -> Stream a
foreign import throw :: forall a. Error -> Stream a
foreign import unsafeLog :: forall e a. EffFn1 e a Unit
foreign import _shamefullySendNext :: forall e a. EffFn2 e a (Stream a) Unit
foreign import _shamefullySendError :: forall e a. EffFn2 e Error (Stream a) Unit
foreign import _shamefullySendComplete :: forall e a. EffFn2 e Unit (Stream a) Unit
foreign import adaptListener :: forall e a. Listener e a -> EffListener e a
foreign import reverseListener :: forall e a. EffListener e a -> Listener e a
