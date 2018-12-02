#!/usr/bin/env python3
import os
import numpy as np
import pandas as pd

# SOURCE: https://w2.weather.gov/climate/xmacis.php?wfo=lot

# SETTTINGS
cd = os.path.join(os.path.dirname(__file__))

# INITIAL DATA FRAME
weather_df = pd.read_csv(os.path.join(cd, 'NOAA_Chicago_Weather.csv'))

print(weather_df.dtypes)
print(weather_df.head())

# CLEAN UP SPECIAL CODES IN LAST THREE COLUMNS
for col in ['Precipitation', 'NewSnow', 'SnowDepth']:
    weather_df[col] = weather_df[col].str.strip()
    weather_df[col] = weather_df[col].where(~weather_df[col].isin(['T', 'M']),
                                            np.nan).astype(float)
    
print(weather_df.dtypes)
print(weather_df.head())

# EXPORT TO CSV
weather_df.to_csv(os.path.join('Chicago_Weather_Data.csv'), index=False)
