{-# LANGUAGE OverloadedStrings #-}
-----------------------------------------------------------------------------
-- |
-- Module      :  Text.Show.Text
-- Copyright   :  (C) 2014 Ryan Scott
-- License     :  BSD-style (see the file LICENSE)
-- Maintainer  :  Ryan Scott
-- Stability   :  Experimental
-- Portability :  GHC
-- 
-- Efficiently convert from values to 'Text' via 'Builder's.
----------------------------------------------------------------------------
module Text.Show.Text (
      -- * The 'Show' class
      Show (..)
    , show
      -- * 'Builder' construction
    , showbParen
    , showbLitChar
    , showbLitString
    , unlinesB
    , unwordsB
      -- * Printing values
    , print
    ) where

import           Data.Array
import           Data.Int
import           Data.Complex
import qualified Data.Map as M
import           Data.Map (Map)
import           Data.Monoid
import           Data.Ratio
import qualified Data.Set as S
import           Data.Set (Set)
import           Data.Text (Text)
import           Data.Text.Buildable (build)
import           Data.Text.IO
import           Data.Text.Lazy (toStrict)
import           Data.Text.Lazy.Builder (Builder, toLazyText)
import           Data.Text.Lazy.Builder.RealFloat
import           Data.Word

import           Foreign.Ptr

import           Prelude hiding (Show(..), print, putStrLn)

import           Text.Show.Text.Char
-- import           Text.Show.Text.Integer
import           Text.Show.Text.Util

-- | Conversion of values to 'Text'.
class Show a where
    -- |
    -- Constructs a 'Text' via an efficient 'Builder'. The precedence is used to 
    -- determine where to put parentheses in a shown expression involving operators.
    -- 
    -- 'Builder's can be efficiently combined, so the @showb@ functions are available
    -- for showing multiple values before producing an output 'Text'.
    showbPrec :: Int -> a -> Builder
    
    -- |
    -- Constructs a 'Text' via an efficient 'Builder'. 'Builder's can be efficiently
    -- combined, so this is available building a 'Text' from multiple values.
    showb :: a -> Builder
    
    -- |
    -- Allows for specialized display of lists. This is used, for example, when
    -- showing lists of 'Char's.
    showbList :: [a] -> Builder
    
    showbPrec _ = showb
    
    showb = showbPrec 0
    
    showbList []     = "[]"
    showbList (x:xs) = s '[' <> showb x <> go xs -- "[..
      where
        go (y:ys) = s ',' <> showb y <> go ys    -- ..,..
        go []     = s ']'                        -- ..]"
    {-# MINIMAL showbPrec | showb #-}

-- | Constructs a 'Text' from a single value.
show :: Show a => a -> Text
show = toStrict . toLazyText . showb

-- | Surrounds 'Builder' output with parentheses if the 'Bool' parameter is 'True'.
showbParen :: Bool -> Builder -> Builder
showbParen p builder | p         = s '(' <> builder <> s ')'
                     | otherwise = builder

-- | Prints a value's 'Text' representation to the standard output.
print :: Show a => a -> IO ()
print = putStrLn . show

-- | Merges several 'Builder's, separating them by newlines.
unlinesB :: [Builder] -> Builder
unlinesB (b:bs) = b <> s '\n' <> unlinesB bs
unlinesB []     = mempty

-- | Merges several 'Builder's, separating them by spaces.
unwordsB :: [Builder] -> Builder
unwordsB (b:bs@(_:_)) = b <> s ' ' <> unwordsB bs
unwordsB [b]          = b
unwordsB []           = mempty

instance Show Builder where
    showb = id

instance Show () where
    showb () = "()"

instance Show Char where
    showb '\'' = "'\\''"
    showb c    = s '\'' <> showbLitChar c <> s '\''
    {-# INLINE showb #-}
    
    showbList = build
    {-# INLINE showbList #-}

instance Show Bool where
    showb True  = "True"
    showb False = "False"

instance Show a => Show [a] where
    showb = showbList
    {-# INLINE showb #-}

instance Show Int where
    showb = build
    {-# INLINE showb #-}
    
    showbPrec k i = showbParen (i < 0 && k > 0) $ build i
    {-# INLINE showbPrec #-}

instance Show Int8 where
    showb = build
    {-# INLINE showb #-}
    
    showbPrec k i = showbParen (i < 0 && k > 0) $ build i
    {-# INLINE showbPrec #-}

instance Show Int16 where
    showb = build
    {-# INLINE showb #-}
    
    showbPrec k i = showbParen (i < 0 && k > 0) $ build i
    {-# INLINE showbPrec #-}

instance Show Int32 where
    showb = build
    {-# INLINE showb #-}
    
    showbPrec k i = showbParen (i < 0 && k > 0) $ build i
    {-# INLINE showbPrec #-}

instance Show Int64 where
    showb = build
    {-# INLINE showb #-}
    
    showbPrec k i = showbParen (i < 0 && k > 0) $ build i
    {-# INLINE showbPrec #-}

instance Show Integer where
    showb = build
    {-# INLINE showb #-}
    
    showbPrec k i = showbParen (i < 0 && k > 0) $ build i
    {-# INLINE showbPrec #-}

instance Show Word where
    showb = build
    {-# INLINE showb #-}

instance Show Word8 where
    showb = build
    {-# INLINE showb #-}

instance Show Word16 where
    showb = build
    {-# INLINE showb #-}

instance Show Word32 where
    showb = build
    {-# INLINE showb #-}

instance Show Word64 where
    showb = build
    {-# INLINE showb #-}

instance Show Float where
    showb = realFloat
    {-# INLINE showb #-}
    
    showbPrec k f = showbParen (f < 0 && k > 0) $ realFloat f
    {-# INLINE showbPrec #-}

instance Show Double where
    showb = realFloat
    {-# INLINE showb #-}
    
    showbPrec k f = showbParen (f < 0 && k > 0) $ realFloat f
    {-# INLINE showbPrec #-}

instance (Show a, Integral a) => Show (Ratio a) where
    {-# SPECIALIZE instance Show Rational #-}
    showbPrec k q = showbParen (k > 7) $ showbPrec 8 (numerator q) <>
                    s '%' <> showb (denominator q)

instance (Show a, RealFloat a) => Show (Complex a) where
    {-# SPECIALIZE instance Show (Complex Float) #-}
    {-# SPECIALIZE instance Show (Complex Double) #-}
    showbPrec k (a :+ b) = showbParen (k > 6) $ showbPrec 7 a <> " :+ " <> showbPrec 7 b

instance Show a => Show (Maybe a) where
    showbPrec _ Nothing  = "Nothing"
    showbPrec k (Just a) = showbParen (k > 10) $ "Just " <> showbPrec 11 a
    {-# INLINE showbPrec #-}

instance (Show a, Show b) => Show (Either a b) where
    showbPrec k (Left a)  = showbParen (k > 10) $ "Left " <> showbPrec 11 a
    showbPrec k (Right b) = showbParen (k > 10) $ "Right " <> showbPrec 11 b

instance Show Ordering where
    showb LT = "LT"
    showb EQ = "EQ"
    showb GT = "GT"

instance (Show a, Show b) => Show (a, b) where
    showb (a, b) =
      s '(' <> showb a <>
      s ',' <> showb b <>
      s ')'
    {-# INLINE showb #-}

instance (Show a, Show b, Show c) => Show (a, b, c) where
    showb (a, b, c) =
      s '(' <> showb a <>
      s ',' <> showb b <>
      s ',' <> showb c <>
      s ')'
    {-# INLINE showb #-}

instance (Show a, Show b, Show c, Show d) => Show (a, b, c, d) where
    showb (a, b, c, d) =
      s '(' <> showb a <>
      s ',' <> showb b <>
      s ',' <> showb c <>
      s ',' <> showb d <>
      s ')'
    {-# INLINE showb #-}

instance (Show a, Show b, Show c, Show d, Show e) => Show (a, b, c, d, e) where
    showb (a, b, c, d, e) =
      s '(' <> showb a <>
      s ',' <> showb b <>
      s ',' <> showb c <>
      s ',' <> showb d <>
      s ',' <> showb e <>
      s ')'
    {-# INLINE showb #-}

instance (Show a, Show b, Show c, Show d, Show e, Show f) => Show (a, b, c, d, e, f) where
    showb (a, b, c, d, e, f) =
      s '(' <> showb a <>
      s ',' <> showb b <>
      s ',' <> showb c <>
      s ',' <> showb d <>
      s ',' <> showb e <>
      s ',' <> showb f <>
      s ')'
    {-# INLINE showb #-}

instance (Show a, Show b, Show c, Show d, Show e, Show f, Show g) =>
  Show (a, b, c, d, e, f, g) where
    showb (a, b, c, d, e, f, g) =
      s '(' <> showb a <>
      s ',' <> showb b <>
      s ',' <> showb c <>
      s ',' <> showb d <>
      s ',' <> showb e <>
      s ',' <> showb f <>
      s ',' <> showb g <>
      s ')'
    {-# INLINE showb #-}

instance (Show a, Show b, Show c, Show d, Show e, Show f, Show g, Show h) =>
  Show (a, b, c, d, e, f, g, h) where
    showb (a, b, c, d, e, f, g, h) =
      s '(' <> showb a <>
      s ',' <> showb b <>
      s ',' <> showb c <>
      s ',' <> showb d <>
      s ',' <> showb e <>
      s ',' <> showb f <>
      s ',' <> showb g <>
      s ',' <> showb h <>
      s ')'
    {-# INLINE showb #-}

instance (Show a, Show b, Show c, Show d, Show e, Show f, Show g, Show h, Show i) =>
  Show (a, b, c, d, e, f, g, h, i) where
    showb (a, b, c, d, e, f, g, h, i) =
      s '(' <> showb a <>
      s ',' <> showb b <>
      s ',' <> showb c <>
      s ',' <> showb d <>
      s ',' <> showb e <>
      s ',' <> showb f <>
      s ',' <> showb g <>
      s ',' <> showb h <>
      s ',' <> showb i <>
      s ')'
    {-# INLINE showb #-}

instance (Show a, Show b, Show c, Show d, Show e, Show f, Show g, Show h, Show i, Show j) =>
  Show (a, b, c, d, e, f, g, h, i, j) where
    showb (a, b, c, d, e, f, g, h, i, j) =
      s '(' <> showb a <>
      s ',' <> showb b <>
      s ',' <> showb c <>
      s ',' <> showb d <>
      s ',' <> showb e <>
      s ',' <> showb f <>
      s ',' <> showb g <>
      s ',' <> showb h <>
      s ',' <> showb i <>
      s ',' <> showb j <>
      s ')'
    {-# INLINE showb #-}

instance (Show a, Show b, Show c, Show d, Show e, Show f,
          Show g, Show h, Show i, Show j, Show k) =>
  Show (a, b, c, d, e, f, g, h, i, j, k) where
    showb (a, b, c, d, e, f, g, h, i, j, k) =
      s '(' <> showb a <>
      s ',' <> showb b <>
      s ',' <> showb c <>
      s ',' <> showb d <>
      s ',' <> showb e <>
      s ',' <> showb f <>
      s ',' <> showb g <>
      s ',' <> showb h <>
      s ',' <> showb i <>
      s ',' <> showb j <>
      s ',' <> showb k <>
      s ')'
    {-# INLINE showb #-}

instance (Show a, Show b, Show c, Show d, Show e, Show f,
          Show g, Show h, Show i, Show j, Show k, Show l) =>
  Show (a, b, c, d, e, f, g, h, i, j, k, l) where
    showb (a, b, c, d, e, f, g, h, i, j, k, l) =
      s '(' <> showb a <>
      s ',' <> showb b <>
      s ',' <> showb c <>
      s ',' <> showb d <>
      s ',' <> showb e <>
      s ',' <> showb f <>
      s ',' <> showb g <>
      s ',' <> showb h <>
      s ',' <> showb i <>
      s ',' <> showb j <>
      s ',' <> showb k <>
      s ',' <> showb l <>
      s ')'
    {-# INLINE showb #-}

instance (Show a, Show b, Show c, Show d, Show e, Show f, Show g,
          Show h, Show i, Show j, Show k, Show l, Show m) =>
  Show (a, b, c, d, e, f, g, h, i, j, k, l, m) where
    showb (a, b, c, d, e, f, g, h, i, j, k, l, m) =
      s '(' <> showb a <>
      s ',' <> showb b <>
      s ',' <> showb c <>
      s ',' <> showb d <>
      s ',' <> showb e <>
      s ',' <> showb f <>
      s ',' <> showb g <>
      s ',' <> showb h <>
      s ',' <> showb i <>
      s ',' <> showb j <>
      s ',' <> showb k <>
      s ',' <> showb l <>
      s ',' <> showb m <>
      s ')'
    {-# INLINE showb #-}

instance (Show a, Show b, Show c, Show d, Show e, Show f, Show g,
          Show h, Show i, Show j, Show k, Show l, Show m, Show n) =>
  Show (a, b, c, d, e, f, g, h, i, j, k, l, m, n) where
    showb (a, b, c, d, e, f, g, h, i, j, k, l, m, n) =
      s '(' <> showb a <>
      s ',' <> showb b <>
      s ',' <> showb c <>
      s ',' <> showb d <>
      s ',' <> showb e <>
      s ',' <> showb f <>
      s ',' <> showb g <>
      s ',' <> showb h <>
      s ',' <> showb i <>
      s ',' <> showb j <>
      s ',' <> showb k <>
      s ',' <> showb l <>
      s ',' <> showb m <>
      s ',' <> showb n <>
      s ')'
    {-# INLINE showb #-}

instance (Show a, Show b, Show c, Show d, Show e, Show f, Show g, Show h,
          Show i, Show j, Show k, Show l, Show m, Show n, Show o) =>
  Show (a, b, c, d, e, f, g, h, i, j, k, l, m, n, o) where
    showb (a, b, c, d, e, f, g, h, i, j, k, l, m, n, o) =
      s '(' <> showb a <>
      s ',' <> showb b <>
      s ',' <> showb c <>
      s ',' <> showb d <>
      s ',' <> showb e <>
      s ',' <> showb f <>
      s ',' <> showb g <>
      s ',' <> showb h <>
      s ',' <> showb i <>
      s ',' <> showb j <>
      s ',' <> showb k <>
      s ',' <> showb l <>
      s ',' <> showb m <>
      s ',' <> showb n <>
      s ',' <> showb o <>
      s ')'
    {-# INLINE showb #-}

instance (Show i, Show e, Ix i) => Show (Array i e) where
    showbPrec k a = showbParen (k > 10) $ "array " <>
                    showb (bounds a) <> s ' ' <> showb (assocs a)
    {-# INLINE showb #-}

instance (Show k, Show v) => Show (Map k v) where
    showbPrec k m = showbParen (k > 10) $ "fromList " <>
                    showb (M.toList m)
    {-# INLINE showb #-}

instance Show e => Show (Set e) where
    showbPrec k set = showbParen (k > 10) $ "fromList " <>
                      showb (S.toList set)
    {-# INLINE showb #-}

instance Show IntPtr where
    showb = build
    {-# INLINE showb #-}

instance Show WordPtr where
    showb = build
    {-# INLINE showb #-}

instance Show (Ptr a) where
    showb = build
    {-# INLINE showb #-}