import subprocess
from io import StringIO
import pandas as pd
import sqlite3
from sqlite3 import Error
import os

columns = ['jobid', 'status', 'step', 'step_id']

def create_connection(db_file):
    """ create a database connection to a SQLite database """
    conn = None
    try:
        conn = sqlite3.connect(db_file)
        return conn
    except Error as e:
        print(e)
    return conn

def create_database(conn):
    """ creates database """

    sql_table = """ CREATE TABLE IF NOT EXISTS jobs (
                    id integer PRIMARY KEY,
                    jobid text NOT NULL UNIQUE,
                    status text NOT NULL,
                    step text NOT NULL,
                    step_id integer NOT NULL,
                    UNIQUE(step, step_id)
                ); """

    cur = conn.cursor()
    try:
        cur.execute(sql_table)
    except Error as e:
        print(e)

def read_database(conn):
    return pd.read_sql_query("SELECT * from jobs", conn).reset_index(drop=True)[columns]

def save_database(conn, df):
    df.reset_index(drop=True)[columns].to_sql("jobs", conn, if_exists="replace")

def parse_output(output):
    input = StringIO(output)
    try:
        df = pd.read_csv(input, skipfooter=1, sep='\s+', engine='python', skiprows=1, names=['jobid', 'owner', 'subday', 'subtime', 'runtime', 'status', 'prio', 'size', 'command'])
    except Exception as error:
        print(error)
        print("Could not parse jobsub_q output ... check output below:")
        for l in input.readlines():
            print(l, end='')
        exit(0)

    running = df[df.status != 'H']
    return running

def get_jobs():
    output = subprocess.run(["jobsub_q", "-G", "dune", os.getlogin()], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    return parse_output(output.stdout.decode("utf-8"))


def get_finished(conn):
    jobs = get_jobs()
    jobs = jobs.reset_index(drop=True)

    df = read_database(conn)
    df = df.reset_index(drop=True)

    merged = df.merge(jobs, on='jobid', how='outer', indicator=True, suffixes=['_old', None])
    

    finished = merged[merged['_merge'] == 'left_only']
    finished['step_id'] = finished['step_id'].astype(int)
    

    new_db = merged[merged['_merge'] == 'both'].reset_index(drop=True)[columns]
    new_db['step_id'] = new_db['step_id'].astype(int)

    return finished, new_db


