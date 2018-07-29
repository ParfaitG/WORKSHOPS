
import sqlite3

from flask import Flask
from flask import render_template, request
from flask import jsonify, flash

app = Flask(__name__)
app.secret_key = "888"

def db_connection():
    dbconn = sqlite3.connect('../Data/CTA_Data.db')
    cur = dbconn.cursor()         
    return (cur, dbconn)


@app.route('/', methods= ['GET',  'POST'])
def getdata(pick={'year':'', 'station':'', 'direction':''}):
    c, db = db_connection()

    # RETRIEVE ALL STATIONS
    sql = "SELECT DISTINCT [stationname] FROM Ridership r ORDER BY [stationname];"
    c.execute(sql)

    station_data = [i[0] for i in c.fetchall()]
    
    # RUN QUERY
    sql = """SELECT r.station_id, strftime('%m-%d-%Y', r.date, 'unixepoch') As ride_date, s.station_descriptive_name, r.rides, s.direction_id
             FROM Ridership r 
             INNER JOIN Stations s ON r.station_id = s.map_id
             WHERE strftime('%m-%d-%Y', r.date, 'unixepoch') LIKE :year
               AND r.stationname = :station
               AND s.direction_id = :direction
          """

    pick['year'] = '%' + pick['year'] + '%'
    c.execute(sql, pick)

    data = []
    for row in c.fetchall():    
        data.append({'station_id':row[0], 'date':row[1], 'station_name': row[2], 'rides':row[3], 'direction':row[4] })

    c.close()
    db.close()
 
    return render_template('output.html', stations=station_data, cta_data=data)

@app.route('/data', methods=['POST'])
def data():
    return getdata(pick={'year':request.form['year'], 'station':request.form['station'], 'direction':request.form['direction']})
    

if __name__ == '__main__':
    app.run(debug=True)
    
