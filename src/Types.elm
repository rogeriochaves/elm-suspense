module Types exposing (Model, Msg(..))

import Html exposing (..)
import Http
import Suspense exposing (..)


type alias Model =
    { view : Html Msg
    , searchInput : String
    , searchResult : Cache (List Movie)
    }


type alias Movie =
    { name : String
    }


type Msg
    = UpdateSearch String
    | SearchMovies String (Result Http.Error String)
