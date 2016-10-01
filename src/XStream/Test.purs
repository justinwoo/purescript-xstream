module Control.XStream.Test
  ( arrayFromStream
  , expectStream
  ) where

import Prelude
import Control.Alternative (empty, (<|>))
import Control.Apply ((<*>))
import Control.Monad.Aff (Aff, makeAff)
import Control.Monad.Aff.Console (CONSOLE)
import Control.Monad.Eff.Ref (REF, readRef, modifyRef, newRef)
import Control.XStream (STREAM, Stream, addListener)
import Data.Array (snoc)
import Test.Unit (Test)
import Test.Unit.Assert (equal)

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
