{-# LANGUAGE RecordWildCards #-}
module Network.BitTorrent.Tracker.RPC.HTTPSpec (spec) where
import Control.Monad
import Data.Default
import Data.List as L
import Test.Hspec

import Network.BitTorrent.Internal.Progress
import Network.BitTorrent.Tracker.Message as Message
import Network.BitTorrent.Tracker.RPC.HTTP

import Network.BitTorrent.Tracker.TestData
import Network.BitTorrent.Tracker.MessageSpec hiding (spec)


validateInfo :: AnnounceQuery -> AnnounceInfo -> Expectation
validateInfo _ (Message.Failure reason) = do
  error $ "validateInfo: " ++ show reason
validateInfo AnnounceQuery {..}  AnnounceInfo {..} = do
  return ()
--  case respComplete <|> respIncomplete of
--    Nothing -> return ()
--    Just n  -> n  `shouldBe` L.length (getPeerList respPeers)

isUnrecognizedScheme :: RpcException -> Bool
isUnrecognizedScheme (RequestFailed _) = True
isUnrecognizedScheme  _                = False

isNotResponding :: RpcException -> Bool
isNotResponding (RequestFailed _) = True
isNotResponding  _                = False

spec :: Spec
spec = parallel $ do
  describe "Manager" $ do
    describe "newManager" $ do
      it "" $ pending

    describe "closeManager" $ do
      it "" $ pending

    describe "withManager" $ do
      it "" $ pending

  describe "RPC" $ do
    describe "announce" $ do
      it "must fail on bad uri scheme" $ do
        withManager def $ \ mgr -> do
          q    <- arbitrarySample
          announce mgr "magnet://foo.bar" q
            `shouldThrow` isUnrecognizedScheme

    describe "scrape" $ do
      it "must fail on bad uri scheme" $ do
        withManager def $ \ mgr -> do
          scrape mgr "magnet://foo.bar" []
            `shouldThrow` isUnrecognizedScheme

    forM_ (L.filter isHttpTracker trackers) $ \ TrackerEntry {..} ->
      context trackerName $ do

        describe "announce" $ do
          if tryAnnounce
            then do
              it "have valid response" $ do
                withManager def $ \ mgr -> do
--                  q    <- arbitrarySample
                  let ih = maybe def L.head hashList
                  let q = AnnounceQuery ih "-HS0003-203534.37420" 6000
                          (Progress 0 0 0) Nothing Nothing (Just Started)
                  info <- announce mgr trackerURI q
                  validateInfo q info
            else do
              it "should fail with RequestFailed" $ do
                withManager def $ \ mgr -> do
                  q <- arbitrarySample
                  announce mgr trackerURI q
                    `shouldThrow` isNotResponding

        describe "scrape" $ do
          if tryScraping
            then do
              it "have valid response" $ do
                withManager def $ \ mgr -> do
                  xs <- scrape mgr trackerURI [def]
                  L.length xs `shouldSatisfy` (>= 1)
            else do
              it "should fail with ScrapelessTracker" $ do
                pending

          when (not tryAnnounce) $ do
            it "should fail with RequestFailed" $ do
              withManager def $ \ mgr -> do
                scrape mgr trackerURI [def]
                  `shouldThrow` isNotResponding
