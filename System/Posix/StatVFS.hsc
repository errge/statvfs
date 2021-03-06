{-# LANGUAGE CPP, GeneralizedNewtypeDeriving, ForeignFunctionInterface, CApiFFI #-}

##include "StatVFSConfig.h"
#include "StatVFSConfig.h"
#include "sys/statvfs.h"
-- | Get information about a mounted filesystem.
-- A minimal example of usage is:
--
-- @
-- import System.Posix.StatVFS (statVFS, statVFS_bfree)
--
-- main = do
--     stat <- statVFS "/"
--     putStrLn $ (show (statVFS_bfree stat)) ++ " free blocks on /"
-- @

module System.Posix.StatVFS where

import Control.Applicative
import Foreign
import Foreign.C.Error (throwErrnoIfMinus1_)
import Foreign.C.Types (CInt(..), CULong(..))
import Foreign.C.String (CString, withCString)
import System.Posix.Types
import Unsafe.Coerce (unsafeCoerce)

newtype CFSBlkCnt = CFSBlkCnt HTYPE_FSBLKCNT_T deriving (Bounded, Enum, Eq, Integral, Num, Ord, Real, Storable)
newtype CFSFilCnt = CFSFilCnt HTYPE_FSFILCNT_T deriving (Bounded, Enum, Eq, Integral, Num, Ord, Real, Storable)

instance Read CFSBlkCnt where
  readsPrec            = unsafeCoerce (readsPrec :: Int -> ReadS HTYPE_FSBLKCNT_T)
  readList             = unsafeCoerce (readList  :: ReadS [HTYPE_FSBLKCNT_T])

instance Show CFSBlkCnt where
   showsPrec            = unsafeCoerce (showsPrec :: Int -> HTYPE_FSBLKCNT_T -> ShowS)
   show                 = unsafeCoerce (show :: HTYPE_FSBLKCNT_T -> String)
   showList             = unsafeCoerce (showList :: [HTYPE_FSBLKCNT_T] -> ShowS)

instance Read CFSFilCnt where
  readsPrec            = unsafeCoerce (readsPrec :: Int -> ReadS HTYPE_FSFILCNT_T)
  readList             = unsafeCoerce (readList  :: ReadS [HTYPE_FSFILCNT_T])

instance Show CFSFilCnt where
   showsPrec            = unsafeCoerce (showsPrec :: Int -> HTYPE_FSFILCNT_T -> ShowS)
   show                 = unsafeCoerce (show :: HTYPE_FSFILCNT_T -> String)
   showList             = unsafeCoerce (showList :: [HTYPE_FSFILCNT_T] -> ShowS)

type CStatVFS = ()

foreign import capi unsafe "sys/statvfs.h fstatvfs"
  c_fstatvfs :: CInt -> Ptr CStatVFS -> IO CInt

foreign import capi unsafe "sys/statvfs.h statvfs"
  c_statvfs :: CString -> Ptr CStatVFS -> IO CInt
-- | File system information record, reflects data mentioned in the statvfs(3) manual
data StatVFS = StatVFS { -- | Filesystem block size
                         statVFS_bsize :: CULong
                         -- | Fragment size
                       , statVFS_frsize :: CULong
                         -- | Size of fs in f_frsize units
                       , statVFS_blocks :: CFSBlkCnt
                         -- | Free blocks
                       , statVFS_bfree :: CFSBlkCnt
                         -- | Free blocks for unprivileged users
                       , statVFS_bavail :: CFSBlkCnt
                         -- | Inodes
                       , statVFS_files :: CFSFilCnt
                         -- | Free inodes
                       , statVFS_ffree :: CFSFilCnt
                         -- | Free inodes for unprivileged users
                       , statVFS_favail :: CFSFilCnt
                         -- | Filesystem ID
                       , statVFS_fsid :: CULong
                         -- | Mount flags
                       , statVFS_flag :: CULong
                         -- | Maximum filename length
                       , statVFS_namemax :: CULong
                       } deriving Show

statVFS_st_rdonly :: CULong
statVFS_st_rdonly = (#const ST_RDONLY)

statVFS_st_nosuid :: CULong
statVFS_st_nosuid = (#const ST_NOSUID)

toStatVFS :: Ptr CStatVFS -> IO StatVFS
toStatVFS p = StatVFS
              <$> (#peek struct statvfs, f_bsize) p
              <*> (#peek struct statvfs, f_frsize) p
              <*> (#peek struct statvfs, f_blocks) p
              <*> (#peek struct statvfs, f_bfree) p
              <*> (#peek struct statvfs, f_bavail) p
              <*> (#peek struct statvfs, f_files) p
              <*> (#peek struct statvfs, f_ffree) p
              <*> (#peek struct statvfs, f_favail) p
              <*> (#peek struct statvfs, f_fsid) p
              <*> (#peek struct statvfs, f_flag) p
              <*> (#peek struct statvfs, f_namemax) p

fStatVFS :: Fd -> IO StatVFS
fStatVFS (Fd fd) = do
  fp <- mallocForeignPtrBytes (#const sizeof(struct statvfs))
  withForeignPtr fp $ \p -> do
    throwErrnoIfMinus1_ "fStatVFS" $ c_fstatvfs fd p
    toStatVFS p

statVFS :: FilePath -> IO StatVFS
statVFS path = do
  withCString path $ \c_path -> do
    fp <- mallocForeignPtrBytes (#const sizeof(struct statvfs))
    withForeignPtr fp $ \p -> do
      throwErrnoIfMinus1_ "statVFS" $ c_statvfs c_path p
      toStatVFS p
