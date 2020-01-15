
library(RSQLite)
library(shiny)
library(DT)

setwd("/home/parfaitg/Documents/CRUG")

conn <- dbConnect(SQLite(), dbname = paste0(getwd(), "/Data/CTA_Data.db"))
stations <- dbGetQuery(conn, "SELECT DISTINCT [stationname] FROM Ridership r ORDER BY [stationname]")
dbDisconnect(conn)


ui <- shinyUI(
              fluidPage(
                pageWithSidebar(
                  headerPanel("CTA SQL Shiny App"),                  
                  sidebarPanel(
                    a(img(src='R_CTA.png')),
                    br(),
                    tags$label("Year"),
                    selectInput("year", NULL, c("", 2000:2018), 
                                width = "600px", selected = 15),
                    tags$label("Station"),
                    selectInput("station", NULL, c("", stations$stationname), 
                                width = "600px", selected = 1),
                    tags$label("Line"),
                    selectInput("line", NULL, c("", "blue", "brown", "green", "orange", 
                                                "pink", "purple", "purple exp", "red", "yellow"),
                                width = "600px", selected = 1),
                    tags$label("Direction"),
                    selectInput("direction", NULL, c("", "N", "S", "W", "E"), 
                                width = "600px", selected = 1),
                    actionButton("output", "Output"),
                    br(),
                    br(),
                    h5("Powered by CTA Data")
                  ),
                  mainPanel(
                    h3("Output"),
                    DT::dataTableOutput("cta_table")
                  )
                )
              )
)

get_data <- function(input) {
  
  tryCatch({
    conn <- dbConnect(SQLite(), dbname = paste0(getwd(), "/Data/CTA_Data.db"))
    
    year_param <- reactive({ paste0("%", input$year, "%") })
    station_param <- reactive({ input$station })
    direction_param <- reactive({ input$direction })
    
    sql <- paste("SELECT r.station_id, strftime('%m-%d-%Y', r.date, 'unixepoch') As ride_date, s.station_descriptive_name, r.rides, s.direction_id",
                 "FROM Ridership r",
                 "INNER JOIN Stations s ON r.station_id = s.map_id",
                 "WHERE strftime('%m-%d-%Y', r.date, 'unixepoch') LIKE ?",
                 "  AND r.stationname = ?",
                 "  AND s.direction_id = ?")
    
    
    res <- dbSendQuery(conn, sql) 
    
    dbBind(res, list(year_param(), station_param(), direction_param()))
    df <- dbFetch(res)
    dbClearResult(res)
    
    return(list(cta_data = df))
  }, 
  warning= function(w) {
    print(w)
  },
  error = function(e) {
    print(e)
  },
  finally = { 
    dbDisconnect(conn) 
  })
  
}

server <- function(input, output, session) {
  
  observeEvent(input$output, {
    dbData <- reactive({
      get_data(input)
    })
    
    output$cta_table <- DT::renderDataTable({
      DT::datatable(dbData()$cta_data)
    })
  })
}


shinyApp(ui, server)
