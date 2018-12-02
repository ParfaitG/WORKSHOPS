#!/usr/bin/env python3
import os
import numpy as np
import pandas as pd

# SETTTINGS
cd = os.path.join(os.path.dirname(__file__))

pd.set_option('display.width', 10000)
pd.set_option('display.max_rows', None)
pd.set_option('display.max_columns', None)

# INITIAL DATA FRAMES
gas_df = pd.read_csv(os.path.join(cd, 'EIA_Retail_Gasoline_Prices.csv'), parse_dates=[0])
print(gas_df.head(10))

dates_df = pd.DataFrame({'Date': pd.date_range(start='2001-01-01', end='2018-09-30')})
print(dates_df.head(10))

## CONVERT WEEK DATES STRINGS TO DATES
for wk in ['Week1_EndDate', 'Week2_EndDate', 'Week3_EndDate', 'Week4_EndDate', 'Week5_EndDate']:
    gas_df[wk] =  gas_df[wk].where(gas_df[wk].str.strip() == '', 
                                   gas_df[wk].str.strip() + '/' + \
                                       gas_df['Month_Year'].dt.year.astype('str') 
                      
                                  )
    
    gas_df[wk] =  gas_df[wk].where(gas_df[wk].str.strip() != '',
                                   np.nan)
    
    gas_df[wk] = pd.to_datetime(gas_df[wk], format='%m/%d/%Y')
                      
print(gas_df.head(10))


# CLEAN UP VARYING WEEK 5 COLUMN
gas_df['Week5_Value'] = gas_df['Week5_Value'].where(gas_df['Week5_Value'].str.strip() != '',
                                                     np.nan).astype('float')
gas_df = gas_df.set_index('Month_Year')


# BUILD LIST OF WEEK DFS
df_list = [(gas_df.filter(like=str(i))
                  .rename({'Week'+str(i)+'_EndDate': 'Date',
                           'Week'+str(i)+'_Value': 'Gas_Price'},
                          axis='columns')
                  .query('Gas_Price > 0')
                  .reset_index(drop=True)
           ) for i in range(1,6)]

for df in df_list:
    print(df.head())
    print()
    
# APPEND ALL WEEK DFS
final_df = pd.concat(df_list, ignore_index=True).sort_values('Date')

# EXPAND DATA FRAME FOR DAILY RECORDS
final_df = pd.merge(dates_df, final_df, on='Date', how='left')
print(final_df.head(20))

# FORWARD FILL WEEKLY PRICES
final_df['Gas_Price'] = final_df['Gas_Price'].ffill()
print(final_df.head(20))

# EXPORT TO CSV
final_df.to_csv(os.path.join(cd, 'US_Gas_Prices.csv'), index=False)


