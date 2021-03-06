#' @import dplyr
#' @export
getCountyNameFIPSMapping <- function(StateFIPSCode) {
   getCountyData() %>%
    filter(STATEFP==StateFIPSCode) %>%
    select(CountyName=NAME, County=GEOID) %>% mutate_each("as.character")
}

#' @importFrom rgdal readOGR
#' @import dplyr
#' @export
getCountyData <- function() {
  if (!exists("countyData", env=packageEnv)) {
    assign("countyData", readOGR("data-raw/tl_2016_us_county/", "tl_2016_us_county")@data, env=packageEnv)
  }
  get("countyData", env=packageEnv)
}

#' @importFrom sp CRS spTransform
#' @importFrom rgdal readOGR
#' @importFrom rgeos gIntersection gArea
getAlaskaPrecinctCountyMapping <- function() {

  if (!exists("alaskaPrecinctCountyMapping", env=packageEnv)) {

    county_shp <- readOGR("data-raw/tl_2016_us_county/", "tl_2016_us_county") %>% subset(.$STATEFP == '02')
    precinct_shp <- readOGR("data-raw/ak/2013-SW-Proc-Shape-files/", "2013-SW-Proc-Shape-files")

    crs <- CRS("+proj=aea +lat_1=55 +lat_2=65 +lat_0=50 +lon_0=-154 +x_0=0 +y_0=0 +ellps=GRS80 +datum=NAD83 +units=m +no_defs")

    boroughList <- as.list(as.character(county_shp@data$COUNTYFP))
    boroughShapefileList <- lapply(boroughList, function(fipscode) {spTransform(subset(county_shp, county_shp$COUNTYFP == fipscode), crs)})
    precinctList <- as.list(as.character(precinct_shp@data$DISTRICT))
    precinctShapefileList <- lapply(precinctList, function(districtCode) {spTransform(subset(precinct_shp, precinct_shp$DISTRICT == districtCode), crs)})

    matchedBoroughs <- character()
    precincts <- character()

    for (ps in precinctShapefileList) {
      maxArea <- 0.0
      bestMatch <- NA
      bestMatchName <- NA
      for (bs in boroughShapefileList) {
        i <- gIntersection(bs, ps)
        if (!is.null(i)) {
          a <- gArea(i) / 1000000
          if (a > maxArea) {
            if (maxArea >= 5) {
              precinctArea <- gArea(ps) / 1000000
              writeLines(paste0("Precinct ", gsub("[\r\n]", "", ps$NAME), " also matched borough ", bestMatchName, " with area of ", maxArea,
                                " out of a total precinct area of ", precinctArea, " square km (", 100*maxArea/precinctArea, "%)"))
            }
            maxArea <- a
            bestMatch <- as.character(bs$COUNTYFP)
            bestMatchName <- as.character(bs$NAMELSAD)
          }
        }
      }
      writeLines(paste0("Matched precinct ", gsub("[\r\n]", "", ps$NAME), " with borough ", bestMatch, "=", bestMatchName))
      matchedBoroughs <- c(matchedBoroughs, bestMatch)
      precincts <- c(precincts, as.character(ps$DISTRICT))
    }

    precinctCountyMap <- data.frame(Precinct=precincts, County=matchedBoroughs, stringsAsFactors=FALSE)
    assign("alaskaPrecinctCountyMapping", precinctCountyMap, env=packageEnv)

  }

  get("alaskaPrecinctCountyMapping", env=packageEnv)

}

packageEnv <- new.env()
