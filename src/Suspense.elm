module Suspense exposing (Cache, CmdHtml, Model, Msg(..), emptyCache, fromView, getFromCache, init, mapCmdView, mapCmdViewList, saveToCache, timeout, update, updateView)

import Dict exposing (Dict)
import Html exposing (..)
import Process
import Task


type alias CacheKey =
    String


type alias Cache a =
    { current : Maybe a, store : Dict CacheKey a }


emptyCache : Cache a
emptyCache =
    { current = Nothing, store = Dict.empty }


saveToCache : CacheKey -> a -> Bool -> Cache a -> Cache a
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
    = Suspend CacheKey (List Msg) (Cmd msg) (Maybe view)
    | Resume CacheKey (List Msg) (Cmd msg) view


type alias CmdHtml msg =
    CmdView (Html msg) msg


type Msg
    = StartTimeout CacheKey Float
    | EndTimeout CacheKey
    | CacheRequest CacheKey
    | ImgLoaded CacheKey


type alias Model =
    { timedOut : { key : CacheKey, state : TimedOut }
    , requestedToCache : List CacheKey
    , imgsCache : Cache ()
    }


type TimedOut
    = NotStarted
    | Waiting
    | TimedOut


init : Model
init =
    { timedOut = { key = "", state = NotStarted }
    , requestedToCache = []
    , imgsCache = emptyCache
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

        ImgLoaded key ->
            ( { model | imgsCache = saveToCache key () False model.imgsCache }
            , Cmd.none
            )


updateView : ({ model | view : view, suspenseModel : Model } -> CmdView view msg) -> ( { model | view : view, suspenseModel : Model }, Cmd msg ) -> ( { model | view : view, suspenseModel : Model }, Cmd msg )
updateView view ( model, updateCmd ) =
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
                    ( { model | view = previousView, suspenseModel = suspenseModel }, Cmd.batch [ viewCmd, updateCmd ] )

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
            ( { model | view = view_, suspenseModel = suspenseModel }, Cmd.batch [ viewCmd, updateCmd ] )


getFromCache : Model -> { cache : Cache a, key : CacheKey, load : Cmd msg } -> (a -> CmdView view msg) -> CmdView view msg
getFromCache model { cache, key, load } render =
    case ( Dict.get key cache.store, List.member key model.requestedToCache, cache.current ) of
        -- Cache Hit
        ( Just result, _, _ ) ->
            case render result of
                Suspend _ msgs cmd_ child ->
                    Suspend key msgs cmd_ child

                Resume _ msgs cmd_ child ->
                    Resume key msgs cmd_ child

        -- Cache Miss, but requested, old data present to render
        ( Nothing, True, Just current ) ->
            case render current of
                Suspend _ msgs cmd_ child ->
                    Suspend key msgs cmd_ child

                Resume _ msgs cmd_ child ->
                    Suspend key msgs cmd_ (Just <| child)

        -- Cache Miss, but requested, nothing to render
        ( Nothing, True, Nothing ) ->
            Suspend key [] Cmd.none Nothing

        -- Cache miss, not requested, old data present to render
        ( Nothing, False, Just current ) ->
            case render current of
                Suspend _ msgs cmd_ child ->
                    Suspend key (msgs ++ [ CacheRequest key ]) load child

                Resume _ msgs cmd_ child ->
                    Suspend key (msgs ++ [ CacheRequest key ]) load (Just <| child)

        -- Cache miss, not requested, nothing to render
        ( Nothing, False, Nothing ) ->
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


timeout : Model -> { ms : Float, fallback : view } -> CmdView view msg -> CmdView view msg
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
