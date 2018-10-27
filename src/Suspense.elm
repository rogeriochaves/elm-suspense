module Suspense exposing (Cache, CmdHtml, CmdView(..), Context, Model, Msg(..), emptyCache, getFromCache, init, mapCmdView, saveToCache, timeout, update, updateView)

import Dict exposing (Dict)
import Html exposing (..)
import Process
import Task


type CacheItem a
    = Requested
    | Cached a


type alias Cache a =
    { current : Maybe a, store : Dict String (CacheItem a) }


emptyCache : Cache a
emptyCache =
    { current = Nothing, store = Dict.empty }


saveToCache : String -> a -> Cache a -> Cache a
saveToCache key item cache =
    { current = Just item
    , store = Dict.insert key (Cached item) cache.store
    }


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


updateView : ({ model | view : view } -> CmdView view msg) -> ( { model | view : view }, Cmd msg ) -> ( { model | view : view }, Cmd msg )
updateView view ( model_, updateCmd ) =
    let
        updatedView =
            view model_
    in
    case updatedView of
        Render view_ ->
            ( { model_ | view = view_ }, updateCmd )

        Suspend _ viewCmd view_ ->
            case view_ of
                Just previousView ->
                    ( { model_ | view = previousView }, Cmd.batch [ viewCmd, updateCmd ] )

                Nothing ->
                    let
                        _ =
                            Debug.log "Warning: nobody recovered from a suspended view and there was no previous state, so we have nothing to render"
                    in
                    ( model_, Cmd.batch [ viewCmd, updateCmd ] )

        Resume viewCmd view_ ->
            ( { model_ | view = view_ }, Cmd.batch [ viewCmd, updateCmd ] )


getFromCache : { cache : Cache a, key : String, load : Cmd msg } -> (a -> view) -> CmdView view msg
getFromCache { cache, key, load } render =
    case ( Dict.get key cache.store, cache.current ) of
        ( Just (Cached result), _ ) ->
            Render (render result)

        ( Just Requested, Just current ) ->
            Suspend key Cmd.none (Just <| render current)

        ( Just Requested, Nothing ) ->
            Suspend key Cmd.none Nothing

        ( Nothing, Just current ) ->
            Suspend key load (Just <| render current)

        ( Nothing, Nothing ) ->
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
