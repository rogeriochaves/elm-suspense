module Types exposing (Model, Movie, Msg(..))

import Html exposing (..)
import Http
import Suspense exposing (..)


type alias Model =
    { suspenseModel : Suspense.Model (Html Msg)
    , view : Html Msg
    , searchInput : String
    , moviesCache : Cache (Result Http.Error (List Movie))
    }


type alias Movie =
    { name : String
    , posterPath : String
    }


type Msg
    = UpdateSearch String
    | MoviesLoaded String (Result Http.Error (List Movie))
    | SuspenseMsg (Suspense.Msg (Html Msg))
