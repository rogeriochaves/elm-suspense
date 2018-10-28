module Main exposing (main)

import Browser
import Html exposing (..)
import MovieDetails
import MovieList
import Suspense exposing (Cache, CmdHtml, emptyCache, mapCmdView, saveToCache, timeout)
import Types exposing (..)


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , view = .view
        , update = \msg model -> Suspense.updateHtmlView SuspenseMsg view <| update msg model
        , subscriptions = always Sub.none
        }


init : () -> ( Model, Cmd Msg )
init flags =
    let
        model =
            { suspenseModel = Suspense.init
            , view = text ""
            , searchInput = ""
            , moviesCache = emptyCache
            , selectedMovie = Nothing
            , movieDetailsCache = emptyCache
            }
    in
    Suspense.updateHtmlView SuspenseMsg view ( model, Cmd.none )


view : Model -> CmdHtml Msg
view model =
    let
        viewToRender =
            case model.selectedMovie of
                Just movie ->
                    MovieDetails.view model

                Nothing ->
                    MovieList.view model
    in
    mapCmdView
        (timeout model.suspenseModel
            { ms = 500, fallback = text "Loading2...", key = "movieDetailsTimeout" }
            viewToRender
        )
        identity


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

        ShowMovieDetails movie ->
            ( { model | selectedMovie = Just movie }, Cmd.none )

        BackToSearch ->
            ( { model | selectedMovie = Nothing }, Cmd.none )

        MovieDetailsLoaded id result ->
            ( { model | movieDetailsCache = saveToCache id result model.movieDetailsCache }, Cmd.none )
