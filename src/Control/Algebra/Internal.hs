{-# LANGUAGE DeriveFunctor, DeriveGeneric, ExistentialQuantification, KindSignatures, StandaloneDeriving, TypeOperators #-}
module Control.Algebra.Internal
( -- * Effects
  Catch(..)
, Choose(..)
, Empty(..)
, Lift(..)
, NonDet
) where

import Control.Effect.Class
import Control.Effect.Sum ((:+:))
import GHC.Generics (Generic1)

-- | 'Catch' effects can be used alongside 'Control.Effect.Throw.Throw' to provide recoverable exceptions.
--
-- @since 1.0.0.0
data Catch e m k
  = forall b . Catch (m b) (e -> m b) (b -> m k)

deriving instance Functor m => Functor (Catch e m)

instance HFunctor (Catch e) where
  hmap f (Catch m h k) = Catch (f m) (f . h) (f . k)

instance Effect (Catch e) where
  handle state handler (Catch m h k) = Catch (handler (m <$ state)) (handler . (<$ state) . h) (handler . fmap k)


-- | @since 1.0.0.0
newtype Choose m k
  = Choose (Bool -> m k)
  deriving (Functor, Generic1)

instance HFunctor Choose
instance Effect   Choose


-- | @since 1.0.0.0
data Empty (m :: * -> *) k = Empty
  deriving (Functor, Generic1)

instance HFunctor Empty
instance Effect   Empty


-- | @since 0.1.0.0
newtype Lift sig m k = Lift { unLift :: sig (m k) }
  deriving (Functor, Generic1)

instance Functor m => HFunctor (Lift m)
instance Functor m => Effect   (Lift m)


-- | The nondeterminism effect is the composition of 'Empty' and 'Choose' effects.
--
-- @since 0.1.0.0
type NonDet = Empty :+: Choose
