-- |
--   Copyright   :  (c) Sam Truzjan 2013
--   License     :  BSD3
--   Maintainer  :  pxqr.sta@gmail.com
--   Stability   :  experimental
--   Portability :  portable
--
--   TODO
--
{-# LANGUAGE TemplateHaskell #-}
module Data.Torrent.Block
       ( -- * Block attributes
         BlockLIx
       , PieceLIx
       , BlockSize (..)

         -- * Block index
       , BlockIx(..)
       , ppBlockIx

         -- * Block data
       , Block(..)
       , ppBlock
       , blockSize
       , pieceIx
       , blockIx
       , blockRange
       , ixRange
       , isPiece
       ) where

import Control.Applicative

import Data.Aeson (ToJSON, FromJSON)
import Data.Aeson.TH
import qualified Data.ByteString.Lazy as Lazy
import Data.Char
import Data.Default
import Data.List as L

import Data.Binary as B
import Data.Binary.Get as B
import Data.Binary.Put as B
import Data.Serialize as S

import Text.PrettyPrint


{-----------------------------------------------------------------------
--  Block attributes
-----------------------------------------------------------------------}

newtype BlockSize = BlockSize { unBlockSize :: Int }
                    deriving (Show, Eq, Num, ToJSON, FromJSON)

-- | Widely used semi-official block size.
instance Default BlockSize where
  def = 16 * 1024
  {-# INLINE def #-}

type BlockLIx = Int
type PieceLIx = Int

{-----------------------------------------------------------------------
    Block Index
-----------------------------------------------------------------------}

data BlockIx = BlockIx {
    -- | Zero-based piece index.
    ixPiece  :: {-# UNPACK #-} !PieceLIx

    -- | Zero-based byte offset within the piece.
  , ixOffset :: {-# UNPACK #-} !Int

    -- | Block size starting from offset.
  , ixLength :: {-# UNPACK #-} !BlockSize
  } deriving (Show, Eq)

$(deriveJSON (L.map toLower . L.dropWhile isLower) ''BlockIx)

getInt :: S.Get Int
getInt = fromIntegral <$> S.getWord32be
{-# INLINE getInt #-}

putInt :: S.Putter Int
putInt = S.putWord32be . fromIntegral
{-# INLINE putInt #-}

getIntB :: B.Get Int
getIntB = fromIntegral <$> B.getWord32be
{-# INLINE getIntB #-}

putIntB :: Int -> B.Put
putIntB = B.putWord32be . fromIntegral
{-# INLINE putIntB #-}

instance Serialize BlockIx where
  {-# SPECIALIZE instance Serialize BlockIx #-}
  get = BlockIx <$> getInt
                <*> getInt
                <*> (BlockSize <$> getInt)
  {-# INLINE get #-}

  put BlockIx {..} = do
    putInt ixPiece
    putInt ixOffset
    putInt (unBlockSize ixLength)
  {-# INLINE put #-}

instance Binary BlockIx where
  {-# SPECIALIZE instance Binary BlockIx #-}
  get = BlockIx <$> getIntB
                <*> getIntB
                <*> (BlockSize <$> getIntB)
  {-# INLINE get #-}

  put BlockIx {..} = do
    putIntB ixPiece
    putIntB ixOffset
    putIntB (unBlockSize ixLength)

-- | Format block index in human readable form.
ppBlockIx :: BlockIx -> Doc
ppBlockIx BlockIx {..} =
  "piece  = " <> int ixPiece  <> "," <+>
  "offset = " <> int ixOffset <> "," <+>
  "length = " <> int (unBlockSize ixLength)

{-----------------------------------------------------------------------
    Block
-----------------------------------------------------------------------}

data Block payload = Block {
    -- | Zero-based piece index.
    blkPiece  :: {-# UNPACK #-} !PieceLIx

    -- | Zero-based byte offset within the piece.
  , blkOffset :: {-# UNPACK #-} !Int

    -- | Payload bytes.
  , blkData   :: !payload
  } deriving (Show, Eq)

-- | Format block in human readable form. Payload is ommitted.
ppBlock :: Block Lazy.ByteString -> Doc
ppBlock = ppBlockIx . blockIx
{-# INLINE ppBlock #-}

blockSize :: Block Lazy.ByteString -> BlockSize
blockSize blk = fromIntegral (Lazy.length (blkData blk))
{-# INLINE blockSize #-}

isPiece :: Int -> Block Lazy.ByteString -> Bool
isPiece pieceSize (Block i offset bs) =
     offset == 0
  && fromIntegral (Lazy.length bs) == pieceSize
  && i >= 0
{-# INLINE isPiece #-}

pieceIx :: Int -> Int -> BlockIx
pieceIx i = BlockIx i 0 . BlockSize
{-# INLINE pieceIx #-}

blockIx :: Block Lazy.ByteString -> BlockIx
blockIx = BlockIx <$> blkPiece <*> blkOffset <*> blockSize

blockRange :: (Num a, Integral a) => Int -> Block Lazy.ByteString -> (a, a)
blockRange pieceSize blk = (offset, offset + len)
  where
    offset = fromIntegral pieceSize * fromIntegral (blkPiece blk)
           + fromIntegral (blkOffset blk)
    len    = fromIntegral (Lazy.length (blkData blk))
{-# INLINE blockRange #-}

ixRange :: (Num a, Integral a) => Int -> BlockIx -> (a, a)
ixRange pieceSize i = (offset, offset + len)
  where
    offset = fromIntegral  pieceSize * fromIntegral (ixPiece i)
           + fromIntegral (ixOffset i)
    len    = fromIntegral (unBlockSize (ixLength i))
{-# INLINE ixRange #-}
