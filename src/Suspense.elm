module Suspense exposing (Cache, CmdHtml, Model, Msg(..), emptyCache, fromView, getFromCache, init, mapCmdView, mapCmdViewList, preloadImg, saveToCache, snapshot, timeout, update, updateHtmlView, updateView)

import Dict exposing (Dict)
import Html exposing (..)
import Html.Attributes exposing (src, style)
import Html.Events exposing (on)
import Json.Decode as Decode
import Process
import Set exposing (Set)
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
    = Suspend (List (Msg view)) (Cmd msg) (Maybe view)
    | Resume (List (Msg view)) (Cmd msg) view


type alias CmdHtml msg =
    CmdView (Html msg) msg


type Msg view
    = StartTimeout CacheKey Float
    | EndTimeout CacheKey
    | ClearTimeout CacheKey
    | CacheRequest CacheKey
    | LoadImg CacheKey
    | ImgLoaded CacheKey
    | SaveSnapshot CacheKey view


type alias Model view =
    { timedOut : { key : CacheKey, state : TimedOut }
    , requestedToCache : Set CacheKey
    , imgsCache : Cache ()
    , snapshotsCache : Cache view
    , imgsToLoad : Set CacheKey
    }


type TimedOut
    = NotStarted
    | Waiting
    | TimedOut


init : Model view
init =
    { timedOut = { key = "", state = NotStarted }
    , requestedToCache = Set.empty
    , imgsCache = emptyCache
    , snapshotsCache = emptyCache
    , imgsToLoad = Set.empty
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

        ClearTimeout key ->
            ( { model | timedOut = { key = key, state = NotStarted } }, Cmd.none )

        CacheRequest key ->
            ( { model | requestedToCache = Set.insert key model.requestedToCache }, Cmd.none )

        LoadImg key ->
            ( { model | imgsToLoad = Set.insert key model.imgsToLoad }, Cmd.none )

        ImgLoaded key ->
            ( { model
                | imgsCache = saveToCache key () model.imgsCache
                , imgsToLoad = Set.remove key model.imgsToLoad
              }
            , Cmd.none
            )

        SaveSnapshot key view ->
            ( { model | snapshotsCache = saveToCache key view model.snapshotsCache }, Cmd.none )


updateHtmlView : (Msg (Html msg) -> msg) -> ({ model | view : Html msg, suspenseModel : Model (Html msg) } -> CmdView (Html msg) msg) -> ( { model | view : Html msg, suspenseModel : Model (Html msg) }, Cmd msg ) -> ( { model | view : Html msg, suspenseModel : Model (Html msg) }, Cmd msg )
updateHtmlView msgMapper view return =
    updateView msgMapper view return
        |> appendHtmlImgsToPreload msgMapper


appendHtmlImgsToPreload : (Msg view -> msg) -> ( { model | view : Html msg, suspenseModel : Model (Html msg) }, Cmd msg ) -> ( { model | view : Html msg, suspenseModel : Model (Html msg) }, Cmd msg )
appendHtmlImgsToPreload msgMapper ( model, cmd ) =
    let
        imgsToLoad =
            List.map
                (\url ->
                    img
                        [ src url
                        , on "load" (Decode.succeed <| msgMapper <| ImgLoaded url)
                        , style "display" "none"
                        ]
                        []
                )
                (Set.toList model.suspenseModel.imgsToLoad)
    in
    ( { model | view = div [] ([ model.view ] ++ imgsToLoad) }, cmd )


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
        Suspend msgs viewCmd view_ ->
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

        Resume msgs viewCmd view_ ->
            let
                ( suspenseModel, suspenseCmds ) =
                    foldMsgs msgs
            in
            ( { model | view = view_, suspenseModel = suspenseModel }, Cmd.batch [ viewCmd, updateCmd, Cmd.map msgMapper suspenseCmds ] )


getFromCache : Model view -> { cache : Cache a, key : CacheKey, load : Cmd msg } -> (a -> CmdView view msg) -> CmdView view msg
getFromCache =
    getFromCache_ False


getFromImgCache : Model view -> { cache : Cache a, key : CacheKey, load : Cmd msg } -> (a -> CmdView view msg) -> CmdView view msg
getFromImgCache =
    getFromCache_ True


preloadImg : Model view -> { src : String } -> view -> CmdView view msg
preloadImg model { src } view =
    getFromImgCache model
        { cache = model.imgsCache
        , key = src
        , load = Cmd.none
        }
        (\_ -> fromView view)


getFromCache_ : Bool -> Model view -> { cache : Cache a, key : CacheKey, load : Cmd msg } -> (a -> CmdView view msg) -> CmdView view msg
getFromCache_ isImg model { cache, key, load } render =
    case ( Dict.get key cache, Set.member key model.requestedToCache ) of
        -- Cache Hit
        ( Just result, _ ) ->
            case render result of
                Suspend msgs cmd_ child ->
                    Suspend msgs cmd_ child

                Resume msgs cmd_ child ->
                    Resume msgs cmd_ child

        -- Cache Miss, but requested
        ( Nothing, True ) ->
            Suspend [] Cmd.none Nothing

        -- Cache miss, not requested
        ( Nothing, False ) ->
            let
                requestCache =
                    if isImg then
                        [ CacheRequest key, LoadImg key ]

                    else
                        [ CacheRequest key ]
            in
            Suspend requestCache load Nothing


mapCmdView : CmdView view msg -> (view -> view) -> CmdView view msg
mapCmdView cmdView render =
    case cmdView of
        Suspend msgs cmd child ->
            Suspend msgs cmd (Maybe.map render child)

        Resume msgs cmd child ->
            Resume msgs cmd (render <| child)


mapCmdViewList : List (CmdView view msg) -> (List view -> view) -> CmdView view msg
mapCmdViewList cmdViewList render =
    let
        result =
            List.foldl
                (\cmdView result_ ->
                    case cmdView of
                        Resume msgs cmd item ->
                            { result_
                                | msgs = result_.msgs ++ msgs
                                , cmds = result_.cmds ++ [ cmd ]
                                , list = result_.list ++ [ item ]
                            }

                        Suspend msgs cmd item ->
                            { result_
                                | resume = False
                                , msgs = result_.msgs ++ msgs
                                , cmds = result_.cmds ++ [ cmd ]
                                , list = result_.list ++ (Maybe.map (\i -> [ i ]) item |> Maybe.withDefault [])
                            }
                )
                { resume = True, msgs = [], cmds = [], list = [] }
                cmdViewList
    in
    if result.resume then
        Resume result.msgs (Cmd.batch result.cmds) (render result.list)

    else
        Suspend result.msgs (Cmd.batch result.cmds) (Just <| render result.list)


fromView : view -> CmdView view msg
fromView =
    Resume [] Cmd.none


timeout : Model view -> { ms : Float, fallback : view, key : CacheKey } -> CmdView view msg -> CmdView view msg
timeout model { ms, fallback, key } cmdView =
    case snapshot model { key = key } cmdView of
        Suspend msgs cmd child ->
            let
                child_ =
                    child |> Maybe.withDefault fallback
            in
            if key == model.timedOut.key then
                case model.timedOut.state of
                    TimedOut ->
                        Resume msgs cmd fallback

                    Waiting ->
                        Resume msgs cmd child_

                    NotStarted ->
                        Resume (msgs ++ [ StartTimeout key ms ]) cmd child_

            else
                Resume (msgs ++ [ StartTimeout key ms ]) cmd child_

        Resume msgs cmd child ->
            Resume (msgs ++ [ ClearTimeout key ]) cmd child


snapshot : Model view -> { key : CacheKey } -> CmdView view msg -> CmdView view msg
snapshot model { key } cmdView =
    case ( cmdView, Dict.get key model.snapshotsCache ) of
        ( Resume msgs cmd child, _ ) ->
            Resume (msgs ++ [ SaveSnapshot key child ]) cmd child

        ( Suspend msgs cmd _, Just snapshot_ ) ->
            Suspend msgs cmd (Just snapshot_)

        ( _, Nothing ) ->
            cmdView
