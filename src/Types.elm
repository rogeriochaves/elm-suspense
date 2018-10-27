module Types exposing (Model, Movie, Msg(..))

import Html exposing (..)
import Http
import Suspense exposing (..)


type alias Model =
    { view : Html Msg
    , searchInput : String
    , searchResult : Cache (Result Http.Error (List Movie))
    }


type alias Movie =
    { name : String
    }


type Msg
    = UpdateSearch String
    | SearchMovies String (Result Http.Error (List Movie))
