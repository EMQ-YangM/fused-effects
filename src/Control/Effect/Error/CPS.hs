{-# LANGUAGE DeriveFunctor, FlexibleInstances, MultiParamTypeClasses, RankNTypes, TypeOperators, UndecidableInstances #-}
module Control.Effect.Error.CPS
( -- * Error effect
  module Control.Effect.Error
  -- * Error carrier
, runError
, ErrorC(..)
-- * Re-exports
, Carrier
, Member
, run
) where

import Control.Applicative (Alternative (..))
import Control.Effect.Carrier
import Control.Effect.Error (Error (..), throwError, catchError)
import Control.Monad (MonadPlus)
import Control.Monad.Fail
import Control.Monad.Fix
import Control.Monad.IO.Class
import Control.Monad.Trans.Class
import Prelude hiding (fail)

-- | Run an 'Error' effect, applying the first continuation to uncaught errors and the second continuation to successful computations’ results.
--
--   prop> run (runError (pure . Left) (pure . Right) (throwError a)) === Left @Int @Int a
--   prop> run (runError (pure . Left) (pure . Right) (pure a)) === Right @Int @Int a
runError :: (e -> m b) -> (a -> m b) -> ErrorC e m a -> m b
runError h k m = runErrorC m h k
{-# INLINE runError #-}

newtype ErrorC e m a = ErrorC { runErrorC :: forall b . (e -> m b) -> (a -> m b) -> m b }
  deriving (Functor)

instance Applicative (ErrorC e m) where
  pure a = ErrorC $ \ _ k -> k a
  {-# INLINE pure #-}
  ErrorC f <*> ErrorC a = ErrorC $ \ h k -> f h (\ f' -> a h (k . f'))
  {-# INLINE (<*>) #-}
  ErrorC a1 *> ErrorC a2 = ErrorC $ \ h k -> a1 h (const (a2 h k))
  {-# INLINE (*>) #-}
  ErrorC a1 <* ErrorC a2 = ErrorC $ \ h k -> a1 h (\ a1' -> a2 h (const (k a1')))
  {-# INLINE (<*) #-}

instance Alternative m => Alternative (ErrorC e m) where
  empty = ErrorC $ \ _ _ -> empty
  {-# INLINE empty #-}
  ErrorC a <|> ErrorC b = ErrorC $ \ h k -> a h k <|> b h k
  {-# INLINE (<|>) #-}

instance Monad (ErrorC e m) where
  ErrorC a >>= f = ErrorC $ \ h k -> a h (runError h k . f)
  {-# INLINE (>>=) #-}

instance MonadFail m => MonadFail (ErrorC e m) where
  fail s = lift (fail s)
  {-# INLINE fail #-}

instance MonadFix m => MonadFix (ErrorC e m) where
  mfix f = ErrorC $ \ h k -> mfix (runError (pure . Left) (pure . Right) . either (const (error "mfix (ErrorC): function returned failure")) f) >>= either h k
  {-# INLINE mfix #-}

instance MonadIO m => MonadIO (ErrorC e m) where
  liftIO io = lift (liftIO io)
  {-# INLINE liftIO #-}

instance (Alternative m, Monad m) => MonadPlus (ErrorC e m)

instance MonadTrans (ErrorC e) where
  lift m = ErrorC $ \ _ k -> m >>= k
  {-# INLINE lift #-}

-- $
-- prop> (throwError e >>= applyFun f) ~= throwError e
-- prop> (throwError e `catchError` applyFun f) ~= applyFun f e
instance (Carrier sig m, Effect sig) => Carrier (Error e :+: sig) (ErrorC e m) where
  eff (L (Throw e))     = ErrorC $ \ h _ -> h e
  eff (L (Catch m h k)) = ErrorC $ \ h' k' -> runError (runError h' (runError h' k' . k) . h) (runError h' k' . k) m
  eff (R other)         = ErrorC $ \ h k -> eff (handle (Right ()) (either (pure . Left) (runError (pure . Left) (pure . Right))) other) >>= either h k
  {-# INLINE eff #-}


-- $setup
-- >>> :seti -XFlexibleContexts
-- >>> :seti -XFlexibleInstances
-- >>> :seti -XScopedTypeVariables
-- >>> :seti -XTypeApplications
-- >>> import Test.QuickCheck
-- >>> import Control.Effect.Pure
-- >>> import Data.Function (on)
-- >>> instance (Show e, Show a) => Show (ErrorC e PureC a) where show = show . run . runError (pure . Left) (pure . Right)
-- >>> instance (Arbitrary e, Arbitrary a) => Arbitrary (ErrorC e PureC a) where arbitrary = either (throwError @e) pure <$> arbitrary ; shrink = map (either (throwError @e) pure) . shrink . run . runError (pure . Left) (pure . Right)
-- >>> :{
-- infix 4 ~=
-- (~=) = (===) `on` run . runError @Integer (pure . Left) (pure . Right)
-- :}
