module Suspense exposing (Cache, CmdHtml, Model, Msg(..), emptyCache, fromView, getFromCache, init, mapCmdView, mapCmdViewList, saveToCache, snapshot, timeout, update, updateView)

import Dict exposing (Dict)
import Html exposing (..)
import Process
import Task


type alias CacheKey =
    String


type alias Cache a =
    Dict CacheKey a


emptyCache : Cache a
emptyCache =
    Dict.empty


saveToCache : CacheKey -> a -> Cache a -> Cache a
saveToCache key item cache =
    Dict.insert key item cache


type CmdView view msg
    = Suspend CacheKey (List (Msg view)) (Cmd msg) (Maybe view)
    | Resume CacheKey (List (Msg view)) (Cmd msg) view


type alias CmdHtml msg =
    CmdView (Html msg) msg


type Msg view
    = StartTimeout CacheKey Float
    | EndTimeout CacheKey
    | CacheRequest CacheKey
    | ImgLoaded CacheKey
    | SaveSnapshot CacheKey view


type alias Model view =
    { timedOut : { key : CacheKey, state : TimedOut }
    , requestedToCache : List CacheKey
    , imgsCache : Cache ()
    , snapshotsCache : Cache view
    }


type TimedOut
    = NotStarted
    | Waiting
    | TimedOut


init : Model view
init =
    { timedOut = { key = "", state = NotStarted }
    , requestedToCache = []
    , imgsCache = emptyCache
    , snapshotsCache = emptyCache
    }


update : Msg view -> Model view -> ( Model view, Cmd (Msg view) )
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

        ImgLoaded key ->
            ( { model | imgsCache = saveToCache key () model.imgsCache }, Cmd.none )

        SaveSnapshot key view ->
            ( { model | snapshotsCache = saveToCache key view model.snapshotsCache }, Cmd.none )


updateView : (Msg view -> msg) -> ({ model | view : view, suspenseModel : Model view } -> CmdView view msg) -> ( { model | view : view, suspenseModel : Model view }, Cmd msg ) -> ( { model | view : view, suspenseModel : Model view }, Cmd msg )
updateView msgMapper view ( model, updateCmd ) =
    let
        updatedView =
            view model

        foldMsgs msgs =
            List.foldl
                (\msg ( model_, cmd ) ->
                    let
                        ( model__, cmd_ ) =
                            update msg model_
                    in
                    ( model__, Cmd.batch [ cmd, cmd_ ] )
                )
                ( model.suspenseModel, Cmd.none )
                msgs
    in
    case updatedView of
        Suspend _ msgs viewCmd view_ ->
            let
                ( suspenseModel, suspenseCmds ) =
                    foldMsgs msgs
            in
            case view_ of
                Just previousView ->
                    ( { model | view = previousView, suspenseModel = suspenseModel }, Cmd.batch [ viewCmd, updateCmd, Cmd.map msgMapper suspenseCmds ] )

                Nothing ->
                    let
                        _ =
                            Debug.log "Warning:" "nobody recovered from a suspended view and there was no previous state, so we have nothing to render"
                    in
                    ( model, Cmd.batch [ viewCmd, updateCmd ] )

        Resume _ msgs viewCmd view_ ->
            let
                ( suspenseModel, suspenseCmds ) =
                    foldMsgs msgs
            in
            ( { model | view = view_, suspenseModel = suspenseModel }, Cmd.batch [ viewCmd, updateCmd, Cmd.map msgMapper suspenseCmds ] )


getFromCache : Model view -> { cache : Cache a, key : CacheKey, load : Cmd msg } -> (a -> CmdView view msg) -> CmdView view msg
getFromCache model { cache, key, load } render =
    case ( Dict.get key cache, List.member key model.requestedToCache ) of
        -- Cache Hit
        ( Just result, _ ) ->
            case render result of
                Suspend _ msgs cmd_ child ->
                    Suspend key msgs cmd_ child

                Resume _ msgs cmd_ child ->
                    Resume key msgs cmd_ child

        -- Cache Miss, but requested
        ( Nothing, True ) ->
            Suspend key [] Cmd.none Nothing

        -- Cache miss, not requested
        ( Nothing, False ) ->
            Suspend key [ CacheRequest key ] load Nothing


mapCmdView : CmdView view msg -> (view -> view) -> CmdView view msg
mapCmdView cmdView render =
    case cmdView of
        Suspend key msgs cmd child ->
            Suspend key msgs cmd (Maybe.map render child)

        Resume key msgs cmd child ->
            Resume key msgs cmd (render <| child)


mapCmdViewList : List (CmdView view msg) -> (List view -> view) -> CmdView view msg
mapCmdViewList cmdViewList render =
    let
        result =
            List.foldl
                (\cmdView result_ ->
                    case cmdView of
                        Resume key msgs cmd item ->
                            { result_
                                | msgs = result_.msgs ++ msgs
                                , cmds = result_.cmds ++ [ cmd ]
                                , list = result_.list ++ [ item ]
                                , key = result_.key ++ key
                            }

                        Suspend key msgs cmd item ->
                            { result_
                                | resume = False
                                , msgs = result_.msgs ++ msgs
                                , cmds = result_.cmds ++ [ cmd ]
                                , list = result_.list ++ (Maybe.map (\i -> [ i ]) item |> Maybe.withDefault [])
                                , key = result_.key ++ key
                            }
                )
                { resume = True, msgs = [], cmds = [], list = [], key = "" }
                cmdViewList
    in
    if result.resume then
        Resume result.key result.msgs (Cmd.batch result.cmds) (render result.list)

    else
        Suspend result.key result.msgs (Cmd.batch result.cmds) (Just <| render result.list)


fromView : view -> CmdView view msg
fromView =
    Resume "" [] Cmd.none


timeout : Model view -> { ms : Float, fallback : view } -> CmdView view msg -> CmdView view msg
timeout model { ms, fallback } cmdView =
    case cmdView of
        Suspend key msgs cmd child ->
            let
                child_ =
                    child |> Maybe.withDefault fallback
            in
            if key == model.timedOut.key then
                case model.timedOut.state of
                    TimedOut ->
                        Resume key msgs cmd fallback

                    Waiting ->
                        Resume key msgs cmd child_

                    NotStarted ->
                        Resume key (msgs ++ [ StartTimeout key ms ]) cmd child_

            else
                Resume key (msgs ++ [ StartTimeout key ms ]) cmd child_

        Resume key msgs cmd child ->
            Resume key msgs cmd child


snapshot : Model view -> { key : CacheKey } -> CmdView view msg -> CmdView view msg
snapshot model { key } cmdView =
    case ( cmdView, Dict.get key model.snapshotsCache ) of
        ( Resume key_ msgs cmd child, _ ) ->
            Resume key_ (msgs ++ [ SaveSnapshot key child ]) cmd child

        ( Suspend key_ msgs cmd _, Just snapshot_ ) ->
            Suspend key_ msgs cmd (Just snapshot_)

        ( _, Nothing ) ->
            cmdView
