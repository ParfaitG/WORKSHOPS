options(connectionObserver = NULL)

library(RSQLite, quietly = TRUE)
library(RGtk2, quietly = TRUE)
library(gWidgets2, quietly = TRUE)
library(gWidgets2RGtk2, quietly = TRUE)
options(guiToolkit="RGtk2")

 setwd("/home/parfaitg/Documents/CRUG")


getList <- function(){
  conn <- dbConnect(SQLite(), dbname = "Data/CTA_Data.db")
  
  strSQL <- "SELECT DISTINCT [stationname] FROM Ridership r ORDER BY [stationname]"
  
  df <- dbGetQuery(conn, strSQL)
  datalist <- c("", df[[1]])
  dbDisconnect(conn)
   
  return(datalist)
}


mainWindow <- function(makelist){
  win <- gwindow("GUI GWidgets Menu", height = 100, width = 550, parent=c(500, 200))

  img <- gdkPixbufNewFromFile("/home/parfaitg/Documents/CRUG/Images/R_Logo.png")
  getToolkitWidget(win)$setIcon(img)

  tbl <- glayout(cont=win, spacing = 8, padding=20)
  box <- gtkHBox(TRUE, 5)
  font(tbl) <- list(size=14, family="Arial")


  # IMAGE AND TITLE
  tmp <- gimage(filename = "Images/R_CTA.gif", dirname = getwd(), container = tbl)
  tbl[1,1] <- tmp
  
  tmp <- glabel("        Ridership and Stations Data Filter        \n", container = tbl)
  font(tmp) <- list(size=16, family="Arial")
  tbl[1,2] <- tmp
  

  # YEAR
  tmp <- glabel("    Year       ", container = tbl)
  font(tmp) <- list(size=14, family="Arial")
  tbl[2,1] <- tmp

  tmp <- gcombobox(c(2001:2018), selected = length(c(2001:2018)), editable = TRUE, container = tbl)
  font(tmp) <- list(size=14, family="Arial")
  tbl[2,2] <- yearcbo <- tmp


  # STATION
  tmp <- glabel("    Station   ", container = tbl)
  font(tmp) <- list(size=14, family="Arial")
  tbl[3,1] <- tmp

  station_list <- getList()
  tmp <- gcombobox(station_list, selected = 1, editable = TRUE, container = tbl, font.attrs=list(size=14, family="Arial"))
  font(tmp) <- list(size=14, family="Arial")
  tbl[3,2] <- stationcbo <- tmp

  
  # RAIL LINE
  tmp <- glabel("    Line       ", container = tbl)
  font(tmp) <- list(size=14, family="Arial")

  tbl[4,1] <- tmp
  tmp <- gcombobox(c("", "blue", "brown", "green", "orange", "pink", "purple", "purple exp", "red", "yellow"),
                   selected = 1, editable = TRUE, container = tbl)
  font(tmp) <- list(size=14, family="Arial")
  tbl[4,2] <- linecbo <- tmp

  
  # DIRECTION
  tmp <- glabel("    Direction", container = tbl)
  font(tmp) <- list(size=14, family="Arial")
  tbl[5,1] <- tmp
  tmp <- gcombobox(c("", "N", "S", "E", "W"), selected = 1, editable = TRUE, container = tbl)
  font(tmp) <- list(size=14, family="Arial")
  tbl[5,2] <- directioncbo <- tmp

  
  # BUTTON
  tmp <- gbutton("OUTPUT", container = tbl)
  font(tmp) <- list(size=12, family="Arial")
  tbl[6,2] <- btnoutput <- tmp

  tbl[7,1] <- glabel("   ", container = tbl)

  addHandlerChanged(btnoutput, handler=function(...){

    yr <- svalue(yearcbo)
    st <- svalue(stationcbo)
    di <- svalue(directioncbo)
    conn <- dbConnect(SQLite(), dbname = "Data/CTA_Data.db")
    strSQL <- paste("SELECT r.station_id, '    ' || strftime('%m-%d-%Y', r.date, 'unixepoch') || '    ' As ride_date,",
                    "       '    ' || s.station_descriptive_name || '    ' as station_name,",
                    "       '    ' || r.rides || '    ' As rides, '    ' || s.direction_id || '    ' As direction",
                    "FROM Ridership r",
                    "INNER JOIN Stations s ON r.station_id = s.map_id",
                    "WHERE strftime('%m-%d-%Y', r.date, 'unixepoch') LIKE ?",
                    "  AND r.stationname = ?",
                    "  AND s.direction_id = ?")

    res <- dbSendQuery(conn, strSQL) 
    dbBind(res, list(paste0("%", yr, "%"), st, di))
    df <- dbFetch(res)
    dbClearResult(res)
    dbDisconnect(conn)
  
    df <- setNames(df[c("ride_date", "direction", "rides", "station_name")], 
                      c("    ride_date", "    direction    ", "    rides", "    station_name"))

    tblwin <- gWidgets2::gwindow("Output Table", height = 450, width = 600, parent=c(700, 200))
    tab <- gtable(df, chosencol = 2, container=tblwin)
    font(tab) <- list(size=12, family="Arial")

  })

  return(list(win=win))
}

m <- mainWindow()
while(isExtant(m$win)) Sys.sleep(1)


