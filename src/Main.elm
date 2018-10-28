module Main exposing (main)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import MovieDetails
import MovieList
import Suspense exposing (Cache, CmdHtml, emptyCache, mapCmdView, mapCmdViewList, saveToCache, timeout)
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
    timeout model.suspenseModel
        { ms = 500, fallback = text "Loading...", key = "movieDetailsTimeout" }
        (mapCmdViewList
            [ MovieList.view model, MovieDetails.view model ]
            (\pages ->
                let
                    detailsSlide =
                        if model.selectedMovie == Nothing then
                            []

                        else
                            [ style "transform" "translateX(-50%)" ]
                in
                div
                    [ style "max-width" "500px"
                    , style "width" "100%"
                    , style "overflow-x" "hidden"
                    ]
                    [ div
                        ([ style "width" "200%"
                         , style "display" "flex"
                         , style "transition" "transform 350ms ease-in-out"
                         ]
                            ++ detailsSlide
                        )
                        pages
                    ]
            )
        )


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
