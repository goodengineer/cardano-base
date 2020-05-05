{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE DerivingVia #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeFamilies #-}

-- | Ed448 digital signatures.
module Cardano.Crypto.DSIGN.Ed448
  ( Ed448DSIGN
  , SigDSIGN (..)
  , SignKeyDSIGN (..)
  , VerKeyDSIGN (..)
  )
where

import Cardano.Binary
  ( Decoder
  , Encoding
  , FromCBOR (..)
  , ToCBOR (..)
  , serialize
  )
import Cardano.Crypto.DSIGN.Class
import Cardano.Crypto.Seed
import Cardano.Prelude (NFData, NoUnexpectedThunks, UseIsNormalForm(..))
import Crypto.Error (CryptoFailable (..))
import Crypto.PubKey.Ed448 as Ed448
import Data.ByteArray (ByteArrayAccess, convert)
import Data.ByteString (ByteString)
import Data.ByteString.Lazy (toStrict)
import GHC.Generics (Generic)

data Ed448DSIGN

instance DSIGNAlgorithm Ed448DSIGN where

    --
    -- Key and signature types
    --

    newtype VerKeyDSIGN Ed448DSIGN = VerKeyEd448DSIGN PublicKey
        deriving (Show, Eq, Generic, ByteArrayAccess)
        deriving newtype NFData
        deriving NoUnexpectedThunks via UseIsNormalForm PublicKey

    newtype SignKeyDSIGN Ed448DSIGN = SignKeyEd448DSIGN SecretKey
        deriving (Show, Eq, Generic, ByteArrayAccess)
        deriving newtype NFData
        deriving NoUnexpectedThunks via UseIsNormalForm SecretKey

    newtype SigDSIGN Ed448DSIGN = SigEd448DSIGN Signature
        deriving (Show, Eq, Generic, ByteArrayAccess)
        deriving NoUnexpectedThunks via UseIsNormalForm Signature

    --
    -- Metadata and basic key operations
    --

    algorithmNameDSIGN _ = "ed448"

    deriveVerKeyDSIGN (SignKeyEd448DSIGN sk) = VerKeyEd448DSIGN $ toPublic sk

    -- | Goldilocks points are 448 bits long
    sizeVerKeyDSIGN  _ = 57
    sizeSignKeyDSIGN _ = 57
    sizeSigDSIGN     _ = 114


    --
    -- Core algorithm operations
    --

    type Signable Ed448DSIGN = ToCBOR

    signDSIGN () a (SignKeyEd448DSIGN sk) =
        let vk = toPublic sk
            bs = toStrict $ serialize a
         in SigEd448DSIGN $ sign sk vk bs

    verifyDSIGN () (VerKeyEd448DSIGN vk) a (SigEd448DSIGN sig) =
        if verify vk (toStrict $ serialize a) sig
          then Right ()
          else Left "Verification failed"

    --
    -- Key generation
    --

    seedSizeDSIGN _  = 57
    genKeyDSIGN seed =
        let sk = runMonadRandomWithSeed seed Ed448.generateSecretKey
         in SignKeyEd448DSIGN sk

    --
    -- raw serialise/deserialise
    --

    rawSerialiseVerKeyDSIGN   = convert
    rawSerialiseSignKeyDSIGN  = convert
    rawSerialiseSigDSIGN      = convert

    rawDeserialiseVerKeyDSIGN  = fmap VerKeyEd448DSIGN
                               . cryptoFailableToMaybe . Ed448.publicKey
    rawDeserialiseSignKeyDSIGN = fmap SignKeyEd448DSIGN
                               . cryptoFailableToMaybe . Ed448.secretKey
    rawDeserialiseSigDSIGN     = fmap SigEd448DSIGN
                               . cryptoFailableToMaybe . Ed448.signature

    --
    -- CBOR encoding/decoding
    --

    encodeVerKeyDSIGN = toCBOR
    encodeSignKeyDSIGN = toCBOR
    encodeSigDSIGN = toCBOR

    decodeVerKeyDSIGN = fromCBOR
    decodeSignKeyDSIGN = fromCBOR
    decodeSigDSIGN = fromCBOR


instance ToCBOR (VerKeyDSIGN Ed448DSIGN) where
  toCBOR = encodeBA

instance FromCBOR (VerKeyDSIGN Ed448DSIGN) where
  fromCBOR = VerKeyEd448DSIGN <$> decodeBA publicKey

instance ToCBOR (SignKeyDSIGN Ed448DSIGN) where
  toCBOR = encodeBA

instance FromCBOR (SignKeyDSIGN Ed448DSIGN) where
  fromCBOR = SignKeyEd448DSIGN <$> decodeBA secretKey

instance ToCBOR (SigDSIGN Ed448DSIGN) where
  toCBOR = encodeBA

instance FromCBOR (SigDSIGN Ed448DSIGN) where
  fromCBOR = SigEd448DSIGN <$> decodeBA signature

encodeBA :: ByteArrayAccess ba => ba -> Encoding
encodeBA ba = let bs = convert ba :: ByteString in toCBOR bs

decodeBA :: forall a s. (ByteString -> CryptoFailable a) -> Decoder s a
decodeBA f = do
  bs <- fromCBOR :: Decoder s ByteString
  case f bs of
    CryptoPassed a -> return a
    CryptoFailed e -> fail $ "decodeBA: " ++ show e


cryptoFailableToMaybe :: CryptoFailable a -> Maybe a
cryptoFailableToMaybe (CryptoPassed a) = Just a
cryptoFailableToMaybe (CryptoFailed _) = Nothing

