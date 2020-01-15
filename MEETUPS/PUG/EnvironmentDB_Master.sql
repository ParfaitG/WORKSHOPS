WITH land AS (
   SELECT CONCAT(year, '-01-01')::date AS "date", 
          percent_arable / 100 AS arable_land
   FROM arable_land
   WHERE country_name = 'World'
), carbon AS (
   SELECT CONCAT(date_year, '-', date_month, '-01')::date AS "date", 
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
         '-01')::date AS "date", 
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
                 AS date) AS "date",
            gmsl_variation_mean_smooth_semi_annual AS global_sea_level
     FROM global_mean_sea_level) sub
  ORDER BY sub.date DESC
), ocean_oxy AS (
   SELECT CONCAT(o.year::int, '-', o.month::int, '-', 1)::date AS "date", 
          AVG(o.oxygen) AS oxygen
   FROM ocean_data o          
   WHERE o.oxygen <> -9999
   GROUP BY CONCAT(o.year::int, '-', o.month::int, '-', 1)::date
), ocean_ph AS (
   SELECT CONCAT(o.year::int, '-', o.month::int, '-', 1)::date as "date", 
          AVG(o.phts25p0) AS ph_scale
   FROM ocean_data o         
   WHERE o.phts25p0 <> -9999
   GROUP BY CONCAT(o.year::int, '-', o.month::int, '-', 1)::date
), ocean_tco2 AS (
   SELECT CONCAT(o.year::int, '-', o.month::int, '-', 1)::date AS "date", 
          AVG(o.tco2) AS tco2
   FROM ocean_data o          
   WHERE o.tco2 <> -9999
   GROUP BY CONCAT(o.year::int, '-', o.month::int, '-', 1)::date
), us_co2 AS (
   SELECT CONCAT(date_year, '-', date_month, '-1')::date AS "date",
          energy_co2 AS us_co2
   FROM us_co2_emissions
   WHERE date_month <> '13'
   AND msn = 'TETCEUS'
), us_gdp AS (
   SELECT "date",
          SUM(real_gdp) / 1E9 AS us_gdp
   FROM us_gdp
   GROUP BY "date"
), us_pop AS (
   SELECT "date",
          popthm as us_pop
   FROM us_population
), world_co2 AS (
   SELECT CONCAT(year, '-01-01')::date AS "date", 
          (co2_emissions / 1E6) AS world_co2
   FROM world_co2_emissions
   WHERE country_name = 'World'
), world_gdp AS (
   SELECT CONCAT(year, '-01-01')::date AS "date",
          (gdp / 1E9) AS world_gdp
   FROM world_gdp
   WHERE country_name = 'World'
), world_pop AS (
   SELECT CONCAT(year, '-01-01')::date AS "date", 
          (population  / 1E6) AS world_pop
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
         ON us_pop.date = land.date
