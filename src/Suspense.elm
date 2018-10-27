module Suspense exposing (Cache(..), CmdView(..))


type Cache a
    = Empty
    | Cached String a


type CmdView view msg
    = NoCmd view
    | Suspend (Cmd msg)
    | Resume (Cmd msg) view
