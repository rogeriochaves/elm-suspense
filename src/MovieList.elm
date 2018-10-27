module MovieList exposing (view)

import Html exposing (..)
import Html.Events exposing (..)
import Suspense exposing (..)
import Types exposing (..)


view model =
    div []
        [ text "Movie Search"
        , br [] []
        , input [ onInput UpdateSearch ] []
        , br [] []
        , results model
        ]


results model =
    case model.searchResult of
        Cached query result ->
            div []
                [ text "Results:"
                , br [] []
                , text model.searchInput
                ]

        Empty ->
            text "no results to show"



-- https://api.themoviedb.org/3/search/movie?api_key=762954999d09f9db6ffc6c0e6f37d509&query=
