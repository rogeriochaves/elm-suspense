module Types exposing (Model, Movie, MovieDetails, Msg(..))

import Html exposing (..)
import Http
import Suspense exposing (..)


type alias Model =
    { suspenseModel : Suspense.Model (Html Msg)
    , view : Html Msg
    , searchInput : String
    , moviesCache : Cache (Result Http.Error (List Movie))
    , movieDetailsCache : Cache (Result Http.Error MovieDetails)
    , selectedMovie : Maybe Movie
    }


type alias Movie =
    { id : Int
    , title : String
    , posterPath : String
    }


type alias MovieDetails =
    { overview : String
    }


type Msg
    = UpdateSearch String
    | MoviesLoaded String (Result Http.Error (List Movie))
    | SuspenseMsg (Suspense.Msg (Html Msg))
    | ShowMovieDetails Movie
    | MovieDetailsLoaded String (Result Http.Error MovieDetails)
    | BackToSearch
