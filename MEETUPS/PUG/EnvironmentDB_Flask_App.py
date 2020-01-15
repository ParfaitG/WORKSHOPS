#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import io
import base64
import psycopg2

from flask import Flask
from flask import render_template, request
from flask import jsonify, flash

import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

sns.set()
seaborn_palette = sns.color_palette()

app = Flask(__name__)
app.secret_key = "888"


###################################
### GRAPH FUNCTIONS
###################################

def graph_fct(df, main, series1, col1, title1, series2, col2, title2):

    img = io.BytesIO()

    with plt.rc_context({'ytick.color':  col1}):
       fig, ax = plt.subplots(figsize=(12,5))
       df.reindex([series1], axis=1).plot(kind='line', ax=ax, color = col1)
       ax.set_ylabel(title1, color =  col1)
       
    with plt.rc_context({'ytick.color': col2}):
       df.reindex([series2], axis=1).plot(kind='line', ax=ax, secondary_y=True, color = col2)   
       ax.right_ax.set_ylabel(title2, color = col2)
    
    lns = ax.get_lines() + ax.right_ax.get_lines()
    labs = [l.get_label() for l in lns]
    ax.legend(lns, labs, loc=0)

    plt.title(main, fontsize=18, fontweight='bold')
    plt.tight_layout()
    
    plt.savefig(img, format='png')
    img.seek(0)

    plot_url = base64.b64encode(img.getvalue()).decode()

    return plot_url


def graph_multiple_fct(df, main, categ, series, multiple_title, other_series, other_col, other_title):
    
    img = io.BytesIO()

    fig, ax = plt.subplots(figsize=(12,5))
    df.reset_index().pivot(index='date', columns=categ, values=series).plot(kind='line', ax=ax)
    ax.set_ylabel(multiple_title)
       
    with plt.rc_context({'ytick.color': other_col}):
       df.reindex([other_series], axis=1).plot(kind='line', ax=ax, secondary_y=True, color = other_col)   
       ax.right_ax.set_ylabel(other_title, color = other_col)
        
    lns = ax.get_lines() + ax.right_ax.get_lines()
    labs = [l.get_label() for l in lns]
    ax.get_legend().remove() 
    first_lgd = plt.legend(lns, labs, loc='upper left')
    ax.right_ax.add_artist(first_lgd)

    plt.title(main, fontsize=18, fontweight='bold')
    plt.tight_layout()
    
    plt.savefig(img, format='png')
    img.seek(0)

    plot_url = base64.b64encode(img.getvalue()).decode()

    return plot_url


def data_query(series1_dict, series2_dict):
  
  # CONNECT TO DATABASE
  conn = psycopg2.connect(host='localhost', user='postgres', password='env19', dbname='environment', port=6432)

  if not series1_dict['source'] in ["species_count", "plants_count", "sea_ice_extent", 
                                    "us_renewable_consumption", "us_sector_consumption"]:
    
    sql = """WITH land AS (
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
         ON us_pop.date = land.date"""
    
    query_df = (pd.read_sql(sql, conn, index_col='date')
                  .reindex([series1_dict['source'], series2_dict['source']], 
                           axis=1)
                  .dropna())

    query_list = (query_df.reset_index().apply(lambda x: x.to_list(), axis=1)).to_list()
    
    # DISCONNECT FROM DATABASE
    conn.close()
    
    title = series1_dict['label'] + ' vs. ' + series2_dict['label']
    
    query_plot = graph_fct(df = query_df, main=title,
                           series1 = series1_dict['source'], 
                           col1 = seaborn_palette[3], title1 = series1_dict['graph'],
                           series2 = series2_dict['source'], 
                           col2 = seaborn_palette[0], title2 = series2_dict['graph'])

  else:

    if series1_dict['source'] == "species_count":
    
       sql = """WITH iucn_species_count AS (
                     SELECT CONCAT(year, '-01-01')::date AS "date", 
                            SUM(species_count) AS species_count, 
                            category
                     FROM iucn_species_count
                     GROUP BY CONCAT(year, '-01-01')::date,
                              category
                ), us_gdp AS (
                     SELECT "date",
                            SUM(real_gdp) AS us_gdp
                     FROM us_gdp
                     GROUP BY "date"
                ), us_pop AS (
                    SELECT "date",
                           popthm as us_pop
                     FROM us_population
                ), world_gdp AS (
                     SELECT CONCAT(year, '-01-01')::date AS "date",
                            (gdp / 1E9) AS world_gdp
                     FROM world_gdp
                     WHERE country_name = 'World'
                ), world_pop AS (
                     SELECT CONCAT(year, '-01-01')::date AS "date", 
                            (population / 1E6) AS world_pop
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
               ON us_pop.date = iucn_species_count.date"""
                  
    elif series1_dict['source'] == "plants_count":

       sql = """WITH plants_count AS (
                     SELECT CONCAT(assessment_year, '-01-01')::date AS "date", 
                            COUNT(*) AS plants_count,  
                            interpreted_status
                     FROM plants_assessments
                     GROUP BY CONCAT(assessment_year, '-01-01')::date,
                              interpreted_status
               ), us_gdp AS (
                     SELECT "date",
                            SUM(real_gdp) AS us_gdp
                     FROM us_gdp
                     GROUP BY "date"
               ), us_pop AS (
                     SELECT "date",
                            popthm as us_pop
                     FROM us_population
               ), world_gdp AS (
                     SELECT CONCAT(year, '-01-01')::date AS "date",
                            (gdp / 1E9) AS world_gdp
                     FROM world_gdp
                     WHERE country_name = 'World'
               ), world_pop AS (
                     SELECT CONCAT(year, '-01-01')::date AS "date", 
                            population / 1E6 AS world_pop
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
                   ON us_pop.date = plants_count.date"""
                  
    elif series1_dict['source'] == "sea_ice_extent":

       sql = """WITH sea_ice AS (
                     SELECT CONCAT(s.date_year, '-01-01')::date AS "date", 
                             AVG(s.extent) AS sea_ice_extent,
                             s.region
                     FROM sea_ice_extent s
                     GROUP BY CONCAT(s.date_year, '-01-01')::date,
                             s.region
               ), us_gdp AS (
                     SELECT "date",
                            SUM(real_gdp) AS us_gdp
                     FROM us_gdp
                     GROUP BY "date"
               ), us_pop AS (
                     SELECT "date",
                            popthm as us_pop
                     FROM us_population
               ), world_gdp AS (
                     SELECT CONCAT(year, '-01-01')::date AS "date",
                            (gdp / 1E9) AS world_gdp
                     FROM world_gdp
                     WHERE country_name = 'World'
               ), world_pop AS (
                     SELECT CONCAT(year, '-01-01')::date AS "date", 
                            (population / 1E6) AS world_pop
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
                   ON us_pop.date = sea_ice.date"""

    elif series1_dict['source'] == "us_renewable_consumption":
                  
       sql = """WITH energy AS (
                     SELECT "date", 
                            energy_type,
                            SUM(consumption) AS us_renewable_consumption
                     FROM us_renewable_energy
                     GROUP BY "date", 
                              energy_type
               ), us_gdp AS (
                     SELECT "date",
                             SUM(real_gdp) AS us_gdp
                     FROM us_gdp
                     GROUP BY "date"
               ), us_pop AS (
                     SELECT "date",
                             popthm AS us_pop
                     FROM us_population
               ), world_gdp AS (
                     SELECT CONCAT(year, '-01-01')::date AS "date",
                            (gdp / 1E9) AS world_gdp
                     FROM world_gdp
                     WHERE country_name = 'World'
               ), world_pop AS (
                     SELECT CONCAT(year, '-01-01')::date AS "date", 
                            (population / 1E6) AS world_pop
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
                   ON us_pop.date = energy.date"""

    elif series1_dict['source'] == "us_sector_consumption":

       sql = """WITH consumed AS (
                     SELECT CONCAT(c.date_year, '-', c.date_month, '-', 1)::date AS "date", 
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
                     SELECT "date",
                            SUM(real_gdp) / 1E6 AS us_gdp
                     FROM us_gdp
                     GROUP BY "date"
               ), us_pop AS (
                     SELECT "date",
                            popthm AS us_pop
                     FROM us_population
               ), world_gdp AS (
                     SELECT CONCAT(year, '-01-01')::date AS "date",
                            (gdp / 1E9) AS world_gdp
                     FROM world_gdp

                     WHERE country_name = 'World'
               ), world_pop AS (
                     SELECT CONCAT(year, '-01-01')::date AS "date", 
                            (population / 1E6) AS world_pop
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
                   ON us_pop.date = consumed.date"""

    query_df = (pd.read_sql(sql, conn, index_col='date')
                  .reindex([series1_dict['categ'], series1_dict['source'], series2_dict['source']], 
                           axis=1)
                  .dropna())

    query_list = (query_df.reset_index().apply(lambda x: x.to_list(), axis=1)).to_list()

    # DISCONNECT FROM DATABASE
    conn.close()
    
    title = series1_dict['label'] + ' vs. ' + series2_dict['label']

    query_plot = graph_multiple_fct(df = query_df, main = title, 
                                    categ = series1_dict['categ'], series = series1_dict['source'], 
                                    multiple_title =  series1_dict['graph'], other_series =  series2_dict['source'], 
                                    other_col = seaborn_palette[5], other_title =  series2_dict['graph'])
      
  return {'headers': query_df.reset_index().columns.to_list(), 'table': query_list, 'plot': query_plot}


@app.route('/', methods= ['GET',  'POST'])
def get_data(s1='carbon_ppm', s2='world_pop'):

    s1_dict = {'arable_land': {'source': 'arable_land',
                               'label': 'Arable Land',
                               'graph': 'World Percent of Arable Land\n'},
               'carbon_ppm': {'source': 'carbon_ppm',
                              'label': 'Carbon PPM',
                              'graph': 'Average Carbon PPM\n'},
               'species_count': {'source': 'species_count',
                                 'label': 'IUCN Red Threat List',
                                 'graph': 'Species Count\n',
                                 'categ': 'category'},
               'plants_count': {'source': 'plants_count',
                                'label': 'BGCI Plants Assessments',
                                 'graph': 'Plants Count\n',
                                 'categ': 'interpreted_status'},
               'global_temperature': {'source': 'global_temperature',
                                      'label': 'Global Temperature',
                                      'graph': 'Global Mean Temperature\n'},
               'global_sea_level': {'source': 'global_sea_level',
                                    'label': 'Global Sea Level',
                                    'graph': 'Global Mean Sea Level\n'},
               'oxygen': {'source': 'oxygen',
                          'label': 'Ocean Data - Oxygen',
                          'graph': 'Avg Oxygen (µmol kg−1)\n'},
               'ph_scale': {'source': 'ph_scale',
                            'label': 'Ocean Data - ph Scale',
                            'graph': 'Avg pH at total scale (25C and 0 dbar of pressure)\n'},
               'tco2': {'source': 'tco2',
                        'label': 'Ocean Data - Total Carbon',
                        'graph': 'Avg Total Carbon Dioxide (µmol kg−1)\n'},
               'sea_ice_extent': {'source': 'sea_ice_extent',
                                  'label': 'Sea Ice Extent',
                                  'graph': 'Average Sea Ice Extent\n',
                                  'categ': 'region'},
               'us_sector_consumption': {'source': 'us_sector_consumption',
                                         'label': 'U.S. Energy Consumed by Sector',
                                         'graph': 'Sector Consumption (trillions BTU)\n',
                                         'categ': 'sector'},
               'us_renewable_consumption': {'source': 'us_renewable_consumption',
                                            'label': 'U.S. Renewable Consumption',
                                            'graph': 'Renewable Consumption (trillions BTU)\n',
                                            'categ': 'energy_type'},
               'us_co2': {'source': 'us_co2',
                          'label': 'U.S. Carbon Emissions',
                          'graph': 'Emissions (Million Metric Tons)\n'},
               'world_co2': {'source': 'world_co2',
                             'label': 'World Carbon Emissions',
                             'graph': 'World CO2 Emissions (kt)\n'}
              }

    s2_dict = {'us_gdp': {'source': 'us_gdp',
                          'label': 'U.S. GDP',
                          'graph': '\nU.S. GDP (millions)'},
               'us_pop': {'source': 'us_pop',
                          'label': 'U.S. Population',
                          'graph': '\nU.S. Population (millions)'},
               'world_gdp': {'source': 'world_gdp',
                             'label': 'World GDP',
                             'graph': '\nWorld GDP (billions)'},
               'world_pop': {'source': 'world_pop',
                             'label': 'World Population\n',
                             'graph': '\nWorld Population (millions)'}}

    output = data_query(s1_dict[s1], s2_dict[s2])
 
    return render_template('output.html', env_hdr = output['headers'], 
                           env_table = output['table'], env_plot = output['plot'])


@app.route('/data', methods=['POST'])
def data():
    return get_data(request.form['series1'], request.form['series2'])
    

if __name__ == '__main__':
    app.run(debug=True)
    
