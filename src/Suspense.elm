module Suspense exposing (Cache, CmdHtml, Context, Model, Msg(..), emptyCache, fromHtml, getFromCache, init, mapCmdView, mapCmdViewList, saveToCache, timeout, update, updateView)

import Dict exposing (Dict)
import Html exposing (..)
import Process
import Task


type alias Cache a =
    { current : Maybe a, store : Dict String a }


emptyCache : Cache a
emptyCache =
    { current = Nothing, store = Dict.empty }


saveToCache : String -> a -> Bool -> Cache a -> Cache a
saveToCache key item isCurrent cache =
    let
        current =
            if isCurrent then
                Just item

            else
                cache.current
    in
    { current = current
    , store = Dict.insert key item cache.store
    }


type CmdView view msg
    = Suspend String (Cmd msg) (Maybe view)
    | Resume (Cmd msg) view


type alias CmdHtml msg =
    CmdView (Html msg) msg


type Msg
    = StartTimeout String Float
    | EndTimeout String
    | CacheRequest String


type alias Model =
    { timedOut : { key : String, state : TimedOut }
    , requestedToCache : List String
    }


type alias Context msg =
    { msg : Msg -> msg, model : Model }


type TimedOut
    = NotStarted
    | Waiting
    | TimedOut


init : Model
init =
    { timedOut = { key = "", state = NotStarted }
    , requestedToCache = []
    }


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

        CacheRequest key ->
            ( { model | requestedToCache = model.requestedToCache ++ [ key ] }, Cmd.none )


updateView : ({ model | view : view } -> CmdView view msg) -> ( { model | view : view }, Cmd msg ) -> ( { model | view : view }, Cmd msg )
updateView view ( model_, updateCmd ) =
    let
        updatedView =
            view model_
    in
    case updatedView of
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


getFromCache : Context msg -> { cache : Cache a, key : String, load : Cmd msg } -> (a -> CmdView view msg) -> CmdView view msg
getFromCache { msg, model } { cache, key, load } render =
    let
        cmd =
            Cmd.batch
                [ generateMsg (msg <| CacheRequest key), load ]
    in
    case ( Dict.get key cache.store, List.member key model.requestedToCache, cache.current ) of
        -- Cache Hit
        ( Just result, _, _ ) ->
            case render result of
                Suspend _ cmd_ child ->
                    Suspend key cmd_ child

                Resume cmd_ child ->
                    Resume cmd_ child

        -- Cache Miss, but requested, old data present to render
        ( Nothing, True, Just current ) ->
            case render current of
                Suspend _ cmd_ child ->
                    Suspend key cmd_ child

                Resume cmd_ child ->
                    Suspend key cmd_ (Just <| child)

        -- Cache Miss, but requested, nothing to render
        ( Nothing, True, Nothing ) ->
            Suspend key Cmd.none Nothing

        -- Cache miss, not requested, old data present to render
        ( Nothing, False, Just current ) ->
            case render current of
                Suspend _ cmd_ child ->
                    Suspend key (Cmd.batch [ cmd, cmd_ ]) child

                Resume cmd_ child ->
                    Suspend key (Cmd.batch [ cmd, cmd_ ]) (Just <| child)

        -- Cache miss, not requested, nothing to render
        ( Nothing, False, Nothing ) ->
            Suspend key cmd Nothing


mapCmdView : CmdView view msg -> (view -> view) -> CmdView view msg
mapCmdView cmdView render =
    case cmdView of
        Suspend key cmd child ->
            Suspend key cmd (Maybe.map render child)

        Resume cmd child ->
            Resume cmd (render <| child)


mapCmdViewList : List (CmdView view msg) -> (List view -> view) -> CmdView view msg
mapCmdViewList cmdViewList render =
    let
        result =
            List.foldl
                (\cmdView result_ ->
                    case cmdView of
                        Resume cmd item ->
                            { result_
                                | cmds = result_.cmds ++ [ cmd ]
                                , list = result_.list ++ [ item ]
                            }

                        Suspend key cmd item ->
                            { result_
                                | resume = True
                                , cmds = result_.cmds ++ [ cmd ]
                                , list = result_.list ++ (Maybe.map (\i -> [ i ]) item |> Maybe.withDefault [])
                                , key = result_.key ++ key
                            }
                )
                { resume = True, cmds = [], list = [], key = "" }
                cmdViewList
    in
    if result.resume then
        Resume (Cmd.batch result.cmds) (render result.list)

    else
        Suspend result.key (Cmd.batch result.cmds) (Just <| render result.list)


fromHtml : view -> CmdView view msg
fromHtml =
    Resume Cmd.none


timeout : Context msg -> { ms : Float, fallback : view } -> CmdView view msg -> CmdView view msg
timeout { msg, model } { ms, fallback } cmdView =
    case cmdView of
        Suspend key cmd child ->
            let
                cmd_ =
                    Cmd.batch [ generateMsg (msg <| StartTimeout key ms), cmd ]

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
                        Resume cmd_ child_

            else
                Resume cmd_ child_

        Resume cmd child ->
            Resume cmd child


generateMsg : msg -> Cmd msg
generateMsg msg =
    Task.succeed ()
        |> Task.perform (always <| msg)
