#!/usr/bin/env python3
import os
import numpy as np
import pandas as pd

cd = os.path.join(os.path.dirname(__file__))

# INITIAL DATA FRAMES
ue_df = pd.read_csv(os.path.join(cd, 'STL_Fed_Reserve_Unemployment.csv'), parse_dates=[0])
print(ue_df.describe())
print(ue_df.dtypes)
print(ue_df.shape)
print(ue_df.head(10))

dates_df = pd.DataFrame({'DATE': pd.date_range(start='2001-01-01', end='2018-09-30')})
print(dates_df.head(10))

# EXPAND DATA FRAME FOR DAILY RECORDS
final_df = (pd.merge(dates_df, ue_df, on='DATE', how='left')
              .sort_values('DATE')
              .rename({'CHIC917URN':'UE_Rate'}, axis='columns')
           )

# FORWARD FILL MONTHLY RATES
final_df['UE_Rate'] = final_df['UE_Rate'].ffill()

print(final_df.tail(10))

# EXPORT TO CSV
final_df.to_csv(os.path.join(cd, 'Chicago_Unemployment_Rates.csv'), index=False)