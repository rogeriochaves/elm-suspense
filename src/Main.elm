module Main exposing (main)

import Browser
import Html exposing (..)
import MovieList
import Suspense exposing (Cache, CmdHtml, CmdView(..), emptyCache, saveToCache)
import Types exposing (..)


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , view = .view
        , update = \msg model -> Suspense.updateView view <| update msg model
        , subscriptions = always Sub.none
        }


init : () -> ( Model, Cmd Msg )
init flags =
    let
        model =
            { view = text ""
            , searchInput = ""
            , moviesCache = emptyCache
            , suspenseModel = Suspense.init
            }
    in
    Suspense.updateView view ( model, Cmd.none )


view : Model -> CmdHtml Msg
view model =
    MovieList.view
        { msg = SuspenseMsg, model = model.suspenseModel }
        model


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        UpdateSearch search ->
            ( { model | searchInput = search }, Cmd.none )

        MoviesLoaded query result ->
            ( { model | moviesCache = saveToCache query result model.moviesCache }, Cmd.none )

        SuspenseMsg msg_ ->
            let
                ( model_, cmd ) =
                    Suspense.update msg_ model.suspenseModel
            in
            ( { model | suspenseModel = model_ }, Cmd.map SuspenseMsg cmd )
