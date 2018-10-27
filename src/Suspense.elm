module Suspense exposing (Cache(..), CmdHtml, CmdView(..), getFromCache, mapCmdView)

import Html exposing (..)


type Cache a
    = Empty
    | Cached String a


type CmdView view msg
    = Render view
    | Suspend (Cmd msg)
    | Resume (Cmd msg) view


type alias CmdHtml msg =
    CmdView (Html msg) msg


getFromCache : { cache : Cache a, key : String, load : Cmd msg } -> (a -> view) -> CmdView view msg
getFromCache { cache, key, load } render =
    case cache of
        Cached key_ result ->
            if key_ == key then
                Render (render result)

            else
                Resume load (render result)

        Empty ->
            Suspend load


mapCmdView : CmdView view msg -> (view -> view) -> CmdView view msg
mapCmdView cmdView render =
    case cmdView of
        Render child ->
            Render (render child)

        Suspend cmd ->
            Suspend cmd

        Resume cmd child ->
            Resume cmd (render <| child)
