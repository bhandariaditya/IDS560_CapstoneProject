import os
import sys
import pytz
import time
import pandas as pd
import sqlalchemy as sql

import xlrd
import requests
import numpy as np
import urllib.request
from bs4 import BeautifulSoup as bs

time_init = time.time()

engine = sql.create_engine("mssql+pyodbc://uic-f1-admin:Noisette4@uic-f1.database.windows.net:1433/test_db_azure?driver=ODBC+Driver+13+for+SQL+Server")
results = [each for each in os.listdir('/Users/adityabhandari/Box/Financial Dashboard 2.0/Company Files/') if each.endswith('.xlsx')]
cols = ['CIK','company_name','period','financial_statement','group','sub_group1','debit_credit','helement','element','amount']

company_dict = {
    "CIK":['0001605484','0000037996','0001467858','0000715153','0001318605','0001094517','0000350698','0001170010','0001034670','0001707092','0001024725','0001590976','0001638290','0000793952','0000931015','0000107687','0000024491','0000042582'],
    "TCKR":['FCAU','F','GM','HMC','TSLA','TM','AN','KMX','ALV','DLPH','TEN','MBUU','MCFT','HOG','PII','WGO','CTB','GT'],
    "COMPANY":['Fiat Chrysler Automobiles N.V.','FORD MOTOR CO','General Motors Co','HONDA MOTOR CO LTD','Tesla, Inc.','TOYOTA MOTOR CORP','AutoNation, Inc.','CarMax Inc.','Autoliv, Inc.','Delphi Automotive Plc.','Tenneco Inc.','Malibu Boats, Inc.','MCBC Holdings Inc.','Harley-Davidson, Inc.','Polaris Industries Inc.','Winnebago Industries, Inc.','Cooper Tire & Rubber Company','The Goodyear Tire & Rubber Company'],
    "FILE_USED":['20-F','10-K','10-K','20-F','10-K','20-F','10-K','10-K','10-K','10-K','10-K','10-K','10-K','10-K','10-K','10-K','10-K','10-K'],
    "CATEGORY":['Automobile Manufacturers','Automobile Manufacturers','Automobile Manufacturers','Automobile Manufacturers','Automobile Manufacturers','Automobile Manufacturers','Automobile Retailers','Automobile Retailers','Auto Part','Auto Part','Auto Part','Boating','Boating','Commercial and Specialty Vehicles','Commercial and Specialty Vehicles','Commercial and Specialty Vehicles','Tires','Tires']
}

text_dict = {'Acquisitions and dispositions', '}


# function to read webpage and generate a soup object with its content
def get_10K_link(CIK='0001318605', file_type='10-K'):
    
    url = "https://www.sec.gov/cgi-bin/browse-edgar?action=getcompany&CIK="+CIK+\
        "&type="+file_type+"&dateb=&owner=exclude&count=40"
    sauce = urllib.request.urlopen(url).read()
    soup = bs(sauce,'html.parser')
    links = []
    for link in soup.findAll('a'):
        
        if link.get('href').endswith('-index.htm'):
            req_url = link.get('href').split('/')
            req_url = req_url[4]+'/'+req_url[5]
            links.append(req_url)
    return links

def download_10K(acc_no_url_list):
    'writes individual excel files for 10K/20F in the given location'
    for acc_no_url in links:
        xl_url = "https://www.sec.gov/Archives/edgar/data/"+acc_no_url+"/Financial_Report.xlsx"
        #     urllib.urlretrieve(xl_url, "test.xlsx")
        resp = requests.get(xl_url)
        
        output = open('Financial_Report_'+str(acc_no_url[8:])+'.xlsx', 'wb')
        output.write(resp.content)
        output.close()

def read_10K(file_path):
    file = pd.ExcelFile(file_path)
    df = pd.read_excel(file, sheet=1)
    return df

def split(string):
    return string.split(' ')[0]

print("Dropping existing tables")
pd.io.sql.execute("DROP TABLE IF EXISTS balance_sheet", engine)
pd.io.sql.execute("DROP TABLE IF EXISTS income_statement", engine)

df = pd.DataFrame(company_dict)
df.to_sql('company_info', con=engine, if_exists='replace', index=False)
print("company_info table created")

# links = get_10K_link()
# download_10K(links)

## Pushing profit-loss and balance sheet data in a single table
for company in results:

    print("starting ", company)
    df_bs = pd.read_excel('/Users/adityabhandari/Box/Financial Dashboard 2.0/Company Files/'+company, sheet_name='balance sheet', names=cols)
    df_pl = pd.read_excel('/Users/adityabhandari/Box/Financial Dashboard 2.0/Company Files/'+company, sheet_name='profit and loss', names=cols)

    df_pl.loc[df_pl.helement == 'Provision for income taxes','group'] = "Tax"

    df_bs['period'] = df_bs.period.apply(split)
    df_pl['period'] = df_pl.period.apply(split)

    df_bs.amount = pd.to_numeric(df_bs.amount, errors='coerce')
    df_pl.amount = pd.to_numeric(df_pl.amount, errors='coerce')

    df_bs.amount.fillna(0)
    df_pl.amount.fillna(0)

    df_pl.to_sql('income_statement', con=engine, if_exists='append', index=False)
    df_bs.to_sql('balance_sheet', con=engine, if_exists='append', index=False)
    print("finished ", company)

engine.dispose()
print("Data pushed to the DB, time taken: ", time.time()/60 - time_init/60, "minutes")
