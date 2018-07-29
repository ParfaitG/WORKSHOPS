import os
import csv, sqlite3
from tkinter import *
from tkinter import ttk

import pandas as pd

cd = os.path.dirname(os.path.abspath(__file__))

conn = sqlite3.connect(os.path.join(cd, '../Data/CTA_Data.db'))
cur = conn.cursor()

class GUIapp():
    
    def __init__(self):
        self.root = Tk()
        self.buildControls()
        self.root.mainloop()

    def DBdata(self, sql):
        cur.execute(sql)
        dbdata = [str(row[0]) for row in cur.fetchall()]
        return(dbdata)

    def buildControls(self):        
        self.root.wm_title("GUI Tkinter Menu")
        self.root.iconphoto(True, PhotoImage(file="../Images/python.png"))
        self.root.eval('tk::PlaceWindow {} center'.format(self.root.winfo_pathname(self.root.winfo_id())))

        self.guiframe = Frame(self.root, width=1200, height=500, bd=1, relief=FLAT)
        self.guiframe.pack(padx=50, pady=25)

        # IMAGE
        self.photo = PhotoImage(file="../Images/Python_CTA.png")
        self.imglbl = Label(self.guiframe, image=self.photo)
        self.imglbl.photo = self.photo
        self.imglbl.grid(row=0, sticky=W, padx=5, pady=5)
        self.imglbl = Label(self.guiframe, text="Ridership and Stations Data Filter Menu", font=("Arial", 14)).\
                            grid(row=0, column=1, sticky=W, padx=5, pady=5)

        
        # YEAR
        self.yearlbl = Label(self.guiframe, text="Year", font=("Arial", 12)).grid(row=1, sticky=W, padx=5, pady=5)
        self.yearvar = StringVar()
        self.yearcbo = ttk.Combobox(self.guiframe, textvariable=self.yearvar, font=("Arial", 12), state='editable', width=40)        
        self.yearcbo.grid(row=1, column=1, sticky=W, padx=5, pady=5)
        self.yearcbo['values'] = [str(i) for i in list(range(2001,2019))]
        self.yearcbo.current(len(range(2001,2019))-1)


        # STATION
        self.stationlbl = Label(self.guiframe, text="Station", font=("Arial", 12)).grid(row=2, sticky=W, padx=5, pady=5)
        self.stationvar = StringVar()
        self.stationcbo = ttk.Combobox(self.guiframe, textvariable=self.stationvar, font=("Arial", 12), state='editable', width=40)        
        self.stationcbo.grid(row=2, column=1, sticky=W, padx=5, pady=5)
        self.station_list = self.DBdata("SELECT DISTINCT [stationname] FROM Ridership r ORDER BY [stationname]")    
        self.stationcbo['values'] = [''] + self.station_list
        self.stationcbo.current(0)
        
        # RAIL LINE
        self.linelbl = Label(self.guiframe, text="Line", font=("Arial", 12)).grid(row=3, sticky=W, padx=5, pady=5)
        self.linevar = StringVar()
        self.linecbo = ttk.Combobox(self.guiframe, textvariable=self.linevar, font=("Arial", 12),state='editable', width=40)        
        self.linecbo.grid(row=3, column=1, sticky=W, padx=5, pady=5)
        self.linecbo['values'] = ['', 'blue', 'brown', 'green', 'orange', 'pink', 'purple', 'purple exp', 'red', 'yellow']  
        self.linecbo.current(0)

        # DIRECTION
        self.directionlbl = Label(self.guiframe, text="Direction", font=("Arial", 12)).grid(row=4, sticky=W, padx=5, pady=5)
        self.directionvar = StringVar()
        self.directioncbo = ttk.Combobox(self.guiframe, textvariable=self.directionvar, font=("Arial", 12), state='editable', width=40)   
        self.directioncbo.grid(row=4, column=1, sticky=W, padx=5, pady=5)
        self.directioncbo['values'] = ['', 'N', 'S', 'E', 'W']
        self.directioncbo.current(0)

        # OUTPUT REPORT BUTTON 
        self.btnoutput = Button(self.guiframe, text="Output", font=("Arial", 12), width=35, command=self.SimpleTable).\
                                grid(row=5, column=1, sticky=W, padx=10, pady=5)


    def SimpleTable(self):

        strSQL = """SELECT r.station_id, '         ' || strftime('%m-%d-%Y', r.date, 'unixepoch') || '         ' As ride_date, 
                           '    ' || s.station_descriptive_name || '    ' as station_name, 
                           '    ' || r.rides || '    ' As rides, '    ' || s.direction_id || '    ' As direction
                    FROM Ridership r 
                    INNER JOIN Stations s ON r.station_id = s.map_id
                    WHERE strftime('%m-%d-%Y', r.date, 'unixepoch') LIKE ?
                      AND r.stationname = ?
                      AND s.direction_id = ?
                 """
        df = pd.read_sql(strSQL, conn, params=['%'+self.yearvar.get()+'%', self.stationvar.get(), self.directionvar.get()])

        # INITIALIZE NEW WINDOW FRAME
        self.tbl = Tk()
        self.tbl.eval('tk::PlaceWindow {} center'.format(self.tbl.winfo_pathname(self.tbl.winfo_id())))
        self.tbl.configure(background='white')
        self.canvas = Canvas(self.tbl, width=550, height=500)
                      
        self.tbl.wm_title("Output Table")
        rows = len(df)
        columns = len(df.columns)

        self.tblFrame = Frame(self.canvas, background="gray", bd=0, relief=FLAT, highlightbackground="white", highlightcolor="white", highlightthickness=0)

        self.tblScrollbar = Scrollbar(self.tbl, orient="vertical", command=self.canvas.yview)
        self.canvas.configure(yscrollcommand = self.tblScrollbar.set)

        self.tblScrollbar.pack(side="right", fill="y")        
        self.canvas.pack(side="left", fill="both", expand=True)        
        self.canvas.create_window((4,4), window=self.tblFrame, anchor="nw", tags="self.frame")
        self.tblFrame.bind("<Configure>", self.onFrameConfigure)
        
        self.tblFrame._widgets = []
        
        # HEADERS
        current_row = []
        for column in range(1,columns):
            label = Label(self.tblFrame, font=("Arial", 12), text=' '+df.columns[column]+' ',
                          borderwidth=0)
            label.grid(row=0, column=column, sticky="nsew", padx=1, pady=1)
            current_row.append(label)
        self.tblFrame._widgets.append(current_row)
        

        # DATA ROWS   
        for row in range(1,rows+1):
            bgcol = 'white' if row % 2 != 0 else 'gainsboro'
            current_row = []
            for column in range(1,columns):
                label = Label(self.tblFrame, font=("Arial", 12), text=df.ix[row-1,column], 
                              borderwidth=0, background=bgcol)
                label.grid(row=row, column=column, sticky="nsew", padx=1, pady=1)
                current_row.append(label)
            self.tblFrame._widgets.append(current_row)

        for column in range(1,columns):
            self.tblFrame.grid_columnconfigure(column, weight=1)

        self.canvas.bind_all("<Button-4>", self._on_mousewheel)
        self.canvas.bind_all("<Button-5>", self._on_mousewheel)

    def _on_mousewheel(self, event):
        if event.num == 4:
           scroll = -1
           self.canvas.yview_scroll(scroll, "units")
        if event.num == 5:
           scroll = 1
           self.canvas.yview_scroll(scroll, "units")

    def onFrameConfigure(self, event):
        '''Reset the scroll region to encompass the inner frame'''
        self.canvas.configure(scrollregion=self.canvas.bbox("all"))       
        

GUIapp()
cur.close()
conn.close()


