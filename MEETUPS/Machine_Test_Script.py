#!/usr/bin/env python3
import os, platform, pwd
from io import StringIO
import re

import numpy as np
import pandas as pd
import datetime as dt

import matplotlib as mpl
import matplotlib.pyplot as plt
import seaborn as sns

from itertools import combinations, chain
import statsmodels.api as sm
import statsmodels.formula.api as smf

import psutil

### SETTINGS
mpl.use('Agg')
plt.ioff()

pd.set_option('display.width', 1000)
pd.set_option('display.max_columns', None) 
pd.set_option('max_colwidth', -1)

#################
### CPU SPECS
#################

sys_data = pd.DataFrame({'user': pwd.getpwuid(os.getuid())[0],
                         'os_type': platform.system(),
                         'os_release': platform.release(),
                         'os_version': platform.platform(),
                         'machine': platform.machine(),
                         'python_version': platform.python_version()
                        }, index=[0])
    
free_data = pd.DataFrame({'mem_total': np.nan, 
                          'mem_used': np.nan,
                          'mem_free': np.nan,
                          'swap_total': np.nan, 
                          'swap_used': np.nan,
                          'swap_free': np.nan
                         }, index=[0])

### LINUX MACHINES
if platform.system() in ["Linux", "Linux2"]:
    try:
        free_raw = tuple(map(int, os.popen('free').readlines()[1].split()[1:])) 
        swap_raw = tuple(map(int, os.popen('free').readlines()[2].split()[1:])) 

        free_data['mem_total'] = free_raw[0] / 1E3 
        free_data['mem_used'] = free_raw[1] / 1E3
        free_data['mem_free'] = free_raw[2] / 1E3
        free_data['swap_total'] = swap_raw[0] / 1E3
        free_data['swap_used'] = swap_raw[1] / 1E3
        free_data['swap_free'] = swap_raw[2] / 1E3

    except Exception as e:
        print(e)

    try:
        free_data['cpu_cores'] = int(os.popen("getconf _NPROCESSORS_ONLN").readlines()[0].split()[0])
    except Exception as e:
        print(e)

    try:
        free_data['cpu_speed'] = float(os.popen("lscpu | grep MHz").readlines()[0].split(':')[1].strip())
    except Exception as e:
        print(e)

    
### MAC OS MACHINES
elif platform.system() == "Darwin":
    try:
        txt = [t for t in os.popen("top -l 1 | head").readlines() if "PhysMem" in t][0].rstrip()
    
        txt = re.sub("PhysMem: | \(|\), ", "", txt)
        txt = re.sub(" used| wired| unused", ",", txt)
        vec = [int(t[:-1])*1000 if t.endswith('G') else int(t[:-1]) for t in txt.split(",")[:-1]]

        free_data['mem_total'] = sum(vec)
        free_data['mem_used'] = vec[0]
        free_data['mem_free'] = vec[2]

    except Exception as e:
        print(e)

    try:
        free_data['cpu_cores'] = os.popen("getconf _NPROCESSORS_ONLN").readlines()[0].rstrip()
    except Exception as e:
        print(e)

    try:
        free_data['cpu_speed'] = float(os.popen("sysctl hw.cpufrequency").readlines()[0].split(':')[1].strip()) / 1E6    
    except Exception as e:
        print(e)

### WINDOWS MACHINES
elif platform.system() in ["win32", "win64"]:
    try:
        free_data = (pd.concat([pd.read_table(StringIO(os.popen("wmic ComputerSystem get TotalPhysicalMemory").readlines()), sep="\s+"),
                                pd.read_table(StringIO(os.popen("wmic OS get FreePhysicalMemory,TotalVirtualMemorySize,FreeVirtualMemory").readlines()), sep="\s+")],
                               axis=1)
                       .rename(columns=["mem_total", "mem_free", "swap_free", "swap_total"])
                    )
    except Exception as e:
        print(e)
  
    try: 
        free_data['cpu_cores'] = os.popen("wmic cpu get NumberOfCores").readlines()[1].strip()
    except Exception as e:
        print(e)

    try:
        free_data['cpu_speed'] = os.popen("wmic cpu get CurrentClockSpeed").readlines()[1].strip()
    except Exception as e:
        print(e)

sys_data = sys_data.join(free_data)


def machine_run():
        
    #################
    ### DATA BUILD
    #################

    alpha = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
    data_tools = ['sas', 'stata', 'spss', 'python', 'r', 'julia']

    np.random.seed(2019)
    random_df = pd.DataFrame({'group': np.random.choice(data_tools, size=int(1E6)),
                              'float': np.random.randint(1, 15, int(1E6)),
                              'y_num': np.random.uniform(0, 100, int(1E6)),
                              'x_num1': np.random.uniform(0, 100, int(1E6)),
                              'x_num2': np.random.uniform(size=int(1E6)) * 10,
                              'x_num3': np.random.normal(10, 1, int(1E6)),
                              'x_num4': np.random.normal(50, 1, int(1E6)),
                              'x_num5': np.random.normal(100, 1, int(1E6)),
                              'char': [''.join(np.random.choice(list(alpha), 3)) for _ in range(int(1E6))],
                              'bool': np.random.choice([True, False], int(1E6)),
                              'date': np.random.choice(pd.date_range('2000-01-01', 
                                                                     dt.datetime.today().strftime('%Y-%m-%d')), int(1E6)),
                               })
    
    #################
    ### AGGREGATION
    #################
    
    agg_df = (random_df.groupby('group')['y_num', 'x_num1', 'x_num2', 'x_num3', 'x_num4', 'x_num5']
                       .agg(['sum', 'mean', 'median', 'min', 'max'])
             )
    
    
    #################
    ### PLOT
    #################
    
    sns.set()
    
    # HISTOGRAM BY GROUP
    plt.figure(figsize=(15,5))
    
    plt.hist(random_df.query("group == 'julia'")['y_num'], bins=50, label='julia')
    plt.hist(random_df.query("group == 'r'")['y_num'], bins=50, label='r')
    plt.hist(random_df.query("group == 'python'")['y_num'], bins=50, label='python')
    plt.hist(random_df.query("group == 'sas'")['y_num'], bins=50, label='sas')
    plt.hist(random_df.query("group == 'stata'")['y_num'], bins=50, label='stata')
    plt.hist(random_df.query("group == 'spss'")['y_num'], bins=50, label='spss')
    
    plt.title("Overlapping Histograms", weight='bold', size=24)
    plt.legend(loc='upper right')
    plt.clf()
    plt.close('all')
    
    # BAR PLOT BY GROUP AND YEAR
    fig, ax = plt.subplots(figsize=(15,6))
    
    grp_df = (random_df.assign(year = random_df['date'].dt.year)
                       .groupby(['group','year'], as_index=False)['y_num']
                       .mean()
              )
    
    sns.barplot(x='year', y='y_num', hue='group', data=grp_df)
    
    plt.title('Barplot by Group and Year', weight='bold', size=20)
    plt.xlabel('Groups', weight='bold', size=18)
    plt.ylabel('Mean of Y', weight='bold', size=16)
    plt.xticks(ha='right')
    
    plt.tight_layout()
    plt.clf()
    plt.close()
    

    #################
    ### MODEL RUN
    #################
    
    def powerset(iterable):
        "powerset([1,2,3]) --> () (1,) (2,) (3,) (1,2) (1,3) (2,3) (1,2,3)"
        s = list(iterable)
        return chain.from_iterable(combinations(s, r) for r in range(len(s)+1))
    
    expvar_list = filter(len, powerset(['x_num'+str(i) for i in range(1,6)]))
    formulas_list = ['y_num ~ {} + group'.format(" + ".join(f)) for f in list(expvar_list)]
            
    models = [smf.ols(f, data=sm.add_constant(random_df)).fit() for f in formulas_list]
    
    
    #################
    ### RESULTS
    #################
    
    coeff_dfs = [pd.DataFrame({'coeff': m.params, 
                               't_stats': m.tvalues,
                               'std_err': m.bse,
                               'p_values': m.pvalues,
                               'low_ci': m.conf_int()[0],
                               'high_ci': m.conf_int()[1]}) for m in models]
    
    anova_dfs = [pd.DataFrame({'obs': m.nobs,
                               'df_resid': m.df_resid,
                               'r_sq': m.rsquared,
                               'r_sq_adj': m.rsquared_adj,
                               'f_value': m.fvalue,
                               'f_pvalue': m.f_pvalue,
                               'ssr': m.ssr,
                               'ess': m.ess,
                               'mse_model': m.mse_model,
                               'mse_resid': m.mse_resid,
                               'mse_total': m.mse_total}, index=[0]) for m in models]
    
    plot_results = []
    
    for m in models:
        fig, ax = plt.subplots(figsize=(15,5))
            
        sns.barplot(x=m.params[1:].index, y=m.params[1:])
        
        plt.title('Barplot of Coefficients', weight='bold', size=18)
        plt.xlabel('Explanatory Variables', weight='bold', size=16)
        plt.ylabel('Estimate', weight='bold', size=16)
        plt.xticks(ha='center')
        
        plt.tight_layout()
        plt.clf()
        plt.close()
        
        plot_results.append(fig)
    

#####################
### BENCHMARK
#####################

if __name__=='__main__':
    from timeit import Timer

    ### RUNTIME MEMORY    
    machine_run()

    # NUMBERS IN BYTES
    process = psutil.Process(os.getpid()).memory_info()      
    sys_data = sys_data.join(pd.DataFrame({'physical_memory_used': process.rss / 1E6, 
                                           'virtual_memory_used': process.vms / 1E6
                                          }, index=[0])
                            )
 
    # TIMINGS
    f = Timer("machine_run()", "from __main__ import machine_run")
    res = f.repeat(repeat=5, number=1)
    
    sys_data = sys_data.join(pd.DataFrame({'min': np.min(res),
                                           'mean': np.mean(res),
                                           'median': np.median(res),
                                           'max': np.max(res),
                                           'neval': 5}, index=[0])
                            )

# OUTPUT TO SCREEN
print(sys_data)

# OUTPUT TO FILE
sys_data.to_csv("Machine_Test_Results_py.csv", index=False)
