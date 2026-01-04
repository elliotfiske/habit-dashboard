module DatasourceIds exposing (RizeDatasourceId(..), TogglDatasourceId(..), rizeDatasourceIdDecoder, rizeDatasourceIdEncoder, togglDatasourceIdDecoder, togglDatasourceIdEncoder)

import Json.Decode exposing (Decoder)
import Json.Encode


type RizeDatasourceId
    = RizeDatasourceIdBrand String


type TogglDatasourceId
    = TogglDatasourceIdBrand String


togglDatasourceIdDecoder : Decoder TogglDatasourceId
togglDatasourceIdDecoder =
    Json.Decode.string
        |> Json.Decode.map TogglDatasourceIdBrand


togglDatasourceIdEncoder : TogglDatasourceId -> Json.Encode.Value
togglDatasourceIdEncoder (TogglDatasourceIdBrand id) =
    Json.Encode.string id


rizeDatasourceIdDecoder : Decoder RizeDatasourceId
rizeDatasourceIdDecoder =
    Json.Decode.string
        |> Json.Decode.map RizeDatasourceIdBrand


rizeDatasourceIdEncoder : RizeDatasourceId -> Json.Encode.Value
rizeDatasourceIdEncoder (RizeDatasourceIdBrand id) =
    Json.Encode.string id
