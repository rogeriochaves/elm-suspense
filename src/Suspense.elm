module Suspense exposing (Cache(..), CmdHtml, CmdView(..), Context, Model, Msg(..), getFromCache, init, mapCmdView, timeout, update)

import Html exposing (..)
import Process
import Task


type Cache a
    = Empty
    | Cached String a


type CmdView view msg
    = Render view
    | Suspend String (Cmd msg) (Maybe view)
    | Resume (Cmd msg) view


type alias CmdHtml msg =
    CmdView (Html msg) msg


type Msg
    = StartTimeout String Float
    | EndTimeout String


type alias Model =
    { timedOut : { key : String, state : TimedOut } }


type alias Context msg =
    { msg : Msg -> msg, model : Model }


type TimedOut
    = NotStarted
    | Waiting
    | TimedOut


init : Model
init =
    { timedOut = { key = "", state = NotStarted } }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        StartTimeout key ms ->
            ( { model | timedOut = { key = key, state = Waiting } }
            , Process.sleep ms
                |> Task.perform (always <| EndTimeout key)
            )

        EndTimeout key ->
            ( { model | timedOut = { key = key, state = TimedOut } }, Cmd.none )


getFromCache : { cache : Cache a, key : String, load : Cmd msg } -> (a -> view) -> CmdView view msg
getFromCache { cache, key, load } render =
    case cache of
        Cached key_ result ->
            if key_ == key then
                Render (render result)

            else
                Suspend key load (Just <| render result)

        Empty ->
            Suspend key load Nothing


mapCmdView : CmdView view msg -> (view -> view) -> CmdView view msg
mapCmdView cmdView render =
    case cmdView of
        Render child ->
            Render (render child)

        Suspend key cmd child ->
            Suspend key cmd (Maybe.map render child)

        Resume cmd child ->
            Resume cmd (render <| child)


timeout : Context msg -> { ms : Float, fallback : view } -> CmdView view msg -> CmdView view msg
timeout { msg, model } { ms, fallback } cmdView =
    case cmdView of
        Render child ->
            Render child

        Suspend key cmd child ->
            let
                timeoutCmd =
                    Task.succeed ()
                        |> Task.perform (always <| msg <| StartTimeout key ms)

                child_ =
                    child |> Maybe.withDefault fallback
            in
            if key == model.timedOut.key then
                case model.timedOut.state of
                    TimedOut ->
                        Resume Cmd.none fallback

                    Waiting ->
                        Resume Cmd.none child_

                    NotStarted ->
                        Resume (Cmd.batch [ timeoutCmd, cmd ]) child_

            else
                Resume (Cmd.batch [ timeoutCmd, cmd ]) child_

        Resume cmd child ->
            Resume cmd child
