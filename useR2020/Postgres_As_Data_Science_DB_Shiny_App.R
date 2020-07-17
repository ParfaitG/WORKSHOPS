
library(shiny, quietly = TRUE)
library(DT, quietly = TRUE)

library(RPostgreSQL, quietly = TRUE)
library(ggplot2, quietly = TRUE)
library(scales, quietly = TRUE)

seabornPalette <- c("#4c72b0","#55a868","#c44e52","#8172b2","#ccb974","#64b5cd","#4c72b0","#55a868",
                    "#c44e52","#8172b2","#ccb974","#64b5cd","#4c72b0","#55a868","#c44e52","#8172b2",
                    "#ccb974","#64b5cd","#4c72b0","#55a868","#c44e52","#8172b2","#ccb974","#64b5cd",
                    "#4c72b0","#55a868","#c44e52","#8172b2","#ccb974","#64b5cd","#4c72b0","#55a868",
                    "#c44e52","#8172b2","#ccb974","#64b5cd","#4c72b0","#55a868","#c44e52","#8172b2",
                    "#ccb974","#64b5cd","#4c72b0","#55a868","#c44e52","#8172b2","#ccb974","#64b5cd",
                    "#4c72b0","#55a868","#c44e52","#8172b2","#ccb974","#64b5cd","#4c72b0","#55a868",
                    "#c44e52","#8172b2","#ccb974","#64b5cd")

###################################
### GRAPH METHODS
###################################

graph_fct <- function(df, main, series1, col1, label1, smooth=FALSE, series2, col2, label2, scale_unit, scale_fmt){
  
  scaleFactor <-  (max(df[[series2]]) / max(df[[series1]])) / scale_unit
  cols <- setNames(c(col1, col2), c(series1, series2))
  
  ggplot(df, aes(x=date)) + 
  {if(smooth == TRUE) {
    geom_smooth(aes(y = !!ensym(series1), color=series1), method="loess")
  } else {
    geom_line(aes(y = !!ensym(series1), color=series1))
  }} +
    geom_line(aes(y = (!!ensym(series2)/scale_unit) / scaleFactor, color=series2)) +
    scale_color_manual(name="", values=cols) +
    scale_x_date(expand=c(0,0)) +
    scale_y_continuous(
      name = label1, 
      expand = c(0, 0),
      sec.axis = sec_axis(~. * scaleFactor, name = label2, labels=comma),
      labels={if(scale_fmt=="percent_format") { percent_format() } 
              else if (scale_fmt == "number_format") { number_format(accuracy = 0.01)} 
              else { comma }}) +
    labs(title=main) +
    theme(plot.title = element_text(hjust=0.5, size=20),
          text = element_text(size=18),
          legend.position="top",
          axis.title.y.left = element_text(color=col1),
          axis.text.y.left = element_text(color=col1),
          axis.title.y.right = element_text(color=col2),
          axis.text.y.right = element_text(color=col2))
  
}

graph_multi_fct <- function(df, main, categ, series1, label1, series2, col2, label2, scale_unit, scale_fmt) {
  is.character(categ)
  scaleFactor <-  (max(df[[series2]]) / max(df[[series1]])) / scale_unit
  
  ggplot(df, aes(x=date, color=!!ensym(categ))) + 
    geom_smooth(aes(y = !!ensym(series1), color=!!ensym(categ)), method="loess") +
    geom_line(aes(y = ((!!ensym(series2)/scale_unit) / scaleFactor)), color=col2) +
    scale_color_manual(values=seabornPalette) +
    scale_y_continuous(
      name = label1, 
      expand = c(0, 0),
      sec.axis = sec_axis(~. * scaleFactor, name=label2, label=comma),
      label=scale_fmt) +
    labs(title=main) +
    theme(plot.title = element_text(hjust=0.5, size=20),
          text = element_text(size=18),
          legend.position="top",
          axis.title.y.right = element_text(color=col2),
          axis.text.y.right = element_text(color=col2))
  
}


data_query <- function(series1_sub_df, series2_sub_df){
  
  # CONNECT TO DATABASE
  conn <- dbConnect(RPostgreSQL::PostgreSQL(), host="10.0.0.220", dbname="environment",
                    user="postgres", password="env19", port=6432)
  
  '%not_in%' <- Negate('%in%')
  
  if(series1_sub_df$source[1] %not_in% c("species_count", "plants_count", "sea_ice_extent", 
                                         "us_renewable_consumption", "us_sector_consumption")) {
    
    sql <- "WITH land AS (
                   SELECT CONCAT(year, '-01-01')::date AS \"date\", 
                          percent_arable / 100 AS arable_land
                   FROM arable_land
                   WHERE country_name = 'World'
            ), carbon AS (
                   SELECT CONCAT(date_year, '-', date_month, '-01')::date AS \"date\", 
                          average_ppm as carbon_ppm
                   FROM ppm_month
            ), temp AS (
                   SELECT CONCAT(t.year::int, '-', 
                          CASE t.period
                              WHEN 'Jan' THEN '01'
                              WHEN 'Feb' THEN '02'
                              WHEN 'Mar' THEN '03'
                              WHEN 'Apr' THEN '04'
                              WHEN 'May' THEN '05'
                              WHEN 'Jun' THEN '06'
                              WHEN 'Jul' THEN '07'
                              WHEN 'Aug' THEN '08'
                              WHEN 'Sep' THEN '09'
                              WHEN 'Oct' THEN '10'
                              WHEN 'Nov' THEN '11'
                              WHEN 'Dec' THEN '12'
                          END,
                         '-01')::date AS \"date\", 
                         AVG(t.global_mean) AS global_temperature
                   FROM global_temperature t
                   WHERE t.period IN ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                                     'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec')
                  GROUP BY CONCAT(t.year::int, '-', 
                                 CASE t.period
                                    WHEN 'Jan' THEN '01'
                                    WHEN 'Feb' THEN '02'
                                    WHEN 'Mar' THEN '03'
                                    WHEN 'Apr' THEN '04'
                                    WHEN 'May' THEN '05'
                                    WHEN 'Jun' THEN '06'
                                    WHEN 'Jul' THEN '07'
                                    WHEN 'Aug' THEN '08'
                                    WHEN 'Sep' THEN '09'
                                    WHEN 'Oct' THEN '10'
                                    WHEN 'Nov' THEN '11'
                                    WHEN 'Dec' THEN '12'
                                END,
                               '-01')::date
            ), sea_level AS (
              SELECT DISTINCT ON (sub.date) sub.date, sub.global_sea_level
              FROM
                (SELECT CAST(DATE_TRUNC('month', CONCAT(floor(year_fraction), '-01-01')::date + 
                                                 INTERVAL '1' day * ((year_fraction - floor(year_fraction)) * 365)::int) 
                             AS date) AS \"date\",
                        gmsl_variation_mean_smooth_semi_annual AS global_sea_level
                 FROM global_mean_sea_level) sub
              ORDER BY sub.date DESC
            ), ocean_oxy AS (
                   SELECT CONCAT(o.year::int, '-', o.month::int, '-', 1)::date AS \"date\", 
                          AVG(o.oxygen) AS oxygen
                   FROM ocean_data o          
                   WHERE o.oxygen <> -9999
                   GROUP BY CONCAT(o.year::int, '-', o.month::int, '-', 1)::date
            ), ocean_ph AS (
                   SELECT CONCAT(o.year::int, '-', o.month::int, '-', 1)::date as \"date\", 
                          AVG(o.phts25p0) AS ph_scale
                   FROM ocean_data o         
                   WHERE o.phts25p0 <> -9999
                   GROUP BY CONCAT(o.year::int, '-', o.month::int, '-', 1)::date
            ), ocean_tco2 AS (
                   SELECT CONCAT(o.year::int, '-', o.month::int, '-', 1)::date AS \"date\", 
                          AVG(o.tco2) AS tco2
                   FROM ocean_data o          
                   WHERE o.tco2 <> -9999
                   GROUP BY CONCAT(o.year::int, '-', o.month::int, '-', 1)::date
            ), us_co2 AS (
                   SELECT CONCAT(date_year, '-', date_month, '-1')::date AS \"date\",
                          energy_co2 AS us_co2
                   FROM us_co2_emissions
                   WHERE date_month <> '13'
                   AND msn = 'TETCEUS'
            ), us_gdp AS (
                   SELECT \"date\",
                          SUM(real_gdp) AS us_gdp
                   FROM us_gdp
                   GROUP BY \"date\"
            ), us_pop AS (
                   SELECT \"date\",
                          popthm as us_pop
                   FROM usa_population
            ), world_co2 AS (
                   SELECT CONCAT(year, '-01-01')::date AS \"date\", 
                          co2_emissions AS world_co2
                   FROM world_co2_emissions
                   WHERE country_name = 'World'
            ), world_gdp AS (
                   SELECT CONCAT(year, '-01-01')::date AS \"date\",
                          gdp AS world_gdp
                   FROM world_gdp
                   WHERE country_name = 'World'
            ), world_pop AS (
                   SELECT CONCAT(year, '-01-01')::date AS \"date\", 
                          population AS world_pop
                   FROM world_population
                   WHERE country_name = 'World'
    )
    
    SELECT us_pop.date, world_pop.world_pop,
           world_gdp.world_gdp, world_co2.world_co2,
           us_pop.us_pop, us_gdp.us_gdp, us_co2.us_co2,
           ocean_oxy.oxygen, ocean_ph.ph_scale, ocean_tco2.tco2, 
           temp.global_temperature, sea_level.global_sea_level,
           carbon.carbon_ppm, land.arable_land
    FROM us_pop
    LEFT JOIN us_gdp
         ON us_pop.date = us_gdp.date
    LEFT JOIN us_co2
         ON us_pop.date = us_co2.date
    LEFT JOIN world_pop
         ON us_pop.date = world_pop.date
    LEFT JOIN world_gdp
         ON us_pop.date = world_gdp.date
    LEFT JOIN world_co2
         ON us_pop.date = world_co2.date
    LEFT JOIN ocean_tco2
         ON us_pop.date = ocean_tco2.date
    LEFT JOIN ocean_ph
         ON us_pop.date = ocean_ph.date
    LEFT JOIN ocean_oxy
         ON us_pop.date = ocean_oxy.date
    LEFT JOIN temp
         ON us_pop.date = temp.date
    LEFT JOIN sea_level
         ON us_pop.date = sea_level.date
    LEFT JOIN carbon
         ON us_pop.date = carbon.date
    LEFT JOIN land
         ON us_pop.date = land.date"
    
    query_df <- withProgress(expr = { dbGetQuery(conn, sql)[c("date", series1_sub_df$source[1], series2_sub_df$source[1])] },
                             message = "Querying... Please wait")
    query_df <- query_df[complete.cases(query_df), ]
    
    # DISCONNECT FROM DATABASE
    on.exit(dbDisconnect(conn))
    
    title <- paste(series1_sub_df$label[1], 'vs.', series2_sub_df$label[1])
    
    query_plot <- graph_fct(df=query_df, main=title, smooth=series1_sub_df$smooth[1],
                            series1=series1_sub_df$source[1], col1=seabornPalette[1], label1=series1_sub_df$graph[1], 
                            series2=series2_sub_df$source[1], col2=seabornPalette[3], label2=series2_sub_df$graph[1],
                            scale_unit=series2_sub_df$scale[1], scale_fmt=series1_sub_df$format[1])
  }
  
  else {
    
    sql <- switch(series1_sub_df$source[1],
                  "species_count" = "WITH iucn_species_count AS (
                                          SELECT CONCAT(year, '-01-01')::date AS \"date\", 
                                                 SUM(species_count) AS species_count, 
                                                 category
                                          FROM iucn_species_count
                                          GROUP BY CONCAT(year, '-01-01')::date,
                                                   category
                                     ), us_gdp AS (
                                          SELECT \"date\",
                                          SUM(real_gdp) AS us_gdp
                                          FROM us_gdp
                                          GROUP BY \"date\"
                                     ), us_pop AS (
                                         SELECT \"date\",
                                          popthm as us_pop
                                          FROM usa_population
                                     ), world_gdp AS (
                                          SELECT CONCAT(year, '-01-01')::date AS \"date\",
                                          gdp AS world_gdp
                                          FROM world_gdp
                                          WHERE country_name = 'World'
                                     ), world_pop AS (
                                          SELECT CONCAT(year, '-01-01')::date AS \"date\", 
                                          population AS world_pop
                                          FROM world_population
                                          WHERE country_name = 'World'
                                     )
                              
                              SELECT us_pop.date, world_pop.world_pop,
                                     world_gdp.world_gdp, us_pop.us_pop, us_gdp.us_gdp, 
                                     iucn_species_count.category,
                                     iucn_species_count.species_count
                              FROM us_pop
                              LEFT JOIN us_gdp
                                    ON us_pop.date = us_gdp.date
                              LEFT JOIN world_pop
                                    ON us_pop.date = world_pop.date
                              LEFT JOIN world_gdp
                                    ON us_pop.date = world_gdp.date
                              LEFT JOIN iucn_species_count
                                    ON us_pop.date = iucn_species_count.date",
                  
                  "plants_count" =  "WITH plants_count AS (
                                          SELECT CONCAT(assessment_year, '-01-01')::date AS \"date\", 
                                                 COUNT(*) AS plants_count,  
                                                 interpreted_status
                                          FROM plants_assessments
                                          GROUP BY CONCAT(assessment_year, '-01-01')::date,
                                                   interpreted_status
                                    ), us_gdp AS (
                                          SELECT \"date\",
                                          SUM(real_gdp) AS us_gdp
                                          FROM us_gdp
                                          GROUP BY \"date\"
                                    ), us_pop AS (
                                          SELECT \"date\",
                                          popthm as us_pop
                                          FROM usa_population
                                    ), world_gdp AS (
                                          SELECT CONCAT(year, '-01-01')::date AS \"date\",
                                          gdp AS world_gdp
                                          FROM world_gdp
                                          WHERE country_name = 'World'
                                    ), world_pop AS (
                                          SELECT CONCAT(year, '-01-01')::date AS \"date\", 
                                          population AS world_pop
                                          FROM world_population
                                          WHERE country_name = 'World'
                                   )
                            
                                  SELECT us_pop.date, world_pop.world_pop,
                                         world_gdp.world_gdp, us_pop.us_pop, us_gdp.us_gdp, 
                                         plants_count.plants_count,
                                         plants_count.interpreted_status
                                  FROM us_pop
                                  LEFT JOIN us_gdp
                                        ON us_pop.date = us_gdp.date
                                  LEFT JOIN world_pop
                                        ON us_pop.date = world_pop.date
                                  LEFT JOIN world_gdp
                                        ON us_pop.date = world_gdp.date
                                  LEFT JOIN plants_count
                                        ON us_pop.date = plants_count.date",
                  
                  "sea_ice_extent" =  "WITH sea_ice AS (
                                          SELECT CONCAT(s.date_year, '-01-01')::date AS \"date\", 
                                                 AVG(s.extent) AS sea_ice_extent,
                                                 s.region
                                          FROM sea_ice_extent s
                                          GROUP BY CONCAT(s.date_year, '-01-01')::date,
                                                  s.region
                                    ), us_gdp AS (
                                          SELECT \"date\",
                                                 SUM(real_gdp) AS us_gdp
                                          FROM us_gdp
                                          GROUP BY \"date\"
                                    ), us_pop AS (
                                          SELECT \"date\",
                                                 popthm as us_pop
                                          FROM usa_population
                                    ), world_gdp AS (
                                          SELECT CONCAT(year, '-01-01')::date AS \"date\",
                                                 gdp AS world_gdp
                                          FROM world_gdp
                                          WHERE country_name = 'World'
                                    ), world_pop AS (
                                          SELECT CONCAT(year, '-01-01')::date AS \"date\", 
                                                 population AS world_pop
                                          FROM world_population
                                          WHERE country_name = 'World'
                                   )
                            
                                  SELECT us_pop.date, world_pop.world_pop,
                                         world_gdp.world_gdp, us_pop.us_pop, us_gdp.us_gdp, 
                                         sea_ice.sea_ice_extent,
                                         sea_ice.region
                                  FROM us_pop
                                  LEFT JOIN us_gdp
                                        ON us_pop.date = us_gdp.date
                                  LEFT JOIN world_pop
                                        ON us_pop.date = world_pop.date
                                  LEFT JOIN world_gdp
                                        ON us_pop.date = world_gdp.date
                                  LEFT JOIN sea_ice
                                        ON us_pop.date = sea_ice.date",
                  
                  "us_renewable_consumption" =  "WITH energy AS (
                                          SELECT \"date\", 
                                                 energy_type,
                                                 SUM(consumption) AS us_renewable_consumption
                                          FROM us_renewable_energy
                                          GROUP BY \"date\", 
                                                   energy_type
                                    ), us_gdp AS (
                                                  SELECT \"date\",
                                                  SUM(real_gdp) AS us_gdp
                                                  FROM us_gdp
                                                  GROUP BY \"date\"
                                    ), us_pop AS (
                                                  SELECT \"date\",
                                          popthm as us_pop
                                          FROM usa_population
                                    ), world_gdp AS (
                                          SELECT CONCAT(year, '-01-01')::date AS \"date\",
                                          gdp AS world_gdp
                                          FROM world_gdp
                                          WHERE country_name = 'World'
                                    ), world_pop AS (
                                          SELECT CONCAT(year, '-01-01')::date AS \"date\", 
                                          population AS world_pop
                                          FROM world_population
                                          WHERE country_name = 'World'
                                   )
                            
                                  SELECT us_pop.date, world_pop.world_pop,
                                         world_gdp.world_gdp, us_pop.us_pop, us_gdp.us_gdp, 
                                         energy.us_renewable_consumption,
                                         energy.energy_type
                                  FROM us_pop
                                  LEFT JOIN us_gdp
                                        ON us_pop.date = us_gdp.date
                                  LEFT JOIN world_pop
                                        ON us_pop.date = world_pop.date
                                  LEFT JOIN world_gdp
                                        ON us_pop.date = world_gdp.date
                                  LEFT JOIN energy
                                        ON us_pop.date = energy.date",
                  
                  "us_sector_consumption" =  "WITH consumed AS (
                                         SELECT CONCAT(c.date_year, '-', c.date_month, '-', 1)::date AS \"date\", 
                                                c.energy_consumed AS us_sector_consumption,
                                                CASE c.msn
                                                     WHEN 'TEACBUS' THEN 'Transportation Sector'
                                                     WHEN 'TECCBUS' THEN 'Commercial Sector'
                                                     WHEN 'TEICBUS' THEN 'Industrial Sector'
                                                     WHEN 'TERCBUS' THEN 'Residential Sector'
                                                END AS sector
                                         FROM consumption c
                                         WHERE c.msn IN ('TEACBUS', 'TECCBUS', 'TEICBUS', 'TERCBUS')
                                           AND c.date_month <> 13
                                    ), us_gdp AS (
                                                  SELECT \"date\",
                                                  SUM(real_gdp) AS us_gdp
                                                  FROM us_gdp
                                                  GROUP BY \"date\"
                                    ), us_pop AS (
                                                  SELECT \"date\",
                                          popthm as us_pop
                                          FROM usa_population
                                    ), world_gdp AS (
                                          SELECT CONCAT(year, '-01-01')::date AS \"date\",
                                          gdp AS world_gdp
                                          FROM world_gdp
                                          WHERE country_name = 'World'
                                    ), world_pop AS (
                                          SELECT CONCAT(year, '-01-01')::date AS \"date\", 
                                          population AS world_pop
                                          FROM world_population
                                          WHERE country_name = 'World'
                                   )
                            
                                  SELECT us_pop.date, world_pop.world_pop,
                                         world_gdp.world_gdp, us_pop.us_pop, us_gdp.us_gdp, 
                                         consumed.us_sector_consumption,
                                         consumed.sector
                                  FROM us_pop
                                  LEFT JOIN us_gdp
                                        ON us_pop.date = us_gdp.date
                                  LEFT JOIN world_pop
                                        ON us_pop.date = world_pop.date
                                  LEFT JOIN world_gdp
                                        ON us_pop.date = world_gdp.date
                                  LEFT JOIN consumed
                                        ON us_pop.date = consumed.date"
    )
    
    
    query_df <- withProgress(expr = { dbGetQuery(conn, sql)[c("date", series1_sub_df$categ[1], 
                                                              series1_sub_df$source[1], series2_sub_df$source[1])] },
                             message = "Querying... Please wait")
    query_df <- query_df[complete.cases(query_df), ]
    
    # DISCONNECT FROM DATABASE
    on.exit(dbDisconnect(conn))
    
    title <- paste(series1_sub_df$label[1], 'vs.', series2_sub_df$label[1])
   
    query_plot <- graph_multi_fct(df=query_df, main=title, categ=series1_sub_df$categ[1], 
                                  series1=series1_sub_df$source[1], label1=series1_sub_df$graph[1], 
                                  series2=series2_sub_df$source[1], col2="red", label2=series2_sub_df$graph[1], 
                                  scale_unit=series2_sub_df$scale[1], scale_fmt=comma)
    
  }

  return(list(table = query_df, plot = query_plot))
}


###################################
### USER INTERFACE
###################################

series1_df <- data.frame(source = c("arable_land", "carbon_ppm", "species_count",
                                    "plants_count", "global_temperature", 
                                    "global_sea_level", "oxygen", 
                                    "ph_scale", "tco2", "sea_ice_extent", 
                                    "us_renewable_consumption", "us_sector_consumption",
                                    "us_co2", "world_co2"),
                         label = c("Arable Land", "Carbon PPM", "IUCN Red Threat List",
                                   "BGCI Plants Assessments", "Global Temperature", 
                                   "Global Sea Level", "Ocean Data - Oxygen", 
                                   "Ocean Data - ph Scale", "Ocean Data - Total Carbon",
                                   "Sea Ice Extent", "U.S. Renewable Consumption", 
                                   "U.S. Sector Consumption", "U.S. Carbon Emissions", 
                                   "World Carbon Emissions"),
                         graph = c("World Percent of Arable Land\n", "Average Carbon PPM\n",
                                   "Species Count\n", "Plants Count\n", "Global Mean Temperature\n",
                                   "Global Sea Level\n", "Avg Oxygen (µmol kg−1)\n",
                                   "Avg pH at total scale (25C and 0 dbar of pressure)\n",
                                   "Avg Total Carbon Dioxide (µmol kg−1)\n", "Average Sea Ice Extent\n",
                                   "Consumption (trillions BTU)\n", "Consumption (trillions BTU)\n", 
                                   "Emissions (Million Metric Tons)\n",
                                   "World CO2 Emissions (kt)\n"),
                         categ = c(NA, NA, "category", "interpreted_status", NA, NA, NA, NA, NA,
                                   "region", "energy_type", "sector", NA, NA),
                         smooth = c(FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, TRUE, 
                                    TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, FALSE),
                         format = c("percent_format", "comma", "comma", "comma", "number_format", 
                                    "number_format", "comma", "comma", "comma", "comma", "comma", 
                                    "comma", "comma", "comma"),
                         stringsAsFactors = FALSE)

series2_df <- data.frame(source = c("us_gdp", "us_pop", "world_gdp", "world_pop"),
                         label = c("U.S. GDP", "U.S. Population", "World GDP", "World Population\n"),
                         graph = c("U.S. GDP (billions)\n", "U.S. Population (millions)\n",
                                   "World GDP (billions)\n", "World Population (millions)\n"),
                         scale = c(1E3, 1, 1E9, 1E6),
                         stringsAsFactors = FALSE)


ui <- fluidPage(
  #titlePanel(windowTitle = "Environment Database Graphs"),
  
  sidebarLayout(
    sidebarPanel(h2("Environment Database Graphs"),
                 br(),
                 img(src='postgresql_r.png', height=80),
                 br(), br(),
                 selectInput("series1", NULL,
                 setNames(series1_df$source, series1_df$label), selected = "carbon_ppm"),
                 selectInput("series2", NULL,
                             setNames(series2_df$source, series2_df$label), selected = "world_pop"),
                 actionButton("submit", "Submit"),
                 br(),br(),
                 p("Powered by Postgres"),
                 width = 3
    ),
    mainPanel(h3("Table"),
              DT::dataTableOutput("env_table"),
              br(),
              h3("Graph"),
              plotOutput("env_plot", height = "500px"),
              br()
    )
  )
)



###################################
### SERVER LOGIC
###################################
server <- function(input, output) {
  
  series1_pick <- reactive({ input$series1 })
  series2_pick <- reactive({ input$series2 })
  
  get_output <- eventReactive(input$submit, {
    tryCatch({
      s1 <- subset(series1_df, source == series1_pick())
      s2 <- subset(series2_df, source == series2_pick())
      data_list <- data_query(s1, s2)
    }, 
    warning = function(w) {
      print(w)
    },
    error = function(e) {
      print(e)
    })
    
    return(data_list)
    
  }, ignoreNULL = FALSE)
  
  output$env_table <- DT::renderDataTable({
    output_list <- get_output()
    DT::datatable(output_list$table, escape = FALSE)
  })
  
  output$env_plot <- renderPlot({
    output_list <- get_output()
    output_list$plot
  })
  
}

###################################
### RUN APP
###################################
shinyApp(ui = ui, server = server)


