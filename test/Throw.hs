{-# LANGUAGE RankNTypes, ScopedTypeVariables, TypeApplications #-}
module Throw
( tests
, gen
, throwTests
) where

import qualified Control.Carrier.Throw.Either as ThrowC
import Control.Effect.Throw
import Hedgehog
import Hedgehog.Function
import Pure
import Test.Tasty
import Test.Tasty.Hedgehog

tests :: TestTree
tests = testGroup "Throw" $
  [ testGroup "ThrowC" $ throwTests ThrowC.runThrow
  ] where
  throwTests :: Has (Throw E) sig m => (forall a . m a -> PureC (Either E a)) -> [TestTree]
  throwTests run = Throw.throwTests run (genM (gen e)) e a b


gen :: Has (Throw e) sig m => Gen e -> (forall a . Gen a -> Gen (m a)) -> Gen a -> Gen (m a)
gen e _ _ = throwError <$> e


throwTests :: forall e m a b sig . (Has (Throw e) sig m, Arg a, Eq b, Eq e, Show a, Show b, Show e, Vary a) => (forall a . m a -> PureC (Either e a)) -> (forall a . Gen a -> Gen (With (m a))) -> Gen e -> Gen a -> Gen b -> [TestTree]
throwTests runThrow m e _ b =
  [ testProperty "throwError annihilation" . forall (e :. fn @a (m b) :. Nil) $
    \ e k -> throwError_annihilation (~=) runThrow e (getWith . apply k)
  ]
