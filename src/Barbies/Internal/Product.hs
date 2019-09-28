{-# LANGUAGE AllowAmbiguousTypes  #-}
{-# LANGUAGE PolyKinds            #-}
{-# LANGUAGE TypeFamilies         #-}
{-# LANGUAGE UndecidableInstances #-}
module Barbies.Internal.Product
  ( ProductB(buniq, bprod)
  , bzip, bunzip, bzipWith, bzipWith3, bzipWith4

  , CanDeriveProductB
  , GProductB(..)
  , gbprodDefault, gbuniqDefault
  )

where

import Barbies.Internal.Functor (FunctorB (..))

import Data.Functor.Product (Product (..))
import Data.Kind            (Type)
import Data.Proxy           (Proxy (..))

import Data.Generics.GenericN


-- | Barbie-types that can form products, subject to the laws:
--
-- @
-- 'bmap' (\\('Pair' a _) -> a) . 'uncurry' 'bprod' = 'fst'
-- 'bmap' (\\('Pair' _ b) -> b) . 'uncurry' 'bprod' = 'snd'
-- @
--
-- Notice that because of the laws, having an internal product structure is not
-- enough to have a lawful instance. E.g.
--
-- @
-- data Ok  f = Ok {o1 :: f 'String', o2 :: f 'Int'}
-- data Bad f = Bad{b1 :: f 'String', hiddenFromArg: 'Int'} -- no lawful instance
-- @
--
-- Intuitively, the laws for this class require that `b` hides no structure
-- from its argument @f@. Because of this, if we are given any:
--
-- @
-- x :: forall a . f a
-- @
--
-- then this determines a unique value of type @b f@, witnessed by the 'buniq'
-- method.
-- For example:
--
-- @
-- 'buniq' x = Ok {o1 = x, o2 = x}
-- @
--
-- Formally, 'buniq' should satisfy:
--
-- @
-- 'const' ('buniq' x) = 'bmap' ('const' x)
-- @
--
-- There is a default implementation of 'bprod' and 'buniq' for 'Generic' types,
-- so instances can derived automatically.
class FunctorB b => ProductB (b :: (k -> Type) -> Type) where
  bprod :: b f -> b g -> b (f `Product` g)

  buniq :: (forall a . f a) -> b f

  default bprod :: CanDeriveProductB b f g => b f -> b g -> b (f `Product` g)
  bprod = gbprodDefault

  default buniq :: CanDeriveProductB b f f => (forall a . f a) -> b f
  buniq = gbuniqDefault


-- | An alias of 'bprod', since this is like a 'zip' for Barbie-types.
bzip :: ProductB b => b f -> b g -> b (f `Product` g)
bzip = bprod

-- | An equivalent of 'unzip' for Barbie-types.
bunzip :: ProductB b => b (f `Product` g) -> (b f, b g)
bunzip bfg = (bmap (\(Pair a _) -> a) bfg, bmap (\(Pair _ b) -> b) bfg)

-- | An equivalent of 'Data.List.zipWith' for Barbie-types.
bzipWith :: ProductB b => (forall a. f a -> g a -> h a) -> b f -> b g -> b h
bzipWith f bf bg
  = bmap (\(Pair fa ga) -> f fa ga) (bf `bprod` bg)

-- | An equivalent of 'Data.List.zipWith3' for Barbie-types.
bzipWith3
  :: ProductB b
  => (forall a. f a -> g a -> h a -> i a)
  -> b f -> b g -> b h -> b i
bzipWith3 f bf bg bh
  = bmap (\(Pair (Pair fa ga) ha) -> f fa ga ha)
         (bf `bprod` bg `bprod` bh)


-- | An equivalent of 'Data.List.zipWith4' for Barbie-types.
bzipWith4
  :: ProductB b
  => (forall a. f a -> g a -> h a -> i a -> j a)
  -> b f -> b g -> b h -> b i -> b j
bzipWith4 f bf bg bh bi
  = bmap (\(Pair (Pair (Pair fa ga) ha) ia) -> f fa ga ha ia)
         (bf `bprod` bg `bprod` bh `bprod` bi)


-- | @'CanDeriveProductB' B f g@ is in practice a predicate about @B@ only.
--   Intuitively, it says that the following holds, for any arbitrary @f@:
--
--     * There is an instance of @'Generic' (B f)@.
--
--     * @B@ has only one constructor (that is, it is not a sum-type).
--
--     * Every field of @B f@ is of the form @f a@, for some type @a@.
--       In other words, @B@ has no "hidden" structure.
type CanDeriveProductB b f g
  = ( GenericN (b f)
    , GenericN (b g)
    , GenericN (b (f `Product` g))
    , GProductB f g (RepN (b f)) (RepN (b g)) (RepN (b (f `Product` g)))
    )


-- ======================================
-- Generic derivation of instances
-- ======================================

-- | Default implementation of 'bprod' based on 'Generic'.
gbprodDefault
  :: forall b f g
  .  CanDeriveProductB b f g
  => b f -> b g -> b (f `Product` g)
gbprodDefault l r
  = toN $ gbprod (Proxy @f) (Proxy @g) (fromN l) (fromN r)
{-# INLINE gbprodDefault #-}

gbuniqDefault:: forall b f . CanDeriveProductB b f f => (forall a . f a) -> b f
gbuniqDefault x
  = toN $ gbuniq (Proxy @f) (Proxy @(RepN (b f))) (Proxy @(RepN (b (f `Product` f)))) x
{-# INLINE gbuniqDefault #-}

class GProductB (f :: k -> *) (g :: k -> *) repbf repbg repbfg where
  gbprod :: Proxy f -> Proxy g -> repbf x -> repbg x -> repbfg x

  gbuniq :: (f ~ g, repbf ~ repbg) => Proxy f -> Proxy repbf -> Proxy repbfg -> (forall a . f a) -> repbf x

-- ----------------------------------
-- Trivial cases
-- ----------------------------------

instance GProductB f g repf repg repfg => GProductB f g (M1 i c repf)
                                                        (M1 i c repg)
                                                        (M1 i c repfg) where
  gbprod pf pg (M1 l) (M1 r) = M1 (gbprod pf pg l r)
  {-# INLINE gbprod #-}

  gbuniq pf _ _ x = M1 (gbuniq pf (Proxy @repf) (Proxy @repfg) x)
  {-# INLINE gbuniq #-}


instance GProductB f g U1 U1 U1 where
  gbprod _ _ U1 U1 = U1
  {-# INLINE gbprod #-}

  gbuniq _ _ _ _ = U1
  {-# INLINE gbuniq #-}

instance
  ( GProductB f g lf lg lfg
  , GProductB f g rf rg rfg
  ) => GProductB f g (lf  :*: rf)
                     (lg  :*: rg)
                     (lfg :*: rfg) where
  gbprod pf pg (l1 :*: l2) (r1 :*: r2)
    = (l1 `lprod` r1) :*: (l2 `rprod` r2)
    where
      lprod = gbprod pf pg
      rprod = gbprod pf pg
  {-# INLINE gbprod #-}

  gbuniq pf _ _ x = (gbuniq pf (Proxy @lf) (Proxy @lfg) x :*: gbuniq pf (Proxy @rf) (Proxy @rfg) x)
  {-# INLINE gbuniq #-}

-- --------------------------------
-- The interesting cases
-- --------------------------------

type P0 = Param 0

instance GProductB f g (Rec (P0 f a) (f a))
                       (Rec (P0 g a) (g a))
                       (Rec (P0 (f `Product` g) a) ((f `Product` g) a)) where
  gbprod _ _ (Rec (K1 fa)) (Rec (K1 ga))
    = Rec (K1 (Pair fa ga))
  {-# INLINE gbprod #-}

  gbuniq _ _ _ x = Rec (K1 x)
  {-# INLINE gbuniq #-}


instance
  ( SameOrParam b b'
  , ProductB b'
  ) => GProductB f g (Rec (b (P0 f)) (b' f))
                     (Rec (b (P0 g)) (b' g))
                     (Rec (b (P0 (f `Product` g))) (b' (f `Product` g))) where
  gbprod _ _ (Rec (K1 bf)) (Rec (K1 bg))
    = Rec (K1 (bf `bprod` bg))
  {-# INLINE gbprod #-}

  gbuniq _ _ _ x = Rec (K1 (buniq x))
  {-# INLINE gbuniq #-}


-- --------------------------------
-- Instances for base types
-- --------------------------------

instance ProductB Proxy where
  bprod _ _ = Proxy
  {-# INLINE bprod #-}

  buniq _ = Proxy
  {-# INLINE buniq #-}

instance (ProductB a, ProductB b) => ProductB (Product a b) where
  bprod (Pair ll lr) (Pair rl rr) = Pair (bprod ll rl) (bprod lr rr)
  {-# INLINE bprod #-}

  buniq x = Pair (buniq x) (buniq x)
  {-# INLINE buniq #-}
