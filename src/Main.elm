module Main exposing (main)

import Browser
import Html exposing (text)
import MovieList
import Suspense exposing (..)
import Types exposing (..)


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , view = .view
        , update = updateView
        , subscriptions = always Sub.none
        }


init flags =
    let
        model =
            { view = text ""
            , searchInput = ""
            , searchResult = Empty
            }
    in
    ( { model | view = view model }, Cmd.none )


view =
    MovieList.view


update msg model =
    case msg of
        UpdateSearch search ->
            ( { model | searchInput = search }, Cmd.none )

        SearchMovies query result ->
            case result of
                Ok _ ->
                    ( { model | searchResult = Cached query [ { name = "worked!" } ] }
                    , Cmd.none
                    )

                Err _ ->
                    ( model, Cmd.none )


updateView msg model =
    let
        ( model_, cmd ) =
            update msg model
    in
    ( { model_ | view = view model_ }, cmd )
